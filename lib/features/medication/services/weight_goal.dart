import '../../../core/services/clean_storage_service.dart';

/// The goal weight, in kilograms, kept on this device.
///
/// Stored as a string on purpose: `setAppPreference` has no double path — it
/// writes a double as a String, and a reader expecting a double breaks only
/// after the next restart.
class WeightGoal {
  const WeightGoal._();

  static const _key = 'weight_goal_kg';

  /// Bounds a typed goal must sit inside. Wide enough for any adult or child
  /// weighing in kg, narrow enough to refuse a stray keystroke ("7" for "70",
  /// "700" for "70.0").
  static const double minKg = 20;
  static const double maxKg = 400;

  static double? get() {
    final v = CleanStorageService.getAppPreference(_key, '');
    final kg = v is num ? v.toDouble() : double.tryParse('$v');
    return kg != null && kg >= minKg && kg <= maxKg ? kg : null;
  }

  static Future<void> set(double kg) =>
      CleanStorageService.setAppPreference(_key, kg.toStringAsFixed(2));

  static Future<void> clear() => CleanStorageService.setAppPreference(_key, '');

  /// What a person typed, in [lb] or kg, as kilograms — or null when it is not a
  /// number or falls outside [minKg]–[maxKg]. Accepts a comma as the decimal
  /// mark.
  static double? parse(String input, {required bool lb}) {
    final v = double.tryParse(input.trim().replaceAll(',', '.'));
    if (v == null) return null;
    final kg = lb ? v / 2.2046226218 : v;
    return kg >= minKg && kg <= maxKg ? kg : null;
  }
}
