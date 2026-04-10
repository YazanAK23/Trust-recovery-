import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_app_updated/Components/drawer_widget/drawer_widget.dart';
import 'package:trust_app_updated/Components/responsive/app_responsive.dart';
import 'package:trust_app_updated/Models/warranty_product_model.dart';
import 'package:trust_app_updated/Pages/merchant_screen/warranties/warranties_screen.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();

  // State
  List<WarrantyProductModel> _products = [];
  int _merchantId = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Responsive helper – updated every build()
  late AppR _r;

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
    final serialNumber = _serialNumberController.text.trim();

    // Check if serial number is empty
    if (serialNumber.isEmpty) {
      _showError(AppLocalizations.of(context)!.enter_serial_number);
      return;
    }

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
      // Clear any existing value in the field before setting new scanned value
      setState(() {
        _serialNumberController.clear();
        _serialNumberController.text = result;
      });
      
      _showSuccess('Barcode scanned: $result');
      
      // Automatically try to add the product to the list
      await _addProductFromScan();
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
      // Clear any existing value in the field before setting new scanned value
      setState(() {
        _serialNumberController.clear();
        _serialNumberController.text = result;
      });
      
      _showSuccess('Serial number extracted: $result');
      
      // Automatically try to add the product to the list
      await _addProductFromScan();
    } else {
      _showError(AppLocalizations.of(context)!.no_text_found);
    }
  }

  /// Add product from scan (automatic) - keeps serial in field if error
  Future<void> _addProductFromScan() async {
    final serialNumber = _serialNumberController.text.trim();

    // Check if serial number is empty
    if (serialNumber.isEmpty) {
      _showError(AppLocalizations.of(context)!.enter_serial_number);
      // Keep the serial number in field so user can see it
      return;
    }

    // Validate serial number format
    if (!WarrantyProductModel.isValidSerialFormat(serialNumber)) {
      _showError(AppLocalizations.of(context)!.invalid_serial_format);
      // Keep the serial number in field so user can see the issue
      return;
    }

    // Check if serial number already added
    if (_products.any((p) => p.serialNumber == serialNumber)) {
      _showError(AppLocalizations.of(context)!.serial_already_added);
      // Keep the serial number in field so user can see the issue
      return;
    }

    // Validate merchant ID
    if (_merchantId == 0) {
      _showError('Merchant ID not found');
      // Keep the serial number in field so user can see the issue
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
        // Keep the serial number in field so user can see the issue
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
        // ONLY clear field if successfully added - this is the success case
        _serialNumberController.clear();
        _isLoading = false;
      });

      _showSuccess(AppLocalizations.of(context)!.product_added);
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isLoading = false);
      // Keep the serial number in field so user can see the issue
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
    final invalidProducts = _products.where((p) => !p.isValid).toList();

    // Check if there are invalid products
    if (invalidProducts.isNotEmpty) {
      // Show warning dialog
      final shouldProceed = await _showInvalidProductsDialog(invalidProducts, validProducts);
      if (!shouldProceed) {
        return; // User cancelled or wants to remove invalid products
      }
    }

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

        // Navigate to the activated warranties list after a delay
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const WarrantiesScreen(),
            ),
          );
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

  /// Handle activation button press - check for issues first
  Future<void> _handleActivateButtonPress() async {
    // Check if currently submitting
    if (_isSubmitting) {
      return;
    }

    // List to collect issues
    List<String> issues = [];
    final isRTL = locale.toString() == 'ar';

    // 1. Check customer information
    if (_customerNameController.text.trim().isEmpty) {
      issues.add(isRTL ? '• يجب إدخال اسم العميل' : '• Customer name is required');
    }
    if (_customerPhoneController.text.trim().isEmpty) {
      issues.add(isRTL ? '• يجب إدخال رقم هاتف العميل' : '• Customer phone is required');
    } else if (_customerPhoneController.text.trim().length < 8) {
      issues.add(isRTL ? '• رقم الهاتف يجب أن يكون 8 أرقام على الأقل' : '• Phone number must be at least 8 digits');
    }

    // 2. Check if products list is empty
    if (_products.isEmpty) {
      issues.add(isRTL ? '• يجب إضافة منتج واحد على الأقل' : '• At least one product must be added');
    } else if (_validProductCount == 0) {
      // 3. Check if all products have active warranties
      issues.add(isRTL 
        ? '• جميع المنتجات في القائمة لديها كفالة نشطة بالفعل'
        : '• All products in the list already have active warranties');
    }

    // If there are issues, show dialog
    if (issues.isNotEmpty) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRTL ? 'لا يمكن تفعيل الكفالات' : 'Cannot Activate Warranties',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRTL 
                      ? 'يرجى حل المشاكل التالية للمتابعة:'
                      : 'Please resolve the following issues to continue:',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: issues.map((issue) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            issue,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF92400E),
                              height: 1.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_products.isNotEmpty && _validProductCount == 0)
                    const SizedBox(height: 12),
                  if (_products.isNotEmpty && _validProductCount == 0)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF15803D), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isRTL
                                ? 'احذف المنتجات ذات الكفالة النشطة من القائمة'
                                : 'Delete products with active warranties from the list',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: Text(
                    isRTL ? 'حسناً' : 'OK',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'GESSTextMedium-edited',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    // If no issues, proceed with submission
    await _submitWarranties();
  }

  /// Show dialog for invalid products (already active warranties)
  Future<bool> _showInvalidProductsDialog(
    List<WarrantyProductModel> invalidProducts,
    List<WarrantyProductModel> validProducts,
  ) async {
    final isRTL = locale.toString() == 'ar';
    
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRTL ? 'خطأ: كفالات نشطة' : 'Error: Active Warranties',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRTL 
                    ? 'المنتجات التالية لديها كفالة نشطة بالفعل ولا يمكن تفعيلها. يجب عليك حذفها من القائمة:'
                    : 'The following products already have active warranties and cannot be activated. You must delete them from the list:',
                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: invalidProducts.map((product) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.productName ?? 'Unknown Product',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    product.serialNumber,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFBBF24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isRTL
                            ? 'انقر على أيقونة الحذف (X) بجانب كل منتج لإزالته من القائمة'
                            : 'Click the delete icon (X) next to each product to remove it from the list',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: Text(
                  isRTL ? 'حسناً' : 'OK',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'GESSTextMedium-edited',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // Always return false to prevent submission
    return false;
  }

  int get _validProductCount => _products.where((p) => p.isValid).length;

  @override
  Widget build(BuildContext context) {
    _r = AppR(context);
    final isRTL = locale.toString() == 'ar';

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: DrawerWell(
        Refresh: () {
          setState(() {});
        },
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Scrollable content including header
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: Column(
              children: [
                // Header (now scrollable)
                Container(
                  color: const Color(0xffe33131),
                  child: SafeArea(
                    bottom: false,
                    child: _buildHeader(isRTL),
                  ),
                ),
                // Rest of the content with gray background
                Container(
                  color: const Color(0xFFF5F5F5),
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
                      const SizedBox(height: 140), // Space for fixed button
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Fixed button at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _buildActivateButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build header
  Widget _buildHeader(bool isRTL) {
    return Container(
      height: _r.headerH,
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
              icon: Icon(Icons.arrow_back, size: _r.actionBtnIconSize, color: Colors.white),
            ),
          ),
          Center(
            child: Text(
              AppLocalizations.of(context)!.warranty_activation,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _r.fs18,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: isRTL ? 8 : null,
            right: isRTL ? null : 8,
            child: IconButton(
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              icon: SvgPicture.asset(
                'assets/images/new_icons/Menu.svg',
                width: _r.actionBtnIconSize,
                height: _r.actionBtnIconSize,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
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
              SizedBox(height: _r.dp(20)),
            ],
          ),
        ),
        Container(
          color: const Color(0xFFF5F5F5),
          child: Padding(
            padding: _r.pagePadding,
            child: Transform.translate(
              offset: Offset(0, -_r.dp(30)),
              child: _buildCustomerInformation(),
            ),
          ),
        ),
      ],
    );
  }

  /// Build top action buttons
  Widget _buildTopButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _r.dp(40), vertical: _r.dp(18)),
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
            width: _r.actionBtnSize,
            height: _r.actionBtnSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(_r.dp(12)),
            ),
            child: Icon(icon, color: Colors.white, size: _r.actionBtnIconSize),
          ),
          SizedBox(height: _r.dp(6)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: _r.fs11,
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
            width: _r.actionBtnSize,
            height: _r.actionBtnSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(_r.dp(12)),
            ),
            child: Center(
              child: SvgPicture.asset(
                svgPath,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                width: _r.actionBtnIconSize,
                height: _r.actionBtnIconSize,
              ),
            ),
          ),
          SizedBox(height: _r.dp(6)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: _r.fs11,
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
          borderRadius: BorderRadius.circular(_r.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: _r.cardPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: const Color(0xffEF4444), size: _r.dp(16)),
                    const SizedBox(width: 6),
                    Text(
                      AppLocalizations.of(context)!.customer_information,
                      style: TextStyle(
                        fontSize: _r.fs13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: _r.dp(12)),
              Text(
                '${AppLocalizations.of(context)!.customer_name} *',
                style: TextStyle(
                  fontSize: _r.fs11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: _r.dp(6)),
              TextFormField(
                controller: _customerNameController,
                enabled: true,
                style: TextStyle(fontSize: _r.fs12),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enter_customer_full_name,
                  hintStyle: TextStyle(fontSize: _r.fs12, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_r.smallRadius),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_r.smallRadius),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_r.smallRadius),
                    borderSide: const BorderSide(color: Color(0xffEF4444)),
                  ),
                  contentPadding: _r.fieldContentPadding,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.please_enter_a_your_customer_name;
                  }
                  return null;
                },
              ),
              SizedBox(height: _r.dp(12)),
              Text(
                '${AppLocalizations.of(context)!.phone_number} *',
                style: TextStyle(
                  fontSize: _r.fs11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: _r.dp(6)),
              TextFormField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                enabled: true,
                style: TextStyle(fontSize: _r.fs12),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enter_phone_number,
                  hintStyle: TextStyle(fontSize: _r.fs12, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_r.smallRadius),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_r.smallRadius),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_r.smallRadius),
                    borderSide: const BorderSide(color: Color(0xffEF4444)),
                  ),
                  contentPadding: _r.fieldContentPadding,
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
      padding: _r.pagePadding,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_r.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: _r.cardPadding,
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
                    style: TextStyle(
                      fontSize: _r.fs13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: _r.dp(12)),
              Text(
                AppLocalizations.of(context)!.serial_number,
                style: TextStyle(
                  fontSize: _r.fs11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: _r.dp(6)),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _serialNumberController,
                      style: TextStyle(fontSize: _r.fs12),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.enter_serial_number,
                        hintStyle: TextStyle(fontSize: _r.fs12, color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_r.smallRadius),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_r.smallRadius),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(_r.smallRadius),
                          borderSide: const BorderSide(color: Color(0xffEF4444)),
                        ),
                        contentPadding: _r.fieldContentPadding,
                      ),
                    ),
                  ),
                  SizedBox(width: _r.dp(8)),
                  // Camera scan button
                  Container(
                    width: _r.scanBtnSize,
                    height: _r.scanBtnSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(_r.smallRadius),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _scanFromImage,
                      icon: Icon(Icons.camera_alt, color: const Color(0xffEF4444), size: _r.scanBtnIconSize),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  SizedBox(width: _r.dp(8)),
                  // Barcode scan button
                  Container(
                    width: _r.scanBtnSize,
                    height: _r.scanBtnSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(_r.smallRadius),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _scanBarcode,
                      icon: SvgPicture.asset(
                        'assets/icon/barcode.svg',
                        width: _r.scanBtnIconSize,
                        height: _r.scanBtnIconSize,
                        colorFilter: const ColorFilter.mode(Color(0xffEF4444), BlendMode.srcIn),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  SizedBox(width: _r.dp(8)),
                  // Add button
                  Container(
                    width: _r.scanBtnSize,
                    height: _r.scanBtnSize,
                    decoration: BoxDecoration(
                      color: const Color(0xffEF4444),
                      borderRadius: BorderRadius.circular(_r.smallRadius),
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
                          : Icon(Icons.add, color: Colors.white, size: _r.scanBtnIconSize),
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
      padding: _r.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: const Color(0xffEF4444), size: _r.dp(16)),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.products_to_activate,
                style: TextStyle(
                  fontSize: _r.fs14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: _r.dp(10), vertical: _r.dp(4)),
                decoration: BoxDecoration(
                  color: const Color(0xffEF4444),
                  borderRadius: BorderRadius.circular(_r.dp(12)),
                ),
                child: Text(
                  '${_products.length}',
                  style: TextStyle(
                    fontSize: _r.fs12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _r.dp(12)),
          ...List.generate(
            _products.length,
            (index) => _buildProductCard(_products[index], index),
          ),
        ],
      ),
    );
  }

  /// Build product card with image - Consistent design for all products
  Widget _buildProductCard(WarrantyProductModel product, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: _r.dp(12)),
      padding: EdgeInsets.all(_r.dp(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_r.cardRadius),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: _r.productImgSize,
            height: _r.productImgSize,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(_r.dp(10)),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: product.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(_r.dp(9)),
                    child: Image.network(
                      product.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, color: Colors.grey, size: 28);
                      },
                    ),
                  )
                : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 32),
          ),
          SizedBox(width: _r.dp(14)),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.productName ?? 'Unknown Product',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: _r.fs14,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: _r.dp(6)),
                // Serial number and status side by side
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: _r.dp(8), vertical: _r.dp(4)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(_r.dp(6)),
                        ),
                        child: Text(
                          product.serialNumber,
                          style: TextStyle(
                            fontSize: _r.fs12,
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(width: _r.dp(8)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: _r.dp(8), vertical: _r.dp(3)),
                      decoration: BoxDecoration(
                        color: product.isValid 
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(_r.dp(6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            product.isValid ? Icons.check_circle : Icons.warning,
                            size: _r.dp(12),
                            color: product.isValid 
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                          SizedBox(width: _r.dp(4)),
                          Text(
                            product.isValid 
                                ? AppLocalizations.of(context)!.valid 
                                : AppLocalizations.of(context)!.warranty_already_active,
                            style: TextStyle(
                              fontSize: _r.fs11,
                              fontWeight: FontWeight.w600,
                              color: product.isValid 
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: _r.dp(8)),
          // Delete button - gray without background
          IconButton(
            onPressed: () => _removeProduct(index),
            icon: Icon(Icons.delete_outline, color: const Color(0xFF9CA3AF), size: _r.dp(22)),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build "Ready to Activate" section
  /// Build important note section
  Widget _buildImportantNote() {
    final isRTL = locale.toString() == 'ar';
    return Padding(
      padding: _r.pagePadding,
      child: Container(
        padding: _r.smallCardPadding,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(_r.cardRadius),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: const Color(0xFFEF4444), size: _r.dp(20)),
            SizedBox(width: _r.dp(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.important_note,
                    style: TextStyle(
                      fontSize: _r.fs12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  SizedBox(height: _r.dp(4)),
                  Text(
                    AppLocalizations.of(context)!.important_note_message,
                    style: TextStyle(
                      fontSize: _r.fs11,
                      color: const Color(0xFF374151),
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
                    child: Text(
                      isRTL ? '210-16480-[رقم الهاتف]' : '210-16480-[Phone Number]',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        isRTL ? 'مثال: ' : 'Example: ',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        '210-16480-0512345678',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
    final bool hasValidProducts = _products.isNotEmpty && _validProductCount > 0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _r.dp(16), vertical: _r.dp(12)),
      child: SizedBox(
        width: double.infinity,
        height: _r.submitBtnH,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _handleActivateButtonPress,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            disabledBackgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_r.smallRadius),
            ),
            elevation: 2,
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
                    Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: _r.dp(22),
                    ),
                    SizedBox(width: _r.dp(10)),
                    Text(
                      hasValidProducts
                          ? '${AppLocalizations.of(context)!.activate_warranties} $_validProductCount ${AppLocalizations.of(context)!.products_text}'
                          : AppLocalizations.of(context)!.activate_warranties,
                      style: TextStyle(
                        fontSize: _r.fs16,
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
