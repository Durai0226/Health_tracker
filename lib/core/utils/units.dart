import 'package:flutter/foundation.dart';

/// How the person likes volumes (a drink, a goal) shown and typed.
enum VolumeUnit { ml, flOz }

/// How the person likes body weight shown and typed.
enum WeightUnit { kg, lb }

/// Volume and weight units, in one place.
///
/// **Everything stored stays metric** — millilitres and kilograms, as every
/// calculation, backup, cloud copy and health-store write already expects. A unit
/// is only how a number is shown and how typed text is read, so choosing ounces
/// cannot change a single stored value.
///
/// The choice itself is a preference ('water_unit': `ml` or `oz`; 'weight_unit':
/// `kg` or `lb`, the key the Weight screen has always used), read from the
/// in-memory preference cache, which is safe before it is loaded (it answers the
/// default) and needs no `await`.
///
/// This file imports no storage, on purpose: the text builders in `core/health`
/// are pure and run without Flutter or a database, and they format amounts. The
/// preference cache is wired in by `CleanStorageService.init`; until it is, nothing
/// has been chosen and every amount is millilitres.
///
/// Ounces are US fluid ounces (29.5735 ml): what a person who counts in ounces
/// means by "8 oz", and what a US drink label states.
abstract final class Units {
  static const double mlPerFlOz = 29.5735295625;
  static const double lbPerKg = 2.2046226218;

  static const _volumeKey = 'water_unit';
  static const _weightKey = 'weight_unit';

  /// Where the choice is read and written. Set by `CleanStorageService.init`.
  static dynamic Function(String key, dynamic defaultValue) preference =
      _nothingChosen;
  static Future<void> Function(String key, dynamic value) writePreference =
      _nowhereToWrite;

  static dynamic _nothingChosen(String key, dynamic defaultValue) => defaultValue;
  static Future<void> _nowhereToWrite(String key, dynamic value) async {}

  /// Back to "nothing chosen, nowhere to write", for a test that must not see
  /// another's preference cache.
  @visibleForTesting
  static void resetForTesting() {
    preference = _nothingChosen;
    writePreference = _nowhereToWrite;
  }

  /// Bumped when either unit changes, so a screen that is already open (the Today
  /// tab under a settings page, say) can rebuild its text.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static VolumeUnit get volume =>
      preference(_volumeKey, 'ml') == 'oz'
          ? VolumeUnit.flOz
          : VolumeUnit.ml;

  static WeightUnit get weight =>
      preference(_weightKey, 'kg') == 'lb'
          ? WeightUnit.lb
          : WeightUnit.kg;

  static Future<void> setVolume(VolumeUnit unit) async {
    await writePreference(_volumeKey, unit == VolumeUnit.flOz ? 'oz' : 'ml');
    changes.value++;
  }

  static Future<void> setWeight(WeightUnit unit) async {
    await writePreference(_weightKey, unit == WeightUnit.lb ? 'lb' : 'kg');
    changes.value++;
  }

  // ---- volume ---------------------------------------------------------------

  /// "ml" or "fl oz".
  static String volumeSymbol([VolumeUnit? unit]) =>
      (unit ?? volume) == VolumeUnit.flOz ? 'fl oz' : 'ml';

  /// [ml] as a number in the unit: the same number in millilitres, ounces to one
  /// decimal (two would claim a precision a glass does not have).
  static double volumeValue(num ml, [VolumeUnit? unit]) =>
      (unit ?? volume) == VolumeUnit.flOz ? ml / mlPerFlOz : ml.toDouble();

  /// The number alone, as it reads: "250", "8.5", "85" — no trailing ".0", and no
  /// decimal at all from 100 ounces up, where it is noise.
  static String volumeNumber(num ml, [VolumeUnit? unit]) {
    final u = unit ?? volume;
    if (u == VolumeUnit.ml) return ml.round().toString();
    final oz = ml / mlPerFlOz;
    if (oz >= 100) return oz.round().toString();
    final one = oz.toStringAsFixed(1);
    return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
  }

  /// "250 ml" or "8.5 fl oz".
  ///
  /// [tight] keeps the app's older "250ml" spelling where a screen has always
  /// written it that way, so choosing millilitres changes no existing text.
  /// Ounces are always spaced: "8.5floz" reads as a typo.
  static String volumeText(num ml, {VolumeUnit? unit, bool tight = false}) {
    final u = unit ?? volume;
    final gap = tight && u == VolumeUnit.ml ? '' : ' ';
    return '${volumeNumber(ml, u)}$gap${volumeSymbol(u)}';
  }

