import 'package:flutter/material.dart';

/// Responsive utility for scaling UI elements across all device sizes.
///
/// Usage:
///   final r = AppR(context);
///   ...fontSize: r.fs14, width: r.actionBtnSize, padding: r.cardPadding
///
/// Base design is built for a 375px-wide phone.
/// On tablets (≥600px) and large phones, sizes scale up proportionally,
/// capped at 1.45× to avoid oversized UI on very wide devices.
class AppR {
  final double screenWidth;
  final double screenHeight;

  /// True when the device is tablet-sized (width ≥ 600 logical px).
  final bool isTablet;

  final double _scale;

  AppR(BuildContext context)
      : screenWidth = MediaQuery.sizeOf(context).width,
        screenHeight = MediaQuery.sizeOf(context).height,
        isTablet = MediaQuery.sizeOf(context).width >= 600,
        _scale =
            (MediaQuery.sizeOf(context).width / 375.0).clamp(0.85, 1.45);

  // ── Scale helpers ────────────────────────────────────────────────────────

  /// Scale a font size.
  double sp(double size) => size * _scale;

  /// Scale a dimension (width, height, padding value, etc.).
  double dp(double size) => size * _scale;

  // ── Horizontal page padding ──────────────────────────────────────────────

  /// Outer horizontal padding used for page-level content blocks.
  double get hPad => isTablet ? screenWidth * 0.055 : 20.0;

  // ── Common widget sizes ──────────────────────────────────────────────────

  double get headerH => dp(60);
  double get cardRadius => dp(12);
  double get smallRadius => dp(8);

  double get actionBtnSize => dp(54);
  double get actionBtnIconSize => dp(24);

  double get scanBtnSize => dp(42);
  double get scanBtnIconSize => dp(20);

  double get productImgSize => dp(65);
  double get productImgSmall => dp(60);

  double get submitBtnH => dp(50);
  double get submitBtnHLarge => dp(52);

  double get statusBoxH => dp(110);

  // ── EdgeInsets helpers ───────────────────────────────────────────────────

  EdgeInsets get cardPadding => EdgeInsets.all(dp(15));
  EdgeInsets get smallCardPadding => EdgeInsets.all(dp(14));
  EdgeInsets get pagePadding => EdgeInsets.symmetric(horizontal: hPad);
  EdgeInsets get fieldContentPadding =>
      EdgeInsets.symmetric(horizontal: dp(12), vertical: dp(12));

  // ── Font size presets ────────────────────────────────────────────────────

  double get fs10 => sp(10);
  double get fs11 => sp(11);
  double get fs12 => sp(12);
  double get fs13 => sp(13);
  double get fs14 => sp(14);
  double get fs16 => sp(16);
  double get fs18 => sp(18);
  double get fs20 => sp(20);
  double get fs22 => sp(22);

  // ── Tablet content constraint ────────────────────────────────────────────

  /// Wrap [child] in a centred max-width container on tablets so the
  /// content never stretches across the full iPad width.
  Widget constrainContent(Widget child) {
    if (!isTablet) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: child,
      ),
    );
  }
}
