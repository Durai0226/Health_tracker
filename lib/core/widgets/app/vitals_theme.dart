import 'package:flutter/material.dart';
import '../../design/app_colors_ext.dart';
import '../../ai/vitals_analyzer.dart';

/// Colors for the vitals trackers, kept self-contained so we don't have to
/// thread two new accents through the core [AppColorsExt] theme extension.
///  - Two distinct tracker identities (BP = rose/cardio, Sugar = violet/glucose).
///  - A 5-step classification band scale (green→dark-red), theme-aware and
///    always paired with an icon + label in the UI (colorblind-safe).
class VitalsColors {
  const VitalsColors._();

  /// Blood-pressure "cardio" accent (rose/red).
  static AccentSwatch bpAccent(bool isDark) => isDark
      ? const AccentSwatch(
          base: Color(0xFFFB7185),
          on: Color(0xFF4C0519),
          strong: Color(0xFFFDA4AF),
          container: Color(0xFF3F1220),
          onContainer: Color(0xFFFECDD3))
      : const AccentSwatch(
          base: Color(0xFFE11D48),
          on: Colors.white,
          strong: Color(0xFFBE123C),
          container: Color(0xFFFFE4E6),
          onContainer: Color(0xFF881337));

  /// Blood-sugar "glucose" accent (violet).
  static AccentSwatch glucoseAccent(bool isDark) => isDark
      ? const AccentSwatch(
          base: Color(0xFFA78BFA),
          on: Color(0xFF2E1065),
          strong: Color(0xFFC4B5FD),
          container: Color(0xFF2A1D4D),
          onContainer: Color(0xFFDDD6FE))
      : const AccentSwatch(
          base: Color(0xFF7C3AED),
          on: Colors.white,
          strong: Color(0xFF6D28D9),
          container: Color(0xFFEDE9FE),
          onContainer: Color(0xFF4C1D95));

  // 5-step band scale (vivid mark color). Dark variants are lighter for contrast.
  static const _green = [Color(0xFF16A34A), Color(0xFF4ADE80)];
  static const _amber = [Color(0xFFD97706), Color(0xFFFBBF24)];
  static const _orange = [Color(0xFFEA580C), Color(0xFFFB923C)];
  static const _red = [Color(0xFFDC2626), Color(0xFFF87171)];
  static const _darkRed = [Color(0xFF991B1B), Color(0xFFFCA5A5)];

  static Color bpBand(bool isDark, BpCategory c) {
    final i = isDark ? 1 : 0;
    switch (c) {
      case BpCategory.normal:
        return _green[i];
      case BpCategory.elevated:
        return _amber[i];
      case BpCategory.stage1:
        return _orange[i];
      case BpCategory.stage2:
        return _red[i];
      case BpCategory.crisis:
        return _darkRed[i];
    }
  }

  static Color glucoseBand(bool isDark, GlucoseClass c) {
    final i = isDark ? 1 : 0;
    switch (c) {
      case GlucoseClass.severeLow:
        return _darkRed[i];
      case GlucoseClass.low:
        return _amber[i];
      case GlucoseClass.inRange:
        return _green[i];
      case GlucoseClass.high:
        return _orange[i];
      case GlucoseClass.veryHigh:
        return _red[i];
    }
  }

  /// Icon per band — the non-color redundancy that keeps the scale accessible.
  static IconData bpIcon(BpCategory c) {
    switch (c) {
      case BpCategory.normal:
        return Icons.check_circle_rounded;
      case BpCategory.elevated:
        return Icons.trending_up_rounded;
      case BpCategory.stage1:
        return Icons.warning_amber_rounded;
      case BpCategory.stage2:
        return Icons.error_rounded;
      case BpCategory.crisis:
        return Icons.emergency_rounded;
    }
  }

  static IconData glucoseIcon(GlucoseClass c) {
    switch (c) {
      case GlucoseClass.severeLow:
        return Icons.emergency_rounded;
      case GlucoseClass.low:
        return Icons.arrow_downward_rounded;
      case GlucoseClass.inRange:
        return Icons.check_circle_rounded;
      case GlucoseClass.high:
        return Icons.arrow_upward_rounded;
      case GlucoseClass.veryHigh:
        return Icons.error_rounded;
    }
  }
}
