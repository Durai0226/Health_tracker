import 'dart:ui';
import 'package:flutter/material.dart';

/// Habit Land Theme Constants
/// Based on Behance Habit Land design - Work Sans font, blue/purple palette
class HabitTheme {
  HabitTheme._();

  // ==========================================
  // PRIMARY COLORS (from Behance #7C91F4)
  // ==========================================
  
  /// Primary blue/purple - main brand color
  static const Color primary = Color(0xFF7C91F4);
  
  /// Lighter primary
  static const Color primaryLight = Color(0xFF9BABF7);
  
  /// Darker primary
  static const Color primaryDark = Color(0xFF5D72D5);
  
  /// Soft primary for backgrounds
  static const Color primarySoft = Color(0xFFE8ECFD);

  // ==========================================
  // SECONDARY COLORS
  // ==========================================
  
  /// Cream/Beige for accents (#FEF0CD)
  static const Color cream = Color(0xFFFEF0CD);
  
  /// Light cream
  static const Color creamLight = Color(0xFFFFF8E7);
  
  /// White
  static const Color white = Color(0xFFFFFFFF);
  
  /// Dark text (#1C1D22)
  static const Color dark = Color(0xFF1C1D22);
  
  /// Gray (#B0B3BF)
  static const Color gray = Color(0xFFB0B3BF);
  
  /// Light gray
  static const Color grayLight = Color(0xFFE5E7EB);
  
  /// Very light background
  static const Color background = Color(0xFFF8F9FC);

  // ==========================================
  // ACCENT COLORS
  // ==========================================
  
  /// Success green
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  
  /// Warning orange
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  
  /// Error red
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  
  /// Info blue
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ==========================================
  // HABIT CATEGORY COLORS
  // ==========================================
  
  static const Color categoryStudy = Color(0xFF7C91F4);
  static const Color categoryExercise = Color(0xFF4CAF50);
  static const Color categoryWork = Color(0xFFFF9800);
  static const Color categoryHealth = Color(0xFFE91E63);
  static const Color categorySocial = Color(0xFF00BCD4);
  static const Color categoryCreative = Color(0xFF9C27B0);
  static const Color categoryMindfulness = Color(0xFF3F51B5);
  static const Color categoryFinance = Color(0xFF795548);

  static const List<Color> habitColors = [
    Color(0xFFE53935), // Red
    Color(0xFFFF5722), // Deep Orange
    Color(0xFFFF9800), // Orange
    Color(0xFFFFC107), // Amber
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF8BC34A), // Light Green
    Color(0xFF4CAF50), // Green
    Color(0xFF009688), // Teal
    Color(0xFF00BCD4), // Cyan
    Color(0xFF2196F3), // Blue
    Color(0xFF3F51B5), // Indigo
    Color(0xFF7C91F4), // Primary
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
  ];

  // ==========================================
  // GRADIENTS
  // ==========================================
  
  /// Main gradient for headers/cards
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C91F4), Color(0xFF9BABF7)],
  );
  
  /// Progress card gradient (matches Behance design)
  static const LinearGradient progressCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8C5F9), Color(0xFFE8D4F8), Color(0xFFFBE5D6)],
  );
  
  /// Soft gradient for backgrounds
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FC), Color(0xFFFFFFFF)],
  );
  
  /// Completed habit gradient
  static const LinearGradient completedGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
  );

  // ==========================================
  // SHADOWS
  // ==========================================
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primary.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: primary.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primary.withOpacity(0.15),
      blurRadius: 30,
      offset: const Offset(0, 15),
      spreadRadius: 0,
    ),
  ];
  
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // ==========================================
  // BORDER RADIUS
  // ==========================================
  
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusFull = 100.0;

  // ==========================================
  // SPACING
  // ==========================================
  
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;

  // ==========================================
  // TYPOGRAPHY (Work Sans style)
  // ==========================================
  
  /// H1 - 22pt SemiBold
  static TextStyle get h1 => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: dark,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  /// H2 - 18pt SemiBold
  static TextStyle get h2 => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: dark,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  /// B1 - 16pt Regular
  static TextStyle get b1 => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: dark,
    height: 1.5,
  );
  
  /// B2 - 14pt Regular
  static TextStyle get b2 => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: dark,
    height: 1.5,
  );
  
  /// B3 - 13pt Regular
  static TextStyle get b3 => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: gray,
    height: 1.5,
  );
  
  /// Description - 12pt Regular
  static TextStyle get description => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: gray,
    height: 1.5,
  );
  
  /// Label - 14pt SemiBold
  static TextStyle get label => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: dark,
    letterSpacing: 0.3,
  );
  
  /// Caption - 11pt Medium
  static TextStyle get caption => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: gray,
    letterSpacing: 0.2,
  );
  
  /// Button text
  static TextStyle get button => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: white,
    letterSpacing: 0.5,
  );

  // ==========================================
  // HABIT ICONS (Material Icons code points)
  // ==========================================
  
  static const List<IconData> habitIcons = [
    Icons.book_outlined,
    Icons.fitness_center,
    Icons.directions_run,
    Icons.local_drink_outlined,
    Icons.restaurant_outlined,
    Icons.self_improvement,
    Icons.music_note_outlined,
    Icons.brush_outlined,
    Icons.code,
    Icons.school_outlined,
    Icons.work_outline,
    Icons.favorite_outline,
    Icons.bedtime_outlined,
    Icons.wb_sunny_outlined,
    Icons.phone_android,
    Icons.no_drinks_outlined,
    Icons.smoke_free,
    Icons.savings_outlined,
    Icons.shopping_cart_outlined,
    Icons.pets_outlined,
    Icons.eco_outlined,
    Icons.sports_esports_outlined,
    Icons.sports_soccer_outlined,
    Icons.pool_outlined,
    Icons.hiking_outlined,
    Icons.directions_bike_outlined,
    Icons.medication_outlined,
    Icons.local_cafe_outlined,
    Icons.cleaning_services_outlined,
    Icons.timer_outlined,
  ];

  // ==========================================
  // GLASSMORPHISM HELPERS
  // ==========================================
  
  static BoxDecoration glassDecoration({
    Color? color,
    double opacity = 0.7,
    double borderRadius = radiusL,
  }) {
    return BoxDecoration(
      color: (color ?? white).withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: white.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: subtleShadow,
    );
  }
  
  static ImageFilter get glassBlur => ImageFilter.blur(sigmaX: 10, sigmaY: 10);

  // ==========================================
  // ANIMATION DURATIONS
  // ==========================================
  
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;

  // ==========================================
  // TIME OF DAY HELPERS
  // ==========================================
  
  static const List<String> timeOfDayLabels = ['Anytime', 'Morning', 'Afternoon', 'Evening'];
  static const List<IconData> timeOfDayIcons = [
    Icons.access_time,
    Icons.wb_sunny_outlined,
    Icons.wb_twilight,
    Icons.nightlight_outlined,
  ];

  // ==========================================
  // DAY LABELS
  // ==========================================
  
  static const List<String> dayLabelsShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> dayLabelsFull = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}

/// Extension for easy color manipulation
extension HabitColorExtension on Color {
  Color get soft => withOpacity(0.1);
  Color get medium => withOpacity(0.5);
  Color get strong => withOpacity(0.8);
}
