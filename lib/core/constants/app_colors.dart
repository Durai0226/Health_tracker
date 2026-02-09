
import 'package:flutter/material.dart';

class AppColors {
  // Premium Medical Theme
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
}
