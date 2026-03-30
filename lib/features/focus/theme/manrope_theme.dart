import 'package:flutter/material.dart';

/// Manrope Design System Theme for Focus/Meditation Feature
/// Based on modern wellness app design with warm, calming color palette
class ManropeTheme {
  ManropeTheme._();

  // ==========================================
  // PRIMARY COLORS
  // ==========================================
  
  static const Color primaryOrange = Color(0xFFF5A623);
  static const Color primaryOrangeLight = Color(0xFFFFBE5C);
  static const Color primaryOrangeDark = Color(0xFFE8940A);
  
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentGreenLight = Color(0xFF81C784);
  static const Color accentGreenDark = Color(0xFF388E3C);
  
  static const Color calmTeal = Color(0xFF00BCD4);
  static const Color calmTealLight = Color(0xFF4DD0E1);
  static const Color calmTealDark = Color(0xFF0097A7);
  
  static const Color warmYellow = Color(0xFFFFCC00);
  static const Color warmYellowLight = Color(0xFFFFE066);
  static const Color warmYellowDark = Color(0xFFFFC107);
  
  static const Color softPink = Color(0xFFFF6B9D);
  static const Color softPinkLight = Color(0xFFFF8FB3);
  static const Color softPinkDark = Color(0xFFE91E63);
  
  static const Color deepPurple = Color(0xFF7C4DFF);
  static const Color deepPurpleLight = Color(0xFFB388FF);
  static const Color deepPurpleDark = Color(0xFF651FFF);

  // ==========================================
  // ACTIVITY COLORS
  // ==========================================
  
  static const Color meditationColor = Color(0xFFF5A623);
  static const Color yogaColor = Color(0xFFFF6B9D);
  static const Color breathingColor = Color(0xFF00BCD4);
  static const Color focusColor = Color(0xFF7C4DFF);
  static const Color walkingColor = Color(0xFF4CAF50);
  static const Color journalingColor = Color(0xFFFFCC00);

  // ==========================================
  // BACKGROUND COLORS
  // ==========================================
  
  static const Color background = Color(0xFFFAFAFA);
  static const Color backgroundPure = Color(0xFFFFFFFF);
  static const Color backgroundWarm = Color(0xFFFFF8F0);
  static const Color backgroundCard = Color(0xFFFFFFFF);
  
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color backgroundDarkCard = Color(0xFF2D2D2D);
  static const Color backgroundDarkElevated = Color(0xFF3D3D3D);

  // ==========================================
  // TEXT COLORS
  // ==========================================
  
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color textHint = Color(0xFFBDBDBD);
  
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  static const Color textTertiaryDark = Color(0xFF808080);

  // ==========================================
  // SURFACE COLORS
  // ==========================================
  
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceMedium = Color(0xFFEEEEEE);
  static const Color surfaceDark = Color(0xFFE0E0E0);
  
  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerDark = Color(0xFF424242);

  // ==========================================
  // SEMANTIC COLORS
  // ==========================================
  
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ==========================================
  // GRADIENTS
  // ==========================================
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryOrangeLight],
  );
  
  static const LinearGradient meditationGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5A623), Color(0xFFFFD54F)],
  );
  
  static const LinearGradient yogaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B9D), Color(0xFFFF8A80)],
  );
  
  static const LinearGradient breathingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)],
  );
  
  static const LinearGradient focusGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
  );
  
  static const LinearGradient walkingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
  );
  
  static const LinearGradient journalingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFCC00), Color(0xFFFFE082)],
  );
  
  static const LinearGradient warmSunset = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF8F0), Color(0xFFFFE4CC)],
  );
  
  static const LinearGradient calmOcean = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
  );

  // ==========================================
  // TYPOGRAPHY
  // ==========================================
  
  static const String fontFamily = 'Manrope';
  
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  );
  
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.29,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.27,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.43,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // ==========================================
  // SPACING
  // ==========================================
  
  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing6 = 6;
  static const double spacing8 = 8;
  static const double spacing10 = 10;
  static const double spacing12 = 12;
  static const double spacing14 = 14;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing28 = 28;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;
  static const double spacing56 = 56;
  static const double spacing64 = 64;

  // ==========================================
  // BORDER RADIUS
  // ==========================================
  
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 20;
  static const double radiusXXLarge = 24;
  static const double radiusRound = 100;
  
  static BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static BorderRadius borderRadiusXLarge = BorderRadius.circular(radiusXLarge);
  static BorderRadius borderRadiusXXLarge = BorderRadius.circular(radiusXXLarge);
  static BorderRadius borderRadiusRound = BorderRadius.circular(radiusRound);

  // ==========================================
  // SHADOWS
  // ==========================================
  
  static List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowXLarge = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  static List<BoxShadow> shadowColored(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: 24,
      spreadRadius: -4,
      offset: const Offset(0, 4),
    ),
  ];

  // ==========================================
  // ANIMATION DURATIONS
  // ==========================================
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVerySlow = Duration(milliseconds: 800);

  // ==========================================
  // ANIMATION CURVES
  // ==========================================
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSmooth = Curves.easeInOutCubic;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSharp = Curves.easeOutExpo;

  // ==========================================
  // HELPER METHODS
  // ==========================================
  
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimaryDark
        : textPrimary;
  }
  
  static Color getTextSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondaryDark
        : textSecondary;
  }
  
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : background;
  }
  
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDarkCard
        : backgroundCard;
  }
  
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static LinearGradient getActivityGradient(String activityType) {
    switch (activityType) {
      case 'meditation':
        return meditationGradient;
      case 'yoga':
        return yogaGradient;
      case 'breathing':
        return breathingGradient;
      case 'focus':
        return focusGradient;
      case 'walking':
        return walkingGradient;
      case 'journaling':
        return journalingGradient;
      default:
        return primaryGradient;
    }
  }
  
  static Color getActivityColor(String activityType) {
    switch (activityType) {
      case 'meditation':
        return meditationColor;
      case 'yoga':
        return yogaColor;
      case 'breathing':
        return breathingColor;
      case 'focus':
        return focusColor;
      case 'walking':
        return walkingColor;
      case 'journaling':
        return journalingColor;
      default:
        return primaryOrange;
    }
  }
}

/// Extension for easy color manipulation
extension ManropeColorExtension on Color {
  Color get soft => withOpacity(0.1);
  Color get medium => withOpacity(0.3);
  Color get strong => withOpacity(0.6);
  
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }
  
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }
}
