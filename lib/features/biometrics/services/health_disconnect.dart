import 'package:flutter/foundation.dart';

import '../../../core/services/background_health_sync_service.dart';
import '../../../core/services/health_data_service.dart';
import '../../focus/services/focus_service.dart';
import '../../medication/services/vitals_health_import.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/hydration_health_sync.dart';
import '../../water/services/water_health_import.dart';

/// What "Disconnect" did.
class HealthDisconnectResult {
  const HealthDisconnectResult({required this.revoked});

  /// Whether the platform took the permissions back. True on Android, where an
  /// app can revoke its own; false on iPhone, where only the person can, in the
  /// Health app — the screen says where.
  final bool revoked;
}

/// Leaving the phone's health store.
///
/// Stops everything in this app that reads from or writes to it, forgets that it
/// was ever connected, and — where the platform lets an app do that — gives the
/// permissions back. What is already stored in DlyMinder stays: disconnecting is
/// not deleting, and the screen says so.
///
/// Every step is attempted whatever happens to the one before it. A background
/// worker that will not stop must not leave the vitals switch on.
class HealthDisconnect {
  const HealthDisconnect._();

  static Future<HealthDisconnectResult> run({
    /// Stands in for the background worker, which needs a device.
    Future<void> Function()? stopBackground,

    /// Stands in for the platform's revoke.
    Future<bool> Function()? revoke,

    /// Stands in for forgetting the connection.
    Future<void> Function()? forget,
  }) async {
    Future<void> attempt(String what, Future<void> Function() step) async {
      try {
        await step();
      } catch (e) {
        debugPrint('HealthDisconnect: $what failed: $e');
      }
    }

    // The app's own readers and writers first: nothing should be reading or
    // writing a store that is about to stop answering.
    await attempt('background sync',
        stopBackground ?? () => BackgroundHealthSyncService.instance.disable());
    await attempt('vitals import', () => VitalsHealthImport.setEnabled(false));
    await attempt('water import', () => WaterHealthImport.setEnabled(false));
    await attempt('vitals sharing',
        () => VitalsStorageService.setHealthConnectSyncEnabled(false));
    await attempt('water sharing', () => HydrationHealthSync.setEnabled(false));
    // Focus writes mindful minutes to the store too. Left on, every finished
    // session and breathing exercise would go on trying to write after the
    // permission is gone, and the switch would still read "on".
    await attempt('mindfulness sync', () async {
      await FocusService().setMindfulnessSync(false);
    });
    await attempt('forgetting the connection',
        forget ?? () => HealthDataService.instance.forgetConnection());

    var revoked = false;
    try {
      revoked =
          await (revoke ?? HealthDataService.instance.revokeAllPermissions)();
    } catch (e) {
      debugPrint('HealthDisconnect: revoking failed: $e');
    }
    return HealthDisconnectResult(revoked: revoked);
  }
}
