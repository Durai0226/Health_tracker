import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Toast notification types
enum ToastType {
  success,
  error,
  warning,
  info,
  achievement,
  reminder,
}

/// Feature-specific toast theming
enum ToastFeature {
  general,
  water,
  medication,
  focus,
  finance,
  habit,
  mood,
  exam,
  fitness,
  period,
  notes,
}

/// Toast theme data containing colors and styling
class ToastThemeData {
  final Color primaryColor;
  final Color secondaryColor;
  final LinearGradient gradient;
  final IconData icon;
  final Color iconColor;
  final List<BoxShadow> glowShadow;

  const ToastThemeData({
    required this.primaryColor,
    required this.secondaryColor,
    required this.gradient,
    required this.icon,
    required this.iconColor,
    required this.glowShadow,
  });

  /// Get gradient border for glassmorphism effect
  LinearGradient get borderGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryColor.withOpacity(0.6),
      secondaryColor.withOpacity(0.3),
      primaryColor.withOpacity(0.1),
    ],
  );
}

/// Toast theme resolver
class ToastTheme {
  ToastTheme._();

  // ==========================================
  // FEATURE COLORS
  // ==========================================
  
  // General
  static const Color successPrimary = Color(0xFF10B981);
  static const Color successSecondary = Color(0xFF059669);
  static const Color errorPrimary = Color(0xFFEF4444);
  static const Color errorSecondary = Color(0xFFDC2626);
  static const Color warningPrimary = Color(0xFFF59E0B);
  static const Color warningSecondary = Color(0xFFD97706);
  static const Color infoPrimary = Color(0xFF3B82F6);
  static const Color infoSecondary = Color(0xFF2563EB);
  static const Color achievementPrimary = Color(0xFFD4AF37);
  static const Color achievementSecondary = Color(0xFFB8860B);
  
  // Water (Aqua)
  static const Color waterPrimary = Color(0xFF00D4FF);
  static const Color waterSecondary = Color(0xFF0EA5E9);
  
  // Medication (Nunito)
  static const Color medicationPrimary = Color(0xFF3D3D6B);
  static const Color medicationSecondary = Color(0xFF6B6B9D);
  
  // Focus
  static const Color focusPrimary = Color(0xFF8B5CF6);
  static const Color focusSecondary = Color(0xFF7C3AED);
  
  // Finance
  static const Color financePrimary = Color(0xFF10B981);
  static const Color financeSecondary = Color(0xFF059669);
  
  // Habit
  static const Color habitPrimary = Color(0xFF7C91F4);
  static const Color habitSecondary = Color(0xFF5B73E8);
  
  // Mood (dynamic, but default)
  static const Color moodPrimary = Color(0xFFEC4899);
  static const Color moodSecondary = Color(0xFFDB2777);
  
  // Exam
  static const Color examPrimary = Color(0xFFF59E0B);
  static const Color examSecondary = Color(0xFFD97706);
  
  // Fitness
  static const Color fitnessPrimary = Color(0xFFFF6B35);
  static const Color fitnessSecondary = Color(0xFFE85D26);
  
  // Period
  static const Color periodPrimary = Color(0xFFE91E63);
  static const Color periodSecondary = Color(0xFF9C27B0);
  
  // Notes
  static const Color notesPrimary = Color(0xFF6366F1);
  static const Color notesSecondary = Color(0xFF4F46E5);

  // ==========================================
  // THEME RESOLUTION
  // ==========================================

  /// Get theme data for a toast type
  static ToastThemeData getThemeForType(ToastType type) {
    switch (type) {
      case ToastType.success:
        return ToastThemeData(
          primaryColor: successPrimary,
          secondaryColor: successSecondary,
          gradient: _buildGradient(successPrimary, successSecondary),
          icon: Symbols.check_circle_rounded,
          iconColor: successPrimary,
          glowShadow: _buildGlow(successPrimary),
        );
      case ToastType.error:
        return ToastThemeData(
          primaryColor: errorPrimary,
          secondaryColor: errorSecondary,
          gradient: _buildGradient(errorPrimary, errorSecondary),
          icon: Symbols.error_rounded,
          iconColor: errorPrimary,
          glowShadow: _buildGlow(errorPrimary),
        );
      case ToastType.warning:
        return ToastThemeData(
          primaryColor: warningPrimary,
          secondaryColor: warningSecondary,
          gradient: _buildGradient(warningPrimary, warningSecondary),
          icon: Symbols.warning_rounded,
          iconColor: warningPrimary,
          glowShadow: _buildGlow(warningPrimary),
        );
      case ToastType.info:
        return ToastThemeData(
          primaryColor: infoPrimary,
          secondaryColor: infoSecondary,
          gradient: _buildGradient(infoPrimary, infoSecondary),
          icon: Symbols.info_rounded,
          iconColor: infoPrimary,
          glowShadow: _buildGlow(infoPrimary),
        );
      case ToastType.achievement:
        return ToastThemeData(
          primaryColor: achievementPrimary,
          secondaryColor: achievementSecondary,
          gradient: _buildGradient(achievementPrimary, achievementSecondary),
          icon: Symbols.star_rounded,
          iconColor: achievementPrimary,
          glowShadow: _buildGlow(achievementPrimary),
        );
      case ToastType.reminder:
        return ToastThemeData(
          primaryColor: infoPrimary,
          secondaryColor: infoSecondary,
          gradient: _buildGradient(infoPrimary, infoSecondary),
          icon: Symbols.notifications_active_rounded,
          iconColor: infoPrimary,
          glowShadow: _buildGlow(infoPrimary),
        );
    }
  }

