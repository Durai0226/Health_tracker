import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'health_data_service.dart';
import 'health_sync_queue.dart';

/// Names are stable identifiers WorkManager persists across app restarts.
/// Changing `kHealthSyncUniqueName` orphans the existing registration rather
/// than replacing it, so version it instead of renaming.
const String kHealthSyncTaskName = 'dlyminder.health.sync';
const String kHealthSyncUniqueName = 'dlyminder.health.sync.v1';

/// Runs in its own isolate and FlutterEngine, like `alarmCallback`.
///
/// ## What it must never do
///
/// * **Touch Drift.** The main isolate owns the database; see
///   [HealthSyncQueue] for why. The four forbidden imports are grepped for by
///   `test/core/background_health_sync_policy_test.dart`.
/// * **Touch Firestore.** It cannot read the cloud-sync consent flag (that
///   needs Drift), so any upload from here would bypass consent entirely.
/// * **Initialise flutter_local_notifications.** That overwrites the app-wide
///   background-response handle and silently breaks "✓ Take" from a
///   notification — documented at `background_alarm_service.dart:214`.
///
/// ## Why it always returns true
///
/// Returning `false` tells WorkManager to retry with exponential backoff. On a
/// missing permission that means waking the device forever for a grant that
/// will never appear on its own. So failures self-cancel or record a
/// breadcrumb and report success.
@pragma('vm:entry-point')
void healthSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (!await HealthSyncQueue.isEnabled()) return true;

      final health = HealthDataService.instance;
      if (await health.availability() != HealthAvailability.available) {
        return true;
      }
      if (!await health.isBackgroundReadAuthorized()) {
        // The user revoked it. Stop rather than retrying a permission that
        // cannot come back without them visiting the app.
        await Workmanager().cancelByUniqueName(kHealthSyncUniqueName);
        await HealthSyncQueue.setEnabled(false);
        return true;
      }

      final snapshot = await _readSnapshot(health);
      if (snapshot != null) {
        await HealthSyncQueue.writeSnapshot(snapshot);
        await HealthSyncQueue.setDirty(true);
      }
      return true;
    } catch (e) {
      await HealthSyncQueue.recordError('$e');
      return true;
    }
  });
}

/// Aggregate reads only — no per-sample pulls. This runs on a wake-up budget,
/// and the point is a cheap freshness snapshot, not a full import; the real
/// import happens on the main isolate when the app next opens.
Future<Map<String, dynamic>?> _readSnapshot(HealthDataService health) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final steps = await health.readTodaySteps();
  if (steps == null) return null;

  return <String, dynamic>{
    'atMs': now.millisecondsSinceEpoch,
    'todayKey': '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}',
    'steps': steps,
  };
}

/// Registers the periodic background health sync.
///
/// Android only. iOS background health needs `HKObserverQuery` plus the
/// background-delivery entitlement, which `package:health` does not expose —
/// see docs/wearables.md.
class BackgroundHealthSyncService {
  BackgroundHealthSyncService._();
  static final BackgroundHealthSyncService instance =
      BackgroundHealthSyncService._();

  bool _initialised = false;

  /// Hourly, not the 15-minute floor. This is a step counter and a sleep
  /// summary: one wake an hour is plenty, and four would be a battery cost
  /// with no user-visible difference.
  static const Duration frequency = Duration(hours: 1);

  Future<void> init() async {
    if (!Platform.isAndroid || _initialised) return;
    try {
      await Workmanager().initialize(healthSyncCallbackDispatcher);
      _initialised = true;
      if (!await HealthSyncQueue.isEnabled()) return;
      await _register();
    } catch (e) {
      debugPrint('BackgroundHealthSyncService.init failed: $e');
    }
  }

  /// Turn the feature on after the user grants background reads.
  Future<bool> enable() async {
    if (!Platform.isAndroid) return false;
    try {
      final granted =
          await HealthDataService.instance.requestBackgroundRead();
      if (!granted) return false;
      await HealthSyncQueue.setEnabled(true);
      if (!_initialised) {
        await Workmanager().initialize(healthSyncCallbackDispatcher);
        _initialised = true;
      }
      await _register();
      // One immediate run so the user sees the effect rather than waiting an
      // hour to find out whether it worked.
      await Workmanager().registerOneOffTask(
        '$kHealthSyncUniqueName.now',
        kHealthSyncTaskName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      return true;
    } catch (e) {
      debugPrint('BackgroundHealthSyncService.enable failed: $e');
      return false;
    }
  }

  Future<void> disable() async {
    try {
      await HealthSyncQueue.setEnabled(false);
      await Workmanager().cancelByUniqueName(kHealthSyncUniqueName);
    } catch (e) {
      debugPrint('BackgroundHealthSyncService.disable failed: $e');
    }
  }

  Future<void> _register() async {
    await Workmanager().registerPeriodicTask(
      kHealthSyncUniqueName,
      kHealthSyncTaskName,
      frequency: frequency,
      initialDelay: const Duration(minutes: 15),
      // `keep`, not `replace`: a re-register on every app start would reset the
      // period and the job would effectively never fire on a frequently-opened
      // app.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      constraints: Constraints(
        // Health Connect is local. This job must never wait on, or wake for, a
        // network connection.
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
