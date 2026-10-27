import 'package:flutter/foundation.dart';

import '../../features/biometrics/services/biometrics_service.dart';
import '../../features/period/services/period_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/steps/services/step_service.dart';

/// The in-memory copies the health services keep of what is in the database.
///
/// Steps, sleep, heart and period each hold their days in a static cache that is
/// read once at start-up, so anything written to the database from outside them —
/// a cloud sync, a restored backup — is invisible until something reloads it.
/// Both of those used to leave that to the next app start, which a restore then
/// told the person to do. This is the one place that says what to reload.
class HealthCaches {
  const HealthCaches._();

  /// Reload every cache from the database.
  ///
  /// Each is independently best-effort: one service failing to reload must not
  /// leave the other three showing stale data. They are all-static with a
  /// ValueNotifier cache, so a throw here would otherwise abort the rest.
  static Future<void> reloadAll() async {
    for (final reload in <Future<void> Function()>[
      StepService.reloadFromDb,
      SleepService.reloadFromDb,
      BiometricsService.reloadFromDb,
      PeriodService.reloadFromDb,
    ]) {
      try {
        await reload();
      } catch (e) {
        debugPrint('⚠️ Health cache reload failed: $e');
      }
    }
  }
}
