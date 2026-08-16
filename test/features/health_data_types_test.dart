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

  group('wearable biometrics', () {
    test('Android biometric list ⊆ dataTypeKeysAndroid', () {
      final unsupported = HealthDataService.biometricTypesFor(true)
          .where((t) => !dataTypeKeysAndroid.contains(t))
          .toList();
      expect(unsupported, isEmpty,
          reason: 'one unmapped type makes Health Connect refuse the WHOLE '
              'request: ${unsupported.map((t) => t.name).join(', ')}');
    });

    test('iOS biometric list ⊆ dataTypeKeysIOS', () {
      final unsupported = HealthDataService.biometricTypesFor(false)
          .where((t) => !dataTypeKeysIOS.contains(t))
          .toList();
      expect(unsupported, isEmpty,
          reason: unsupported.map((t) => t.name).join(', '));
    });

    // The single highest-value assertion in this group: HRV is the same bug
    // shape as DISTANCE_WALKING_RUNNING, and worse in consequence. RMSSD and
    // SDNN are different statistics over different ranges, so swapping them
    // does not fail loudly — it silently fabricates a trend.
    test('HRV is RMSSD on Android and SDNN on iOS, never the other way', () {
      expect(HealthDataService.hrvTypeAndroid,
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD);
      expect(HealthDataService.hrvTypeIOS,
          HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      expect(dataTypeKeysAndroid,
          isNot(contains(HealthDataType.HEART_RATE_VARIABILITY_SDNN)));
      expect(dataTypeKeysIOS,
          isNot(contains(HealthDataType.HEART_RATE_VARIABILITY_RMSSD)));
    });

    test('skin temperature is SKIN_TEMPERATURE on Android and '
        'SLEEP_WRIST_TEMPERATURE on iOS', () {
      expect(HealthDataService.skinTempTypeAndroid,
          HealthDataType.SKIN_TEMPERATURE);
      expect(HealthDataService.skinTempTypeIOS,
          HealthDataType.SLEEP_WRIST_TEMPERATURE);
      expect(dataTypeKeysAndroid,
          isNot(contains(HealthDataType.SLEEP_WRIST_TEMPERATURE)));
      expect(dataTypeKeysIOS, isNot(contains(HealthDataType.SKIN_TEMPERATURE)));
    });

    // A user who allows steps+sleep but declines heart rate is still
    // "connected". Promoting a biometric into essentialTypes would gate
    // availability() on it and break the two features that already work.
    test('no biometric type is essential, and none rides the first-run sheet',
        () {
      for (final android in [true, false]) {
        for (final t in HealthDataService.biometricTypesFor(android)) {
          expect(HealthDataService.essentialTypesFor(android), isNot(contains(t)),
              reason: '${t.name} would gate availability()');
          expect(HealthDataService.readTypesFor(android), isNot(contains(t)),
              reason: '${t.name} would bloat the first-run consent sheet, '
                  'which Play policy and grant rates both punish');
        }
      }
    });

    test('biometrics are read-only — none appears in vitalsWriteTypes', () {
      for (final android in [true, false]) {
        for (final t in HealthDataService.biometricTypesFor(android)) {
          expect(HealthDataService.vitalsWriteTypes, isNot(contains(t)));
        }
      }
    });

    test('allReadTypesFor is the union, with no duplicates', () {
      for (final android in [true, false]) {
        final all = HealthDataService.allReadTypesFor(android);
        expect(all.toSet().length, all.length, reason: 'duplicate type');
        expect(all, containsAll(HealthDataService.readTypesFor(android)));
        expect(all, containsAll(HealthDataService.biometricTypesFor(android)));
      }
    });

    // Encodes a plugin constraint rather than our behaviour: health 13.3.2
    // declares no VO2MAX on either platform, even though HealthKit and Health
    // Connect both store one. `BiometricDailyData.vo2Max` exists but has no
    // importer. When a plugin bump adds the type, THIS test fails and tells
    // you to wire it up — and to add READ_VO2_MAX to the manifest.
    test('VO2 max still has no plugin type — wire the importer when this fails',
        () {
      final names = HealthDataType.values.map((t) => t.name).toSet();
      expect(names.any((n) => n.contains('VO2')), isFalse);
    });
  });
}
