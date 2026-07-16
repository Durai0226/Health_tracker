import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One type scale. Display/headings = Plus Jakarta Sans (friendly at large
/// sizes); UI/body = Inter. Roles are assigned to their nearest Material slot
/// so `Theme.of(context).textTheme.*` resolves everywhere.
///
/// Modern & clean per the chosen direction. Colors are injected by
/// [textTheme] at theme-build time; callers override with `.copyWith(color:)`.
class AppType {
  AppType._();

  static TextStyle _display(double size, FontWeight w, double h, double ls,
          Color color) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: w,
        height: h / size,
        letterSpacing: ls,
        color: color,
      );

  static TextStyle _ui(double size, FontWeight w, double h, double ls,
          Color color) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        height: h / size,
        letterSpacing: ls,
        color: color,
      );

  /// Build the full Material TextTheme. [primary] drives display/title/body,
  /// [secondary] drives the muted caption slot.
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      // Jakarta display / headings
      displayLarge: _display(32, FontWeight.w700, 38, -0.5, primary),
      displayMedium: _display(28, FontWeight.w700, 34, -0.5, primary),
      displaySmall: _display(24, FontWeight.w700, 30, -0.4, primary),
      headlineLarge: _display(26, FontWeight.w700, 32, -0.4, primary), // h1 screen title
      headlineMedium: _display(22, FontWeight.w700, 28, -0.3, primary), // h2 section
      headlineSmall: _display(18, FontWeight.w600, 24, -0.2, primary), // h3 card/sheet title
      // Inter titles / body / labels
      titleLarge: _ui(16, FontWeight.w600, 22, -0.1, primary), // list-row / card title
      titleMedium: _ui(15, FontWeight.w600, 20, -0.1, primary),
      titleSmall: _ui(13, FontWeight.w600, 18, 0, primary),
      bodyLarge: _ui(16, FontWeight.w400, 24, 0, primary),
      bodyMedium: _ui(14, FontWeight.w400, 20, 0, primary), // secondary body / subtitle
      bodySmall: _ui(12, FontWeight.w500, 16, 0.2, secondary), // caption
      labelLarge: _ui(13, FontWeight.w600, 16, 0.1, primary), // buttons/chips/nav
      labelMedium: _ui(12, FontWeight.w600, 16, 0.2, primary),
      labelSmall: _ui(11, FontWeight.w600, 14, 0.3, primary),
    );
  }
}
