import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/design/app_palette.dart';
import '../models/beverage_type.dart';

/// Aqua Water Tracking Theme - Modern 2025/2026 Design System
/// Dynamic beverage gradients with glassmorphism effects
class AquaTheme {
  AquaTheme._();

  // ==========================================
  // BEVERAGE COLORS
  // ==========================================
  
  /// Water - Fresh cyan blue
  static const Color waterPrimary = AppPalette.water;
  static const Color waterSecondary = AppPalette.waterStrong;
  
  /// Coffee - Rich brown
  static const Color coffeePrimary = Color(0xFF8B4513);
  static const Color coffeeSecondary = Color(0xFFD2691E);
  
  /// Tea - Golden amber
  static const Color teaPrimary = Color(0xFFDAA520);
  static const Color teaSecondary = Color(0xFFF4A460);
  
  /// Juice - Vibrant orange
  static const Color juicePrimary = Color(0xFFFF6B35);
  static const Color juiceSecondary = Color(0xFFFF8C00);
  
  /// Soda - Pink magenta
  static const Color sodaPrimary = Color(0xFFE91E63);
  static const Color sodaSecondary = Color(0xFFFF4081);
  
  /// Milk - Clean white
  static const Color milkPrimary = Color(0xFFFAFAFA);
  static const Color milkSecondary = Color(0xFFE0E0E0);
  
  /// Smoothie - Purple berry
  static const Color smoothiePrimary = Color(0xFF9C27B0);
  static const Color smoothieSecondary = Color(0xFFE040FB);
  
  /// Alcohol - Deep purple
  static const Color alcoholPrimary = Color(0xFF7B1FA2);
  static const Color alcoholSecondary = Color(0xFFAB47BC);
  
  /// Energy drink - Neon green
  static const Color energyPrimary = Color(0xFF76FF03);
  static const Color energySecondary = Color(0xFFB2FF59);

  // ==========================================
  // BACKGROUND COLORS
  // ==========================================
  
  static const Color backgroundLight = AppPalette.backgroundL;
  static const Color backgroundDark = AppPalette.backgroundD;
  static const Color cardLight = AppPalette.surfaceL;
  static const Color cardDark = AppPalette.surfaceD;
  static const Color surfaceLight = AppPalette.surfaceVariantL;
  static const Color surfaceDark = AppPalette.surfaceVariantD;

  // ==========================================
  // TEXT COLORS
  // ==========================================
  
  static const Color textPrimary = AppPalette.textPrimaryL;
  static const Color textSecondary = AppPalette.textSecondaryL;
  static const Color textTertiary = AppPalette.textTertiaryL;
  static const Color textOnDark = Colors.white;
  static const Color textOnPrimary = Colors.white;

  // ==========================================
  // STATUS COLORS
  // ==========================================
  
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ==========================================
  // BEVERAGE DATA
  // ==========================================
  
