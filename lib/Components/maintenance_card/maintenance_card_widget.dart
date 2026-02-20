import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class MaintenanceCardWidget extends StatefulWidget {
  final String productImage;
  final String productName;
  final String productSerialNumber;
  final String status;
  final String scheduledDate;
  final String customerName;
  final String customerPhone;
  final String maintenanceCategoryNotes;
  final String notes;
  final VoidCallback onViewReport;
  final VoidCallback onEdit;

  const MaintenanceCardWidget({
    Key? key,
    required this.productImage,
    required this.productName,
    required this.productSerialNumber,
    required this.status,
    required this.scheduledDate,
    required this.customerName,
    required this.customerPhone,
    required this.maintenanceCategoryNotes,
    required this.notes,
    required this.onViewReport,
    required this.onEdit,
  }) : super(key: key);

  @override
  State<MaintenanceCardWidget> createState() => _MaintenanceCardWidgetState();
}

class _MaintenanceCardWidgetState extends State<MaintenanceCardWidget> {
  bool isExpanded = false;

  Color _getStatusColor() {
    switch (widget.status.toLowerCase()) {
      case 'pending':
        return Color(0xFF2196F3); // Blue
      case 'in_progress':
        return Color(0xFFFF9800); // Orange
      case 'done':
        return Color(0xFF4CAF50); // Green
      case 'delivered':
        return Color(0xFF2E7D32); // Bold Dark Green
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppLocalizations.of(context)!.pending;
      case 'in_progress':
        return AppLocalizations.of(context)!.in_progress;
      case 'done':
        return AppLocalizations.of(context)!.done;
      case 'delivered':
        return AppLocalizations.of(context)!.delivered;
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final formatter = intl.DateFormat('d MMM, yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildHorizontalInfoItem(IconData icon, String label, String value, bool isRTL, {bool keepValueLTR = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: keepValueLTR ? TextDirection.ltr : (isRTL ? TextDirection.rtl : TextDirection.ltr),
              textAlign: isRTL ? TextAlign.left : TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header with image and basic info
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: widget.productImage.isNotEmpty
                        ? FancyShimmerImage(
                            imageUrl: widget.productImage,
                            boxFit: BoxFit.cover,
                            errorWidget: Icon(Icons.image_not_supported,
                                size: 40, color: Colors.grey),
                          )
                        : Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
                ),
                SizedBox(width: 12),
                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Product name with status badge on same line
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isExpanded = !isExpanded;
                                });
                              },
                              child: Text(
                                widget.productName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: isExpanded ? null : 2,
                                overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                                textAlign: isRTL ? TextAlign.right : TextAlign.left,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Status Badge beside title
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusLabel(context, widget.status),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Align(
                        alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                          children: [
                            Text(
                              '${AppLocalizations.of(context)!.order_id_label}: ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              widget.productSerialNumber,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Notes in orange
                      if (widget.notes.isNotEmpty)
                        Align(
                          alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text(
                            widget.notes,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF9800),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details Section
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Gray container with information
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFAFAFA).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!.withOpacity(0.5), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildHorizontalInfoItem(
                        Icons.calendar_today,
                        AppLocalizations.of(context)!.scheduled_date,
                        _formatDate(widget.scheduledDate),
                        isRTL,
                        keepValueLTR: true,
                      ),
                      SizedBox(height: 8),
                      _buildHorizontalInfoItem(
                        Icons.person,
                        AppLocalizations.of(context)!.customer_name,
                        widget.customerName,
                        isRTL,
                      ),
                      SizedBox(height: 8),
                      _buildHorizontalInfoItem(
                        Icons.phone,
                        AppLocalizations.of(context)!.phone_number,
                        widget.customerPhone,
                        isRTL,
                        keepValueLTR: true,
                      ),
                    ],
                  ),
                ),
                // Service Notes Section
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.service_notes,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                        if (widget.maintenanceCategoryNotes.isNotEmpty) ...[
                          SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              widget.maintenanceCategoryNotes,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                              textAlign: isRTL ? TextAlign.right : TextAlign.left,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // View Report Button
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: widget.onViewReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.view_report,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // Edit Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: widget.onEdit,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.edit,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
