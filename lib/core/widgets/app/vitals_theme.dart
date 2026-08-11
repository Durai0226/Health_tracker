import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_colors_ext.dart';
import '../../health/vitals_analyzer.dart';

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

  /// Weight "body measurement" accent (teal).
  static AccentSwatch weightAccent(bool isDark) => isDark
      ? const AccentSwatch(
          base: Color(0xFF2DD4BF),
          on: Color(0xFF042F2E),
          strong: Color(0xFF5EEAD4),
          container: Color(0xFF0F3B38),
          onContainer: Color(0xFF99F6E4))
      : const AccentSwatch(
          base: Color(0xFF0D9488),
          on: Colors.white,
          strong: Color(0xFF0F766E),
          container: Color(0xFFCCFBF1),
          onContainer: Color(0xFF134E4A));

  /// Caffeine "coffee" accent (warm brown). Replaces the raw
  /// `Colors.brown.shade*` the caffeine screen used to hardcode, so it
  /// participates in the same theming/dark-mode contract as every other
  /// tracker instead of being light-mode-only.
  static AccentSwatch caffeineAccent(bool isDark) => isDark
      ? const AccentSwatch(
          base: Color(0xFFD7A487),
          on: Color(0xFF3E2416),
          strong: Color(0xFFE8C0A8),
          container: Color(0xFF3A2A20),
          onContainer: Color(0xFFF0D6C4))
      : const AccentSwatch(
          base: Color(0xFF8D5B3F),
          on: Colors.white,
          strong: Color(0xFF6F452E),
          container: Color(0xFFF5E4D8),
          onContainer: Color(0xFF4A2C1A));

  /// Mood "wellbeing" accent (amber).
  static AccentSwatch moodAccent(bool isDark) => isDark
      ? const AccentSwatch(
          base: Color(0xFFFBBF24),
          on: Color(0xFF451A03),
          strong: Color(0xFFFCD34D),
          container: Color(0xFF3F2D0B),
          onContainer: Color(0xFFFDE68A))
      : const AccentSwatch(
          base: Color(0xFFD97706),
          on: Colors.white,
          strong: Color(0xFFB45309),
          container: Color(0xFFFEF3C7),
          onContainer: Color(0xFF78350F));

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
        return Symbols.check_circle_rounded;
      case BpCategory.elevated:
        return Symbols.trending_up_rounded;
      case BpCategory.stage1:
        return Symbols.warning_amber_rounded;
      case BpCategory.stage2:
        return Symbols.error_rounded;
      case BpCategory.crisis:
        return Symbols.emergency_rounded;
    }
  }

  static IconData glucoseIcon(GlucoseClass c) {
    switch (c) {
      case GlucoseClass.severeLow:
        return Symbols.emergency_rounded;
      case GlucoseClass.low:
        return Symbols.arrow_downward_rounded;
      case GlucoseClass.inRange:
        return Symbols.check_circle_rounded;
      case GlucoseClass.high:
        return Symbols.arrow_upward_rounded;
      case GlucoseClass.veryHigh:
        return Symbols.error_rounded;
    }
  }

  /// One sentiment icon per `moodRatingLabels` index (0 = Great … 4 = Terrible).
  static const List<IconData> moodIcons = [
    Symbols.sentiment_very_satisfied_rounded,
    Symbols.sentiment_satisfied_rounded,
    Symbols.sentiment_neutral_rounded,
    Symbols.sentiment_dissatisfied_rounded,
    Symbols.sentiment_very_dissatisfied_rounded,
  ];

  static IconData moodIcon(int index) =>
      moodIcons[index.clamp(0, moodIcons.length - 1)];

  // 5-step band scale for mood, best→worst (0 = Great green … 4 = Terrible red).
  static Color moodBand(bool isDark, int index) {
    final i = isDark ? 1 : 0;
    switch (index.clamp(0, 4)) {
      case 0:
        return _green[i];
      case 1:
        return _amber[i];
      case 2:
        return _orange[i];
      case 3:
        return _red[i];
      default:
        return _darkRed[i];
    }
  }
}
