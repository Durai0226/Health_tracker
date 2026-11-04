/// The Focus screen's side of "Break first?": the question before another round,
/// its two answers, and the switch that turns it off.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppSwitch;
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();
  final now = DateTime(2026, 3, 14, 13);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    StatsService().resetForTesting();
    ToastOverlay.instance.resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    ToastOverlay.instance.resetForTesting();
    focus.resetForTesting();
    StatsService().resetForTesting();
    await db.close();
  });

  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 10));
  }

  var counter = 0;

  /// [rounds] 25-minute rounds with five-minute rests, the last ending five
  /// minutes before [now]: two of them are 50 minutes, four are 100.
  Future<void> doneRounds(int rounds) async {
    final first = now.subtract(Duration(minutes: 5 + 30 * rounds - 5));
    await focus.importSessionsJson([
      for (var i = 0; i < rounds; i++)
        () {
          counter++;
          final start = first.add(Duration(minutes: 30 * i));
          return FocusSession(
            id: 'ui-round-$counter',
            startedAt: start,
            completedAt: start.add(const Duration(minutes: 25)),
            targetMinutes: 25,
            actualMinutes: 25,
            wasCompleted: true,
            activityType: FocusActivityType.work,
            plantType: PlantType.seedling,
          ).toJson();
        }(),
    ]);
  }

  void screenTest(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    int rounds = 4,
  }) {
    testWidgets(description, (tester) async {
      quietOverflow();
      await withClock(Clock.fixed(now), () async {
        await doneRounds(rounds);
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(375, 2400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
        await pump(tester);
        try {
          await body(tester);
        } finally {
          if (focus.isRunning) await focus.abandonSession();
          await settle(tester);
        }
      });
    });
  }

  Future<void> tapStart(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Start Focus'));
    await tester.pump();
    await tester.tap(find.text('Start Focus'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('after a long stretch', () {
    screenTest('Start asks first, and says how long it has been', (tester) async {
      await tapStart(tester);

      expect(find.text('Break first?'), findsOneWidget);
      expect(find.textContaining('1 h 40 min'), findsOneWidget);
      expect(find.text('Take 20 min'), findsOneWidget);
      expect(find.text('Start anyway'), findsOneWidget);
      expect(focus.isRunning, isFalse, reason: 'nothing starts until they answer');
    });

    screenTest('"Take 20 min" starts a break: nothing earned, nothing recorded',
        (tester) async {
      final sessionsBefore = focus.sessions.length;

      await tapStart(tester);
      await tester.tap(find.text('Take 20 min'));
      await pump(tester);

      expect(focus.isRunning, isTrue);
      expect(focus.isRestBreak, isTrue);
      expect(focus.remainingSeconds, 20 * 60);
      expect(focus.sessions.length, sessionsBefore);
      expect(find.text('On a Break'), findsOneWidget);
    });

    screenTest('"Start anyway" starts the round', (tester) async {
      await tapStart(tester);

      await tester.tap(find.text('Start anyway'));
      await pump(tester);

      expect(focus.isRunning, isTrue);
      expect(focus.isRestBreak, isFalse);
      expect(find.text('Break first?'), findsNothing);
    });

    screenTest('and it is not asked again for the same stretch', (tester) async {
      await tapStart(tester);
      await tester.tap(find.text('Start anyway'));
      await pump(tester);
      await focus.abandonSession();
      await pump(tester);

      await tapStart(tester);

      expect(find.text('Break first?'), findsNothing);
      expect(focus.isRunning, isTrue);
    });

    screenTest('closing the question starts nothing', (tester) async {
      await tapStart(tester);

      await tester.tapAt(const Offset(10, 10));
      await pump(tester);

      expect(find.text('Break first?'), findsNothing);
      expect(focus.isRunning, isFalse);
      expect(focus.isRestBreak, isFalse);
    });
  });

  group('without one', () {
    screenTest('under ninety minutes, Start just starts', (tester) async {
      await tapStart(tester);

      expect(find.text('Break first?'), findsNothing);
      expect(focus.isRunning, isTrue);
    }, rounds: 2);
  });

  group('the switch in Session setup', () {
    Future<void> openSetup(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Session setup'));
      await tester.pump();
      await tester.tap(find.text('Session setup'));
      await pump(tester);
      await tester.ensureVisible(find.text('Offer a break after long stretches'));
      await tester.pump();
    }

    screenTest('is on, and says what it does and that Start anyway is always there',
        (tester) async {
      await openSetup(tester);

      expect(tester.widget<AppSwitch>(find.byType(AppSwitch).at(2)).value, isTrue,
          reason: 'third switch in the sheet: breaths, step away, then this');
      expect(find.textContaining('90 minutes'), findsOneWidget);
      expect(find.textContaining('You can always start anyway'), findsOneWidget);
    });

    screenTest('off, Start just starts even after a long stretch', (tester) async {
      await openSetup(tester);
      await tester.tap(find.text('Offer a break after long stretches'));
      await pump(tester);
      expect(focus.breakOffers, isFalse);
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch).at(2)).value, isFalse);

      // Close the sheet, then Start.
      await tester.tapAt(const Offset(10, 10));
      await pump(tester);
      await tapStart(tester);

      expect(find.text('Break first?'), findsNothing);
      expect(focus.isRunning, isTrue);
    });
  });
}
