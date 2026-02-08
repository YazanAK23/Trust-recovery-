import 'package:flutter/material.dart';
import '../../Constants/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class StatusSummaryWidget extends StatelessWidget {
  final int scheduledCount;  // pending count
  final int inProgressCount; // in_progress count
  final int completedCount;  // done count

  const StatusSummaryWidget({
    Key? key,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.completedCount,
  }) : super(key: key);

  Widget _buildStatusBox({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int count,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    final isRTL = locale.toString() == 'ar';
    return Expanded(
      child: Container(
        height: 115,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 6),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MAIN_COLOR, MAIN_COLOR.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          _buildStatusBox(
            context: context,
            icon: Icons.schedule,
            label: AppLocalizations.of(context)!.pending,
            count: scheduledCount,
            backgroundColor: Colors.white,
            iconColor: Color(0xFF2196F3), // Blue
          ),
          SizedBox(width: 12),
          _buildStatusBox(
            context: context,
            icon: Icons.build_circle,
            label: AppLocalizations.of(context)!.in_progress,
            count: inProgressCount,
            backgroundColor: Colors.white,
            iconColor: Color(0xFFFF9800), // Orange
          ),
          SizedBox(width: 12),
          _buildStatusBox(
            context: context,
            icon: Icons.check_circle,
            label: AppLocalizations.of(context)!.done,
            count: completedCount,
            backgroundColor: Colors.white,
            iconColor: Color(0xFF4CAF50), // Green
          ),
        ],
      ),
    );
  }
}
