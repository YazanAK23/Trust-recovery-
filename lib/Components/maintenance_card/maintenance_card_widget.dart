import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import '../../Constants/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class MaintenanceCardWidget extends StatelessWidget {
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
  }) : super(key: key);

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return Color(0xFF2196F3); // Blue
      case 'in_progress':
        return Color(0xFF4CAF50); // Green
      case 'done':
        return Color(0xFF4CAF50); // Green
      case 'delivered':
        return Color(0xFFFF9800); // Orange
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

  Widget _buildInfoRow(IconData icon, String label, String value, bool isRTL, {bool keepValueLTR = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
                SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    value.isEmpty ? '-' : value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: keepValueLTR ? TextDirection.ltr : (isRTL ? TextDirection.rtl : TextDirection.ltr),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ),
              ],
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
                    child: productImage.isNotEmpty
                        ? FancyShimmerImage(
                            imageUrl: productImage,
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
                      Text(
                        productName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        textAlign: isRTL ? TextAlign.right : TextAlign.left,
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
                              productSerialNumber,
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
                      if (notes.isNotEmpty)
                        Align(
                          alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              notes,
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
                        ),
                      // Status Badge
                      Align(
                        alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusLabel(context, status),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: Colors.grey[200]),

          // Details Section
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.calendar_today,
                  AppLocalizations.of(context)!.scheduled_date,
                  _formatDate(scheduledDate),
                  isRTL,
                  keepValueLTR: true,
                ),
                _buildInfoRow(
                  Icons.person,
                  AppLocalizations.of(context)!.customer_name,
                  customerName,
                  isRTL,
                ),
                _buildInfoRow(
                  Icons.phone,
                  AppLocalizations.of(context)!.phone_number,
                  customerPhone,
                  isRTL,
                  keepValueLTR: true,
                ),
                // Service Notes Section
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
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
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.service_notes,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                        if (maintenanceCategoryNotes.isNotEmpty) ...[
                          SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              maintenanceCategoryNotes,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                              textAlign: isRTL ? TextAlign.right : TextAlign.left,
                            ),
                          ),
                        ] else ...[
                          SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
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

          // View Report Button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MAIN_COLOR,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  AppLocalizations.of(context)!.view_report,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
