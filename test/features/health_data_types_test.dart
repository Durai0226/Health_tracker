import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';

/// QA — the health request lists must contain ONLY types the target platform
/// implements.
///
/// This is regression cover for the bug that made "Enable health" do nothing on
/// Android: the shared list included `DISTANCE_WALKING_RUNNING` (HealthKit-only —
/// Health Connect wants `DISTANCE_DELTA`) and `SLEEP_IN_BED` (HealthKit-only).
/// `package:health` fails hard and *silently* on an unknown type:
///
///  * Android `hasPermissions` / `requestAuthorization` return `success(false)` at
///    the FIRST unmapped type, so the Health Connect consent sheet never opens —
///    the user sees "not granted" no matter what they allow.
///  * `getHealthDataFromTypes` throws `HealthException` from inside its own loop,
///    discarding every point already collected — i.e. all sleep segments.
///
/// Both platform lists are asserted here, not just the running one, because
/// headless `flutter test` runs on neither Android nor iOS — checking only the
/// host platform is exactly how the Android list rotted unnoticed.
void main() {
  group('platform type lists only contain supported types', () {
    test('Android request list ⊆ dataTypeKeysAndroid', () {
      final unsupported = HealthDataService.readTypesFor(true)
          .where((t) => !dataTypeKeysAndroid.contains(t))
          .toList();
      expect(unsupported, isEmpty,
          reason: 'Health Connect would reject the whole permission request: '
              '${unsupported.map((t) => t.name).join(', ')}');
    });

    test('iOS request list ⊆ dataTypeKeysIOS', () {
      final unsupported = HealthDataService.readTypesFor(false)
          .where((t) => !dataTypeKeysIOS.contains(t))
          .toList();
      expect(unsupported, isEmpty,
          reason: 'HealthKit would silently map these to the wrong sample type: '
              '${unsupported.map((t) => t.name).join(', ')}');
    });

    test('sleep read lists are platform-correct in both directions', () {
      expect(HealthDataService.sleepTypesAndroid,
          contains(HealthDataType.SLEEP_SESSION),
          reason: 'the session record is the only sleep signal many Android '
              'providers write');
      expect(HealthDataService.sleepTypesAndroid,
          isNot(contains(HealthDataType.SLEEP_IN_BED)));
      expect(HealthDataService.sleepTypesIOS,
          contains(HealthDataType.SLEEP_IN_BED));
      expect(HealthDataService.sleepTypesIOS,
          isNot(contains(HealthDataType.SLEEP_SESSION)));
    });

    test('distance uses the delta record on Android, walking+running on iOS', () {
      expect(HealthDataService.distanceTypeAndroid,
          HealthDataType.DISTANCE_DELTA);
      expect(HealthDataService.distanceTypeIOS,
          HealthDataType.DISTANCE_WALKING_RUNNING);
    });
  });

  group('essential vs optional split', () {
    test('steps and sleep are essential; distance and calories are not', () {
      for (final android in [true, false]) {
        final essential = HealthDataService.essentialTypesFor(android);
        expect(essential, contains(HealthDataType.STEPS));
        expect(essential, contains(HealthDataType.SLEEP_ASLEEP));
        // A user who allows only steps + sleep must still count as connected,
        // so these two must stay OUT of the essential set.
        expect(essential, isNot(contains(HealthDataType.ACTIVE_ENERGY_BURNED)));
        expect(essential,
            isNot(contains(HealthDataService.distanceTypeAndroid)));
        expect(essential, isNot(contains(HealthDataService.distanceTypeIOS)));
      }
    });

    test('the full request is essential + optional with no duplicates', () {
      for (final android in [true, false]) {
        final all = HealthDataService.readTypesFor(android);
        expect(all.toSet().length, all.length,
            reason: 'a duplicated type doubles up the consent sheet');
        expect(
            all.toSet(),
            HealthDataService.essentialTypesFor(android)
                .toSet()
                .union(HealthDataService.optionalTypesFor(android).toSet()));
      }
    });
  });

  group('vitals write types (Phase 5)', () {
    test('BP + glucose are supported on both platforms, unlike sleep/distance',
        () {
      for (final type in HealthDataService.vitalsWriteTypes) {
        expect(dataTypeKeysAndroid, contains(type),
            reason: 'Health Connect would reject the whole write/permission '
                'request for an unmapped type: ${type.name}');
        expect(dataTypeKeysIOS, contains(type),
            reason: 'HealthKit would silently reject the write for an '
                'unmapped type: ${type.name}');
      }
    });

    test('BP is written as one combined record, never split', () {
      expect(HealthDataService.vitalsWriteTypes,
          contains(HealthDataType.BLOOD_PRESSURE_SYSTOLIC));
      expect(HealthDataService.vitalsWriteTypes,
          contains(HealthDataType.BLOOD_PRESSURE_DIASTOLIC));
      expect(HealthDataService.vitalsWriteTypes,
          contains(HealthDataType.BLOOD_GLUCOSE));
    });

    test('weight was added for Tier 1 write-back alongside BP/glucose', () {
      expect(
          HealthDataService.vitalsWriteTypes, contains(HealthDataType.WEIGHT));
      // 2 BP components + glucose + weight — pinned so a future addition is a
      // deliberate edit here, not a silent drift.
      expect(HealthDataService.vitalsWriteTypes.length, 4);
    });
  });
}
