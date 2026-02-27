import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_app_updated/Models/warranty_product_model.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';
import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/Services/scanning_service/scanning_service.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Warranty Activation Screen - Redesigned to match UI mockup
class WarrantyActivationScreen extends StatefulWidget {
  const WarrantyActivationScreen({super.key});

  @override
  State<WarrantyActivationScreen> createState() => _WarrantyActivationScreenState();
}

class _WarrantyActivationScreenState extends State<WarrantyActivationScreen> {
  // Static variable to persist products across navigation
  static List<WarrantyProductModel> _savedProducts = [];
  static String _savedCustomerName = '';
  static String _savedCustomerPhone = '';

  // Form keys
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();

  // State
  List<WarrantyProductModel> _products = [];
  int _merchantId = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeMerchantId();
    // Restore saved state
    _products = List.from(_savedProducts);
    _customerNameController.text = _savedCustomerName;
    _customerPhoneController.text = _savedCustomerPhone;
  }

  @override
  void dispose() {
    // Save state before disposing
    _savedProducts = List.from(_products);
    _savedCustomerName = _customerNameController.text;
    _savedCustomerPhone = _customerPhoneController.text;
    
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }

  /// Initialize merchant ID from shared preferences
  Future<void> _initializeMerchantId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final merchantIdStr = prefs.getString('merchant_id');
      if (merchantIdStr != null && merchantIdStr.isNotEmpty) {
        setState(() {
          _merchantId = int.parse(merchantIdStr);
        });
      }
    } catch (e) {
      debugPrint('Error initializing merchant ID: $e');
    }
  }

  /// Add product to list with validation (WITHOUT activating)
  Future<void> _addProduct() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      _showError(AppLocalizations.of(context)!.please_fill_required_fields);
      return;
    }

    final serialNumber = _serialNumberController.text.trim();

    // Validate serial number format
    if (!WarrantyProductModel.isValidSerialFormat(serialNumber)) {
      _showError(AppLocalizations.of(context)!.invalid_serial_format);
      return;
    }

    // Check if serial number already added
    if (_products.any((p) => p.serialNumber == serialNumber)) {
      _showError(AppLocalizations.of(context)!.serial_already_added);
      return;
    }

    // Validate merchant ID
    if (_merchantId == 0) {
      _showError('Merchant ID not found');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check warranty status
      final warrantyResponse = await getRequest(
        '$URL_WARRANTIES_BY_PRODUCT_SERIAL_NUMBER/$serialNumber',
      );

      // Get product details
      final firstTwoParts = serialNumber.split('-').take(2).join('-');
      final productResponse = await getRequest(
        '$URL_PRODUCT_BY_FIRST_SERIAL_PART/$firstTwoParts',
      );

      if (!productResponse.containsKey('response')) {
        _showError(AppLocalizations.of(context)!.product_not_found);
        setState(() => _isLoading = false);
        return;
      }

      final product = productResponse['response'];
      final productId = product['id'];
      final productName = product['name'] ?? 'Unknown Product';
      String? productImage;
      
      // Parse image from JSON array
      if (product['image'] != null && product['image'].toString().isNotEmpty) {
        try {
          final imageList = json.decode(product['image']);
          if (imageList is List && imageList.isNotEmpty) {
            productImage = URLIMAGE + imageList[0].toString();
          }
        } catch (e) {
          debugPrint('Error parsing image: $e');
        }
      }

      // Check if warranty already exists
      bool isAlreadyActive = warrantyResponse.containsKey('response');

      // Add product to list
      final warrantyProduct = WarrantyProductModel(
        serialNumber: serialNumber,
        productName: productName,
        productImage: productImage,
        productId: productId,
        isValid: !isAlreadyActive, // Valid if not already active
        isActive: isAlreadyActive,
        errorMessage: isAlreadyActive ? AppLocalizations.of(context)!.warranty_already_active : null,
      );

      setState(() {
        _products.add(warrantyProduct);
        _serialNumberController.clear();
        _isLoading = false;
      });

      _showSuccess(AppLocalizations.of(context)!.product_added);
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Remove product from list
  void _removeProduct(int index) {
    setState(() {
      _products.removeAt(index);
    });
  }

  /// Scan barcode
  Future<void> _scanBarcode() async {
    final result = await ScanningService.scanBarcode(context);
    if (result != null) {
      setState(() {
        _serialNumberController.text = result;
      });
      _showSuccess('Barcode scanned: $result');
    } else {
      _showError(AppLocalizations.of(context)!.no_barcode_found);
    }
  }

  /// Scan from image/camera
  Future<void> _scanFromImage() async {
    setState(() => _isLoading = true);
    final result = await ScanningService.scanFromCamera(context);
    setState(() => _isLoading = false);

    if (result != null) {
      setState(() {
        _serialNumberController.text = result;
      });
      _showSuccess('Serial number extracted: $result');
    } else {
      _showError(AppLocalizations.of(context)!.no_text_found);
    }
  }

  /// Submit all valid warranties using batch API
  Future<void> _submitWarranties() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate products
    if (_products.isEmpty) {
      _showError(AppLocalizations.of(context)!.at_least_one_product);
      return;
    }

    // Get only valid products (not already active)
    final validProducts = _products.where((p) => p.isValid).toList();

    if (validProducts.isEmpty) {
      _showError('No valid products to activate');
      return;
    }

    // Validate merchant ID
    if (_merchantId == 0) {
      _showError('Merchant ID not found');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare batch warranty data
      final List<Map<String, dynamic>> warrantiesData = validProducts.map((product) {
        return {
          "customerPhone": _customerPhoneController.text.trim(),
          "customerName": _customerNameController.text.trim(),
          "productSerialNumber": product.serialNumber,
          "productId": product.productId,
          "merchantId": _merchantId,
          "notes": "",
        };
      }).toList();

      // Submit batch warranties
      final url = Uri.parse(URL_WARRANTIES);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(warrantiesData),
      );

      final data = json.decode(response.body);
      
      if (data["success"] == true) {
        _showSuccess(AppLocalizations.of(context)!.warranties_submitted_successfully);
        
        // Clear form, products, and saved state
        _customerNameController.clear();
        _customerPhoneController.clear();
        setState(() => _products.clear());
        _savedProducts.clear();
        _savedCustomerName = '';
        _savedCustomerPhone = '';

        // Navigate back after a delay
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showError(data["message"] ?? AppLocalizations.of(context)!.some_warranties_failed);
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// Show error message
  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  int get _validProductCount => _products.where((p) => p.isValid).length;

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';

    return Container(
      color: const Color(0xffe33131),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Column(
            children: [
              _buildHeader(isRTL),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTopSection(isRTL),
                      const SizedBox(height: 0),
                      _buildAddProducts(),
                      const SizedBox(height: 20),
                      if (_products.isNotEmpty) ...[
                        _buildProductsList(),
                        const SizedBox(height: 20),
                      ],
                      _buildImportantNote(),
                      const SizedBox(height: 20),
                      if (_products.isNotEmpty && _validProductCount > 0) 
                        _buildActivateButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(bool isRTL) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xffe33131)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: isRTL ? null : 8,
            right: isRTL ? 8 : null,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
            ),
          ),
          Center(
            child: Text(
              AppLocalizations.of(context)!.warranty_activation,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build top section with buttons and customer info
  Widget _buildTopSection(bool isRTL) {
    return Column(
      children: [
        Container(
          color: const Color(0xffe33131),
          child: Column(
            children: [
              _buildTopButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Transform.translate(
            offset: const Offset(0, -30),
            child: _buildCustomerInformation(),
          ),
        ),
      ],
    );
  }

  /// Build top action buttons
  Widget _buildTopButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.shield_outlined,
            label: AppLocalizations.of(context)!.protect,
            onTap: () {},
          ),
          _buildActionButtonSvg(
            svgPath: 'assets/icon/scan.svg',
            label: AppLocalizations.of(context)!.scan,
            onTap: () {},
          ),
          _buildActionButton(
            icon: Icons.check_circle_outline,
            label: AppLocalizations.of(context)!.activate,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  /// Build action button
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action button with SVG icon
  Widget _buildActionButtonSvg({
    required String svgPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SvgPicture.asset(
                svgPath,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                width: 24,
                height: 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build customer information section
  Widget _buildCustomerInformation() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: Color(0xffEF4444), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.customer_information,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                '${AppLocalizations.of(context)!.customer_name} *',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _customerNameController,
                enabled: true,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enter_customer_full_name,
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffEF4444)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.please_enter_a_your_customer_name;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                '${AppLocalizations.of(context)!.phone_number} *',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                enabled: true,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enter_phone_number,
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xffEF4444)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.please_enter_a_customer_phone_number;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ))
    );
  }

  /// Build add products section
  Widget _buildAddProducts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xffEF4444),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.add_products,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.serial_number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _serialNumberController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.enter_serial_number,
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xffEF4444)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Camera scan button
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _scanFromImage,
                      icon: const Icon(Icons.camera_alt, color: Color(0xffEF4444), size: 20),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Barcode scan button
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner, color: Color(0xffEF4444), size: 20),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add button
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xffEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _addProduct,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build products list with header
  Widget _buildProductsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xffEF4444), size: 16),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.products_to_activate,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_products.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _products.length,
            (index) => _buildProductCard(_products[index], index),
          ),
        ],
      ),
    );
  }

  /// Build product card with image
  Widget _buildProductCard(WarrantyProductModel product, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product.isValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: product.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 30),
          ),
          const SizedBox(width: 12),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName ?? 'Unknown Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.serialNumber,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: product.isValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      product.isValid 
                          ? AppLocalizations.of(context)!.valid 
                          : AppLocalizations.of(context)!.warranty_already_active,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: product.isValid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            onPressed: () => _removeProduct(index),
            icon: const Icon(Icons.delete_outline, color: Color(0xffEF4444), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build "Ready to Activate" section
  /// Build important note section
  Widget _buildImportantNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.important_note,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.important_note_message,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF374151),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                    ),
                    child: const Text(
                      '210-16480-[Phone Number]',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Example: 210-16480-0512345678',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitWarranties,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8A8A),
            disabledBackgroundColor: const Color(0xFFFFB4B4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${AppLocalizations.of(context)!.activate_warranties} $_validProductCount ${AppLocalizations.of(context)!.products_text}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'GESSTextMedium-edited',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
