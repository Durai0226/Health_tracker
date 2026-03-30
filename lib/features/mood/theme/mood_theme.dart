import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mood Feature Theme - BloomFit Wellness Design
/// Single file to control the entire mood feature appearance
/// Theme adapts based on user's recent mood patterns
class MoodTheme {
  // ============================================
  // MOOD TYPE ENUM
  // ============================================
  static const String moodHappy = 'happy';
  static const String moodSad = 'sad';
  static const String moodLove = 'love';
  static const String moodNeutral = 'neutral';
  static const String moodAngry = 'angry';
  static const String moodAnxious = 'anxious';
  static const String moodExcited = 'excited';
  static const String moodTired = 'tired';

  // ============================================
  // PRIMARY COLORS - Exact Behance Design Palette
  // Purple gradient: #F0EFFE → #291D4A
  // ============================================
  static const Color primary = Color(0xFF9884F3);
  static const Color primaryDark = Color(0xFF673DC5);
  static const Color primaryLight = Color(0xFFC9C7FC);
  static const Color primarySoft = Color(0xFFF0EFFE);
  static const Color primaryDeep = Color(0xFF5650DF);
  static const Color primaryDarkest = Color(0xFF291D4A);
  
  // Extended purple palette from design
  static const Color purple50 = Color(0xFFF0EFFE);
  static const Color purple100 = Color(0xFFE0E0FF);
  static const Color purple200 = Color(0xFFC9C7FC);
  static const Color purple300 = Color(0xFFACA7F9);
  static const Color purple400 = Color(0xFF9884F3);
  static const Color purple500 = Color(0xFF8868EB);
  static const Color purple600 = Color(0xFF776CDF);
  static const Color purple700 = Color(0xFF673DC5);
  static const Color purple800 = Color(0xFF5650DF);
  static const Color purple900 = Color(0xFF46317E);
  static const Color purple950 = Color(0xFF291D4A);

  // ============================================
  // SECONDARY COLORS - Warm Cream/Beige from Design
  // Beige gradient: #F7F6F5 → #292D22
  // ============================================
  static const Color secondary = Color(0xFFF7F6F5);
  static const Color secondaryDark = Color(0xFFF0EFEC);
  static const Color cream = Color(0xFFFFFBF5);
  
  // Extended beige palette from design
  static const Color beige50 = Color(0xFFF7F6F5);
  static const Color beige100 = Color(0xFFF0EFEC);
  static const Color beige200 = Color(0xFFDDD7CE);
  static const Color beige300 = Color(0xFFC7B5B0);
  static const Color beige400 = Color(0xFFAAA1BE);
  static const Color beige500 = Color(0xFF9B8E7E);
  static const Color beige600 = Color(0xFF887D68);
  static const Color beige700 = Color(0xFF74695A);
  static const Color beige800 = Color(0xFF61674C);
  static const Color beige900 = Color(0xFF4F475F);
  static const Color beige950 = Color(0xFF292D22);

  // ============================================
  // ACCENT COLORS
  // ============================================
  static const Color accentGold = Color(0xFFFFD966);
  static const Color accentPink = Color(0xFFFFB5C5);
  static const Color accentCoral = Color(0xFFFF9F9F);

