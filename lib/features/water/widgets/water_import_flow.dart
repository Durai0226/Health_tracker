import 'package:flutter/material.dart';

import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_store_name.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/health_import_turn_on.dart';
import '../services/water_health_import.dart';

/// Where drinks are brought in from: the phone's health store.
///
/// A seam, so the flow that asks, reads and reports can be driven without the
/// platform plugin, which headless tests cannot reach.
abstract class WaterImportSource {
  /// "Health Connect" or "Apple Health".
  String get storeName;

  /// Whether drinks may already be read: true or false when the platform says,
  /// null when it could not be asked right now. Null is not "no" — see
  /// `VitalsImportSource.allowed`.
  Future<bool?> allowed();

  /// Ask for it. True only when the grant is confirmed.
  Future<bool> ask();

  /// Read, keep what is new, and say what was kept.
  Future<WaterImportResult> run();
}

/// The real source: [WaterHealthImport] over [HealthDataService].
class HealthStoreWaterSource implements WaterImportSource {
  const HealthStoreWaterSource();

  @override
  String get storeName => healthStoreName();

  @override
  Future<bool?> allowed() => HealthDataService.instance.hydrationReadAccess();

  /// Reading drinks is all the import does, so that is all it asks for. See
  /// `HealthStoreVitalsSource.ask`.
  @override
  Future<bool> ask() => HealthDataService.instance.requestHydrationReadPermission();

  @override
  Future<WaterImportResult> run() => WaterHealthImport.run();
}

/// "Count drinks from other apps", turned on: ask if needed, remember it, read
/// straight away, say what came in, and offer to take it back. The order of
/// events, and what a failed first read does to the choice, are
/// [HealthImportTurnOn]'s, shared with the other imports.
class WaterImportFlow {
  const WaterImportFlow._();

  /// True when it is now on.
  static Future<bool> turnOn(
    BuildContext context, {
    WaterImportSource source = const HealthStoreWaterSource(),
  }) {
    final store = source.storeName;
    return HealthImportTurnOn.run<WaterImportResult>(
      context,
      name: 'WaterImportFlow',
      allowed: () async => await source.allowed() == true,
      ask: source.ask,
      setEnabled: WaterHealthImport.setEnabled,
      read: source.run,
      declinedMessage: '$store did not share your drinks, so nothing was '
          'counted. You can allow it any time in $store\'s settings.',
      silentMessage: 'Switched on, but $store did not answer just now. '
          'Drinks will be counted when it does.',
      report: (context, result) {
        if (result.isEmpty) {
          context.toastInfo('Switched on. Drinks other apps save to $store will '
              'be counted here by themselves.');
        } else {
          context.toastSuccess(
            'Counted ${result.describe()} from $store',
            action: AppToastAction(
              label: 'Undo',
              onPressed: () => WaterHealthImport.undo(result),
            ),
          );
        }
      },
    );
  }

  static Future<void> turnOff() => WaterHealthImport.setEnabled(false);
}
