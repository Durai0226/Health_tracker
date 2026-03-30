import 'dart:ui';
import 'package:flutter/material.dart';

/// NUNITO Wellness App Theme Constants
/// Based on the Behance design for Wellness Aging Care Mood & Meds Tracking app
class NunitoTheme {
  NunitoTheme._();

  // ==========================================
  // PRIMARY COLORS
  // ==========================================
  
  /// Deep purple - main brand color
  static const Color primary = Color(0xFF3D3D6B);
  
  /// Slightly lighter purple
  static const Color primaryLight = Color(0xFF4A4A7D);
  
  /// Dark purple for emphasis
  static const Color primaryDark = Color(0xFF2D2D5B);
  
  /// Soft purple for secondary elements
  static const Color secondary = Color(0xFF6B6B9D);
  
  /// Light purple for backgrounds
  static const Color secondaryLight = Color(0xFF8E8EBF);
  
  // ==========================================
  // ACCENT COLORS
  // ==========================================
  
  /// Warm coral for alerts/important
  static const Color accent = Color(0xFFFF7B7B);
  
  /// Light blue for info/secondary actions
  static const Color accentBlue = Color(0xFF7BB3FF);
  
  /// Success green
  static const Color success = Color(0xFF4CAF50);
  
  /// Warning orange
  static const Color warning = Color(0xFFFF9800);
  
  /// Error red
  static const Color error = Color(0xFFE53935);
  
  // ==========================================
  // BACKGROUND COLORS
  // ==========================================
  
  /// Light mode background
  static const Color backgroundLight = Color(0xFFF5F5FA);
  
  /// Dark mode background
  static const Color backgroundDark = Color(0xFF1A1A2E);
  
  /// Card background light
  static const Color cardLight = Colors.white;
  
  /// Card background dark
  static const Color cardDark = Color(0xFF252540);
  
  /// Surface color for elevated elements
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Surface color dark mode
  static const Color surfaceDark = Color(0xFF2D2D4A);
  
  // ==========================================
  // TEXT COLORS
  // ==========================================
  
  /// Primary text color
  static const Color textPrimary = Color(0xFF2D2D4A);
  
  /// Secondary text color
  static const Color textSecondary = Color(0xFF6B6B9D);
  
  /// Tertiary/hint text
  static const Color textTertiary = Color(0xFF9E9EBF);
  
  /// Text on dark backgrounds
  static const Color textOnDark = Colors.white;
  
  /// Text on primary color
  static const Color textOnPrimary = Colors.white;
  
  // ==========================================
  // GRADIENT DEFINITIONS
  // ==========================================
  
  /// Main gradient for headers/buttons
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  /// Soft gradient for cards
  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8F8FF), Color(0xFFEEEEFA)],
  );
  
  /// Accent gradient
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, Color(0xFF5B93DF)],
  );
  
  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
  );
  
  // ==========================================
  // SHADOWS
  // ==========================================
  
  /// Soft shadow for cards
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
  
  /// Elevated shadow for floating elements
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: primary.withOpacity(0.15),
      blurRadius: 30,
      offset: const Offset(0, 15),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: primary.withOpacity(0.08),
      blurRadius: 15,
      offset: const Offset(0, 5),
      spreadRadius: 0,
    ),
  ];
  
  /// Subtle shadow for minimal elevation
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: primary.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  // ==========================================
  // BORDER RADIUS
  // ==========================================
  
  /// Small radius (buttons, chips)
  static const double radiusSmall = 8.0;
  
  /// Medium radius (cards, inputs)
  static const double radiusMedium = 16.0;
  
  /// Large radius (modals, sheets)
  static const double radiusLarge = 24.0;
  
  /// Extra large radius (pill shapes)
  static const double radiusXLarge = 32.0;
  
  /// Full round
  static const double radiusFull = 100.0;
  
  // ==========================================
  // SPACING
  // ==========================================
  
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // ==========================================
  // TYPOGRAPHY
  // ==========================================
  
  /// Display large - for big headers
  static TextStyle get displayLarge => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  /// Display medium
  static TextStyle get displayMedium => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  /// Heading 1
  static TextStyle get heading1 => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  /// Heading 2
  static TextStyle get heading2 => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  /// Heading 3
  static TextStyle get heading3 => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  /// Body large
  static TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  /// Body medium
  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  /// Body small
  static TextStyle get bodySmall => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  /// Label large
  static TextStyle get labelLarge => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );
  
  /// Label medium
  static TextStyle get labelMedium => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.5,
  );
  
  /// Caption
  static TextStyle get caption => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.3,
  );
  
  // ==========================================
  // PILL COLORS (for medication visualization)
  // ==========================================
  
  static const List<Color> pillColors = [
    Color(0xFFFFFFFF), // White
    Color(0xFFFFF3E0), // Cream/Beige
    Color(0xFFFFCDD2), // Light Pink
    Color(0xFFE91E63), // Pink
    Color(0xFFF44336), // Red
    Color(0xFFFF5722), // Orange
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF8BC34A), // Light Green
    Color(0xFF4CAF50), // Green
    Color(0xFF009688), // Teal
    Color(0xFF00BCD4), // Cyan
    Color(0xFF2196F3), // Blue
    Color(0xFF3F51B5), // Indigo
    Color(0xFF673AB7), // Purple
    Color(0xFF9C27B0), // Deep Purple
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF9E9E9E), // Grey
    Color(0xFF212121), // Black
  ];
  
  static const List<String> pillColorNames = [
    'White',
    'Cream',
    'Light Pink',
    'Pink',
    'Red',
    'Orange',
    'Yellow',
    'Light Green',
    'Green',
    'Teal',
    'Cyan',
    'Blue',
    'Indigo',
    'Purple',
    'Deep Purple',
    'Brown',
    'Blue Grey',
    'Grey',
    'Black',
  ];
  
  // ==========================================
  // MOOD COLORS
  // ==========================================
  
  static const Color moodGreat = Color(0xFF4CAF50);
  static const Color moodGood = Color(0xFF8BC34A);
  static const Color moodOkay = Color(0xFFFFEB3B);
  static const Color moodBad = Color(0xFFFF9800);
  static const Color moodTerrible = Color(0xFFE53935);
  
  static const List<String> moodEmojis = ['😄', '🙂', '😐', '😕', '😢'];
  static const List<String> moodLabels = ['Great', 'Good', 'Okay', 'Bad', 'Terrible'];
  static const List<Color> moodColors = [moodGreat, moodGood, moodOkay, moodBad, moodTerrible];
  
  // ==========================================
  // GLASSMORPHISM HELPERS
  // ==========================================
  
  /// Creates a glassmorphism decoration
  static BoxDecoration glassDecoration({
    Color? color,
    double opacity = 0.7,
    double borderRadius = radiusMedium,
    double blur = 10,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: subtleShadow,
    );
  }
  
  /// Glassmorphism with blur effect (use with BackdropFilter)
  static ImageFilter get glassBlur => ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  
  // ==========================================
  // ANIMATION DURATIONS
  // ==========================================
  
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // ==========================================
  // CURVES
  // ==========================================
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
}

/// Extension for easy color manipulation
extension NunitoColorExtension on Color {
  Color get soft => withOpacity(0.1);
  Color get medium => withOpacity(0.5);
  Color get strong => withOpacity(0.8);
}