  static const Map<String, BeverageThemeData> beverages = {
    'water': BeverageThemeData(
      id: 'water',
      name: 'Water',
      emoji: '💧',
      primary: waterPrimary,
      secondary: waterSecondary,
      hydrationFactor: 1.0,
    ),
    'coffee': BeverageThemeData(
      id: 'coffee',
      name: 'Coffee',
      emoji: '☕',
      primary: coffeePrimary,
      secondary: coffeeSecondary,
      hydrationFactor: 0.8,
    ),
    'tea': BeverageThemeData(
      id: 'tea',
      name: 'Tea',
      emoji: '🍵',
      primary: teaPrimary,
      secondary: teaSecondary,
      hydrationFactor: 0.9,
    ),
    'juice': BeverageThemeData(
      id: 'juice',
      name: 'Juice',
      emoji: '🧃',
      primary: juicePrimary,
      secondary: juiceSecondary,
      hydrationFactor: 0.85,
    ),
    'soda': BeverageThemeData(
      id: 'soda',
      name: 'Soda',
      emoji: '🥤',
      primary: sodaPrimary,
      secondary: sodaSecondary,
      hydrationFactor: 0.7,
    ),
    'milk': BeverageThemeData(
      id: 'milk',
      name: 'Milk',
      emoji: '🥛',
      primary: milkPrimary,
      secondary: milkSecondary,
      hydrationFactor: 0.9,
    ),
    'smoothie': BeverageThemeData(
      id: 'smoothie',
      name: 'Smoothie',
      emoji: '🫐',
      primary: smoothiePrimary,
      secondary: smoothieSecondary,
      hydrationFactor: 0.85,
    ),
    'alcohol': BeverageThemeData(
      id: 'alcohol',
      name: 'Alcohol',
      emoji: '🍷',
      primary: alcoholPrimary,
      secondary: alcoholSecondary,
      hydrationFactor: -0.5,
    ),
    'energy': BeverageThemeData(
      id: 'energy',
      name: 'Energy',
      emoji: '⚡',
      primary: energyPrimary,
      secondary: energySecondary,
      hydrationFactor: 0.6,
    ),
  };

  /// Get beverage theme data (styling only) by ID.
  ///
  /// Prefers a curated gradient when one exists, otherwise derives styling from
  /// the real beverage catalog ([BeverageType.defaultBeverages]) so drinks like
  /// beer / energy drink / espresso keep their own accent instead of falling
  /// back to Water. Water is only used as a last resort for truly unknown ids.
  static BeverageThemeData getBeverage(String id) {
    final curated = beverages[id];
    if (curated != null) return curated;
    for (final b in BeverageType.defaultBeverages) {
      if (b.id == id) return themeFromBeverage(b);
    }
    return beverages['water']!;
  }

  /// Parse a `#RRGGBB` / `#AARRGGBB` hex string into a [Color].
  static Color colorFromHex(String hex) {
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final value = int.tryParse(h, radix: 16);
    return value != null ? Color(value) : waterPrimary;
  }

  /// Build [BeverageThemeData] styling for any [BeverageType], including custom
  /// beverages. Uses the curated gradient when available, otherwise derives a
  /// gradient from the beverage's own [BeverageType.colorHex].
  static BeverageThemeData themeFromBeverage(BeverageType b) {
    final curated = beverages[b.id];
    if (curated != null) return curated;
    final primary = colorFromHex(b.colorHex);
    final secondary = b.isAlcoholic
        ? Color.lerp(primary, Colors.black, 0.2)!
        : Color.lerp(primary, Colors.white, 0.28)!;
    return BeverageThemeData(
      id: b.id,
      name: b.name,
      emoji: b.emoji,
      primary: primary,
      secondary: secondary,
      hydrationFactor: b.hydrationPercent / 100.0,
    );
  }

  /// Get gradient for a beverage
  static LinearGradient getBeverageGradient(String beverageId, {bool vertical = true}) {
    final beverage = getBeverage(beverageId);
    return LinearGradient(
      begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
      end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
      colors: [beverage.primary, beverage.secondary],
    );
  }

  /// Get radial gradient for glow effects
  static RadialGradient getBeverageGlow(String beverageId, {double opacity = 0.3}) {
    final beverage = getBeverage(beverageId);
    return RadialGradient(
      colors: [
        beverage.primary.withOpacity(opacity),
        beverage.primary.withOpacity(0),
      ],
    );
  }

