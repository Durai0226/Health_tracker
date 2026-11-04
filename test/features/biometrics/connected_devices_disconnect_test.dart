/// "Disconnect Health Connect" on the Connected devices screen.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/health_sync_queue.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppButton;
import 'package:tablet_remainder/features/biometrics/screens/connected_devices_screen.dart';
import 'package:tablet_remainder/features/biometrics/services/connected_devices_controller.dart';
import 'package:tablet_remainder/features/biometrics/services/health_disconnect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await HealthSyncQueue.clearForTesting();
  });

  tearDown(() async => db.close());

  late int probes;
  late int disconnects;

  /// What the platform answers when asked. Starts as [availability]; a disconnect
  /// that took effect changes it to [afterRevoke], as Health Connect does once its
  /// permissions are really gone.
  late HealthAvailability current;

  Future<ConnectedDevicesController> pump(
    WidgetTester tester, {
    HealthAvailability availability = HealthAvailability.available,
    HealthAvailability afterRevoke = HealthAvailability.notDetermined,
    Future<HealthDisconnectResult> Function()? disconnect,
  }) async {
    probes = 0;
    disconnects = 0;
    current = availability;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = ConnectedDevicesController(
      readSources: () async => const [],
      probeAvailability: () async {
        probes++;
        return current;
      },
      probeBackgroundAvailable: () async => false,
      readBackgroundEnabled: () async => false,
      writeSourceEnabled: (_, _) async {},
      writeSourcePriority: (_, _) async {},
      runSync: () async => 0,
      reloadAggregation: () async {},
      setBackground: (_) async {},
      disconnect: () async {
        disconnects++;
        final result = disconnect == null
            ? const HealthDisconnectResult(revoked: true)
            : await disconnect();
        if (result.revoked) current = afterRevoke;
        return result;
      },
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: ConnectedDevicesScreen(key: UniqueKey(), controller: c),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> tapDisconnect(WidgetTester tester) async {
    await tester.tap(find.text('Disconnect Health Connect'));
    await tester.pumpAndSettle();
  }

  testWidgets('is offered while something is connected, and says what it does',
      (tester) async {
    await pump(tester);

    expect(find.text('Disconnect'), findsOneWidget); // the section
    expect(find.text('Disconnect Health Connect'), findsOneWidget);
    expect(find.textContaining('already in DlyMinder stays'), findsOneWidget);
  });

  for (final a in [
    HealthAvailability.notDetermined,
    HealthAvailability.denied,
    HealthAvailability.unavailable,
    HealthAvailability.needsProviderUpdate,
  ]) {
    testWidgets('is not offered when the state is ${a.name}: nothing to leave',
        (tester) async {
      await pump(tester, availability: a);

      expect(find.text('Disconnect Health Connect'), findsNothing);
    });
  }

  testWidgets('asks first, and says what will stop', (tester) async {
    await pump(tester);

    await tapDisconnect(tester);

    expect(find.text('Disconnect Health Connect?'), findsOneWidget);
    expect(find.textContaining('turns off background sync'), findsOneWidget);
    expect(disconnects, 0, reason: 'nothing happens until it is confirmed');
  });

  testWidgets('Cancel does nothing', (tester) async {
    await pump(tester);
    await tapDisconnect(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(disconnects, 0);
    expect(find.text('Disconnect Health Connect?'), findsNothing);
  });

  testWidgets('confirmed: disconnects, says so, and looks again', (tester) async {
    await pump(tester);
    await tapDisconnect(tester);
    final before = probes;

    await tester.tap(find.widgetWithText(AppButton, 'Disconnect').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(disconnects, 1);
    expect(find.text('Disconnected from Health Connect.'), findsOneWidget);
    expect(probes, greaterThan(before),
        reason: 'what the platform now says is what the screen shows');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the platform still says the permissions are held: does not claim it is done',
      (tester) async {
    // Health Connect may hand them back when the app is closed rather than at that
    // moment, so the look that follows can find them still there. "Disconnected"
    // over a screen that still reads connected would be saying two things.
    await pump(tester, afterRevoke: HealthAvailability.available);
    await tapDisconnect(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Disconnect').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Disconnected from Health Connect.'), findsNothing);
    expect(find.textContaining('takes its access away completely when DlyMinder is closed'),
        findsOneWidget);
    expect(find.textContaining('Health Connect → App permissions → DlyMinder'), findsOneWidget,
        reason: 'and what to do if it does not: the plugin swallows a refusal, so '
            '"later" and "never" look the same from here');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the platform would not take its permissions: says where to go',
      (tester) async {
    await pump(tester,
        disconnect: () async => const HealthDisconnectResult(revoked: false));
    await tapDisconnect(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Disconnect').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('has stopped using Health Connect'), findsOneWidget);
    expect(find.textContaining('Health Connect → App permissions → DlyMinder'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('a failure says so', (tester) async {
    await pump(tester, disconnect: () async => throw StateError('boom'));
    await tapDisconnect(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Disconnect').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Could not disconnect. Please try again.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('a second tap while it is working does not start another',
      (tester) async {
    final gate = Completer<HealthDisconnectResult>();
    await pump(tester, disconnect: () => gate.future);
    await tapDisconnect(tester);

    await tester.tap(find.widgetWithText(AppButton, 'Disconnect').last);
    await tester.pump();
    await tester.tap(find.text('Disconnect Health Connect'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(disconnects, 1);
    expect(find.text('Disconnect Health Connect?'), findsNothing,
        reason: 'the row is inert while the first is still working: it must not '
            'open a second confirmation');
    gate.complete(const HealthDisconnectResult(revoked: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
  });
}