  /// Get theme data for a feature
  static ToastThemeData getThemeForFeature(ToastFeature feature, {ToastType type = ToastType.success}) {
    Color primary;
    Color secondary;
    IconData icon;
    
    switch (feature) {
      case ToastFeature.water:
        primary = waterPrimary;
        secondary = waterSecondary;
        icon = Symbols.water_drop_rounded;
        break;
      case ToastFeature.medication:
        primary = medicationPrimary;
        secondary = medicationSecondary;
        icon = Symbols.medication_rounded;
        break;
      case ToastFeature.focus:
        primary = focusPrimary;
        secondary = focusSecondary;
        icon = Symbols.track_changes_rounded;
        break;
      case ToastFeature.finance:
        primary = financePrimary;
        secondary = financeSecondary;
        icon = Symbols.account_balance_wallet_rounded;
        break;
      case ToastFeature.habit:
        primary = habitPrimary;
        secondary = habitSecondary;
        icon = Symbols.repeat_rounded;
        break;
      case ToastFeature.mood:
        primary = moodPrimary;
        secondary = moodSecondary;
        icon = Symbols.mood_rounded;
        break;
      case ToastFeature.exam:
        primary = examPrimary;
        secondary = examSecondary;
        icon = Symbols.school_rounded;
        break;
      case ToastFeature.fitness:
        primary = fitnessPrimary;
        secondary = fitnessSecondary;
        icon = Symbols.fitness_center_rounded;
        break;
      case ToastFeature.period:
        primary = periodPrimary;
        secondary = periodSecondary;
        icon = Symbols.favorite_rounded;
        break;
      case ToastFeature.notes:
        primary = notesPrimary;
        secondary = notesSecondary;
        icon = Symbols.note_alt_rounded;
        break;
      case ToastFeature.general:
        return getThemeForType(type);
    }

    // Override icon based on type if needed
    if (type == ToastType.error) {
      icon = Symbols.error_rounded;
    } else if (type == ToastType.warning) {
      icon = Symbols.warning_rounded;
    } else if (type == ToastType.achievement) {
      icon = Symbols.star_rounded;
    }

    return ToastThemeData(
      primaryColor: primary,
      secondaryColor: secondary,
      gradient: _buildGradient(primary, secondary),
      icon: icon,
      iconColor: primary,
      glowShadow: _buildGlow(primary),
    );
  }

  /// Build standard gradient
  static LinearGradient _buildGradient(Color primary, Color secondary) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, secondary],
    );
  }

  /// Build glow shadow
  static List<BoxShadow> _buildGlow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.4),
        blurRadius: 20,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: color.withOpacity(0.2),
        blurRadius: 40,
        spreadRadius: 5,
      ),
    ];
  }

  // ==========================================
  // GLASSMORPHISM HELPERS
  // ==========================================

  /// Get glassmorphism background for light mode
  static Color get glassBackgroundLight => Colors.white.withOpacity(0.85);
  
  /// Get glassmorphism background for dark mode
  static Color get glassBackgroundDark => const Color(0xFF1A2028).withOpacity(0.9);

  /// Get glassmorphism background based on brightness
  static Color getGlassBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? glassBackgroundDark
        : glassBackgroundLight;
  }

  /// Get text color based on brightness
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A2E);
  }

  /// Get secondary text color based on brightness
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.7)
        : const Color(0xFF6B7280);
  }

  /// Get border color based on brightness
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.5);
  }

  // ==========================================
  // ANIMATION CONSTANTS
  // ==========================================

  static const Duration entryDuration = Duration(milliseconds: 350);
  static const Duration exitDuration = Duration(milliseconds: 250);
  static const Duration shimmerDuration = Duration(milliseconds: 2000);
  static const Duration particleDuration = Duration(milliseconds: 3000);
  static const Duration pulseDuration = Duration(milliseconds: 800);
  static const Duration defaultAutoDismiss = Duration(seconds: 4);

  static const Curve entryCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve pulseCurve = Curves.elasticOut;

  // ==========================================
  // LAYOUT CONSTANTS
  // ==========================================

  static const double borderRadius = 20.0;
  static const double iconSize = 28.0;
  static const double iconContainerSize = 48.0;
  static const double horizontalPadding = 16.0;
  static const double verticalPadding = 14.0;
  static const double topOffset = 50.0;
  static const double maxWidth = 400.0;
  static const double progressHeight = 3.0;
}
