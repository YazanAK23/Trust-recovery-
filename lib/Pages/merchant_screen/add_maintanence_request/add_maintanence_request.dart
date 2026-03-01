import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';
import 'package:trust_app_updated/Server/functions/functions.dart';
import 'package:trust_app_updated/Services/scanning_service/scanning_service.dart';
import 'package:trust_app_updated/main.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:trust_app_updated/Components/drawer_widget/drawer_widget.dart';

/// Send To Maintenance Screen - Redesigned to match UI mockup
class AddMaintanenceRequest extends StatefulWidget {
  final prodSerialNumber;
  const AddMaintanenceRequest({super.key, required this.prodSerialNumber});

  @override
  State<AddMaintanenceRequest> createState() => _AddMaintanenceRequestState();
}

class _AddMaintanenceRequestState extends State<AddMaintanenceRequest> {
  // Scaffold key for drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Controllers
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // State
  String productImage = "";
  String productName = "";
  String purchaseDate = "";
  String warrantyOwner = "";
  String ownerPhone = "";
  int productID = 0;
  int merchantID = 0;
  bool warrantyStatus = false;
  int warrantyID = 0;
  bool productAdded = false;
  bool _isLoading = false;
  bool _serialChecked = false;
  String _lastCheckedSerial = "";
  
  @override
  void initState() {
    super.initState();
    _initializeController();
    // Add listener to track serial number changes
    _serialNumberController.addListener(_onSerialNumberChanged);
  }

  void _onSerialNumberChanged() {
    // If serial was checked and user is editing it, mark as needs refresh
    if (_serialChecked && _serialNumberController.text != _lastCheckedSerial) {
      setState(() {
        _serialChecked = false;
      });
    }
  }

