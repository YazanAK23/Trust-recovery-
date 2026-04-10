import 'package:flutter/material.dart';
import 'package:trust_app_updated/Components/responsive/app_responsive.dart';
import 'package:trust_app_updated/l10n/app_localizations.dart';
import 'package:trust_app_updated/Server/domains/domains.dart';

/// Reusable warranty card widget
class WarrantyCard extends StatefulWidget {
  final String productName;
  final String productSerialNumber;
  final String productImage;
  final String customerName;
  final String customerPhone;
  final String purchaseDate;
  final String expiryDate;
  final String status; // 'active', 'expiring-soon', 'expired'
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WarrantyCard({
    Key? key,
    required this.productName,
    required this.productSerialNumber,
    required this.productImage,
    required this.customerName,
    required this.customerPhone,
    required this.purchaseDate,
    required this.expiryDate,
    required this.status,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<WarrantyCard> createState() => _WarrantyCardState();
}

class _WarrantyCardState extends State<WarrantyCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final r = AppR(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.hPad, vertical: r.dp(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Product info and status badge
          Padding(
            padding: EdgeInsets.all(r.dp(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                Container(
                  width: r.productImgSmall,
                  height: r.productImgSmall,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.smallRadius),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r.smallRadius),
                    child: widget.productImage.isNotEmpty
                        ? Image.network(
                            URLIMAGE + widget.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 30,
                              );
                            },
                          )
                        : const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.grey,
                            size: 30,
                          ),
                  ),
                ),
                  SizedBox(width: r.dp(12)),
                
                // Product name and serial
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isExpanded = !isExpanded;
                          });
                        },
                        child: Text(
                          widget.productName,
                          style: TextStyle(
                            fontSize: r.fs13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: r.dp(4)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: r.dp(6), vertical: r.dp(2)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(r.dp(4)),
                        ),
                        child: Text(
                          widget.productSerialNumber,
                          style: TextStyle(
                            fontSize: r.fs12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status badge
                _buildStatusBadge(context, r),
              ],
            ),
          ),
          
          // Customer info in light gray container
          Container(
            margin: EdgeInsets.symmetric(horizontal: r.dp(16), vertical: r.dp(8)),
            padding: EdgeInsets.all(r.dp(12)),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(r.smallRadius),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        r: r,
                        label: AppLocalizations.of(context)!.customer,
                        value: widget.customerName,
                      ),
                    ),
                    SizedBox(width: r.dp(16)),
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        r: r,
                        label: AppLocalizations.of(context)!.phone,
                        value: widget.customerPhone,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.dp(10)),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        r: r,
                        label: AppLocalizations.of(context)!.purchase_date,
                        value: widget.purchaseDate,
                      ),
                    ),
                    SizedBox(width: r.dp(16)),
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        r: r,
                        label: AppLocalizations.of(context)!.warranty_period,
                        value: widget.expiryDate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(4), r.dp(16), r.dp(16)),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    r: r,
                    label: AppLocalizations.of(context)!.edit,
                    icon: Icons.edit_outlined,
                    onTap: widget.onEdit,
                    backgroundColor: Colors.black,
                  ),
                ),
                SizedBox(width: r.dp(12)),
                Expanded(
                  child: _buildActionButton(
                    context,
                    r: r,
                    label: AppLocalizations.of(context)!.delete,
                    icon: Icons.delete_outline,
                    onTap: widget.onDelete,
                    backgroundColor: const Color(0xFFFFEBEE),
                    textColor: const Color(0xffD51C29),
                    borderColor: Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, AppR r) {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (widget.status.toLowerCase()) {
      case 'active':
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF4CAF50);
        statusText = AppLocalizations.of(context)!.active;
        break;
      case 'expiring-soon':
        backgroundColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFFF9800);
        statusText = AppLocalizations.of(context)!.expiring_soon;
        break;
      case 'expired':
        backgroundColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFF44336);
        statusText = AppLocalizations.of(context)!.expired;
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        statusText = widget.status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.dp(8), vertical: r.dp(4)),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(r.dp(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: r.dp(8),
            color: textColor,
          ),
          SizedBox(width: r.dp(4)),
          Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontSize: r.fs12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required AppR r, required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: r.fs12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: r.dp(2)),
        Text(
          value,
          style: TextStyle(
            fontSize: r.fs14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required AppR r,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    Color? textColor,
    Color? borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.dp(10)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.dp(8), horizontal: r.dp(12)),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(r.dp(10)),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: r.dp(16),
              color: textColor ?? Colors.white,
            ),
            SizedBox(width: r.dp(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: r.fs13,
                fontWeight: FontWeight.normal,
                color: textColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
