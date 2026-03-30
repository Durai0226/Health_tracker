import 'package:flutter/material.dart';

/// Finance module theme based on the Behance UI design
/// Purple/Navy gradients with coral accents
class FinanceTheme {
  FinanceTheme._();

  // ==================== COLORS ====================
  
  // Primary Colors (Purple/Navy gradient)
  static const Color primaryDark = Color(0xFF1E1B4B);
  static const Color primary = Color(0xFF312E81);
  static const Color primaryLight = Color(0xFF4338CA);
  
  // Accent Colors
  static const Color accent = Color(0xFFF472B6);      // Coral/Pink
  static const Color accentLight = Color(0xFFFBCFE8);
  
  // Semantic Colors
  static const Color income = Color(0xFF10B981);      // Green
  static const Color expense = Color(0xFFEF4444);     // Red
  static const Color transfer = Color(0xFF6366F1);    // Indigo
  static const Color warning = Color(0xFFF59E0B);     // Orange
  
  // Background Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;
  
  // ==================== GRADIENTS ====================
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  static const LinearGradient incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), income],
  );
  
  static const LinearGradient expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), expense],
  );
  
  // ==================== SPACING ====================
  
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // ==================== BORDER RADIUS ====================
  
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusRound = 100.0;
  
  static BorderRadius borderRadiusS = BorderRadius.circular(radiusS);
  static BorderRadius borderRadiusM = BorderRadius.circular(radiusM);
  static BorderRadius borderRadiusL = BorderRadius.circular(radiusL);
  static BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  
  // ==================== SHADOWS ====================
  
  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: primary.withValues(alpha: 0.3),
      blurRadius: 30,
      offset: const Offset(0, 15),
    ),
  ];
  
  // ==================== TEXT STYLES ====================
  
  static const TextStyle headingXL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headingL = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );
  
  static const TextStyle headingM = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle headingS = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyL = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodyM = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodyS = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const TextStyle labelL = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
  
  static const TextStyle labelM = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
  
  static const TextStyle labelS = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textLight,
  );
  
  static const TextStyle currency = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: textOnPrimary,
    letterSpacing: -1,
  );
  
  static const TextStyle currencySmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  // ==================== ICONS ====================
  
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;
  
  // ==================== ANIMATION ====================
  
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  static const Curve animationCurve = Curves.easeInOut;
  
  // ==================== BOTTOM NAV ====================
  
  static const double bottomNavHeight = 80.0;
  static const double fabSize = 56.0;
  static const double fabExpandedSize = 180.0;
}

/// Extension for easy theme access
extension FinanceThemeContext on BuildContext {
  // Colors
  Color get primaryColor => FinanceTheme.primary;
  Color get accentColor => FinanceTheme.accent;
  Color get backgroundColor => FinanceTheme.background;
  Color get surfaceColor => FinanceTheme.surface;
  Color get incomeColor => FinanceTheme.income;
  Color get expenseColor => FinanceTheme.expense;
  
  // Gradients
  LinearGradient get primaryGradient => FinanceTheme.primaryGradient;
  LinearGradient get cardGradient => FinanceTheme.cardGradient;
  
  // Text Styles
  TextStyle get headingXL => FinanceTheme.headingXL;
  TextStyle get headingL => FinanceTheme.headingL;
  TextStyle get headingM => FinanceTheme.headingM;
  TextStyle get headingS => FinanceTheme.headingS;
  TextStyle get bodyL => FinanceTheme.bodyL;
  TextStyle get bodyM => FinanceTheme.bodyM;
  TextStyle get bodyS => FinanceTheme.bodyS;
  TextStyle get labelL => FinanceTheme.labelL;
  TextStyle get labelM => FinanceTheme.labelM;
  TextStyle get currencyStyle => FinanceTheme.currency;
}
