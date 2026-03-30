import 'package:flutter/material.dart';

/// Modern 2025/2026 design system for Exam Prep feature
/// Glassmorphism, gradients, and premium visual effects
class ExamPrepTheme {
  ExamPrepTheme._();

  // Primary Colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Subject Colors
  static const Color quantitative = Color(0xFF3B82F6); // Blue
  static const Color reasoning = Color(0xFF8B5CF6); // Purple
  static const Color english = Color(0xFF10B981); // Green
  static const Color generalAwareness = Color(0xFFF59E0B); // Amber
  static const Color computer = Color(0xFF06B6D4); // Cyan
  static const Color generalScience = Color(0xFFEC4899); // Pink

  // Exam Category Colors
  static const Color banking = Color(0xFF0EA5E9);
  static const Color ssc = Color(0xFF22C55E);
  static const Color railways = Color(0xFFEF4444);
  static const Color statePsc = Color(0xFFF97316);
  static const Color defense = Color(0xFF14B8A6);
  static const Color teaching = Color(0xFFA855F7);

  // Difficulty Colors
  static const Color easy = Color(0xFF22C55E);
  static const Color medium = Color(0xFFF59E0B);
  static const Color hard = Color(0xFFEF4444);

  // Status Colors
  static const Color correct = Color(0xFF10B981);
  static const Color incorrect = Color(0xFFEF4444);
  static const Color skipped = Color(0xFF6B7280);
  static const Color bookmarked = Color(0xFFF59E0B);

  // Semantic Colors (aliases)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Background Colors
  static Color getBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC);
  }

  static Color getCardBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1A1A2E) : Colors.white;
  }

  static Color getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF1E293B);
  }

  static Color getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  }

  // Subject color map
  static Color getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'quantitative aptitude':
      case 'quantitative':
      case 'mathematics':
      case 'maths':
        return quantitative;
      case 'reasoning':
      case 'logical reasoning':
        return reasoning;
      case 'english':
      case 'english language':
        return english;
      case 'general awareness':
      case 'general knowledge':
      case 'gk':
      case 'current affairs':
        return generalAwareness;
      case 'computer':
      case 'computer awareness':
        return computer;
      case 'general science':
      case 'science':
        return generalScience;
      default:
        return primary;
    }
  }

  // Exam category color map
  static Color getExamCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'banking':
      case 'ibps':
      case 'sbi':
      case 'rbi':
        return banking;
      case 'ssc':
      case 'ssc cgl':
      case 'ssc chsl':
        return ssc;
      case 'railways':
      case 'rrb':
      case 'rrb ntpc':
        return railways;
      case 'state psc':
      case 'upsc':
      case 'psc':
        return statePsc;
      case 'defense':
      case 'cds':
      case 'nda':
        return defense;
      case 'teaching':
      case 'ctet':
      case 'tet':
        return teaching;
      default:
        return primary;
    }
  }

  // Difficulty color map
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return easy;
      case 'medium':
        return medium;
      case 'hard':
      case 'difficult':
        return hard;
      default:
        return medium;
    }
  }

  // Gradients
  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primaryLight],
      );

  static LinearGradient getSubjectGradient(String subject) {
    final color = getSubjectColor(subject);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, color.withOpacity(0.7)],
    );
  }

  static LinearGradient getExamCategoryGradient(String category) {
    final color = getExamCategoryColor(category);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, color.withOpacity(0.7)],
    );
  }

  // Glassmorphism decoration
  static BoxDecoration glassCard(BuildContext context, {Color? accentColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? primary;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                accent.withOpacity(0.15),
                accent.withOpacity(0.05),
              ]
            : [
                Colors.white.withOpacity(0.95),
                accent.withOpacity(0.05),
              ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: accent.withOpacity(isDark ? 0.2 : 0.15),
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withOpacity(isDark ? 0.15 : 0.1),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Premium card decoration
  static BoxDecoration premiumCard(BuildContext context, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? primary;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [cardColor.withOpacity(0.2), cardColor.withOpacity(0.08)]
            : [Colors.white, cardColor.withOpacity(0.05)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cardColor.withOpacity(0.15)),
      boxShadow: [
        BoxShadow(
          color: cardColor.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Icon container decoration
  static BoxDecoration iconContainer(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withOpacity(0.8)],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Progress bar decoration
  static BoxDecoration progressBarBg(Color color) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      color: color.withOpacity(0.15),
    );
  }

  static BoxDecoration progressBarFill(Color color) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.8)],
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // Text styles
  static TextStyle headingLarge(BuildContext context) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: getTextPrimary(context),
      letterSpacing: -0.5,
    );
  }

  static TextStyle headingMedium(BuildContext context) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: getTextPrimary(context),
      letterSpacing: -0.3,
    );
  }

  static TextStyle headingSmall(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: getTextPrimary(context),
    );
  }

  static TextStyle bodyLarge(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: getTextPrimary(context),
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: getTextSecondary(context),
    );
  }

  static TextStyle labelSmall(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: getTextSecondary(context),
    );
  }

  // Chip/badge style
  static BoxDecoration chipDecoration(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    );
  }

  // Option button styles (for MCQ)
  static BoxDecoration optionDefault(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
        width: 1.5,
      ),
    );
  }

  static BoxDecoration optionSelected(Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color, width: 2),
    );
  }

  static BoxDecoration optionCorrect() {
    return BoxDecoration(
      color: correct.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: correct, width: 2),
    );
  }

  static BoxDecoration optionIncorrect() {
    return BoxDecoration(
      color: incorrect.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: incorrect, width: 2),
    );
  }

  // Spacing constants
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // Border radius constants
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // Subject icons
  static IconData getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'quantitative aptitude':
      case 'quantitative':
      case 'mathematics':
      case 'maths':
        return Icons.calculate_rounded;
      case 'reasoning':
      case 'logical reasoning':
        return Icons.psychology_rounded;
      case 'english':
      case 'english language':
        return Icons.abc_rounded;
      case 'general awareness':
      case 'general knowledge':
      case 'gk':
        return Icons.public_rounded;
      case 'current affairs':
        return Icons.newspaper_rounded;
      case 'computer':
      case 'computer awareness':
        return Icons.computer_rounded;
      case 'general science':
      case 'science':
        return Icons.science_rounded;
      default:
        return Icons.book_rounded;
    }
  }

  // Exam category icons
  static IconData getExamCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'banking':
      case 'ibps':
      case 'sbi':
      case 'rbi':
        return Icons.account_balance_rounded;
      case 'ssc':
      case 'ssc cgl':
      case 'ssc chsl':
        return Icons.work_rounded;
      case 'railways':
      case 'rrb':
      case 'rrb ntpc':
        return Icons.train_rounded;
      case 'state psc':
      case 'upsc':
      case 'psc':
        return Icons.assured_workload_rounded;
      case 'defense':
      case 'cds':
      case 'nda':
        return Icons.military_tech_rounded;
      case 'teaching':
      case 'ctet':
      case 'tet':
        return Icons.school_rounded;
      default:
        return Icons.quiz_rounded;
    }
  }
}