  // ==========================================
  // GRADIENTS
  // ==========================================
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [waterPrimary, waterSecondary],
  );

  static LinearGradient get backgroundGradientLight => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      waterPrimary.withOpacity(0.1),
      backgroundLight,
    ],
    stops: const [0.0, 0.4],
  );

  static LinearGradient get backgroundGradientDark => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      waterPrimary.withOpacity(0.15),
      backgroundDark,
    ],
    stops: const [0.0, 0.4],
  );

  // ==========================================
  // SHADOWS
  // ==========================================
  
  static List<BoxShadow> cardShadow(Color accentColor) => [
    BoxShadow(
      color: accentColor.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: accentColor.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get defaultCardShadow => cardShadow(waterPrimary);

  static List<BoxShadow> dropletGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4),
      blurRadius: 30,
      spreadRadius: 5,
    ),
    BoxShadow(
      color: color.withOpacity(0.2),
      blurRadius: 50,
      spreadRadius: 10,
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // ==========================================
  // BORDER RADIUS
  // ==========================================
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 32.0;
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
  
  static TextStyle get displayLarge => const TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displayMedium => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get heading1 => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static TextStyle get heading2 => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle get heading3 => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.4,
  );

  static TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySmall => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static TextStyle get labelLarge => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get labelMedium => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.5,
  );

  static TextStyle get caption => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.3,
  );

  // ==========================================
  // ANIMATION DURATIONS
  // ==========================================
  
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationFill = Duration(milliseconds: 800);
  static const Duration animationWave = Duration(milliseconds: 2500);
  static const Duration animationBubble = Duration(milliseconds: 3000);

  // ==========================================
  // CURVES
  // ==========================================
  
  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveSmooth = Curves.easeInOutCubic;

  // ==========================================
  // GLASSMORPHISM HELPERS
  // ==========================================
  
  static BoxDecoration glassDecoration({
    Color? color,
    double opacity = 0.7,
    double borderRadius = radiusMedium,
    Color? borderColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: shadows ?? subtleShadow,
    );
  }

  static BoxDecoration glassDecorationDark({
    double opacity = 0.3,
    double borderRadius = radiusMedium,
  }) {
    return BoxDecoration(
      color: Colors.black.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    );
  }

  static ImageFilter get glassBlur => ImageFilter.blur(sigmaX: 10, sigmaY: 10);

  // ==========================================
  // HELPER METHODS
  // ==========================================
  
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color getBackground(BuildContext context) {
    return isDark(context) ? backgroundDark : backgroundLight;
  }

  static Color getCardBg(BuildContext context) {
    return isDark(context) ? cardDark : cardLight;
  }

  static Color getSurface(BuildContext context) {
    return isDark(context) ? surfaceDark : surfaceLight;
  }

  static Color getTextPrimary(BuildContext context) {
    return isDark(context) ? textOnDark : textPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return isDark(context) ? textTertiary : textSecondary;
  }

  static LinearGradient getBackgroundGradient(BuildContext context) {
    return isDark(context) ? backgroundGradientDark : backgroundGradientLight;
  }

  static BoxDecoration getCardDecoration(BuildContext context, {Color? accentColor}) {
    final color = accentColor ?? waterPrimary;
    return BoxDecoration(
      color: getCardBg(context),
      borderRadius: BorderRadius.circular(radiusMedium),
      boxShadow: cardShadow(color),
      border: isDark(context) 
          ? Border.all(color: Colors.white.withOpacity(0.1))
          : null,
    );
  }
}

/// Beverage theme data class
class BeverageThemeData {
  final String id;
  final String name;
  final String emoji;
  final Color primary;
  final Color secondary;
  final double hydrationFactor;

  const BeverageThemeData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primary,
    required this.secondary,
    required this.hydrationFactor,
  });

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, secondary],
  );

  LinearGradient get horizontalGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, secondary],
  );

  Color get lightColor => Color.lerp(primary, Colors.white, 0.3)!;
  Color get darkColor => Color.lerp(secondary, Colors.black, 0.2)!;
}

/// Extension for color manipulation
extension AquaColorExtension on Color {
  Color get soft => withOpacity(0.1);
  Color get medium => withOpacity(0.5);
  Color get strong => withOpacity(0.8);
  
  Color mix(Color other, double amount) {
    return Color.lerp(this, other, amount)!;
  }
}
