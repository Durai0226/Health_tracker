/// The phone's own step sensor is asked for, where there is no health app to ask
/// through.
///
/// The activity-recognition permission was requested in one place only: inside
/// "Enable", the health app's consent. With no health app on the phone the card
/// offers nothing but "Log manually" — so the permission was never asked, the live
/// counter never emitted, and the Steps screen read zero all day.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_sensor_access.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/widgets/steps_permission_card.dart';

class FakeSensor implements StepSensorAccess {
  FakeSensor({this.granted = false, this.grants = true});

  bool granted;
  bool grants;
  int asked = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    asked++;
    if (grants) granted = true;
    return grants;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  final now = DateTime(2026, 3, 12, 18, 30);

  // The pedometer's EventChannel: a stream handler that does nothing, so that
  // subscribing is real — and observable — without a platform behind it.
  const stepCount = EventChannel('step_count');

  var listens = 0;
  var cancels = 0;

  setUp(() async {
    listens = 0;
    cancels = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
            stepCount,
            MockStreamHandler.inline(
                onListen: (_, _) => listens++, onCancel: (_) => cancels++));
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
  });

  tearDown(() async {
    await StepService.stopLiveTracking(flush: false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(stepCount, null);
    await database.close();
  });

  group('the card', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      HealthAvailability availability = HealthAvailability.unavailable,
      Future<void> Function()? onUseSensor,
      bool sensorGranted = false,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepsPermissionCard(
              availability: availability,
              onEnable: () async {},
              onLogManually: () {},
              onUseSensor: onUseSensor,
              sensorGranted: sensorGranted,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('with no health app it still offers the sensor, besides typing',
        (tester) async {
      var used = 0;
      await pumpCard(tester, onUseSensor: () async => used++);

      expect(find.text('Health data unavailable'), findsOneWidget);
      expect(find.text('Log manually'), findsOneWidget);
      expect(find.text("Count with this phone's sensor"), findsOneWidget);
      expect(find.textContaining('no step sensor'), findsNothing,
          reason: 'it must not say there is none above the button that counts with it');
      expect(find.textContaining('count them itself with its step sensor'), findsOneWidget);

      await tester.tap(find.text("Count with this phone's sensor"));
      await tester.pump();
      expect(used, 1);
    });

    testWidgets('offered beside "Enable" too, when a health app could be connected',
        (tester) async {
      await pumpCard(tester,
          availability: HealthAvailability.notDetermined, onUseSensor: () async {});

      expect(find.text('Enable'), findsOneWidget);
      expect(find.text("Count with this phone's sensor"), findsOneWidget);
    });

    testWidgets('not offered once the sensor is allowed', (tester) async {
      await pumpCard(tester, onUseSensor: () async {}, sensorGranted: true);

      expect(find.text("Count with this phone's sensor"), findsNothing);
    });

    testWidgets('and not at all when the caller does not offer it', (tester) async {
      await pumpCard(tester);

      expect(find.text("Count with this phone's sensor"), findsNothing);
      expect(find.textContaining('no step sensor or health provider'), findsOneWidget,
          reason: 'then there really is nothing: the plain copy stands');
    });

    testWidgets('once the sensor is allowed the card is not offering it, and says what it said',
        (tester) async {
      await pumpCard(tester, onUseSensor: () async {}, sensorGranted: true);

      expect(find.textContaining('no step sensor or health provider'), findsOneWidget);
    });
  });

  group('on the Steps screen', () {
    Future<void> open(WidgetTester tester, FakeSensor sensor) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(411, 2400);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
      };
      addTearDown(() => FlutterError.onError = prev);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: StepsDashboardScreen(sensorAccess: sensor),
        ));
        // The health probe has no platform here and runs into its own six-second
        // limit before the screen leaves its spinner; fake time gets past it.
        await tester.pump(const Duration(seconds: 7));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    }

    /// Real time for the database work behind a tap, then the frames it earns.
    /// Stops short of the toast's own timeout, so it can still be asserted on.
    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a sensor not yet allowed is offered, and asking starts the count',
        (tester) async {
      final sensor = FakeSensor();
      await open(tester, sensor);
      final offer = find.text("Count with this phone's sensor");
      await tester.ensureVisible(offer);
      expect(offer, findsOneWidget);

      await tester.tap(offer);
      await settle(tester);

      expect(sensor.asked, 1);
      expect(StepService.liveTrackingStartedForTesting, isTrue);
      expect([listens, cancels], [2, 1],
          reason: 'the stream the screen opened before the permission is replaced '
              'by a new one, or the count would stay at zero');
      expect(find.text("Counting steps with this phone's sensor."), findsOneWidget);
      expect(find.text("Count with this phone's sensor"), findsNothing,
          reason: 'it is allowed now: the offer goes');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a refusal says where to allow it, and keeps the offer', (tester) async {
      final sensor = FakeSensor(grants: false);
      await open(tester, sensor);
      final offer = find.text("Count with this phone's sensor");
      await tester.ensureVisible(offer);

      await tester.tap(offer);
      await settle(tester);

      expect(sensor.asked, 1);
      expect(find.textContaining('Settings → Apps → DlyMinder → Permissions'), findsOneWidget);
      expect(find.text("Count with this phone's sensor"), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('allowed in Settings while the app was away: the offer goes, and counting starts',
        (tester) async {
      // The refusal's toast sends the person to Settings; they come back with the
      // permission given. Asked once when the screen opened, the offer stayed and the
      // count — a subscription opened before the permission — stayed at zero.
      final sensor = FakeSensor();
      await open(tester, sensor);
      final offer = find.text("Count with this phone's sensor");
      await tester.ensureVisible(offer);
      expect(offer, findsOneWidget);
      final listensBefore = listens;

      sensor.granted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(find.text("Count with this phone's sensor"), findsNothing,
          reason: 'it is allowed now: the offer goes');
      expect(listens, greaterThan(listensBefore),
          reason: 'and a new subscription replaces the one opened without it');
      expect(sensor.asked, 0, reason: 'nothing was asked: it was only looked at');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a resume with nothing changed does not start counting again', (tester) async {
      // Looked at on every resume; only a CHANGE is acted on. Restarting the live
      // count each time would drop and reopen the sensor subscription at every return
      // to the app.
      final sensor = FakeSensor(granted: true);
      await open(tester, sensor);
      final listensBefore = listens;
      final cancelsBefore = cancels;

      for (var i = 0; i < 3; i++) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(tester);
      }

      expect([listens, cancels], [listensBefore, cancelsBefore]);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('taken away in Settings: the offer comes back', (tester) async {
      final sensor = FakeSensor(granted: true);
      await open(tester, sensor);
      expect(find.text("Count with this phone's sensor"), findsNothing);

      sensor.granted = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      final offer = find.text("Count with this phone's sensor");
      await tester.ensureVisible(offer);
      expect(offer, findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('closing the screen leaves the count going', (tester) async {
      // The screen used to switch the sensor off as it closed, so steps were counted
      // only while it was open. The count now belongs to the app (see
      // StepService.keepCountingWhileOpen); the screen must not end it.
      final sensor = FakeSensor(granted: true);
      await open(tester, sensor);
      expect(StepService.liveTrackingStartedForTesting, isTrue);
      final cancelsBefore = cancels;

      await tester.pumpWidget(const SizedBox());
      await settle(tester);

      expect(StepService.liveTrackingStartedForTesting, isTrue);
      expect(cancels, cancelsBefore, reason: 'the subscription was cancelled on close');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('already allowed: nothing is offered and nothing is asked',
        (tester) async {
      final sensor = FakeSensor(granted: true);
      await open(tester, sensor);

      expect(find.text("Count with this phone's sensor"), findsNothing);
      expect(sensor.asked, 0);
    });
  });

  group('starting again', () {
    test('subscribes anew: what was subscribed before the permission is replaced',
        () async {
      await StepService.startLiveTracking();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect([listens, cancels], [1, 0]);

      await StepService.restartLiveTracking();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(StepService.liveTrackingStartedForTesting, isTrue);
      expect([listens, cancels], [2, 1],
          reason: 'the stream opened before the permission was given never '
              'emits: it is cancelled and a new one opened');
    });

    test('starting twice is still one subscription', () async {
      await StepService.startLiveTracking();
      await StepService.startLiveTracking();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(listens, 1);
    });

    test('stopping leaves nothing subscribed', () async {
      await StepService.startLiveTracking();
      await StepService.stopLiveTracking();
      expect(StepService.liveTrackingStartedForTesting, isFalse);
    });
  });
}
