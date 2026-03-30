import 'package:flutter/material.dart';
import 'dart:ui';

/// Flo-inspired theme for Period Tracking feature
/// Based on "Revamping Flo in Domingo's style" Behance case study
class FloTheme {
  FloTheme._();

  // ============ PRIMARY COLORS ============
  
  /// Main pink for period phase
  static const Color periodPink = Color(0xFFFF8698);
  static const Color periodPinkLight = Color(0xFFFFE4E8);
  static const Color periodPinkDark = Color(0xFFE5677A);
  
  /// Yellow for follicular phase
  static const Color follicularYellow = Color(0xFFFFF6A4);
  static const Color follicularYellowDark = Color(0xFFE6D88A);
  static const Color follicularYellowAccent = Color(0xFFFFD93D);
  
  /// Green for luteal phase
  static const Color lutealGreen = Color(0xFFD2EBBF);
  static const Color lutealGreenDark = Color(0xFFB8D4A5);
  static const Color lutealGreenAccent = Color(0xFF8BC34A);
  
  /// Blue for ovulation phase
  static const Color ovulationBlue = Color(0xFFBCE7F0);
  static const Color ovulationBlueDark = Color(0xFF9DD1DD);
  static const Color ovulationBlueAccent = Color(0xFF4FC3F7);
  
  /// Orange accent
  static const Color accentOrange = Color(0xFFFF8E5E);
  static const Color accentOrangeLight = Color(0xFFFFD4C4);
  
  // ============ NEUTRAL COLORS ============
  
