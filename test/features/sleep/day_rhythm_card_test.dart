/// "A typical day", fitted to the person's wake time — on the Sleep screen, and
/// honest about being a general pattern rather than a measurement.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/day_rhythm.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_schedule.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/day_rhythm_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/sleep/widgets/day_rhythm_card.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/font_free_theme.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int at(int h, [int m = 0]) => h * 60 + m;

  List<RhythmSpan> typicalDay() =>
      DayRhythm.of(wakeMinute: at(6, 30), bedMinute: at(22, 30))!;

  Future<void> pumpCard(
    WidgetTester tester, {
    int? nowMinute,
    bool fromNights = false,
    double width = 430,
    double scale = 1,
    List<RhythmSpan>? spans,
    int wake = 6 * 60 + 30,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 2400);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DayRhythmCard(
            spans: spans ?? typicalDay(),
            wakeMinute: wake,
            fromNights: fromNights,
            nowMinute: nowMinute,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('the card', () {
    testWidgets('leads with when focus is often best, with the day beneath',
        (tester) async {
      await pumpCard(tester);
      expect(find.text('A TYPICAL DAY'), findsOneWidget);
      expect(find.text('Often best for focus 9:00 AM – 11:30 AM'), findsOneWidget);
      expect(find.text('Waking up'), findsOneWidget);
      expect(find.text('6:30 AM – 7:30 AM'), findsOneWidget);
      expect(find.text('Usual afternoon dip'), findsOneWidget);
      expect(find.text('1:30 PM – 3:30 PM'), findsOneWidget);
      expect(find.text('Wind down'), findsOneWidget);
      expect(find.text('9:00 PM – 10:30 PM'), findsOneWidget);
    });

    testWidgets('says it is a general pattern, not measured, and from where',
        (tester) async {
      await pumpCard(tester, fromNights: true);
      expect(find.textContaining('not measured from you'), findsOneWidget);
      expect(find.textContaining('6:30 AM'), findsWidgets);
      expect(find.textContaining('from your recent nights'), findsOneWidget);

      await pumpCard(tester, fromNights: false);
      expect(find.textContaining('from your sleep schedule'), findsOneWidget);
    });

    testWidgets('says which phase it is now, when it is one', (tester) async {
      await pumpCard(tester, nowMinute: at(10));
      expect(find.text('Right now: often best for focus'), findsOneWidget);
    });

    testWidgets('and says nothing between phases', (tester) async {
      // 12:00 falls in the gap between focus and the dip.
      await pumpCard(tester, nowMinute: at(12));
      expect(find.textContaining('Right now'), findsNothing);
    });

    testWidgets('nor before the day starts', (tester) async {
      await pumpCard(tester, nowMinute: at(3));
      expect(find.textContaining('Right now'), findsNothing);
    });

    testWidgets('a day that runs past midnight is matched on either side of it',
        (tester) async {
      final late = DayRhythm.of(wakeMinute: at(10), bedMinute: at(2))!;
      // 00:45 is inside the wind-down (00:30 to 02:00), a day on from waking.
      await pumpCard(tester, spans: late, wake: at(10), nowMinute: at(0, 45));
      expect(find.text('Right now: wind down'), findsOneWidget);
    });

    testWidgets('no verdicts, no score', (tester) async {
      await pumpCard(tester, nowMinute: at(14));
      for (final banned in ['score', 'should', 'unhealthy', 'bad', 'diagnos']) {
        expect(find.textContaining(RegExp(banned, caseSensitive: false)), findsNothing,
            reason: banned);
      }
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0), (390.0, 1.3)]) {
      testWidgets('fits a $width-wide screen at ${scale}x text', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await pumpCard(tester, width: width, scale: scale, nowMinute: at(10));
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
      });
    }
  });

  group('phaseAt', () {
    final day = typicalDay();

    test('the span a time falls in', () {
      expect(DayRhythmCard.phaseAt(day, at(9))!.phase, RhythmPhase.focus);
      expect(DayRhythmCard.phaseAt(day, at(14))!.phase, RhythmPhase.dip);
    });

    test('start is in, end is out', () {
      expect(DayRhythmCard.phaseAt(day, at(9))!.phase, RhythmPhase.focus);
      expect(DayRhythmCard.phaseAt(day, at(11, 30)), isNull);
    });

    test('nothing in the gaps or at night', () {
      expect(DayRhythmCard.phaseAt(day, at(12)), isNull);
      expect(DayRhythmCard.phaseAt(day, at(2)), isNull);
    });
  });

  group('fitted to the person', () {
    late db.AppDatabase database;
    final now = DateTime(2026, 6, 20, 12);

    setUpAll(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      db.AppDatabase.setInstanceForTesting(database);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      await SleepService.resetForTesting();
      NotificationService().schedulerForTesting = RecordingNotificationScheduler();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (_) async => <String, dynamic>{},
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
      await database.close();
    });

    String key(int daysAgo) {
      final d = DateTime(now.year, now.month, now.day - daysAgo);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    Future<void> night(int daysAgo, {int wakeHour = 7}) async {
      final wake = DateTime(now.year, now.month, now.day - daysAgo, wakeHour);
      await database.sleepDao.upsert(db.SleepSessionsCompanion(
        id: Value('n$daysAgo'),
        dateKey: Value(key(daysAgo)),
        bedtime: Value(wake.subtract(const Duration(minutes: 480))),
        wakeTime: Value(wake),
        inBedMinutes: const Value(480),
        asleepMinutes: const Value(450),
        sourceIndex: Value(SleepSource.healthConnect.index),
        createdAt: Value(wake),
        updatedAt: Value(wake),
      ));
    }

    test('with too few nights, the schedule they set', () async {
      await withClock(Clock.fixed(now), () async {
        await SleepService.saveSchedule(const SleepSchedule(
            wakeHour: 6, wakeMinute: 30, bedtimeHour: 22, bedtimeMinute: 30));
        final v = DayRhythmService.current()!;
        expect(v.fromNights, isFalse);
        expect(v.wakeMinute, at(6, 30));
        expect(v.spans.first.start, at(6, 30));
      });
    });

    test('with enough nights, when they actually wake', () async {
      await withClock(Clock.fixed(now), () async {
        await SleepService.saveSchedule(const SleepSchedule(
            wakeHour: 6, wakeMinute: 30, bedtimeHour: 22, bedtimeMinute: 30));
        for (var i = 0; i < 5; i++) {
          await night(i, wakeHour: 8);
        }
        await SleepService.reloadFromDb();

        final v = DayRhythmService.current()!;
        expect(v.fromNights, isTrue);
        expect(v.wakeMinute, at(8),
            reason: 'the nights they slept, not the time they set');
        expect(v.spans.first.start, at(8));
      });
    });

    test('a wake time and bedtime too close together make no card', () async {
      await withClock(Clock.fixed(now), () async {
        await SleepService.saveSchedule(const SleepSchedule(
            wakeHour: 7, wakeMinute: 0, bedtimeHour: 13, bedtimeMinute: 0));
        expect(DayRhythmService.current(), isNull);
      });
    });

    testWidgets('the Sleep screen shows it, placed after tonight\'s bedtime',
        (tester) async {
      await withClock(Clock.fixed(now), () async {
        for (var i = 0; i < 5; i++) {
          await night(i);
        }
        await SleepService.saveSchedule(const SleepSchedule());
        await SleepService.reloadFromDb();

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 6000);
        addTearDown(tester.view.reset);
        final prev = FlutterError.onError;
        FlutterError.onError = (_) {};
        try {
          await tester.pumpWidget(MaterialApp(
              theme: fontFreeTheme(), home: const SleepDashboardScreen()));
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        } finally {
          FlutterError.onError = prev;
        }

        expect(find.byType(DayRhythmCard), findsOneWidget);
        expect(find.text('A TYPICAL DAY'), findsOneWidget);
        final bedtime = tester.getTopLeft(find.text("TONIGHT'S BEDTIME")).dy;
        final rhythm = tester.getTopLeft(find.text('A TYPICAL DAY')).dy;
        expect(rhythm, greaterThan(bedtime));
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });
}
