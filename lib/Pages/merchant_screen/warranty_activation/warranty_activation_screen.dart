import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_app_updated/Components/button_widget/button_widget.dart';
import 'package:trust_app_updated/Constants/constants.dart';
import 'package:trust_app_updated/Models/warranty_product_model.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';
import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/Services/scanning_service/scanning_service.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/main.dart';

/// Warranty Activation Screen - Clean and modular implementation
class WarrantyActivationScreen extends StatefulWidget {
  const WarrantyActivationScreen({super.key});

  @override
  State<WarrantyActivationScreen> createState() => _WarrantyActivationScreenState();
}

class _WarrantyActivationScreenState extends State<WarrantyActivationScreen> {
  // Form keys
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
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
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _idNumberController.dispose();
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

  /// Add product and activate warranty immediately
  Future<void> _addProduct() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill in all required customer information');
      return;
    }

    final serialNumber = _serialNumberController.text.trim();

    // Validate serial number format
    if (!WarrantyProductModel.isValidSerialFormat(serialNumber)) {
      _showError(AppLocalizations.of(context)!.invalid_serial_format);
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

      int? productId;

      if (productResponse.containsKey('response')) {
        final product = productResponse['response'];
        productId = product['id'];
      } else {
        _showError('Product not found');
        setState(() => _isLoading = false);
        return;
      }

      // Check if warranty already exists
      if (warrantyResponse.containsKey('response')) {
        _showError(AppLocalizations.of(context)!.effectice);
        setState(() => _isLoading = false);
        return;
      }

      // Activate warranty immediately
      await addWarranty(
        _customerPhoneController.text.trim(),
        _customerNameController.text.trim(),
        serialNumber,
        productId.toString(),
        _idNumberController.text.trim(),
        _merchantId.toString(),
        '',
        context,
      );

      setState(() => _isLoading = false);
      
      // Show success and go back
      _showSuccess(AppLocalizations.of(context)!.warranties_submitted_successfully);
      
      // Wait a moment for user to see success message, then go back
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
      }
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
      // Show success feedback
      _showSuccess('Barcode scanned: $result');
    } else {
      _showError(AppLocalizations.of(context)!.no_barcode_found);
    }
  }

  /// Scan from image
  Future<void> _scanFromImage() async {
    setState(() => _isLoading = true);
    final result = await ScanningService.scanFromCamera(context);
    setState(() => _isLoading = false);

    if (result != null) {
      setState(() {
        _serialNumberController.text = result;
      });
      // Show success feedback
      _showSuccess('Serial number extracted: $result');
    } else {
      _showError(AppLocalizations.of(context)!.no_text_found);
    }
  }

  /// Submit all warranties
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

    // Validate merchant ID
    if (_merchantId == 0) {
      _showError('Merchant ID not found');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      int failCount = 0;

      for (final product in _products) {
        // Skip already active warranties
        if (product.isActive) {
          continue;
        }

        try {
          await addWarranty(
            _customerPhoneController.text.trim(),
            _customerNameController.text.trim(),
            product.serialNumber,
            product.productId.toString(),
            _idNumberController.text.trim(),
            _merchantId.toString(),
            '',
            context,
          );
        } catch (e) {
          debugPrint('Failed to add warranty: $e');
          failCount++;
        }
      }

      if (failCount == 0) {
        _showSuccess(AppLocalizations.of(context)!.warranties_submitted_successfully);
        // Clear form
        _customerNameController.clear();
        _customerPhoneController.clear();
        _idNumberController.clear();
        setState(() => _products.clear());
      } else {
        _showError(AppLocalizations.of(context)!.some_warranties_failed);
      }
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

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';

    return Container(
      color: const Color(0xffe33131),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xffe33131),
          body: SingleChildScrollView(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(isRTL),
                    _buildTopButtons(),
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F5F5),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 220),
                          _buildAddProducts(),
                          if (_products.isNotEmpty) _buildProductsList(),
                          const SizedBox(height: 20),
                          if (_products.isNotEmpty) _buildSubmitButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 165,
                  left: 20,
                  right: 20,
                  child: _buildCustomerInformation(),
                ),
              ],
            ),
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
    return Container(
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
                      return AppLocalizations.of(context)!
                          .please_enter_a_your_customer_name;
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
                      return AppLocalizations.of(context)!
                          .please_enter_a_customer_phone_number;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
    );
  }

  /// Build add products section
  Widget _buildAddProducts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
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
                        hintText: AppLocalizations.of(context)!
                            .enter_or_scan_serial_number,
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
                    ),
                  ),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanBarcode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: Text(
                    AppLocalizations.of(context)!.scan_with_camera,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanFromImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.image, size: 16),
                  label: Text(
                    AppLocalizations.of(context)!.scan_from_image,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xff3B82F6), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.multiple_products_info,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff3B82F6),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build products list
  Widget _buildProductsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        children: List.generate(
          _products.length,
          (index) => _buildProductCard(_products[index], index),
        ),
      ),
    );
  }

  /// Build product card
  Widget _buildProductCard(WarrantyProductModel product, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product.isActive ? Colors.orange : Colors.green,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: product.isActive
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  product.isActive ? Icons.warning : Icons.check_circle,
                  color: product.isActive ? Colors.orange : Colors.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.serialNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeProduct(index),
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (product.isActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      product.errorMessage ?? 'Already Active',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build submit button
  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: ButtonWidget(
        name: AppLocalizations.of(context)!.submit_warranties,
        height: 48,
        width: double.infinity,
        BorderColor: MAIN_COLOR,
        FontSize: 15,
        OnClickFunction: _isSubmitting ? () {} : _submitWarranties,
        BorderRaduis: 12,
        ButtonColor: MAIN_COLOR,
        NameColor: Colors.white,
      ),
    );
  }
}
