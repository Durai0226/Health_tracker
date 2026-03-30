import 'package:flutter/material.dart';
import 'dart:ui';

/// Luna Cycle theme - Women's wellness app
/// Based on "Safeline" Behance case study with Lufga font & pink design system
class LunaTheme {
  LunaTheme._();

  // ============ APP IDENTITY ============
  
  static const String appName = 'Luna Cycle';
  static const String tagline = 'Your Wellness Companion';
  
  // ============ PRIMARY COLORS (Safeline Palette) ============
  
  /// Main Safeline pink
  static const Color primaryPink = Color(0xFFFF6B8A);
  static const Color primaryPinkLight = Color(0xFFFFB6C1);
  static const Color primaryPinkDark = Color(0xFFE85577);
  static const Color primaryPinkSoft = Color(0xFFFFF0F3);
  
  /// Secondary coral
  static const Color secondaryCoral = Color(0xFFFF8A80);
  static const Color secondaryCoralLight = Color(0xFFFFCCBC);
  
  /// Accent purple (for special features)
  static const Color accentPurple = Color(0xFFB388FF);
  static const Color accentPurpleLight = Color(0xFFE1BEE7);
  
  /// Safety red (for emergency features)
  static const Color safetyRed = Color(0xFFFF5252);
  static const Color safetyRedLight = Color(0xFFFFCDD2);
  
  /// Community teal
  static const Color communityTeal = Color(0xFF4DB6AC);
  static const Color communityTealLight = Color(0xFFB2DFDB);
  
  /// Education blue
  static const Color educationBlue = Color(0xFF64B5F6);
  static const Color educationBlueLight = Color(0xFFBBDEFB);
  
  // ============ CYCLE PHASE COLORS ============
  
  /// Period phase - warm pink
  static const Color periodPink = Color(0xFFFF6B8A);
  static const Color periodPinkLight = Color(0xFFFFE4E8);
  
  /// Follicular phase - energetic yellow
  static const Color follicularYellow = Color(0xFFFFE082);
  static const Color follicularYellowLight = Color(0xFFFFF8E1);
  
  /// Ovulation phase - fertile blue
  static const Color ovulationBlue = Color(0xFF81D4FA);
  static const Color ovulationBlueLight = Color(0xFFE1F5FE);
  
  /// Luteal phase - calming green
  static const Color lutealGreen = Color(0xFFA5D6A7);
  static const Color lutealGreenLight = Color(0xFFE8F5E9);
  
  /// PMS phase - soothing lavender
  static const Color pmsLavender = Color(0xFFCE93D8);
  static const Color pmsLavenderLight = Color(0xFFF3E5F5);
  
  // ============ MOON PHASE COLORS ============
  
  static const Color moonNew = Color(0xFF37474F);
  static const Color moonWaxing = Color(0xFFFFE082);
  static const Color moonFull = Color(0xFFFFF9C4);
  static const Color moonWaning = Color(0xFFB0BEC5);
  
  // ============ NEUTRAL COLORS ============
  
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textOnPink = Color(0xFFFFFFFF);
  