  /// For a screen reader: "250 millilitres", "8.5 fluid ounces", "1 fluid ounce".
  static String volumeSpoken(num ml, [VolumeUnit? unit]) {
    final u = unit ?? volume;
    final n = volumeNumber(ml, u);
    final one = n == '1';
    return u == VolumeUnit.flOz
        ? '$n fluid ${one ? 'ounce' : 'ounces'}'
        : '$n ${one ? 'millilitre' : 'millilitres'}';
  }

  /// The text to put in an amount field for [ml]: the number, nothing else.
  static String volumeInput(num ml, [VolumeUnit? unit]) => volumeNumber(ml, unit);

  /// Millilitres from what was typed in the unit, or null when it is not a number
  /// above zero. A comma is a decimal point. Rounded, so 8 oz is 237 ml.
  static int? mlFromInput(String text, [VolumeUnit? unit]) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v <= 0) return null;
    final ml = (unit ?? volume) == VolumeUnit.flOz ? v * mlPerFlOz : v;
    return ml.round();
  }

  /// Amounts offered as one-tap choices, in millilitres, for the unit: the
  /// millilitre list as given, or [ounces] converted — round ounce sizes a person
  /// who counts in ounces recognises, not 100 ml shown as 3.4.
  static List<int> presetsMl(List<int> millilitres, List<int> ounces,
          [VolumeUnit? unit]) =>
      (unit ?? volume) == VolumeUnit.flOz
          ? [for (final oz in ounces) (oz * mlPerFlOz).round()]
          : millilitres;

  /// What a "glass" is: 250 ml, or 8 fl oz for someone counting in ounces.
  static int glassMl([VolumeUnit? unit]) =>
      (unit ?? volume) == VolumeUnit.flOz ? (8 * mlPerFlOz).round() : 250;

  /// [ml] moved one press of a "+" ([direction] 1) or "−" (-1): [mlStep]
  /// millilitres, or [ozStep] WHOLE ounces.
  ///
  /// In ounces it works from the nearest whole ounce and converts back, rather
  /// than adding a rounded 30 ml each press: that drifts, and 16 oz plus a dozen
  /// presses would stop being a whole number of ounces.
  static int stepped(int ml, int direction,
      {required int mlStep, required int ozStep, VolumeUnit? unit}) {
    if ((unit ?? volume) == VolumeUnit.ml) return ml + direction * mlStep;
    final oz = (ml / mlPerFlOz).round() + direction * ozStep;
    return (oz * mlPerFlOz).round();
  }

  /// Whether [ml] is a whole number of US fluid ounces, as the app stores one
  /// typed or stepped in ounces (to the rounding of a millilitre).
  static bool isWholeOunces(int ml) {
    final oz = ml / mlPerFlOz;
    return oz >= 1 && (oz - oz.round()).abs() <= 0.5 / mlPerFlOz + 1e-9;
  }

  /// One press of a "+" or "−" on an amount, in millilitres: [ml] steps of that
  /// size, or [ounces] ounces' worth.
  static int stepMl(int ml, int ounces, [VolumeUnit? unit]) =>
      (unit ?? volume) == VolumeUnit.flOz ? (ounces * mlPerFlOz).round() : ml;

  // ---- weight ---------------------------------------------------------------

  static String weightSymbol([WeightUnit? unit]) =>
      (unit ?? weight) == WeightUnit.lb ? 'lb' : 'kg';

  static double weightValue(num kg, [WeightUnit? unit]) =>
      (unit ?? weight) == WeightUnit.lb ? kg * lbPerKg : kg.toDouble();

  /// "68.5", or "151" — one decimal, dropped when it is ".0".
  static String weightNumber(num kg, [WeightUnit? unit]) {
    final one = weightValue(kg, unit).toStringAsFixed(1);
    return one.endsWith('.0') ? one.substring(0, one.length - 2) : one;
  }

  static String weightText(num kg, [WeightUnit? unit]) =>
      '${weightNumber(kg, unit)} ${weightSymbol(unit)}';

  /// Kilograms from what was typed in the unit; null when it is not a number
  /// above zero. Not rounded: 150 lb is 68.0388 kg and reads back as "150", where
  /// rounding the kilograms to a tenth would read back as 149.9.
  static double? kgFromInput(String text, [WeightUnit? unit]) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (v == null || !v.isFinite || v <= 0) return null;
    return (unit ?? weight) == WeightUnit.lb ? v / lbPerKg : v;
  }
}
