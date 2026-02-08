import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_app_updated/Components/button_widget/button_widget.dart';
import 'package:trust_app_updated/Components/text_field_widget/text_field_widget.dart';
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

      String? productName;
      int? productId;

      if (productResponse.containsKey('response')) {
        final product = productResponse['response'];
        productName = product['name'];
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
    final result = await ScanningService.scanFromImage(context);
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
      color: const Color(0xffD51C29),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: const Color(0xffD51C29),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(isRTL),
                _buildTopButtons(),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xffF0F0F0),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildCustomerInformation(),
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
          ),
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(bool isRTL) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xffD51C29)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: isRTL ? null : 0,
            right: isRTL ? 0 : null,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 28, color: Colors.white),
            ),
          ),
          Center(
            child: Text(
              AppLocalizations.of(context)!.warranty_activation,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleButton(
            icon: Icons.security,
            label: AppLocalizations.of(context)!.protect,
            onTap: () {},
          ),
          _buildCircleButton(
            icon: Icons.qr_code_scanner,
            label: AppLocalizations.of(context)!.scan,
            onTap: () {},
          ),
          _buildCircleButton(
            icon: Icons.check_circle,
            label: AppLocalizations.of(context)!.activate,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  /// Build circle button
  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build customer information section
  Widget _buildCustomerInformation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xffD51C29), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.customer_information,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _customerNameController,
                  hintText: AppLocalizations.of(context)!.enter_customer_full_name,
                  backgroundColor: const Color(0xffF7F9FA),
                  borderColor: const Color(0xffEBEBEB),
                  borderRadius: 15,
                  height: 55,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!
                          .please_enter_a_your_customer_name;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: _customerPhoneController,
                  hintText: AppLocalizations.of(context)!.enter_phone_number,
                  backgroundColor: const Color(0xffF7F9FA),
                  borderColor: const Color(0xffEBEBEB),
                  borderRadius: 15,
                  height: 55,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context)!
                          .please_enter_a_customer_phone_number;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                CustomTextField(
                  controller: _idNumberController,
                  hintText: AppLocalizations.of(context)!.id_number,
                  backgroundColor: const Color(0xffF7F9FA),
                  borderColor: const Color(0xffEBEBEB),
                  borderRadius: 15,
                  height: 55,
                  validator: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build add products section
  Widget _buildAddProducts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2, color: Color(0xffD51C29), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.add_products,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.serial_number,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _serialNumberController,
                      hintText: AppLocalizations.of(context)!
                          .enter_or_scan_serial_number,
                      backgroundColor: const Color(0xffF7F9FA),
                      borderColor: const Color(0xffEBEBEB),
                      borderRadius: 15,
                      height: 55,
                      validator: null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: MAIN_COLOR,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _addProduct,
                      icon: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildScanButton(
                      icon: Icons.qr_code_scanner,
                      label: AppLocalizations.of(context)!.scan_barcode,
                      onTap: _scanBarcode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildScanButton(
                      icon: Icons.image,
                      label: AppLocalizations.of(context)!.scan_from_image,
                      onTap: _scanFromImage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffE8F4FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.multiple_products_info,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
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

  /// Build scan button
  Widget _buildScanButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: product.isActive ? Colors.orange : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: product.isActive
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  product.isActive ? Icons.warning : Icons.check_circle,
                  color: product.isActive ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName ?? 'Unknown Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.serialNumber,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeProduct(index),
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
          if (product.isActive) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.errorMessage ?? 'Already Active',
                      style: const TextStyle(
                        fontSize: 12,
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
        height: 55,
        width: double.infinity,
        BorderColor: MAIN_COLOR,
        FontSize: 18,
        OnClickFunction: _isSubmitting ? () {} : _submitWarranties,
        BorderRaduis: 15,
        ButtonColor: MAIN_COLOR,
        NameColor: Colors.white,
      ),
    );
  }
}
