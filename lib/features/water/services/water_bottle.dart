import '../../../core/health/bottle_mode.dart';
import '../../../core/services/clean_storage_service.dart';

/// The size of the bottle the person drinks from, kept on this device. Null until
/// they set it; setting it is what turns the bottle card on.
class WaterBottle {
  const WaterBottle._();

  static const _key = 'water_bottle_ml';

  static int? get sizeMl {
    final v = CleanStorageService.getAppPreference(_key, 0);
    return v is int && BottleMode.isValid(v) ? v : null;
  }

  /// Set the size, or pass null to forget it. A size the sheet could not have
  /// produced is ignored rather than stored.
  static Future<void> setSize(int? ml) async {
    if (ml != null && !BottleMode.isValid(ml)) return;
    await CleanStorageService.setAppPreference(_key, ml ?? 0);
  }
}
