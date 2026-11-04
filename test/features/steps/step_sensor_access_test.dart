/// The phone's own step sensor permission, asked where it can be asked.
///
/// On iPhone `permission_handler` answers "denied" to everything unless the app is
/// built with `PERMISSION_SENSORS=1` — which the Podfile does not set. So the
/// "Count with this phone's sensor" offer showed to every iPhone user, including
/// those whose pedometer already worked, and tapping it showed the Android-worded
/// route to Settings and never restarted the live count. iPhone asks for itself
/// (the pedometer raises the system prompt on first read), so the offer is Android's.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/steps/services/step_sensor_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  late List<MethodCall> asked;

  /// A platform that answers "denied" to everything, as an iPhone without the
  /// macro does — and remembers that it was asked.
  void platformDenies() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      asked.add(call);
      switch (call.method) {
        case 'checkPermissionStatus':
          return 0; // PermissionStatus.denied
        case 'requestPermissions':
          return {for (final p in (call.arguments as List)) p as int: 0};
      }
      return null;
    });
  }

  setUp(() {
    asked = [];
    platformDenies();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('on iPhone', () {
    const ios = PlatformStepSensorAccess(iosForTesting: true);

    test('the sensor reads as allowed, so the offer is not made', () async {
      expect(await ios.isGranted(), isTrue);
    });

    test('and the platform is not asked at all', () async {
      await ios.isGranted();
      await ios.request();

      expect(asked, isEmpty,
          reason: 'it would only have said "denied"; the pedometer asks for itself');
    });

    test('a request has nothing to refuse', () async {
      expect(await ios.request(), isTrue);
    });
  });

  group('on Android', () {
    const android = PlatformStepSensorAccess(iosForTesting: false);

    test('the platform is asked, and its "denied" is believed', () async {
      expect(await android.isGranted(), isFalse);
      expect(asked.map((c) => c.method), ['checkPermissionStatus']);
    });

    test('a request goes to the platform too, and a refusal is a no', () async {
      expect(await android.request(), isFalse);
      expect(asked.map((c) => c.method), contains('requestPermissions'));
    });

    test('and a yes is a yes', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'checkPermissionStatus':
            return 1; // granted
          case 'requestPermissions':
            return {for (final p in (call.arguments as List)) p as int: 1};
        }
        return null;
      });

      expect(await android.isGranted(), isTrue);
      expect(await android.request(), isTrue);
    });

    test('with no platform to ask it does not nag, and does not claim a grant', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no platform');
      });

      expect(await android.isGranted(), isTrue,
          reason: 'a permission that cannot be asked for is not offered');
      expect(await android.request(), isFalse);
    });
  });
}
