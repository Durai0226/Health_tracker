import 'package:flutter/material.dart';

/// Fitness Feature Theme - Bloomfit/Home Workout Style
/// Single file to control the entire fitness feature appearance
/// Change values here to update the entire feature look
class FitnessTheme {
  // ============================================
  // PRIMARY COLORS - Neon Yellow/Lime Accent
  // ============================================
  static const Color primary = Color(0xFFCDFF00);
  static const Color primaryDark = Color(0xFFB8E600);
  static const Color primaryLight = Color(0xFFE5FF66);
  
  // ============================================
  // BACKGROUND COLORS - Dark Theme
  // ============================================
  static const Color background = Color(0xFF0D0D0D);
  static const Color backgroundSecondary = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  
  // ============================================
  // TEXT COLORS
  // ============================================
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF808080);
  static const Color textOnPrimary = Color(0xFF0D0D0D);
  
  // ============================================
  // ACCENT COLORS
  // ============================================
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF3B82F6);
  
  // ============================================
  // BODY PART COLORS
  // ============================================
  static const Color fullBody = Color(0xFFCDFF00);
  static const Color abs = Color(0xFFFF6B6B);
  static const Color arms = Color(0xFF4ECDC4);
  static const Color legs = Color(0xFFFFE66D);
  static const Color chest = Color(0xFFFF8C42);
  static const Color back = Color(0xFF95E1D3);
  static const Color shoulders = Color(0xFFA78BFA);
  static const Color cardio = Color(0xFFFF6B9D);
  
  static Color getBodyPartColor(String bodyPart) {
    switch (bodyPart.toLowerCase()) {
      case 'full body':
        return fullBody;
      case 'abs':
        return abs;
      case 'arms':
        return arms;
      case 'legs':
        return legs;
      case 'chest':
        return chest;
      case 'back':
        return back;
      case 'shoulders':
        return shoulders;
      case 'cardio':
        return cardio;
      default:
        return primary;
    }
  }
  
  // ============================================
  // DIFFICULTY COLORS
  // ============================================
  static const Color beginner = Color(0xFF4ADE80);
  static const Color intermediate = Color(0xFFFBBF24);
  static const Color advanced = Color(0xFFEF4444);
  
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return beginner;
      case 'intermediate':
        return intermediate;
      case 'advanced':
        return advanced;
      default:
        return primary;
    }
  }
  
  // ============================================
  // GRADIENTS
  // ============================================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, backgroundSecondary],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2A2A),
      Color(0xFF1A1A1A),
    ],
  );
  
  static LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primary.withOpacity(0.3),
      primary.withOpacity(0.1),
      primary.withOpacity(0.3),
    ],
  );
  
  // ============================================
  // BORDER RADIUS
  // ============================================
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusRound = 100.0;
  
  static BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static BorderRadius borderRadiusRound = BorderRadius.circular(radiusRound);
  
  // ============================================
  // SPACING
  // ============================================
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  
  // ============================================
  // SHADOWS
  // ============================================
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> glowShadow = [
    BoxShadow(
      color: primary.withOpacity(0.4),
      blurRadius: 30,
      spreadRadius: 2,
    ),
  ];
  
  // ============================================
  // TYPOGRAPHY
  // ============================================
  static const String fontFamily = 'SF Pro Display';
  
  static const TextStyle headingXl = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headingLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headingMd = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headingSm = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle titleLg = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle titleMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle titleSm = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: textMuted,
    letterSpacing: 0.5,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textOnPrimary,
    letterSpacing: 0.5,
  );
  
  static const TextStyle timerLarge = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w200,
    color: textPrimary,
    letterSpacing: 4,
  );
  
  static const TextStyle timerMedium = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w300,
    color: textPrimary,
    letterSpacing: 2,
  );
  
  static const TextStyle statValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: primary,
  );
  
  static const TextStyle statLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  // ============================================
  // CARD DECORATIONS
  // ============================================
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: borderRadiusMd,
    border: Border.all(
      color: Colors.white.withOpacity(0.05),
      width: 1,
    ),
    boxShadow: cardShadow,
  );
  
  static BoxDecoration glassDecoration = BoxDecoration(
    color: cardBackground.withOpacity(0.8),
    borderRadius: borderRadiusMd,
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
      width: 1,
    ),
  );
  
  static BoxDecoration primaryDecoration = BoxDecoration(
    gradient: primaryGradient,
    borderRadius: borderRadiusMd,
    boxShadow: primaryShadow,
  );
  
  static BoxDecoration outlineDecoration = BoxDecoration(
    color: Colors.transparent,
    borderRadius: borderRadiusMd,
    border: Border.all(
      color: primary,
      width: 2,
    ),
  );
  
  // ============================================
  // ANIMATIONS
  // ============================================
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationVerySlow = Duration(milliseconds: 800);
  
  static const Curve animationCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  
  // ============================================
  // ICON SIZES
  // ============================================
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  
  // ============================================
  // WORKOUT TIMER SETTINGS
  // ============================================
  static const int defaultRestSeconds = 30;
  static const int defaultExerciseSeconds = 30;
  static const int countdownSeconds = 3;
  
  // ============================================
  // HELPER METHODS
  // ============================================
  static ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    cardColor: cardBackground,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: primaryDark,
      surface: surface,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: headingSm,
    ),
    textTheme: const TextTheme(
      headlineLarge: headingLg,
      headlineMedium: headingMd,
      headlineSmall: headingSm,
      titleLarge: titleLg,
      titleMedium: titleMd,
      titleSmall: titleSm,
      bodyLarge: bodyLg,
      bodyMedium: bodyMd,
      bodySmall: bodySm,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textOnPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
        textStyle: button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
        textStyle: button.copyWith(color: primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: borderRadiusMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadiusMd,
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusMd,
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: bodySm,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: background,
      selectedItemColor: primary,
      unselectedItemColor: textMuted,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: surfaceLight,
      circularTrackColor: surfaceLight,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: surfaceLight,
      thumbColor: primary,
      overlayColor: primary.withOpacity(0.2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary.withOpacity(0.5);
        return surfaceLight;
      }),
    ),
  );
}
