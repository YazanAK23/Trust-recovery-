import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:trust_app_updated/Components/responsive/app_responsive.dart';
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
    required AppR r,
    required IconData icon,
    required String label,
    required int count,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    final isRTL = locale.toString() == 'ar';
    return Expanded(
      child: Container(
        height: r.statusBoxH,
        padding: EdgeInsets.symmetric(vertical: r.dp(12), horizontal: r.dp(8)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(r.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.dp(8)),
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: r.dp(22),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: r.dp(6)),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: r.fs18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: r.dp(3)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.dp(2)),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: r.fs12,
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
          },
        ),
      ),
    );
  }

  Widget _buildStatusBoxSvg({
    required BuildContext context,
    required AppR r,
    required String svgPath,
    required String label,
    required int count,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    final isRTL = locale.toString() == 'ar';
    return Expanded(
      child: Container(
        height: r.statusBoxH,
        padding: EdgeInsets.symmetric(vertical: r.dp(12), horizontal: r.dp(8)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(r.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: EdgeInsets.all(r.dp(8)),
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        svgPath,
                        width: r.dp(22),
                        height: r.dp(22),
                        colorFilter: ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    SizedBox(height: r.dp(6)),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: r.fs18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: r.dp(3)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.dp(2)),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: r.fs12,
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
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = locale.toString() == 'ar';
    final r = AppR(context);
    
    return Container(
      padding: EdgeInsets.all(r.dp(16)),
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
          _buildStatusBoxSvg(
            context: context,
            r: r,
            svgPath: 'assets/icon/scheduled.svg',
            label: AppLocalizations.of(context)!.pending,
            count: scheduledCount,
            backgroundColor: Colors.white,
            iconColor: Color(0xFF2196F3), // Blue
          ),
          SizedBox(width: r.dp(12)),
          _buildStatusBox(
            context: context,
            r: r,
            icon: Icons.build_circle,
            label: AppLocalizations.of(context)!.in_progress,
            count: inProgressCount,
            backgroundColor: Colors.white,
            iconColor: Color(0xFFFF9800), // Orange
          ),
          SizedBox(width: r.dp(12)),
          _buildStatusBox(
            context: context,
            r: r,
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
