import 'package:flutter/material.dart';

/// Evernote-inspired dark theme design system for Notes feature
/// Dark UI with Lime Green (#CDDC39) accent color
class EvernoteTheme {
  EvernoteTheme._();

  // ============ BRAND COLORS ============
  
  /// Primary lime green accent color (Evernote style)
  static const Color primary = Color(0xFFCDDC39);
  static const Color primaryLight = Color(0xFFDCE775);
  static const Color primaryDark = Color(0xFFC0CA33);
  static const Color primaryMuted = Color(0xFFD4E157);
  
  /// Secondary accent (slightly different green)
  static const Color secondary = Color(0xFFAFB42B);
  static const Color secondaryLight = Color(0xFFE6EE9C);
  
  // ============ DARK THEME COLORS ============
  
  /// Background colors (Evernote dark)
  static const Color background = Color(0xFF0D0D0D);
  static const Color backgroundElevated = Color(0xFF141414);
  
  /// Surface colors for cards and containers
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF242424);
  static const Color surfaceElevated = Color(0xFF2A2A2A);
  static const Color surfaceHighlight = Color(0xFF333333);
  
  /// Card specific colors
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF2E2E2E);
  static const Color cardHover = Color(0xFF262626);
  
  /// Border colors
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF3A3A3A);
  static const Color borderFocus = Color(0xFFCDDC39);
  static const Color divider = Color(0xFF252525);
  
  // ============ TEXT COLORS ============
  
  /// Text on dark background
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textMuted = Color(0xFF606060);
  static const Color textDisabled = Color(0xFF4A4A4A);
  
  /// Text on light/accent background
  static const Color textOnPrimary = Color(0xFF000000);
  static const Color textOnLight = Color(0xFF1A1A1A);
  
  // ============ CATEGORY COLORS ============
  
  /// Note category colors
  static const Color categoryWork = Color(0xFF2196F3);
  static const Color categoryPersonal = Color(0xFF9C27B0);
  static const Color categoryIdeas = Color(0xFFFF9800);
  static const Color categoryArchive = Color(0xFF607D8B);
  static const Color categoryAll = Color(0xFFCDDC39);
  
  static const List<Color> categoryColors = [
    Color(0xFFCDDC39), // Lime Green
    Color(0xFF2196F3), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFFFF9800), // Orange
    Color(0xFF4CAF50), // Green
    Color(0xFFE91E63), // Pink
    Color(0xFF673AB7), // Deep Purple
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF8BC34A), // Light Green
    Color(0xFF795548), // Brown
  ];
  
  // ============ STATUS COLORS ============
  
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFE57373);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF64B5F6);
  
  // ============ SPECIAL COLORS ============
  
  /// Pinned/favorite indicator
  static const Color pinned = Color(0xFFFFD700);
  static const Color favorite = Color(0xFFFF4081);
  
  /// Search highlight
  static const Color searchHighlight = Color(0xFFCDDC39);
  static const Color selectionColor = Color(0x33CDDC39);
  
  /// Shimmer/loading
  static const Color shimmerBase = Color(0xFF1A1A1A);
  static const Color shimmerHighlight = Color(0xFF2A2A2A);

  // ============ SPACING ============
  
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing10 = 10.0;
  static const double spacing12 = 12.0;
  static const double spacing14 = 14.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing56 = 56.0;
  static const double spacing64 = 64.0;

  // ============ BORDER RADIUS ============
  
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radius2xl = 24.0;
  static const double radius3xl = 32.0;
  static const double radiusFull = 999.0;

  // ============ TYPOGRAPHY ============
  
  static const String fontFamily = 'Inter';
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.4,
    height: 1.25,
  );
  
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.35,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.1,
    height: 1.4,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.45,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.45,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.4,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    height: 1.4,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.4,
  );

  // ============ SHADOWS ============
  
  static List<BoxShadow> shadowNone = [];
  
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Colors.black.withOpacity(0.35),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  
  static List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowInner = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: -2,
    ),
  ];

  // ============ DECORATIONS ============
  
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: cardBorder, width: 1),
  );
  
  static BoxDecoration cardHoverDecoration = BoxDecoration(
    color: cardHover,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: borderLight, width: 1),
  );
  
  static BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: surfaceElevated,
    borderRadius: BorderRadius.circular(radiusLg),
    boxShadow: shadowMd,
  );
  
  static BoxDecoration searchBarDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusFull),
    border: Border.all(color: border, width: 1),
  );
  
  static BoxDecoration chipDecoration({bool isSelected = false}) => BoxDecoration(
    color: isSelected ? primary : surface,
    borderRadius: BorderRadius.circular(radiusFull),
    border: Border.all(
      color: isSelected ? primary : border,
      width: 1,
    ),
  );
  
  static BoxDecoration bottomNavDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius2xl),
    boxShadow: shadowLg,
    border: Border.all(color: border, width: 1),
  );
  
  static BoxDecoration fabDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, primaryDark],
    ),
    borderRadius: BorderRadius.circular(radiusLg),
    boxShadow: shadowGlow,
  );
  
  static BoxDecoration modalDecoration = BoxDecoration(
    color: surfaceLight,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
  );

  // ============ GRADIENTS ============
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Color(0xFF0A0A0A)],
  );
  
  static LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceLight],
  );
  
  static LinearGradient fadeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, background],
  );

  // ============ ANIMATIONS ============
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationVerySlow = Duration(milliseconds: 600);
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveSharp = Curves.easeInOutCubic;

  // ============ ICON SIZES ============
  
  static const double iconXs = 14.0;
  static const double iconSm = 18.0;
  static const double iconMd = 22.0;
  static const double iconLg = 26.0;
  static const double iconXl = 32.0;
  static const double icon2xl = 40.0;

  // ============ BOTTOM NAV ============
  
  static const double bottomNavHeight = 70.0;
  static const double bottomNavItemSize = 48.0;
  static const double fabSize = 56.0;
}

/// Extension for easy theme color access
extension EvernoteColors on BuildContext {
  Color get primaryColor => EvernoteTheme.primary;
  Color get backgroundColor => EvernoteTheme.background;
  Color get surfaceColor => EvernoteTheme.surface;
  Color get cardColor => EvernoteTheme.cardBackground;
  Color get textColor => EvernoteTheme.textPrimary;
  Color get secondaryTextColor => EvernoteTheme.textSecondary;
  Color get borderColor => EvernoteTheme.border;
}