  static const Color background = Color(0xFFFFF8F9);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  
  static const Color divider = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF424242);
  
  // ============ SEMANTIC COLORS ============
  
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
  
  // ============ GRADIENTS ============
  
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B8A), Color(0xFFFF8A80)],
  );
  
  static LinearGradient get softPinkGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF0F3), Color(0xFFFFFFFF)],
  );
  
  static LinearGradient get periodGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B8A), Color(0xFFFFB6C1)],
  );
  
  static LinearGradient get follicularGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE082), Color(0xFFFFF59D)],
  );
  
  static LinearGradient get ovulationGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF81D4FA), Color(0xFFB3E5FC)],
  );
  
  static LinearGradient get lutealGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA5D6A7), Color(0xFFC8E6C9)],
  );
  
  static LinearGradient get pmsGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCE93D8), Color(0xFFE1BEE7)],
  );
  
  static LinearGradient get safetyGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5252), Color(0xFFFF8A80)],
  );
  
  static LinearGradient get communityGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4DB6AC), Color(0xFF80CBC4)],
  );
  
  static LinearGradient get educationGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF64B5F6), Color(0xFF90CAF9)],
  );
  
  static LinearGradient moonGradient(double phase) {
    // phase: 0 = new moon, 0.5 = full moon, 1 = new moon again
    if (phase < 0.25) {
      return LinearGradient(
        colors: [moonNew, moonWaxing.withOpacity(phase * 4)],
      );
    } else if (phase < 0.5) {
      return const LinearGradient(colors: [moonWaxing, moonFull]);
    } else if (phase < 0.75) {
      return const LinearGradient(colors: [moonFull, moonWaning]);
    } else {
      return LinearGradient(
        colors: [moonWaning, moonNew.withOpacity((1 - phase) * 4)],
      );
    }
  }
  
  // ============ TYPOGRAPHY (Lufga Font) ============
  
  static const String fontFamily = 'Lufga';
  static const String fontFamilyFallback = 'Nunito';
  
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    color: textPrimary,
    height: 1.2,
  );
  
  static TextStyle get displayMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: textPrimary,
    height: 1.2,
  );
  
  static TextStyle get displaySmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );
  
  static TextStyle get headlineLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );
  
  static TextStyle get headlineMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  static TextStyle get headlineSmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle get titleSmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.5,
  );
  
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.6,
  );
  
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.6,
  );
  
  static TextStyle get bodySmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.5,
  );
  
  static TextStyle get labelLarge => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textPrimary,
  );
  
  static TextStyle get labelMedium => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textSecondary,
  );
  
  static TextStyle get labelSmall => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: textTertiary,
  );
  
  // ============ SPACING ============
  
  static const double spacingXxs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacing2xl = 24.0;
  static const double spacing3xl = 32.0;
  static const double spacing4xl = 40.0;
  static const double spacing5xl = 48.0;
  
  // ============ BORDER RADIUS ============
  
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radius3xl = 32.0;
  static const double radiusFull = 999.0;
  
  // ============ SHADOWS ============
  
  static List<BoxShadow> get shadowXs => [
    BoxShadow(
      color: primaryPink.withOpacity(0.08),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: primaryPink.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: primaryPink.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: primaryPink.withOpacity(0.15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get shadowXl => [
    BoxShadow(
      color: primaryPink.withOpacity(0.2),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  static List<BoxShadow> shadowColored(Color color, {double opacity = 0.25}) => [
    BoxShadow(
      color: color.withOpacity(opacity),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  // ============ GLASSMORPHISM ============
  
  static BoxDecoration glassCard({
    Color? color,
    double borderRadius = radiusLg,
    bool isDark = false,
    double blur = 10,
  }) {
    return BoxDecoration(
      color: (color ?? (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.85))),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: (isDark ? Colors.white : primaryPink).withOpacity(0.1),
        width: 1,
      ),
      boxShadow: shadowSm,
    );
  }
  
  static BoxDecoration pinkGlassCard({
    double borderRadius = radiusLg,
    bool isDark = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark 
          ? [primaryPink.withOpacity(0.2), primaryPinkDark.withOpacity(0.1)]
          : [primaryPinkSoft, Colors.white],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: primaryPink.withOpacity(0.15),
        width: 1,
      ),
      boxShadow: shadowSm,
    );
  }
  
  static BoxDecoration phaseCard(LunaCyclePhase phase, {bool isDark = false}) {
    final color = getPhaseColor(phase);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withOpacity(isDark ? 0.25 : 0.15),
          color.withOpacity(isDark ? 0.1 : 0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(radiusXl),
      border: Border.all(
        color: color.withOpacity(0.2),
        width: 1,
      ),
    );
  }
  
  // ============ PHASE HELPERS ============
  
  static Color getPhaseColor(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return periodPink;
      case LunaCyclePhase.follicular:
        return follicularYellow;
      case LunaCyclePhase.ovulation:
        return ovulationBlue;
      case LunaCyclePhase.luteal:
        return lutealGreen;
      case LunaCyclePhase.pms:
        return pmsLavender;
    }
  }
  
  static Color getPhaseLightColor(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return periodPinkLight;
      case LunaCyclePhase.follicular:
        return follicularYellowLight;
      case LunaCyclePhase.ovulation:
        return ovulationBlueLight;
      case LunaCyclePhase.luteal:
        return lutealGreenLight;
      case LunaCyclePhase.pms:
        return pmsLavenderLight;
    }
  }
  
  static LinearGradient getPhaseGradient(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return periodGradient;
      case LunaCyclePhase.follicular:
        return follicularGradient;
      case LunaCyclePhase.ovulation:
        return ovulationGradient;
      case LunaCyclePhase.luteal:
        return lutealGradient;
      case LunaCyclePhase.pms:
        return pmsGradient;
    }
  }
  
  static String getPhaseEmoji(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return '🌙';
      case LunaCyclePhase.follicular:
        return '🌸';
      case LunaCyclePhase.ovulation:
        return '✨';
      case LunaCyclePhase.luteal:
        return '🍃';
      case LunaCyclePhase.pms:
        return '💜';
    }
  }
  
  static String getPhaseMoonEmoji(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return '🌑'; // New moon
      case LunaCyclePhase.follicular:
        return '🌒'; // Waxing crescent
      case LunaCyclePhase.ovulation:
        return '🌕'; // Full moon
      case LunaCyclePhase.luteal:
        return '🌖'; // Waning gibbous
      case LunaCyclePhase.pms:
        return '🌘'; // Waning crescent
    }
  }
  
  static String getPhaseName(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return 'Menstrual';
      case LunaCyclePhase.follicular:
        return 'Follicular';
      case LunaCyclePhase.ovulation:
        return 'Ovulation';
      case LunaCyclePhase.luteal:
        return 'Luteal';
      case LunaCyclePhase.pms:
        return 'Pre-menstrual';
    }
  }
  
  static String getPhaseDescription(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return 'Rest, reflect, and nurture yourself';
      case LunaCyclePhase.follicular:
        return 'Rising energy, new beginnings';
      case LunaCyclePhase.ovulation:
        return 'Peak energy and confidence';
      case LunaCyclePhase.luteal:
        return 'Slow down and prepare';
      case LunaCyclePhase.pms:
        return 'Self-care and gentle activities';
    }
  }
  
  static String getPhaseAdvice(LunaCyclePhase phase) {
    switch (phase) {
      case LunaCyclePhase.menstrual:
        return 'Focus on rest, warm foods, and gentle stretching. Your body is working hard.';
      case LunaCyclePhase.follicular:
        return 'Great time to start new projects, try new workouts, and be social.';
      case LunaCyclePhase.ovulation:
        return 'Your communication skills peak now. Schedule important conversations.';
      case LunaCyclePhase.luteal:
        return 'Finish projects, organize your space, and prepare for the next cycle.';
      case LunaCyclePhase.pms:
        return 'Practice extra self-compassion. Reduce commitments if possible.';
    }
  }
  
  // ============ FEATURE COLORS ============
  
  static Color getFeatureColor(LunaFeature feature) {
    switch (feature) {
      case LunaFeature.cycle:
        return primaryPink;
      case LunaFeature.community:
        return communityTeal;
      case LunaFeature.education:
        return educationBlue;
      case LunaFeature.safety:
        return safetyRed;
      case LunaFeature.partner:
        return accentPurple;
    }
  }
  
  static LinearGradient getFeatureGradient(LunaFeature feature) {
    switch (feature) {
      case LunaFeature.cycle:
        return primaryGradient;
      case LunaFeature.community:
        return communityGradient;
      case LunaFeature.education:
        return educationGradient;
      case LunaFeature.safety:
        return safetyGradient;
      case LunaFeature.partner:
        return LinearGradient(
          colors: [accentPurple, accentPurpleLight],
        );
    }
  }
  
  static IconData getFeatureIcon(LunaFeature feature) {
    switch (feature) {
      case LunaFeature.cycle:
        return Icons.nightlight_round;
      case LunaFeature.community:
        return Icons.people_outline;
      case LunaFeature.education:
        return Icons.school_outlined;
      case LunaFeature.safety:
        return Icons.shield_outlined;
      case LunaFeature.partner:
        return Icons.favorite_outline;
    }
  }
  
  // ============ ANIMATION DURATIONS ============
  
  static const Duration animInstant = Duration(milliseconds: 100);
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animVerySlow = Duration(milliseconds: 800);
  static const Duration animPageTransition = Duration(milliseconds: 350);
  
  // ============ CURVES ============
  
  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveDecelerate = Curves.decelerate;
  
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
  
  static Color getTextTertiary(BuildContext context) {
    return isDark(context) ? Colors.white54 : textTertiary;
  }
  
  static Color getDivider(BuildContext context) {
    return isDark(context) ? dividerDark : divider;
  }
  
  // ============ THEME DATA ============
  
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryPink,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.light(
      primary: primaryPink,
      secondary: secondaryCoral,
      surface: surface,
      error: error,
    ),
    fontFamily: fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headlineMedium.copyWith(color: textPrimary),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primaryPink,
      unselectedItemColor: textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        textStyle: titleMedium.copyWith(color: Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryPink,
        side: const BorderSide(color: primaryPink, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryPink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: primaryPinkSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryPink, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimary,
      contentTextStyle: bodyMedium.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
  
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryPink,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: ColorScheme.dark(
      primary: primaryPink,
      secondary: secondaryCoral,
      surface: surfaceDark,
      error: error,
    ),
    fontFamily: fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: headlineMedium.copyWith(color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: primaryPink,
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),
  );
}