  static const Color textPrimary = Color(0xFF121211);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  static const Color background = Color(0xFFFFFBFC);
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D2D2D);
  
  static const Color divider = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF404040);
  
  // ============ BLOB CHARACTER COLORS ============
  
  static const Color blobPink = Color(0xFFFF8698);
  static const Color blobYellow = Color(0xFFFFD93D);
  static const Color blobGreen = Color(0xFFB8E986);
  static const Color blobBlue = Color(0xFF87CEEB);
  static const Color blobOrange = Color(0xFFFF8E5E);
  static const Color blobPurple = Color(0xFFB8A9C9);
  
  // ============ PHASE GRADIENTS ============
  
  static LinearGradient get periodGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8698), Color(0xFFFFB6C1)],
  );
  
  static LinearGradient get follicularGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF6A4), Color(0xFFFFE082)],
  );
  
  static LinearGradient get ovulationGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBCE7F0), Color(0xFF81D4FA)],
  );
  
  static LinearGradient get lutealGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD2EBBF), Color(0xFFA5D6A7)],
  );
  
  static LinearGradient get pmsGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8E5E), Color(0xFFFFAB91)],
  );
  
  static LinearGradient get pregnancyGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFCDD2), Color(0xFFF8BBD9)],
  );
  
  // ============ TYPOGRAPHY ============
  
  static const String fontFamily = 'Nunito';
  
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    color: textPrimary,
  );
  
  static TextStyle get displayMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: textPrimary,
  );
  
  static TextStyle get displaySmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get headlineLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );
  
  static TextStyle get headlineMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get headlineSmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );
  
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );
  
  static TextStyle get bodySmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
  );
  
  static TextStyle get labelLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textPrimary,
  );
  
  static TextStyle get labelSmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textSecondary,
  );
  
  // ============ SPACING ============
  
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacing2xl = 24.0;
  static const double spacing3xl = 32.0;
  static const double spacing4xl = 40.0;
  
  // Grid system from Behance
  static const double gridMargin = 16.0;
  static const double gridGutter = 12.0;
  static const int gridColumns = 4;
  
  // ============ BORDER RADIUS ============
  
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radiusFull = 999.0;
  
  // ============ SHADOWS ============
  
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowColored(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  // ============ GLASSMORPHISM ============
  
  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = radiusLg,
    bool isDark = false,
  }) {
    return BoxDecoration(
      color: (color ?? (isDark ? Colors.white : Colors.white)).withOpacity(isDark ? 0.1 : 0.8),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.white).withOpacity(0.2),
        width: 1,
      ),
      boxShadow: shadowSm,
    );
  }
  
  static BoxDecoration phaseCardDecoration(Color phaseColor, {bool isDark = false}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          phaseColor.withOpacity(isDark ? 0.3 : 0.15),
          phaseColor.withOpacity(isDark ? 0.15 : 0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(radiusXl),
      border: Border.all(
        color: phaseColor.withOpacity(0.2),
        width: 1,
      ),
    );
  }
  
  // ============ PHASE HELPERS ============
  
  static Color getPhaseColor(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return periodPink;
      case CyclePhaseType.follicular:
        return follicularYellow;
      case CyclePhaseType.ovulation:
        return ovulationBlue;
      case CyclePhaseType.luteal:
        return lutealGreen;
      case CyclePhaseType.pms:
        return accentOrange;
    }
  }
  
  static LinearGradient getPhaseGradient(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return periodGradient;
      case CyclePhaseType.follicular:
        return follicularGradient;
      case CyclePhaseType.ovulation:
        return ovulationGradient;
      case CyclePhaseType.luteal:
        return lutealGradient;
      case CyclePhaseType.pms:
        return pmsGradient;
    }
  }
  
  static Color getPhaseBackgroundColor(CyclePhaseType phase, {bool isDark = false}) {
    final baseColor = getPhaseColor(phase);
    return isDark 
        ? baseColor.withOpacity(0.15) 
        : baseColor.withOpacity(0.08);
  }
  
  static String getPhaseEmoji(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return '😌';
      case CyclePhaseType.follicular:
        return '⚡';
      case CyclePhaseType.ovulation:
        return '💕';
      case CyclePhaseType.luteal:
        return '🧘';
      case CyclePhaseType.pms:
        return '🥺';
    }
  }
  
  static String getPhaseName(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return 'Period Phase';
      case CyclePhaseType.follicular:
        return 'Follicular Phase';
      case CyclePhaseType.ovulation:
        return 'Ovulation Phase';
      case CyclePhaseType.luteal:
        return 'Luteal Phase';
      case CyclePhaseType.pms:
        return 'PMS Phase';
    }
  }
  
  static String getPhaseDescription(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return 'Rest and self-care time';
      case CyclePhaseType.follicular:
        return 'Rising energy and creativity';
      case CyclePhaseType.ovulation:
        return 'Peak energy and fertility';
      case CyclePhaseType.luteal:
        return 'Winding down, reflection';
      case CyclePhaseType.pms:
        return 'Extra self-care needed';
    }
  }
  
  // ============ PREGNANCY HELPERS ============
  
  static Color getPregnancyTrimesterColor(int trimester) {
    switch (trimester) {
      case 1:
        return const Color(0xFFFFCDD2); // Light pink
      case 2:
        return const Color(0xFFF8BBD9); // Pink
      case 3:
        return const Color(0xFFE1BEE7); // Light purple
      default:
        return periodPink;
    }
  }
  
  // ============ ANIMATION DURATIONS ============
  
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animVerySlow = Duration(milliseconds: 800);
  
  // ============ CURVES ============
  
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  
  // ============ DARK MODE HELPERS ============
  
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
  
  static Color getBackground(BuildContext context) {
    return isDark(context) ? backgroundDark : background;
  }
  
  static Color getSurface(BuildContext context) {
    return isDark(context) ? surfaceDark : surface;
  }
  
  static Color getTextPrimary(BuildContext context) {
    return isDark(context) ? Colors.white : textPrimary;
  }
  
  static Color getTextSecondary(BuildContext context) {
    return isDark(context) ? Colors.white70 : textSecondary;
  }
  
  static Color getDivider(BuildContext context) {
    return isDark(context) ? dividerDark : divider;
  }
}

/// Cycle phase types for theming
enum CyclePhaseType {
  menstrual,
  follicular,
  ovulation,
  luteal,
  pms,
}

/// Extension to convert from existing CyclePhase enum
extension CyclePhaseTypeExtension on CyclePhaseType {
  static CyclePhaseType fromLegacy(dynamic legacyPhase) {
    final name = legacyPhase.toString().split('.').last;
    switch (name) {
      case 'menstrual':
        return CyclePhaseType.menstrual;
      case 'follicular':
        return CyclePhaseType.follicular;
      case 'ovulation':
        return CyclePhaseType.ovulation;
      case 'luteal':
        return CyclePhaseType.luteal;
      case 'pms':
        return CyclePhaseType.pms;
      default:
        return CyclePhaseType.follicular;
    }
  }
}