  @override
  void dispose() {
    _serialNumberController.removeListener(_onSerialNumberChanged);
    _serialNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeController() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? _merchantID = prefs.getString('merchant_id');
    try {
      if (_merchantID != null && _merchantID.isNotEmpty) {
        merchantID = int.parse(_merchantID);
      }
    } catch (e) {
      debugPrint('Error parsing merchant ID: $e');
      merchantID = 0;
    }
    if (widget.prodSerialNumber != null && widget.prodSerialNumber.toString().isNotEmpty) {
      _serialNumberController.text = widget.prodSerialNumber.toString();
      // Auto-check if serial number provided
      if (_serialNumberController.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkSerialNumber();
        });
      }
    }
  }

  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xffe33131), // Red background for status bar area
      drawer: DrawerWell(
        Refresh: () {
          setState(() {});
        },
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Header and top section with red background
                Container(
                  color: const Color(0xffe33131),
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: _buildHeader(isRTL),
                      ),
                      _buildTopButtons(),
                      const SizedBox(height: 30), // Extra space for overlap
                    ],
                  ),
                ),
                // Content with gray background
                Container(
                  color: const Color(0xFFF5F5F5),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -30), // Move up to create overlap
                          child: _buildSerialNumberSection(),
                        ),
                        const SizedBox(height: 5),
                        if (productAdded) ...[
                          _buildProductDetails(),
                          const SizedBox(height: 15),
                        ],
                        _buildCustomerInformation(),
                        const SizedBox(height: 15),
                        _buildMalfunctionDetails(),
                        const SizedBox(height: 15),
                        _buildImportantNote(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fixed button at the bottom - Hide when keyboard is visible
          if (MediaQuery.of(context).viewInsets.bottom == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSubmitButton(),
            ),
        ],
      ),
    );
  }

  /// Build header
  Widget _buildHeader(bool isRTL) {
    return Container(
      height: 60,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: isRTL ? null : 0,
            right: isRTL ? 0 : null,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 24, color: Colors.white),
            ),
          ),
          Center(
            child: Text(
              AppLocalizations.of(context)!.send_to_maintenance,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: isRTL ? 0 : null,
            right: isRTL ? null : 0,
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: SvgPicture.asset(
                'assets/images/Menu.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
            icon: Icons.report_outlined,
            label: AppLocalizations.of(context)!.report,
            onTap: () {},
          ),
          _buildActionButtonSvg(
            svgPath: 'assets/icon/scan.svg',
            label: AppLocalizations.of(context)!.scan,
            onTap: _scanBarcode,
          ),
          _buildActionButton(
            icon: Icons.send_outlined,
            label: AppLocalizations.of(context)!.submit,
            onTap: _submitMaintenanceRequest,
            rotateIcon: true,
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
    bool rotateIcon = false,
  }) {
    final isRTL = locale.toString() == 'ar';
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
            child: rotateIcon
                ? Transform.rotate(
                    angle: isRTL ? 0.785398 : -0.785398, // 45 degrees for RTL, -45 for LTR
                    child: Icon(icon, color: Colors.white, size: 24),
                  )
                : Icon(icon, color: Colors.white, size: 24),
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
              const SizedBox(height: 15),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build malfunction details section
  Widget _buildMalfunctionDetails() {
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
                  const Icon(Icons.info_outline, color: Color(0xffEF4444), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.malfunction_details,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                '${AppLocalizations.of(context)!.malfunction_description} *',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(fontSize: 12),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.malfunction_description,
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
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.notes,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.notes,
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
            ],
          ),
        ),
      ),
    );
  }
  /// Build important note section
  Widget _buildImportantNote() {
    final isRTL = locale.toString() == 'ar';
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
                  Align(
                    alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                      ),
                      child: Text(
                        '\u202A210-16480-[${isRTL ? 'رقم الهاتف' : 'Phone Number'}]\u202C',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                          '\u202A210-16480-0512345678\u202C',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
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

  /// Build serial number section
  Widget _buildSerialNumberSection() {
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
                    child: SvgPicture.asset(
                      'assets/icon/barcode.svg',
                      width: 12,
                      height: 12,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.product_serial_number,
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
                      icon: SvgPicture.asset(
                        'assets/icon/barcode.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(Color(0xffEF4444), BlendMode.srcIn),
                      ),
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
                      onPressed: _isLoading ? null : _checkSerialNumber,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              productAdded && !_serialChecked ? Icons.refresh : Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
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

  /// Build product details section
  Widget _buildProductDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title outside the card
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xffEF4444), size: 18),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.product_details,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Card container
          Container(
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
                  // Product row with delete icon
                  Row(
                    children: [
                      // Product image
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: productImage.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  productImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.image_not_supported,
                                        color: Colors.grey, size: 28);
                                  },
                                ),
                              )
                            : const Icon(Icons.inventory_2_outlined,
                                color: Colors.grey, size: 32),
                      ),
                      const SizedBox(width: 14),
                      // Product details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF111827),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _serialNumberController.text,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Delete icon in gray at top right
                      IconButton(
                        onPressed: () {
                          setState(() {
                            productAdded = false;
                            _serialNumberController.clear();
                            _customerNameController.clear();
                            _customerPhoneController.clear();
                            _descriptionController.clear();
                            _notesController.clear();
                            productName = "";
                            productImage = "";
                            productID = 0;
                            warrantyStatus = false;
                            warrantyID = 0;
                            warrantyOwner = "";
                            ownerPhone = "";
                            purchaseDate = "";
                            _serialChecked = false;
                            _lastCheckedSerial = "";
                          });
                        },
                        icon: const Icon(Icons.delete_outline, color: Color(0xFF9CA3AF), size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Divider
                  Divider(color: Colors.grey[200], height: 1),
                  const SizedBox(height: 15),
                  // Warranty details
                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    AppLocalizations.of(context)!.purchase_date,
                    purchaseDate.isNotEmpty ? purchaseDate : '--',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.verified_outlined,
                    AppLocalizations.of(context)!.warranty_status,
                    warrantyStatus ? AppLocalizations.of(context)!.active : AppLocalizations.of(context)!.not_effectice,
                    valueColor: warrantyStatus ? const Color(0xFF10B981) : Colors.red,
                    isStatus: warrantyStatus,
                  ),
                  if (warrantyOwner.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.person_outline,
                      AppLocalizations.of(context)!.customer_name,
                      warrantyOwner,
                    ),
                  ],
                  if (ownerPhone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.phone_outlined,
                      AppLocalizations.of(context)!.phone_number,
                      ownerPhone,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build detail row helper
  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isStatus = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        if (isStatus && warrantyStatus)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Build submit button
  Widget _buildSubmitButton() {
    final isRTL = locale.toString() == 'ar';
    return SafeArea(
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
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canSubmit() ? _submitMaintenanceRequest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffEF4444),
              disabledBackgroundColor: Colors.grey[300],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isRTL ? [
                Text(
                  AppLocalizations.of(context)!.submit_maintenance_request,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Transform.rotate(
                  angle: 0.785398, // 45 degrees for RTL
                  child: const Icon(Icons.send, size: 20),
                ),
              ] : [
                Transform.rotate(
                  angle: -0.785398, // -45 degrees for LTR
                  child: const Icon(Icons.send, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.submit_maintenance_request,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Check if can submit
  bool _canSubmit() {
    return productAdded &&
        _customerNameController.text.isNotEmpty &&
        _customerPhoneController.text.isNotEmpty &&
        _descriptionController.text.isNotEmpty;
  }

  /// Check serial number and fetch warranty data
  Future<void> _checkSerialNumber() async {
    final serialNumber = _serialNumberController.text.trim();

    if (serialNumber.isEmpty) {
      _showError(AppLocalizations.of(context)!.enter_serial_number);
      return;
    }

    // Clear previous product data before checking new serial
    setState(() {
      _isLoading = true;
      // Clear product data
      productAdded = false;
      productName = "";
      productImage = "";
      productID = 0;
      // Clear warranty data
      warrantyStatus = false;
      warrantyID = 0;
      warrantyOwner = "";
      ownerPhone = "";
      purchaseDate = "";
      // Clear serial check state
      _serialChecked = false;
      _lastCheckedSerial = "";
    });
    
    // Clear customer input fields
    _customerNameController.clear();
    _customerPhoneController.clear();

    try {
      // Get warranty data
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
      productID = product['id'];
      productName = product['name'] ?? 'Unknown Product';

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

      // Check if warranty exists and auto-fill data
      if (warrantyResponse.containsKey('response')) {
        final warranty = warrantyResponse['response'];
        warrantyID = warranty['id'] ?? 0;
        warrantyStatus = true;
        
        // Auto-fill customer information from warranty
        _customerNameController.text = warranty['customerName'] ?? '';
        _customerPhoneController.text = warranty['customerPhone'] ?? '';
        
        // Set warranty details
        warrantyOwner = warranty['customerName'] ?? '';
        ownerPhone = warranty['customerPhone'] ?? '';
        
        // Parse and format purchase date
        if (warranty['activationDate'] != null) {
          try {
            final date = DateTime.parse(warranty['activationDate']);
            purchaseDate = DateFormat('dd MMM yyyy').format(date);
          } catch (e) {
            purchaseDate = '';
          }
        }
        
        _showSuccess(AppLocalizations.of(context)!.warranty_found);
      } else {
        warrantyStatus = false;
        warrantyID = 0;
        warrantyOwner = '';
        ownerPhone = '';
        purchaseDate = '';
        _showError(AppLocalizations.of(context)!.no_warranty_found);
      }

      setState(() {
        productAdded = true;
        _isLoading = false;
        _serialChecked = true;
        _lastCheckedSerial = serialNumber;
      });
    } catch (e) {
      debugPrint('Error checking serial number: $e');
      _showError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Scan barcode
  Future<void> _scanBarcode() async {
    final result = await ScanningService.scanBarcode(context);
    if (result != null) {
      setState(() {
        _serialNumberController.text = result;
      });
      _showSuccess('Barcode scanned');
      await _checkSerialNumber();
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
      _showSuccess('Serial number extracted');
      await _checkSerialNumber();
    } else {
      _showError(AppLocalizations.of(context)!.no_text_found);
    }
  }

  /// Submit maintenance request
  Future<void> _submitMaintenanceRequest() async {
    if (!_canSubmit()) {
      _showError(AppLocalizations.of(context)!.please_fill_all_required_fields);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: SizedBox(
            height: 100,
            width: 100,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xffEF4444),
              ),
            ),
          ),
        );
      },
    );

    try {
      await addMaintanenceRequest(
        _customerPhoneController.text,
        _customerNameController.text,
        _serialNumberController.text,
        productID.toString(),
        merchantID.toString(),
        _notesController.text,
        warrantyID.toString() == "0" ? "null" : warrantyID.toString(),
        warrantyStatus,
        _descriptionController.text,
        context,
      );
      // Dialog closed in function
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _showError('Error: $e');
    }
  }
}