/// Luna Cycle phase types
enum LunaCyclePhase {
  menstrual,
  follicular,
  ovulation,
  luteal,
  pms,
}

/// Luna feature types for theming
enum LunaFeature {
  cycle,
  community,
  education,
  safety,
  partner,
}

/// Extension to convert from legacy CyclePhase
extension LunaCyclePhaseExtension on LunaCyclePhase {
  static LunaCyclePhase fromLegacy(dynamic legacyPhase) {
    final name = legacyPhase.toString().split('.').last.toLowerCase();
    switch (name) {
      case 'menstrual':
        return LunaCyclePhase.menstrual;
      case 'follicular':
        return LunaCyclePhase.follicular;
      case 'ovulation':
        return LunaCyclePhase.ovulation;
      case 'luteal':
        return LunaCyclePhase.luteal;
      case 'pms':
        return LunaCyclePhase.pms;
      default:
        return LunaCyclePhase.follicular;
    }
  }
  
  /// Convert to moon phase (0-1 scale where 0.5 is full moon)
  double get moonPhase {
    switch (this) {
      case LunaCyclePhase.menstrual:
        return 0.0; // New moon
      case LunaCyclePhase.follicular:
        return 0.25; // First quarter
      case LunaCyclePhase.ovulation:
        return 0.5; // Full moon
      case LunaCyclePhase.luteal:
        return 0.75; // Last quarter
      case LunaCyclePhase.pms:
        return 0.9; // Waning crescent
    }
  }
}
