import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';

/// The permission REQUEST and the permission CHECK must ask about the same
/// scopes. They did not, and the consequence was total.
///
/// `requestBiometricPermission` dropped skin temperature when the installed
/// Health Connect was too old to know the type — correctly, because an
/// unsupported type makes Android bail with `success(false)` before the consent
/// sheet is even shown. `hasBiometricPermission` kept asking about all eight.
///
/// So on any Android device with an older Health Connect: the user granted the
/// seven scopes, the sheet succeeded, the persisted flag was set — and then
/// `hasPermissions` answered **false**, forever, because it was asking about a
/// scope that had never been requested and could not be granted. All three
/// consumers gate on that single boolean:
///
///  * `heart_dashboard_screen` — Enable card up forever
///  * `workouts_screen` — same
///  * `BiometricsService.syncFromHealth` — returns 0 before reading anything
///
/// Re-granting could not fix it. This is the same defect the class docstring
/// describes for `DISTANCE_WALKING_RUNNING` and `SLEEP_IN_BED` — *"which is why
/// granting access used to leave the Enable card up forever"* — reintroduced by
/// fixing one of the two lists and not the other.
///
/// Both platforms are asserted, not just the host: headless `flutter test` runs
/// on neither, and checking only the host is exactly how the Android list rotted
/// unnoticed the first time.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

void main() {
  group('the effective list drops what cannot be granted', () {
    test('unsupported skin temperature is excluded, on both platforms', () {
      for (final android in [true, false]) {
        final types = HealthDataService.effectiveBiometricTypesFor(android,
            skinTemperatureSupported: false);
        final skinTemp = android
            ? HealthDataService.skinTempTypeAndroid
            : HealthDataService.skinTempTypeIOS;
        expect(types, isNot(contains(skinTemp)),
            reason: 'android=$android — requesting a scope Health Connect does '
                'not implement makes the whole request fail');
        expect(types, hasLength(HealthDataService.biometricTypesFor(android).length - 1));
      }
    });

    test('supported skin temperature is kept', () {
      for (final android in [true, false]) {
        final types = HealthDataService.effectiveBiometricTypesFor(android,
            skinTemperatureSupported: true);
        expect(types, HealthDataService.biometricTypesFor(android));
      }
    });

    test('it never returns a type the platform does not implement', () {
      for (final supported in [true, false]) {
        final onAndroid = HealthDataService.effectiveBiometricTypesFor(true,
            skinTemperatureSupported: supported);
        expect(onAndroid.where((t) => !dataTypeKeysAndroid.contains(t)), isEmpty);

        final onIOS = HealthDataService.effectiveBiometricTypesFor(false,
            skinTemperatureSupported: supported);
        expect(onIOS.where((t) => !dataTypeKeysIOS.contains(t)), isEmpty);
      }
    });

    test('it does not mutate the shared list it derives from', () {
      // `biometricTypesFor` returning a fresh list is what makes the `remove`
      // safe. If it ever returns a const or cached list, dropping skin
      // temperature here would corrupt every other caller.
      final before = HealthDataService.biometricTypesFor(true).length;
      HealthDataService.effectiveBiometricTypesFor(true,
          skinTemperatureSupported: false);
      expect(HealthDataService.biometricTypesFor(true), hasLength(before));
    });

    test('the platform split survives the drop', () {
      // Removing the wrong platform's skin-temperature type would leave the
      // real one in and silently reintroduce the original failure.
      final android = HealthDataService.effectiveBiometricTypesFor(true,
          skinTemperatureSupported: false);
      expect(android, isNot(contains(HealthDataService.skinTempTypeIOS)));
      expect(android, isNot(contains(HealthDataService.skinTempTypeAndroid)));

      final ios = HealthDataService.effectiveBiometricTypesFor(false,
          skinTemperatureSupported: false);
      expect(ios, isNot(contains(HealthDataService.skinTempTypeAndroid)));
      expect(ios, isNot(contains(HealthDataService.skinTempTypeIOS)));
    });
  });

  group('request and check cannot diverge again', () {
    late String code;

    setUpAll(() {
      code = _codeOnly(
          File('lib/core/services/health_data_service.dart').readAsStringSync());
    });

    String bodyOf(String signature, String nextSignature) => code.substring(
        code.indexOf(signature), code.indexOf(nextSignature));

    test('both derive from the one shared helper', () {
      final check = bodyOf('Future<bool> hasBiometricPermission()',
          'Future<bool> requestBiometricPermission()');
      final request = bodyOf('Future<bool> requestBiometricPermission()',
          'Future<bool> isSkinTemperatureSupported()');

      expect(check, contains('_effectiveBiometricTypes()'),
          reason: 'the check asking about a scope the request never asked for '
              'is the entire bug');
      expect(request, contains('_effectiveBiometricTypes()'));
    });

    test('neither reaches for the unfiltered list', () {
      final check = bodyOf('Future<bool> hasBiometricPermission()',
          'Future<bool> requestBiometricPermission()');
      final request = bodyOf('Future<bool> requestBiometricPermission()',
          'Future<bool> isSkinTemperatureSupported()');
      for (final body in [check, request]) {
        expect(body.contains('biometricTypes;'), isFalse);
        expect(body.contains('from(biometricTypes)'), isFalse);
      }
    });

    test('neither re-implements the skin-temperature drop', () {
      // Two copies of the rule is how they diverged the first time.
      final check = bodyOf('Future<bool> hasBiometricPermission()',
          'Future<bool> requestBiometricPermission()');
      final request = bodyOf('Future<bool> requestBiometricPermission()',
          'Future<bool> isSkinTemperatureSupported()');
      for (final body in [check, request]) {
        expect(body.contains('remove(skinTempType)'), isFalse);
      }
    });
  });
}
