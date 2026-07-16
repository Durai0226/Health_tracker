import 'package:flutter/widgets.dart';

/// One radius scale (collapses the previous 21 distinct radii).
/// Defaults: AppCard = [card] (20); buttons/inputs/rows = [md] (12);
/// chips = [sm] (8); bottom sheets/dialogs = [sheet] (24).
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double card = 20;
  static const double sheet = 24;
  static const double full = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius brSheet = BorderRadius.all(Radius.circular(sheet));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));

  /// Top-rounded corners (bottom sheets).
  static const BorderRadius topSheet =
      BorderRadius.vertical(top: Radius.circular(sheet));
}
