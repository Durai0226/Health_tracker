import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Health Connect permission strings, checked against what the app actually
/// requests.
///
/// ## Why this exists
///
/// The Flutter `health` plugin names the hydration type `HealthDataType.WATER`.
/// The Android permission is **not** `READ_WATER`/`WRITE_WATER` — it is
/// `android.permission.health.READ_HYDRATION` / `WRITE_HYDRATION`, because the
/// underlying Health Connect record is `HydrationRecord`. Nothing in the build
/// catches the mismatch: an undeclared or misspelled health permission is not a
/// compile error, not a manifest-merger error, and not a runtime crash. The
/// request simply returns "denied" forever, and the feature looks like it works
/// while writing nothing — which is the single most common one-star complaint
/// against every app in this category.
///
/// Reading the permission out of the manifest and asserting the exact spelling
/// is deterministic, needs no device, and catches the one mistake that is
/// otherwise invisible until a user reports it.
void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const servicePath = 'lib/core/services/health_data_service.dart';

  late String manifest;
  late String service;

  setUpAll(() {
    manifest = File(manifestPath).readAsStringSync();
    service = File(servicePath).readAsStringSync();
  });

  String perm(String name) =>
      '<uses-permission android:name="android.permission.health.$name"/>';

  group('hydration', () {
    test('the manifest declares READ_HYDRATION and WRITE_HYDRATION', () {
      expect(manifest, contains(perm('READ_HYDRATION')),
          reason: 'reading other apps\' hydration needs READ_HYDRATION');
      expect(manifest, contains(perm('WRITE_HYDRATION')),
          reason: 'writing logged drinks needs WRITE_HYDRATION');
    });

    test('the invalid READ_WATER/WRITE_WATER spelling is never used', () {
      // The plugin's Dart enum is WATER; the Android permission is HYDRATION.
      // Getting this wrong denies silently.
      expect(manifest, isNot(contains('android.permission.health.READ_WATER')));
      expect(manifest, isNot(contains('android.permission.health.WRITE_WATER')));
    });

    test('the service requests the hydration type it declares', () {
      expect(service, contains('hydrationWriteTypes'),
          reason: 'hydration must have its own scope, separate from vitals — '
              'a user may want to share water without sharing blood pressure');
      expect(service, contains('HealthDataType.WATER'));
    });
  });

  group('every declared write permission is one the app actually writes', () {
    test('the declared write set is exactly what is expected', () {
      // Declaring a health permission the app never uses is a Play Console
      // Health-apps-declaration failure: each requested type must be justified.
      // Computed inside the test, not at group-declaration time — the manifest
      // is not read until setUpAll.
      final declared = RegExp(
              r'<uses-permission android:name="android\.permission\.health\.WRITE_(\w+)"\s*/>')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        declared,
        {
          'MINDFULNESS',
          'BLOOD_PRESSURE',
          'BLOOD_GLUCOSE',
          'WEIGHT',
          'HYDRATION',
        },
        reason: 'Adding a WRITE permission means updating the Play Console '
            'Health apps declaration AND the disclosure on '
            'health_privacy_screen.dart. If this list changed, do both.',
      );
    });
  });

  test('the privacy screen discloses hydration in both directions', () {
    // health_privacy_screen.dart's own doc says: "If you add a data type,
    // change this screen in the same commit." Claiming less than you read or
    // write is the specific thing that fails review.
    final privacy =
        File('lib/features/settings/screens/health_privacy_screen.dart')
            .readAsStringSync();
    expect(privacy.toLowerCase(), contains('water logged in other apps'),
        reason: 'the READ_HYDRATION disclosure is missing');
    expect(privacy.toLowerCase(), contains('drinks you log'),
        reason: 'the WRITE_HYDRATION disclosure is missing');
  });
}
