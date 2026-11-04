/// The Focus screen's side of leaving the app mid-round: the card that offers a
/// shorter round, what its buttons do, and the switch that turns it all off.
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
import 'package:tablet_remainder/features/focus/models/focus_session.dart' show FocusMode;
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_drift.dart';
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
  final t0 = DateTime(2026, 3, 14, 13);

  const title = 'You often step away around minute 22';

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
    // The overlay is cached once for the whole isolate: without this, the first
    // test's toast lands in a later test's defunct one.
    ToastOverlay.instance.resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    ToastOverlay.instance.resetForTesting();
    focus.resetForTesting();
    StatsService().resetForTesting();
    await db.close();
  });

  /// A test font makes every glyph a wide square, so a footer that fits on a phone
  /// overflows here; that belongs to the responsive harness, not to this.
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

  /// Short pumps, then past the toast's own timeout, so no timer outlives the test.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 10));
  }

  /// Six days of leaving at minute 22 of a 25-minute round, ending yesterday.
  Future<void> seedHabit({int days = 6}) async {
    await CleanStorageService.setAppPreference('focusDriftLog', [
      for (var d = 1; d <= days; d++)
        DriftEvent(
          at: DateTime(t0.year, t0.month, t0.day - d, 10),
          minute: 22,
          plannedMinutes: 25,
        ).toJson(),
    ]);
    focus.resetForTesting();
    await focus.init();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
    await pump(tester);
  }

  /// Runs [body] under the fixed clock with the screen open and settled after.
  void screenTest(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    int habitDays = 6,
    bool seed = true,
  }) {
    testWidgets(description, (tester) async {
      quietOverflow();
      await withClock(Clock.fixed(t0), () async {
        if (seed) await seedHabit(days: habitDays);
        await open(tester);
        try {
          await body(tester);
        } finally {
          if (focus.isRunning) await focus.abandonSession();
          await settle(tester);
        }
      });
    });
  }

  group('the card', () {
    screenTest('a habit of leaving at minute 22 shows it, with the round it offers',
        (tester) async {
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('20-minute round'), findsOneWidget);
      expect(find.text('Try 20 + 5'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Why this?'), findsOneWidget);
    });

    screenTest('"Why this?" shows the working, and that a screen lock counts', (tester) async {
      await tester.ensureVisible(find.text('Try 20 + 5'));
      await tester.pump();
      await tester.tap(find.text('Why this?'));
      await settle(tester);

      expect(find.textContaining('6 times'), findsOneWidget);
      expect(find.textContaining('The screen turning off counts as leaving'),
          findsOneWidget);
    });

    screenTest('four days is not a habit yet, so there is no card', (tester) async {
      expect(find.textContaining('step away'), findsNothing);
    }, habitDays: 4);

    screenTest('nothing noticed, nothing said', (tester) async {
      expect(find.textContaining('step away'), findsNothing);
    }, seed: false);

    screenTest('while a round is running it is out of the way', (tester) async {
      await focus.startSession();
      await pump(tester);

      expect(find.text(title), findsNothing);
    });

    screenTest('a round already shorter than the usual minute needs no advice',
        (tester) async {
      focus.setDuration(20);
      await pump(tester);

      expect(find.text(title), findsNothing);
    });
  });

  group('Try 20 + 5', () {
    screenTest('sets the round, says so, and the card goes', (tester) async {
      await tester.ensureVisible(find.text('Try 20 + 5'));
      await tester.pump();
      await tester.tap(find.text('Try 20 + 5'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(focus.mode, FocusMode.pomodoro);
      expect(focus.workMinutes, 20);
      expect(focus.shortBreakMinutes, 5);
      expect(find.text(title), findsNothing);
      expect(find.text('Round set'), findsOneWidget);
      expect(find.textContaining('Pomodoro: 20 minutes, then a 5-minute break.'),
          findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    screenTest('Undo puts the old round back and the card returns', (tester) async {
      focus.setPomodoroConfig(workMinutes: 45, shortBreakMinutes: 10);
      await pump(tester);
      await tester.ensureVisible(find.text('Try 20 + 5'));
      await tester.pump();
      await tester.tap(find.text('Try 20 + 5'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(focus.workMinutes, 20);

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(focus.mode, FocusMode.single);
      expect(focus.workMinutes, 45);
      expect(focus.shortBreakMinutes, 10);
      expect(find.text(title), findsOneWidget);
    });
  });

  group('Dismiss', () {
    screenTest('removes it, and it does not come back on the next visit', (tester) async {
      await tester.ensureVisible(find.text('Dismiss'));
      await tester.pump();
      await tester.tap(find.text('Dismiss'));
      await pump(tester);

      expect(find.text(title), findsNothing);
      expect(focus.mode, FocusMode.single, reason: 'it changes nothing');

      // Leave and come back.
      await tester.pumpWidget(const SizedBox());
      await open(tester);
      expect(find.text(title), findsNothing);
    });
  });

  group('the switch in Session setup', () {
    Future<void> openSetup(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Session setup'));
      await tester.pump();
      await tester.tap(find.text('Session setup'));
      await pump(tester);
      await tester.ensureVisible(find.text('Notice when I step away'));
      await tester.pump();
    }

    screenTest('is on, and says what it counts and what switching off does', (tester) async {
      await openSetup(tester);

      final tile = find.ancestor(
        of: find.text('Notice when I step away'),
        matching: find.byType(InkWell),
      );
      expect(tile, findsWidgets);
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch).at(1)).value, isTrue,
          reason: 'second switch in the sheet, after "Start with a few breaths"');
      expect(find.textContaining('Screen locks count too'), findsOneWidget);
      expect(find.textContaining('Switching it off clears what was noticed'),
          findsOneWidget);
    });

    screenTest('switching it off forgets what was noticed, and the card with it',
        (tester) async {
      expect(focus.driftEventCount, 6);
      await openSetup(tester);

      await tester.tap(find.text('Notice when I step away'));
      await pump(tester);

      expect(focus.driftNoticing, isFalse);
      expect(focus.driftEventCount, 0);
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch).at(1)).value, isFalse);
    });

    screenTest('and back on does not bring the old ones back', (tester) async {
      await openSetup(tester);
      await tester.tap(find.text('Notice when I step away'));
      await pump(tester);

      await tester.tap(find.text('Notice when I step away'));
      await pump(tester);

      expect(focus.driftNoticing, isTrue);
      expect(focus.driftEventCount, 0);
    });
  });
}
