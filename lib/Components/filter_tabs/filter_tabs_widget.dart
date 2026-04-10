import 'package:flutter/material.dart';
import 'package:trust_app_updated/Components/responsive/app_responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class FilterTabsWidget extends StatelessWidget {
  final String selectedTab;
  final Function(String) onTabSelected;
  final int allCount;
  final int scheduledCount;  // pending count
  final int inProgressCount; // in_progress count (new)
  final int completedCount;  // done count
  final int overdueCount;    // delivered count

  const FilterTabsWidget({
    Key? key,
    required this.selectedTab,
    required this.onTabSelected,
    required this.allCount,
    required this.scheduledCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.overdueCount,
  }) : super(key: key);

  Widget _buildTab({
    required BuildContext context,
    required AppR r,
    required String label,
    required String value,
    required int count,
    required Color selectedColor,
  }) {
    final bool isSelected = selectedTab == value;
    final isRTL = locale.toString() == 'ar';

    return GestureDetector(
      onTap: () => onTabSelected(value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.dp(10), horizontal: r.dp(18)),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.85) : Colors.grey.shade300.withOpacity(0.7),
          borderRadius: BorderRadius.circular(r.dp(25)),
        ),
        child: Center(
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: r.fs13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';
    final r = AppR(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: r.hPad, vertical: r.dp(12)),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            _buildTab(
              context: context,
              r: r,
              label: AppLocalizations.of(context)!.all,
              value: 'all',
              count: allCount,
              selectedColor: Color(0xFFEF4444),
            ),
            SizedBox(width: r.dp(8)),
            _buildTab(
              context: context,
              r: r,
              label: AppLocalizations.of(context)!.pending,
              value: 'pending',
              count: scheduledCount,
              selectedColor: Color(0xFF2196F3), // Blue
            ),
            SizedBox(width: r.dp(8)),
            _buildTab(
              context: context,
              r: r,
              label: AppLocalizations.of(context)!.in_progress,
              value: 'in_progress',
              count: inProgressCount,
              selectedColor: Color(0xFFFF9800), // Orange
            ),
            SizedBox(width: r.dp(8)),
            _buildTab(
              context: context,
              r: r,
              label: AppLocalizations.of(context)!.done,
              value: 'done',
              count: completedCount,
              selectedColor: Color(0xFF4CAF50), // Green
            ),
            SizedBox(width: r.dp(8)),
            _buildTab(
              context: context,
              r: r,
              label: AppLocalizations.of(context)!.delivered,
              value: 'delivered',
              count: overdueCount,
              selectedColor: Color(0xFF2E7D32), // Bold Dark Green
            ),
          ],
        ),
      ),
    );
  }
}
