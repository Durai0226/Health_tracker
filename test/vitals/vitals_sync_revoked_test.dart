import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_reminder_settings_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// PV-17 — the vitals reminders screen re-validates the persisted "share with
/// Health Connect" flag against the real OS grant on every open, and used to
/// correct it silently. A user who had switched sync ON came back to a switch
/// that was OFF, with nothing on screen separating "the permission was revoked
/// and your readings stopped being shared" from "you never turned this on".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late List<String> healthCalls;

  /// The health plugin has no platform implementation under `flutter test`,
  /// and its `configure()` blocks on device_info — so both channels are
  /// mocked. Without the device_info stub the permission probe never
  /// completes and the screen sits on its loading state forever, which would
  /// make every assertion below vacuously unreachable.
  void mockHealthChannels({required bool? granted}) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (call) async => <String, dynamic>{});
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_health'),
        (call) async {
      healthCalls.add(call.method);
      return call.method == 'hasPermissions' ? granted : null;
    });
  }

  setUp(() async {
    healthCalls = [];
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2000);
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(const MaterialApp(home: VitalsReminderSettingsScreen()));
    await tester.pumpAndSettle();
  }

  final noticeFinder =
      find.textContaining('its permission was turned off outside DlyMinder');

  testWidgets('a revoked grant is explained, not silently switched off',
      (tester) async {
    // The user turned sync on at some point; the OS grant behind it is gone.
    SharedPreferences.setMockInitialValues(
        {'health_connect_vitals_sync_enabled': true});
    mockHealthChannels(granted: false);

    await pump(tester);

    expect(healthCalls, contains('hasPermissions'),
        reason: 'the screen must actually probe the grant');
    expect(noticeFinder, findsOneWidget,
        reason: 'the user must be able to tell revoked from never-enabled');
    expect(find.textContaining('no longer being sent'), findsOneWidget);

    // The existing correction still happens — the notice explains it, it does
    // not replace it.
    expect(await VitalsStorageService.isHealthConnectSyncEnabled(), isFalse);
  });

  testWidgets('a grant that is still live says nothing', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'health_connect_vitals_sync_enabled': true});
    mockHealthChannels(granted: true);

    await pump(tester);

    expect(healthCalls, contains('hasPermissions'));
    expect(noticeFinder, findsNothing,
        reason: 'sync is working; there is nothing to explain');
    expect(await VitalsStorageService.isHealthConnectSyncEnabled(), isTrue);
  });

  testWidgets('a sync the user never enabled says nothing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    mockHealthChannels(granted: false);

    await pump(tester);

    expect(noticeFinder, findsNothing,
        reason: 'an off switch nobody touched is not a revocation');
    // The Sync row itself is unconditional — only the notice is not.
    expect(find.textContaining('Share with'), findsOneWidget);
  });
}