  // ============================================
  // BACKGROUND COLORS
  // ============================================
  static const Color background = Color(0xFFFAFAFA);
  static const Color backgroundSecondary = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFEFC);

  // Dark mode backgrounds
  static const Color backgroundDark = Color(0xFF121218);
  static const Color backgroundSecondaryDark = Color(0xFF1A1A24);
  static const Color surfaceDark = Color(0xFF22222E);
  static const Color surfaceElevatedDark = Color(0xFF2A2A38);

  // ============================================
  // TEXT COLORS
  // ============================================
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF8B8B8B);
  static const Color textLight = Color(0xFFAAAAAA);

  // Dark mode text
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textMutedDark = Color(0xFF808080);

  // ============================================
  // MOOD COLORS - 3D Emoji Color Mapping
  // ============================================
  static const Color moodHappyColor = Color(0xFFFFD93D);
  static const Color moodHappyLight = Color(0xFFFFF4CC);
  static const Color moodHappyGradientEnd = Color(0xFFFFB347);

  static const Color moodSadColor = Color(0xFF6EB5FF);
  static const Color moodSadLight = Color(0xFFE3F2FF);
  static const Color moodSadGradientEnd = Color(0xFF4A90D9);

  static const Color moodLoveColor = Color(0xFFFF6B9D);
  static const Color moodLoveLight = Color(0xFFFFE4ED);
  static const Color moodLoveGradientEnd = Color(0xFFFF4081);

  static const Color moodNeutralColor = Color(0xFFB8B8B8);
  static const Color moodNeutralLight = Color(0xFFF0F0F0);
  static const Color moodNeutralGradientEnd = Color(0xFF909090);

  static const Color moodAngryColor = Color(0xFFFF6B6B);
  static const Color moodAngryLight = Color(0xFFFFE4E4);
  static const Color moodAngryGradientEnd = Color(0xFFE53935);

  static const Color moodAnxiousColor = Color(0xFFFFAB40);
  static const Color moodAnxiousLight = Color(0xFFFFF3E0);
  static const Color moodAnxiousGradientEnd = Color(0xFFFF8F00);

  static const Color moodExcitedColor = Color(0xFFAB47BC);
  static const Color moodExcitedLight = Color(0xFFF3E5F5);
  static const Color moodExcitedGradientEnd = Color(0xFF8E24AA);

  static const Color moodTiredColor = Color(0xFF78909C);
  static const Color moodTiredLight = Color(0xFFECEFF1);
  static const Color moodTiredGradientEnd = Color(0xFF546E7A);

  // ============================================
  // MOOD COLOR GETTERS
  // ============================================
  static Color getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case moodHappy:
        return moodHappyColor;
      case moodSad:
        return moodSadColor;
      case moodLove:
        return moodLoveColor;
      case moodNeutral:
        return moodNeutralColor;
      case moodAngry:
        return moodAngryColor;
      case moodAnxious:
        return moodAnxiousColor;
      case moodExcited:
        return moodExcitedColor;
      case moodTired:
        return moodTiredColor;
      default:
        return primary;
    }
  }

  static Color getMoodLightColor(String mood) {
    switch (mood.toLowerCase()) {
      case moodHappy:
        return moodHappyLight;
      case moodSad:
        return moodSadLight;
      case moodLove:
        return moodLoveLight;
      case moodNeutral:
        return moodNeutralLight;
      case moodAngry:
        return moodAngryLight;
      case moodAnxious:
        return moodAnxiousLight;
      case moodExcited:
        return moodExcitedLight;
      case moodTired:
        return moodTiredLight;
      default:
        return primarySoft;
    }
  }

  static LinearGradient getMoodGradient(String mood) {
    Color start = getMoodColor(mood);
    Color end;
    switch (mood.toLowerCase()) {
      case moodHappy:
        end = moodHappyGradientEnd;
        break;
      case moodSad:
        end = moodSadGradientEnd;
        break;
      case moodLove:
        end = moodLoveGradientEnd;
        break;
      case moodNeutral:
        end = moodNeutralGradientEnd;
        break;
      case moodAngry:
        end = moodAngryGradientEnd;
        break;
      case moodAnxious:
        end = moodAnxiousGradientEnd;
        break;
      case moodExcited:
        end = moodExcitedGradientEnd;
        break;
      case moodTired:
        end = moodTiredGradientEnd;
        break;
      default:
        end = primaryDark;
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [start, end],
    );
  }

  static String getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case moodHappy:
        return '😊';
      case moodSad:
        return '😢';
      case moodLove:
        return '🥰';
      case moodNeutral:
        return '😐';
      case moodAngry:
        return '😠';
      case moodAnxious:
        return '😰';
      case moodExcited:
        return '🤩';
      case moodTired:
        return '😴';
      default:
        return '😊';
    }
  }

  static String getMoodLabel(String mood) {
    switch (mood.toLowerCase()) {
      case moodHappy:
        return 'Happy';
      case moodSad:
        return 'Sad';
      case moodLove:
        return 'Loved';
      case moodNeutral:
        return 'Neutral';
      case moodAngry:
        return 'Angry';
      case moodAnxious:
        return 'Anxious';
      case moodExcited:
        return 'Excited';
      case moodTired:
        return 'Tired';
      default:
        return 'Unknown';
    }
  }

  // ============================================
  // ADAPTIVE THEME - Based on Mood Patterns
  // ============================================
  static Color getAdaptivePrimary(String? dominantMood) {
    if (dominantMood == null) return primary;
    return getMoodColor(dominantMood);
  }

  static Color getAdaptiveAccent(String? dominantMood) {
    if (dominantMood == null) return accentGold;
    return getMoodLightColor(dominantMood);
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
    colors: [surface, secondaryDark],
  );

  static LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.8),
      Colors.white.withOpacity(0.4),
    ],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEDE8FF),
      Color(0xFFD4CCFF),
      Color(0xFFEDE8FF),
    ],
  );

  // Dark mode gradients
  static const LinearGradient backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, backgroundSecondaryDark],
  );

  // ============================================
  // BORDER RADIUS
  // ============================================
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;
  static const double radiusRound = 100.0;

  static BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static BorderRadius borderRadiusXxl = BorderRadius.circular(radiusXxl);
  static BorderRadius borderRadiusRound = BorderRadius.circular(radiusRound);

  // ============================================
  // SPACING
  // ============================================
  static const double spacingXxs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  static const double spacingXxxl = 64.0;

  // ============================================
  // SHADOWS
  // ============================================
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> getMoodShadow(String mood) {
    return [
      BoxShadow(
        color: getMoodColor(mood).withOpacity(0.25),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

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
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -1.5,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -1.0,
      );

  static TextStyle get headingXl => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get headingLg => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get headingMd => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get headingSm => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get titleLg => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get titleMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: textMuted,
        letterSpacing: 0.3,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.5,
      );

  static TextStyle get emojiLarge => const TextStyle(
        fontSize: 72,
        height: 1.2,
      );

  static TextStyle get emojiMedium => const TextStyle(
        fontSize: 48,
        height: 1.2,
      );

  static TextStyle get emojiSmall => const TextStyle(
        fontSize: 32,
        height: 1.2,
      );

  static TextStyle get statValue => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: primary,
      );

  static TextStyle get statLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      );

  // ============================================
  // CARD DECORATIONS
  // ============================================
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: borderRadiusLg,
        boxShadow: cardShadow,
      );

  static BoxDecoration get glassDecoration => BoxDecoration(
        gradient: glassGradient,
        borderRadius: borderRadiusLg,
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: softShadow,
      );

  static BoxDecoration get primaryDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: borderRadiusMd,
        boxShadow: primaryShadow,
      );

  static BoxDecoration get outlineDecoration => BoxDecoration(
        color: Colors.transparent,
        borderRadius: borderRadiusMd,
        border: Border.all(
          color: primary,
          width: 2,
        ),
      );

  static BoxDecoration getMoodDecoration(String mood) => BoxDecoration(
        color: getMoodLightColor(mood),
        borderRadius: borderRadiusMd,
        border: Border.all(
          color: getMoodColor(mood).withOpacity(0.3),
          width: 1,
        ),
      );

  // ============================================
  // ANIMATIONS
  // ============================================
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationVerySlow = Duration(milliseconds: 800);
  static const Duration animationPage = Duration(milliseconds: 400);

  static const Curve animationCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve springCurve = Curves.easeOutBack;

  // ============================================
  // ICON SIZES
  // ============================================
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // ============================================
  // ACTIVITY ICONS (for mood tracking) - Extended from Design
  // ============================================
  static const Map<String, IconData> activityIcons = {
    // Original activities
    'exercise': Icons.fitness_center_rounded,
    'work': Icons.work_rounded,
    'social': Icons.people_rounded,
    'sleep': Icons.bedtime_rounded,
    'food': Icons.restaurant_rounded,
    'music': Icons.music_note_rounded,
    'nature': Icons.park_rounded,
    'reading': Icons.menu_book_rounded,
    'gaming': Icons.sports_esports_rounded,
    'meditation': Icons.self_improvement_rounded,
    'travel': Icons.flight_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'family': Icons.family_restroom_rounded,
    'pets': Icons.pets_rounded,
    'creative': Icons.palette_rounded,
    'learning': Icons.school_rounded,
    // New activities from Behance design
    'nutrition': Icons.eco_rounded,
    'coffee': Icons.coffee_rounded,
    'sport': Icons.sports_soccer_rounded,
    'dance': Icons.music_note_rounded,
    'date': Icons.favorite_rounded,
    'party': Icons.celebration_rounded,
    'traveling': Icons.luggage_rounded,
    'groceries': Icons.shopping_cart_rounded,
    'relax': Icons.spa_rounded,
    'beauty': Icons.face_rounded,
    'movies': Icons.movie_rounded,
    'cooking': Icons.soup_kitchen_rounded,
    'cleaning': Icons.cleaning_services_rounded,
    'selfcare': Icons.self_improvement_rounded,
  };

  static const Map<String, Color> activityColors = {
    'exercise': Color(0xFF4CAF50),
    'work': Color(0xFF2196F3),
    'social': Color(0xFFFF9800),
    'sleep': Color(0xFF673AB7),
    'food': Color(0xFFE91E63),
    'music': Color(0xFF9C27B0),
    'nature': Color(0xFF8BC34A),
    'reading': Color(0xFF795548),
    'gaming': Color(0xFF00BCD4),
    'meditation': Color(0xFF3F51B5),
    'travel': Color(0xFFFF5722),
    'shopping': Color(0xFFFFC107),
    'family': Color(0xFFf44336),
    'pets': Color(0xFF009688),
    'creative': Color(0xFFCDDC39),
    'learning': Color(0xFF607D8B),
    // New activity colors from design
    'nutrition': Color(0xFF66BB6A),
    'coffee': Color(0xFF8D6E63),
    'sport': Color(0xFF42A5F5),
    'dance': Color(0xFFEC407A),
    'date': Color(0xFFEF5350),
    'party': Color(0xFFAB47BC),
    'traveling': Color(0xFF26A69A),
    'groceries': Color(0xFF7CB342),
    'relax': Color(0xFF9575CD),
    'beauty': Color(0xFFFF8A80),
    'movies': Color(0xFF5C6BC0),
    'cooking': Color(0xFFFF7043),
    'cleaning': Color(0xFF4DD0E1),
    'selfcare': Color(0xFFBA68C8),
  };

  // ============================================
  // NAV BAR THEME COLORS
  // ============================================
  static Color get navBarBackground => surface;
  static Color get navBarBackgroundDark => surfaceDark;
  static Color get navBarActiveColor => primary;
  static Color get navBarInactiveColor => textMuted;
  static Color get navBarIndicatorColor => primary;

  // ============================================
  // HELPER METHODS
  // ============================================
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color getBackgroundColor(BuildContext context) {
    return isDark(context) ? backgroundDark : background;
  }

  static Color getSurfaceColor(BuildContext context) {
    return isDark(context) ? surfaceDark : surface;
  }

  static Color getTextPrimaryColor(BuildContext context) {
    return isDark(context) ? textPrimaryDark : textPrimary;
  }

  static Color getTextSecondaryColor(BuildContext context) {
    return isDark(context) ? textSecondaryDark : textSecondary;
  }

  // ============================================
  // FULL THEME DATA
  // ============================================
  static ThemeData get themeData => ThemeData(
        brightness: Brightness.light,
        primaryColor: primary,
        scaffoldBackgroundColor: background,
        cardColor: surface,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: primaryDark,
          surface: surface,
          error: Color(0xFFE53935),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: textPrimary),
          titleTextStyle: headingSm,
        ),
        textTheme: TextTheme(
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
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
            textStyle: button,
            elevation: 0,
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
          fillColor: backgroundSecondary,
          border: OutlineInputBorder(
            borderRadius: borderRadiusMd,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadiusMd,
            borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadiusMd,
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          hintStyle: bodySm,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textMuted,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primary,
          linearTrackColor: backgroundSecondary,
          circularTrackColor: backgroundSecondary,
        ),
      );

  static ThemeData get darkThemeData => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        scaffoldBackgroundColor: backgroundDark,
        cardColor: surfaceDark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryDark,
          surface: surfaceDark,
          error: Color(0xFFEF5350),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: textPrimaryDark),
          titleTextStyle: headingSm.copyWith(color: textPrimaryDark),
        ),
        textTheme: TextTheme(
          headlineLarge: headingLg.copyWith(color: textPrimaryDark),
          headlineMedium: headingMd.copyWith(color: textPrimaryDark),
          headlineSmall: headingSm.copyWith(color: textPrimaryDark),
          titleLarge: titleLg.copyWith(color: textPrimaryDark),
          titleMedium: titleMd.copyWith(color: textPrimaryDark),
          titleSmall: titleSm.copyWith(color: textPrimaryDark),
          bodyLarge: bodyLg.copyWith(color: textPrimaryDark),
          bodyMedium: bodyMd.copyWith(color: textSecondaryDark),
          bodySmall: bodySm.copyWith(color: textSecondaryDark),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: borderRadiusMd),
            textStyle: button,
            elevation: 0,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceDark,
          selectedItemColor: primary,
          unselectedItemColor: textMutedDark,
        ),
      );
}
