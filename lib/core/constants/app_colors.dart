
import 'package:flutter/material.dart';

class AppColors {
  // Medical Theme
  static const Color primary = Color(0xFF00897B); // Deep Teal
  static const Color primaryDark = Color(0xFF00695C);
  static const Color primaryLight = Color(0xFFB2DFDB);
  static const Color accent = Color(0xFFFF8A80); // Soft Coral

  // Backgrounds
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Dividers & Borders
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);
  static const Color secondary = Color(0xFF6B7280);
  static const Color shadow = Color(0x1A000000);

  // ============ THEME-AWARE COLOR GETTERS ============
  
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkBackground : background;
  }
  
  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkSurface : surface;
  }
  
  static Color getCardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkCard : cardBg;
  }
  
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkTextPrimary : textPrimary;
  }
  
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkTextSecondary : textSecondary;
  }
  
  static Color getTextLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkTextLight : textLight;
  }
  
  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkDivider : divider;
  }
  
  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkBorder : border;
  }
  
  static Color getElevatedCardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkElevatedCard : cardBg;
  }
  
  static Color getShimmer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkShimmer : const Color(0xFFE0E0E0);
  }
  
  static Color getShadow(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkShadow : shadow;
  }
  
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Focus Theme
  static const Color focusPrimary = Color(0xFF8B5CF6);
  static const Color focusLight = Color(0xFFEDE9FE);
  static const Color focusAccent = Color(0xFF7C3AED);

  // Period Theme (Elegant Rose)
  static const Color periodPrimary = Color(0xFFE91E63);
  static const Color periodLight = Color(0xFFFCE4EC);
  static const Color periodAccent = Color(0xFF9C27B0);
  static const Color periodHighlight = Color(0xFFF8BBD9);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF26A69A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF8A80), Color(0xFFFF5252)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient periodGradient = LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF8F9FA), Color(0xFFE8F5E9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient focusGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============ LUXURY DARK THEME COLORS ============
  // Deep, rich backgrounds with subtle blue undertones for luxury feel
  static const Color darkBackground = Color(0xFF0A0E14);      // Deep space black
  static const Color darkSurface = Color(0xFF12171E);         // Rich charcoal
  static const Color darkCard = Color(0xFF1A2028);            // Elevated card
  static const Color darkElevatedCard = Color(0xFF222A35);    // Higher elevation
  static const Color darkBorder = Color(0xFF2D3748);          // Subtle border
  static const Color darkTextPrimary = Color(0xFFF7FAFC);     // Crisp white
  static const Color darkTextSecondary = Color(0xFFA0AEC0);   // Muted silver
  static const Color darkTextLight = Color(0xFF718096);       // Soft gray
  static const Color darkDivider = Color(0xFF2D3748);         // Subtle divider
  static const Color darkShimmer = Color(0xFF2D3748);         // Shimmer effect
  static const Color darkShadow = Color(0x40000000);          // Deep shadow
  
  // Luxury accent colors for dark theme
  static const Color darkAccentGold = Color(0xFFD4AF37);      // Gold accent
  static const Color darkAccentPurple = Color(0xFF9F7AEA);    // Royal purple
  static const Color darkAccentTeal = Color(0xFF38B2AC);      // Vibrant teal
  static const Color darkAccentRose = Color(0xFFED64A6);      // Elegant rose

  // Main Gradients  
  static const LinearGradient darkAccentGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alarmGradient = LinearGradient(
    colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============ LUXURY DARK THEME GRADIENTS ============
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF00695C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkLuxuryGradient = LinearGradient(
    colors: [Color(0xFF1A2028), Color(0xFF12171E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGoldGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF1A2028), Color(0xFF0A0E14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF222A35), Color(0xFF1A2028)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gradient helper for theme-aware usage
  static LinearGradient getSurfaceGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkSurfaceGradient : surfaceGradient;
  }

  static LinearGradient getCardGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? darkCardGradient : const LinearGradient(
            colors: [Colors.white, Color(0xFFFAFAFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }

  // ============ ADDITIONAL THEME-AWARE HELPERS ============
  
  /// Get appropriate grey color for dark/light mode
  static Color getGrey100(BuildContext context) {
    return isDark(context) ? darkCard : Colors.grey[100]!;
  }
  
  static Color getGrey200(BuildContext context) {
    return isDark(context) ? darkBorder : Colors.grey[200]!;
  }
  
  static Color getGrey300(BuildContext context) {
    return isDark(context) ? darkBorder : Colors.grey[300]!;
  }
  
  static Color getGrey50(BuildContext context) {
    return isDark(context) ? darkSurface : Colors.grey[50]!;
  }

  /// Get modal/sheet background color
  static Color getModalBackground(BuildContext context) {
    return isDark(context) ? darkSurface : Colors.white;
  }

  /// Get icon background color  
  static Color getIconBackground(BuildContext context, Color accentColor) {
    return isDark(context) 
        ? accentColor.withOpacity(0.2) 
        : accentColor.withOpacity(0.1);
  }

  /// Get subtle shadow color
  static Color getSubtleShadow(BuildContext context) {
    return isDark(context) 
        ? Colors.black.withOpacity(0.3) 
        : Colors.black.withOpacity(0.05);
  }

  /// Get card shadow color
  static Color getCardShadow(BuildContext context) {
    return isDark(context) 
        ? Colors.black.withOpacity(0.4) 
        : Colors.black.withOpacity(0.08);
  }

  /// Get overlay color for modals
  static Color getOverlay(BuildContext context) {
    return isDark(context) 
        ? Colors.white.withOpacity(0.05) 
        : Colors.black.withOpacity(0.02);
  }

  /// Get container decoration for cards
  static BoxDecoration getCardDecoration(BuildContext context, {
    double borderRadius = 20,
    Color? customColor,
    bool elevated = false,
  }) {
    final bgColor = customColor ?? getCardBg(context);
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: isDark(context) 
          ? Border.all(color: darkBorder.withOpacity(0.5), width: 1) 
          : null,
      boxShadow: [
        BoxShadow(
          color: getCardShadow(context),
          blurRadius: elevated ? 20 : 12,
          offset: Offset(0, elevated ? 8 : 4),
        ),
      ],
    );
  }

  /// Get luxury glass effect decoration for cards
  static BoxDecoration getLuxuryCardDecoration(BuildContext context, {
    double borderRadius = 24,
    Color? accentColor,
  }) {
    final accent = accentColor ?? primary;
    return BoxDecoration(
      gradient: isDark(context) 
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                darkCard,
                darkElevatedCard,
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.95),
              ],
            ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark(context) 
            ? accent.withOpacity(0.2) 
            : accent.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark(context) 
              ? accent.withOpacity(0.15) 
              : accent.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Get gradient for feature-specific accents
  static LinearGradient getFeatureGradient(BuildContext context, Color accentColor) {
    return isDark(context) 
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.15),
              accentColor.withOpacity(0.05),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.1),
              accentColor.withOpacity(0.03),
            ],
          );
  }

  /// Get transparent app bar gradient for dark theme
  static LinearGradient? getAppBarGradient(BuildContext context, Color accentColor) {
    return isDark(context) 
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.2),
              accentColor.withOpacity(0.05),
            ],
          )
        : null;
  }

  /// Water feature specific colors
  static Color getWaterAccent(BuildContext context) {
    return isDark(context) ? const Color(0xFF4FC3F7) : info;
  }

  /// Focus feature specific colors  
  static Color getFocusAccent(BuildContext context) {
    return isDark(context) ? darkAccentPurple : focusPrimary;
  }

  /// Period feature specific colors
  static Color getPeriodAccent(BuildContext context) {
    return isDark(context) ? darkAccentRose : periodPrimary;
  }

  /// Finance feature specific colors
  static Color getFinanceAccent(BuildContext context) {
    return isDark(context) ? darkAccentGold : const Color(0xFF4CAF50);
  }
}
