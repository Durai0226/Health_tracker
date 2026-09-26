import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
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

  // Text and status colours are deliberately ABSENT.
  //
  // This class used to export `textPrimary/textSecondary/textTertiary` bound to
  // the LIGHT palette and `textOnDark = Colors.white`, i.e. exactly the shape of
  // the deleted `AppColors` consts that painted white-on-white in dark mode. A
  // const cannot know the brightness, so every consumer that reached for one was
  // one theme away from being unreadable. Read colour from
  // `AppColorsExt.of(context)` — or the context helpers at the bottom of this
  // file, which resolve through it.

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
  // SHADOWS
  // ==========================================

  /// The one card shadow, from the design system.
  ///
  /// What was here before was a two-layer ACCENT-TINTED glow (0.15/0.08 of the
  /// beverage colour, blur 20 and 10) plus a brightness-blind
  /// `black.withOpacity(0.05)` "subtle" variant. Neither matched
  /// [AppShadows.card] (0.06 light / 0.30 dark, blur 16, spread -2, offset
  /// 0,6), so a water card cast a visibly different shadow from every other
  /// card in the app — and the black-at-5% one was invisible on dark.
  ///
  /// It takes a context now because a shadow that cannot see the brightness
  /// cannot be right in both themes.
  static List<BoxShadow> cardShadow(BuildContext context) =>
      AppShadows.card(context);

  /// Sheets, dialogs, menus.
  static List<BoxShadow> elevatedShadow(BuildContext context) =>
      AppShadows.elevated(context);

  // ==========================================
  // BORDER RADIUS — aliases of the one scale
  // ==========================================
  //
  // Kept as names rather than deleted so the water widgets do not all have to
  // change in the same commit, but every value now resolves to [AppRadius].
  // `radiusFull` was 100 and is now the scale's 999: identical on any pill
  // smaller than 200pt, which is all of them.

  static const double radiusSmall = AppRadius.sm;    // 8
  static const double radiusMedium = AppRadius.lg;   // 16
  static const double radiusLarge = AppRadius.sheet; // 24
  static const double radiusFull = AppRadius.full;   // 999

  // ==========================================
  // SPACING — aliases of the 4pt scale
  // ==========================================
  //
  // Mapped BY VALUE, not by name: this scale's `M` is 16, which is
  // `AppSpacing.lg`, not `AppSpacing.md` (12). Renaming without measuring would
  // have quietly retightened every gap in the feature by 4pt.

  static const double spacingXS = AppSpacing.xs;  // 4
  static const double spacingS = AppSpacing.sm;   // 8
  static const double spacingM = AppSpacing.lg;   // 16
  static const double spacingL = AppSpacing.xl;   // 24
  static const double spacingXL = AppSpacing.xxl; // 32
  static const double spacingXXL = AppSpacing.huge; // 48

  // Typography lives in `AppType` / `Theme.of(context).textTheme`.
  //
  // The eleven `TextStyle` getters that were here (36/28/24/20/18/16/14/12/14/
  // 12/11) were a SECOND type scale, off the app's one at four of eleven steps,
  // and every one of them baked `color: AppPalette.textPrimaryL` — a light-mode
  // colour — into a const. A caller that forgot `.copyWith(color:)` rendered
  // near-black text on the dark surface.

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
  // HELPER METHODS
  // ==========================================
  
  static bool isDark(BuildContext context) => AppColorsExt.of(context).isDark;

  static Color getBackground(BuildContext context) =>
      AppColorsExt.of(context).background;

  static Color getCardBg(BuildContext context) =>
      AppColorsExt.of(context).surface;

  static Color getSurface(BuildContext context) =>
      AppColorsExt.of(context).surfaceVariant;

  static Color getTextPrimary(BuildContext context) =>
      AppColorsExt.of(context).textPrimary;

  static Color getTextSecondary(BuildContext context) =>
      AppColorsExt.of(context).textSecondary;

  /// The third text rank. It exists because two widgets were reaching for the
  /// deleted `textTertiary` CONST, which was the light value in both themes.
  static Color getTextTertiary(BuildContext context) =>
      AppColorsExt.of(context).textTertiary;

  /// The card surface every water widget shares: token surface, token radius,
  /// token shadow, and on dark the 1px outline `AppCard` uses — shadows read
  /// weakly on dark, so the outline is what defines the card's edge.
  ///
  /// `accentColor` is gone rather than ignored. Its only effect was tinting the
  /// shadow, which is the thing that made these cards disagree with every
  /// `AppCard` in the app.
  static BoxDecoration getCardDecoration(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return BoxDecoration(
      color: ext.surface,
      borderRadius: AppRadius.brCard,
      boxShadow: AppShadows.card(context),
      border: ext.isDark ? Border.all(color: ext.outline, width: 1) : null,
    );
  }

  /// The foreground for text or an icon drawn ON a beverage fill.
  ///
  /// Beverage identity is a real product decision (the quick-add block is
  /// deliberately tinted by the selected drink), but the colours it tints with
  /// are a hand-picked set spanning #FAFAFA (milk) to #7B1FA2 (alcohol) — so a
  /// hardcoded `Colors.white` foreground, which is what every one of these
  /// sites used, measured 1.04:1 on milk and 1.14:1 on energy's neon green.
  ///
  /// This picks whichever of white / near-black scores HIGHER against the fill,
  /// so the worst case is the crossover at relative luminance ~0.209, where
  /// both sides measure 4.09:1 — above the 3:1 large-text floor everywhere and
  /// above 4.5:1 for all but the mid-tone beverages.
  static Color onBeverage(Color fill) {
    final l = fill.computeLuminance();
    final againstWhite = 1.05 / (l + 0.05);
    final againstInk =
        (l + 0.05) / (AppPalette.textPrimaryL.computeLuminance() + 0.05);
    return againstWhite >= againstInk ? Colors.white : AppPalette.textPrimaryL;
  }

  /// A beverage's Material Symbol.
  ///
  /// DS-17: an emoji sized 20-28pt inside a decorated tile is CHROME, not
  /// content — it renders in the platform's emoji font, ignores the accent, and
  /// on Android is a different picture per OEM. Beverage identity still comes
  /// from [BeverageThemeData.primary]; the glyph is now drawn by the icon font
  /// the rest of the app uses.
  ///
  /// The user's own persisted cup emoji is NOT routed through here — that is a
  /// choice they made and stored, so it stays as they picked it.
  static IconData iconFor(String beverageId) {
    switch (beverageId.toLowerCase()) {
      case 'coffee':
      case 'espresso':
        return Symbols.coffee_rounded;
      case 'tea':
      case 'green_tea':
      case 'herbal_tea':
      case 'iced_tea':
        return Symbols.emoji_food_beverage_rounded;
      case 'milk':
      case 'juice':
      case 'orange_juice':
      case 'lemonade':
      case 'coconut_water':
      case 'soda':
      case 'diet_soda':
      case 'smoothie':
        return Symbols.local_drink_rounded;
      case 'energy':
      case 'energy_drink':
      case 'sports_drink':
        return Symbols.bolt_rounded;
      case 'beer':
        return Symbols.sports_bar_rounded;
      case 'wine':
      case 'alcohol':
      case 'spirits':
      case 'cocktail':
        return Symbols.local_bar_rounded;
      case 'water':
      case 'sparkling_water':
      default:
        return Symbols.water_drop_rounded;
    }
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
