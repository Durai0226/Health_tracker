import 'package:flutter/material.dart';

/// Three soft, neutral shadow recipes (no colored glows, no glass).
/// Dark mode pairs a faint shadow with a 1px outline for card definition
/// (handled by the card widgets), since shadows read weakly on dark.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> resting(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(dark ? 0.24 : 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Default for feature/summary cards.
  static List<BoxShadow> card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(dark ? 0.30 : 0.06),
        blurRadius: 16,
        spreadRadius: -2,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// Sheets, dialogs, menus, FAB.
  static List<BoxShadow> elevated(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(dark ? 0.40 : 0.10),
        blurRadius: 28,
        spreadRadius: -4,
        offset: const Offset(0, 12),
      ),
    ];
  }
}
