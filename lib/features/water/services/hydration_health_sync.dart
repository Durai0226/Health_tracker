import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/health_data_service.dart';
import '../models/enhanced_water_log.dart';

/// Opt-in write-through of logged drinks to Health Connect (Android) and
/// HealthKit (iOS).
///
/// Hydration was the only metric this app tracks that never reached the
/// platform health store: the manifest declared twenty health permissions and
/// no hydration one, and `HealthDataType.WATER` appeared nowhere in `lib/`.
/// That made every drink logged here invisible to Samsung Health, Fitbit, Apple
/// Health and any other app the user has — while the competing hydration apps
/// all advertise the integration.
///
/// Shape deliberately mirrors `VitalsStorageService`'s Health Connect sync:
/// a single opt-in preference, an "already written" record kept only after a
/// write actually succeeds (so a failure retries rather than silently
/// dropping), and no use of the plugin's `clientRecordId`/delete APIs — see
/// `HealthDataService.vitalsWriteTypes` for why those are avoided. Unlike
/// vitals, that record is a single capped list rather than a key per drink —
/// see [_recentSyncsKey].
///
/// NOT YET two-directional: deleting a drink here does not remove the record
/// from the platform store, because `HealthDataService` exposes no hydration
/// delete. Until it does, an undone drink stays in Health Connect / HealthKit.
///
/// Every method swallows its own failures. A health-store problem must never
/// stop a drink being recorded locally, and this is called from
/// `WaterService`, which runs headless in tests where neither SharedPreferences
/// nor the health plugin exist.
class HydrationHealthSync {
  HydrationHealthSync._();

  static const String _syncEnabledKey = 'health_connect_hydration_sync_enabled';

  /// Off by default — writing to a shared health store is the user's call.
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_syncEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);
  }

  /// The ids written out recently, newest last, as ONE preference.
  ///
  /// This used to be one boolean key per drink — `hydration_hc_synced_<uuid>`
  /// — which nothing ever removed. `SharedPreferences.getInstance()` loads the
  /// whole store into memory at start-up, so a few drinks a day added a
  /// permanent key each, for the life of the install, to something read on the
  /// launch path.
  ///
  /// A bounded FIFO is enough for what the flag is actually for. Its only job
  /// is "do not write this same log twice": [onLogAdded] is called once, from
  /// [WaterService.addWaterLogForDate], immediately after the log is created,
  /// and ids are v4 UUIDs that are never reused. So only the recent past can
  /// ever be queried, and [_recentSyncsCap] is far past it.
  static const String _recentSyncsKey = 'hydration_hc_recent_syncs';

  /// Deliberately not the prefix of [_recentSyncsKey] — [_sweepLegacyFlags]
  /// deletes every key that starts with this, and must not delete the list that
  /// replaces them.
  static const String _legacyFlagPrefix = 'hydration_hc_synced_';

  static const int _recentSyncsCap = 200;

  /// Once per process, on the first write: delete the per-log keys the old
  /// scheme left behind. Runs here rather than in `WaterService.init()` because
  /// init happens before the first frame and this path already holds `prefs`.
  static bool _legacyFlagsSwept = false;

  static Future<void> _sweepLegacyFlags(SharedPreferences prefs) async {
    if (_legacyFlagsSwept) return;
    _legacyFlagsSwept = true;
    final stale =
        prefs.getKeys().where((k) => k.startsWith(_legacyFlagPrefix)).toList();
    for (final key in stale) {
      await prefs.remove(key);
    }
    if (stale.isNotEmpty) {
      debugPrint('HydrationHealthSync: removed ${stale.length} legacy '
          'per-drink sync flags');
    }
  }

  /// [id] appended to [existing], oldest entries dropped past the cap.
  ///
  /// Pure and visible for testing: the cap is the whole point of the change and
  /// it is the part that can silently stop capping.
  @visibleForTesting
  static List<String> appendCapped(List<String> existing, String id) {
    final out = [...existing.where((e) => e != id), id];
    return out.length <= _recentSyncsCap
        ? out
        : out.sublist(out.length - _recentSyncsCap);
  }

  /// Lets a test run the one-per-process legacy sweep again.
  @visibleForTesting
  static void resetForTesting() {
    _legacyFlagsSwept = false;
  }

  /// Write one drink out, if the user has opted in and it has not gone already.
  ///
  /// Sends [EnhancedWaterLog.amountMl] — the RAW volume — not
  /// `effectiveHydrationMl`. Health Connect's `HydrationRecord` and HealthKit's
  /// `dietaryWater` both mean "fluid consumed"; our per-beverage hydration
  /// coefficients are a DlyMinder concept and would corrupt the shared record
  /// (and an alcoholic drink's negative effective value is not a volume at all).
  static Future<void> onLogAdded(EnhancedWaterLog log) async {
    try {
      if (log.amountMl <= 0) return;
      if (!await isEnabled()) return;

      final prefs = await SharedPreferences.getInstance();
      await _sweepLegacyFlags(prefs);
      final recent = prefs.getStringList(_recentSyncsKey) ?? const <String>[];
      if (recent.contains(log.id)) return;

      if (!await HealthDataService.instance.hasHydrationWritePermission()) {
        return;
      }

      final ok = await HealthDataService.instance
          .writeWater(volumeMl: log.amountMl, at: log.time);
      // Only record on success, so a transient failure retries next time.
      if (ok) {
        await prefs.setStringList(
            _recentSyncsKey, appendCapped(recent, log.id));
      }
    } catch (e) {
      debugPrint('HydrationHealthSync.onLogAdded skipped: $e');
    }
  }

  /// Turning the toggle on: ask for the scope and report whether it was granted.
  static Future<bool> requestPermission() async {
    try {
      await HealthDataService.instance.requestHydrationWritePermission();
      // Re-query rather than trusting the request's return value —
      // requestAuthorization reports "the sheet was shown", not "access was
      // granted"; hasHydrationWritePermission asks about WRITE directly.
      return await HealthDataService.instance.hasHydrationWritePermission();
    } catch (e) {
      debugPrint('HydrationHealthSync.requestPermission failed: $e');
      return false;
    }
  }

  /// Hydration recorded by OTHER apps over [from]..[to], in millilitres.
  static Future<int> readExternalMl(DateTime from, DateTime to) async {
    try {
      if (!await isEnabled()) return 0;
      return await HealthDataService.instance.readWaterMl(from, to);
    } catch (e) {
      debugPrint('HydrationHealthSync.readExternalMl failed: $e');
      return 0;
    }
  }
}
