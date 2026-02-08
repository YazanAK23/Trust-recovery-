import 'package:flutter/material.dart';
import '../../Constants/constants.dart';
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
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 13,
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
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            _buildTab(
              context: context,
              label: AppLocalizations.of(context)!.all,
              value: 'all',
              count: allCount,
              selectedColor: MAIN_COLOR,
            ),
            SizedBox(width: 8),
            _buildTab(
              context: context,
              label: AppLocalizations.of(context)!.pending,
              value: 'pending',
              count: scheduledCount,
              selectedColor: Color(0xFF2196F3), // Blue
            ),
            SizedBox(width: 8),
            _buildTab(
              context: context,
              label: AppLocalizations.of(context)!.in_progress,
              value: 'in_progress',
              count: inProgressCount,
              selectedColor: Color(0xFFFF9800), // Orange
            ),
            SizedBox(width: 8),
            _buildTab(
              context: context,
              label: AppLocalizations.of(context)!.done,
              value: 'done',
              count: completedCount,
              selectedColor: Color(0xFF4CAF50), // Green
            ),
            SizedBox(width: 8),
            _buildTab(
              context: context,
              label: AppLocalizations.of(context)!.delivered,
              value: 'delivered',
              count: overdueCount,
              selectedColor: Color(0xFF9C27B0), // Purple
            ),
          ],
        ),
      ),
    );
  }
}
