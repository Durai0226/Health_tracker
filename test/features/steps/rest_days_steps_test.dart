import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/widgets/rest_day_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final today = DateTime(2026, 3, 12, 18, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
  });

  tearDown(() async => database.close());

  group('RestDayStore', () {
    test('marks today, survives a restart, and can be taken back', () async {
      await withClock(Clock.fixed(today), () async {
        expect(RestDayStore.kindToday(), isNull);
        await RestDayStore.markToday(RestKind.unwell);
        CleanStorageService.resetForTesting();
        await CleanStorageService.init();
        expect(RestDayStore.kindToday(), RestKind.unwell);
        await RestDayStore.clear(today);
        expect(RestDayStore.kindToday(), isNull);
      });
    });
  });

  group('the steps streak', () {
    // Ten good days, a day off sick in the middle of the run, then more.
    Future<void> goodDays(Iterable<int> days) async {
      for (final d in days) {
        await StepService.addManualStepsForDate(DateTime(2026, 3, d), 30000,
            maxDaysBack: 60);
      }
    }

    test('without marking a long gap breaks the streak; marked, it holds',
        () async {
      await withClock(Clock.fixed(today), () async {
        // 5th-9th missing: longer than the engine's own grace for a stray day.
        await goodDays([1, 2, 3, 4, 10, 11, 12]);
        expect(StepService.getStreakResult().current, 3,
            reason: 'only the run since the gap');

        for (var d = 5; d <= 9; d++) {
          await RestDayStore.markToday(
              d.isEven ? RestKind.rest : RestKind.unwell,
              now: DateTime(2026, 3, d));
        }
        expect(StepService.getStreakResult().current, 7,
            reason: 'marked days are neither completions nor misses');
      });
    });
  });

  group('the adaptive goal', () {
    test('marking the day removes it from what the goal is learned from',
        () async {
      await withClock(Clock.fixed(today), () async {
        // Many low days so the median would move if they were counted.
        for (var d = 1; d <= 11; d++) {
          final steps = d <= 6 ? 300 : 7000;
          await StepService.addManualStepsForDate(DateTime(2026, 3, d), steps,
              maxDaysBack: 60);
        }
        final withLowDays = StepService.computeAdaptiveGoal();
        for (var d = 1; d <= 6; d++) {
          await RestDayStore.markToday(RestKind.unwell, now: DateTime(2026, 3, d));
        }
        final withoutThem = StepService.computeAdaptiveGoal();
        expect(withoutThem, greaterThan(withLowDays),
            reason: 'six sick days must not drag the goal down');
      });
    });
  });

  group('the evening reminder', () {
    test('stays quiet on a marked day, even with no step data', () async {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
      final scheduler = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = scheduler;
      await withClock(Clock.fixed(DateTime(2026, 3, 12, 18, 30)), () async {
        await StepService.setReminder(true, 19 * 60);
        await RestDayStore.markToday(RestKind.rest);
        await StepService.replanReminder();
        expect(
            scheduler.scheduled
                .where((s) => s.id == NotificationService.stepReminderTodayId),
            isEmpty);
        final repeating = scheduler.scheduled
            .singleWhere((s) => s.id == NotificationService.stepReminderId);
        expect(repeating.when.isAtSameMomentAs(DateTime(2026, 3, 13, 19)), isTrue,
            reason: 'tomorrow carries on');
      });
    });
  });

  group('RestDayCard', () {
    Widget host(Widget child) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    testWidgets('unmarked, it offers Rest day and Unwell', (tester) async {
      final marks = <RestKind>[];
      await tester.pumpWidget(host(RestDayCard(
          marked: null, onMark: marks.add, onUndo: () {})));
      expect(find.text('Taking it easy today?'), findsOneWidget);
      await tester.tap(find.text('Unwell'));
      await tester.tap(find.text('Rest day'));
      expect(marks, [RestKind.unwell, RestKind.rest]);
    });

    testWidgets('marked, it says the goal is paused and offers Undo',
        (tester) async {
      var undone = 0;
      await tester.pumpWidget(host(RestDayCard(
          marked: RestKind.unwell, onMark: (_) {}, onUndo: () => undone++)));
      expect(find.text('Unwell'), findsOneWidget);
      expect(find.textContaining('goal is paused'), findsOneWidget);
      expect(find.text('Taking it easy today?'), findsNothing);
      await tester.tap(find.text('Undo'));
      expect(undone, 1);
    });
  });

  group('on the Steps screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow is the responsive suite's job
      try {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const StepsDashboardScreen(),
        ));
        for (var f = 0; f < 8; f++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    testWidgets('mark a rest day, see it, take it back', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 12, 13)), () async {
        await open(tester);
        expect(find.text('Taking it easy today?'), findsOneWidget);

        await tester.tap(find.text('Rest day'));
        await tester.pump();
        await tester.pump();
        expect(RestDayStore.kindToday(), RestKind.rest);
        expect(find.textContaining('goal is paused'), findsOneWidget);
        expect(find.textContaining('Rest day · goal paused'), findsOneWidget);

        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.pump();
        expect(RestDayStore.kindToday(), isNull);
        expect(find.text('Taking it easy today?'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });
}
