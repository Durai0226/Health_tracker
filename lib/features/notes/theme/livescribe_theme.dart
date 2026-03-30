import 'package:flutter/material.dart';

/// Livescribe-inspired design system for the Notes feature
/// Clean, minimalist aesthetic with blue accents and paper-like feel
class LivescribeTheme {
  LivescribeTheme._();

  // ============ COLORS ============
  
  /// Primary blue - main accent color
  static const Color primary = Color(0xFF0066FF);
  static const Color primaryLight = Color(0xFF3385FF);
  static const Color primaryDark = Color(0xFF0052CC);
  
  /// Secondary blue backgrounds
  static const Color secondaryLight = Color(0xFFE8F4FF);
  static const Color secondaryMedium = Color(0xFFCCE5FF);
  
  /// Surface colors
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceGray = Color(0xFFF1F5F9);
  
  /// Text colors
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  /// Border colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderFocus = Color(0xFF0066FF);
  
  /// Canvas paper colors
  static const Color canvasWhite = Color(0xFFFFFFFF);
  static const Color canvasBeige = Color(0xFFFFF8E7);
  static const Color canvasGrid = Color(0xFFF0FFF0);
  static const Color canvasBlue = Color(0xFFF0F8FF);
  
  /// Paper line colors
  static const Color linedPaperLine = Color(0xFFE0E7EE);
  static const Color gridPaperLine = Color(0xFFE8F0E8);
  static const Color marginLine = Color(0xFFFFCCCC);
  
  /// Ink colors for drawing
  static const List<Color> inkColors = [
    Color(0xFF1A1D26), // Black
    Color(0xFF0066FF), // Blue
    Color(0xFFDC2626), // Red
    Color(0xFF059669), // Green
    Color(0xFF7C3AED), // Purple
    Color(0xFFEA580C), // Orange
    Color(0xFFCA8A04), // Yellow
    Color(0xFFDB2777), // Pink
    Color(0xFF0891B2), // Cyan
    Color(0xFF4B5563), // Gray
    Color(0xFF92400E), // Brown
    Color(0xFF1E40AF), // Navy
  ];
  
  /// Highlighter colors (with transparency)
  static const List<Color> highlighterColors = [
    Color(0x80FFEB3B), // Yellow
    Color(0x8000FF00), // Green
    Color(0x80FF69B4), // Pink
    Color(0x8000BFFF), // Blue
    Color(0x80FFA500), // Orange
    Color(0x80DA70D6), // Purple
  ];
  
  /// Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  /// Dark mode colors
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkSurfaceLight = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

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
  static const double spacing64 = 64.0;

  // ============ BORDER RADIUS ============
  
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radius2xl = 20.0;
  static const double radius3xl = 24.0;
  static const double radiusFull = 999.0;

  // ============ TYPOGRAPHY ============
  
  static const String fontFamily = 'Inter';
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
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
  
  static List<BoxShadow> shadowXs = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowXl = [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  
  static List<BoxShadow> shadowPrimary = [
    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ============ DECORATIONS ============
  
  static BoxDecoration cardDecoration({bool isDark = false}) => BoxDecoration(
    color: isDark ? darkSurfaceLight : surfaceWhite,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(
      color: isDark ? darkBorder : border,
      width: 1,
    ),
    boxShadow: shadowSm,
  );
  
  static BoxDecoration elevatedCardDecoration({bool isDark = false}) => BoxDecoration(
    color: isDark ? darkSurfaceLight : surfaceWhite,
    borderRadius: BorderRadius.circular(radiusXl),
    boxShadow: shadowMd,
  );
  
  static BoxDecoration notebookCoverDecoration(Color color) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color,
        color.withOpacity(0.85),
      ],
    ),
    borderRadius: BorderRadius.circular(radiusLg),
    boxShadow: shadowMd,
  );
  
  static BoxDecoration searchBarDecoration({bool isDark = false}) => BoxDecoration(
    color: isDark ? darkSurfaceLight : surfaceGray,
    borderRadius: BorderRadius.circular(radiusFull),
    border: Border.all(
      color: isDark ? darkBorder : borderLight,
      width: 1,
    ),
  );
  
  static BoxDecoration chipDecoration({
    bool isSelected = false,
    bool isDark = false,
  }) => BoxDecoration(
    color: isSelected 
        ? primary 
        : (isDark ? darkSurfaceLight : surfaceGray),
    borderRadius: BorderRadius.circular(radiusFull),
    border: isSelected ? null : Border.all(
      color: isDark ? darkBorder : border,
      width: 1,
    ),
  );
  
  static BoxDecoration toolbarDecoration({bool isDark = false}) => BoxDecoration(
    color: isDark ? darkSurface.withOpacity(0.95) : surfaceWhite.withOpacity(0.95),
    borderRadius: BorderRadius.circular(radius2xl),
    boxShadow: shadowLg,
    border: Border.all(
      color: isDark ? darkBorder : border,
      width: 1,
    ),
  );
  
  static BoxDecoration floatingActionDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, primaryDark],
    ),
    borderRadius: BorderRadius.circular(radiusXl),
    boxShadow: shadowPrimary,
  );

  // ============ PAPER TEMPLATES ============
  
  static const double lineSpacing = 28.0;
  static const double gridSize = 20.0;
  static const double marginLeft = 60.0;

  // ============ STROKE SETTINGS ============
  
  static const double penStrokeWidthThin = 1.5;
  static const double penStrokeWidthMedium = 3.0;
  static const double penStrokeWidthThick = 5.0;
  
  static const double highlighterStrokeWidth = 20.0;
  static const double eraserStrokeWidth = 30.0;

  // ============ ANIMATIONS ============
  
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);
  static const Duration durationVerySlow = Duration(milliseconds: 600);
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;

  // ============ HELPER METHODS ============
  
  static Color getTextColor(bool isDark) => isDark ? darkTextPrimary : textPrimary;
  static Color getSecondaryTextColor(bool isDark) => isDark ? darkTextSecondary : textSecondary;
  static Color getSurfaceColor(bool isDark) => isDark ? darkSurface : surfaceWhite;
  static Color getBackgroundColor(bool isDark) => isDark ? darkSurface : surfaceLight;
  static Color getBorderColor(bool isDark) => isDark ? darkBorder : border;
  
  /// Get notebook cover colors
  static const List<Color> notebookCovers = [
    Color(0xFF0066FF), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF6366F1), // Indigo
    Color(0xFF84CC16), // Lime
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF64748B), // Slate
  ];
}

/// Extension for easy dark mode color access
extension LivescribeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  
  Color get primaryColor => LivescribeTheme.primary;
  Color get textColor => LivescribeTheme.getTextColor(isDark);
  Color get secondaryTextColor => LivescribeTheme.getSecondaryTextColor(isDark);
  Color get surfaceColor => LivescribeTheme.getSurfaceColor(isDark);
  Color get backgroundColor => LivescribeTheme.getBackgroundColor(isDark);
  Color get borderColor => LivescribeTheme.getBorderColor(isDark);
}
