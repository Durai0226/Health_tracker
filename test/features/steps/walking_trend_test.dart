/// "Up 12% on your 90-day average", on the Steps screen: where it reads from,
/// what it leaves out, and how it looks.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/health/walking_trends.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/models/step_daily_data.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/services/walking_trend_service.dart';
import 'package:tablet_remainder/features/steps/widgets/step_hourly_chart.dart';
import 'package:tablet_remainder/features/steps/widgets/step_weekly_chart.dart';
import 'package:tablet_remainder/features/steps/widgets/walking_trend_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;
  final now = DateTime(2026, 6, 30, 9, 0);
  DateTime ago(int n) => DateTime(2026, 6, 30 - n);

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

  /// [steps] on each day from [from] to [to] days ago, inclusive.
  Future<void> walk(int from, int to, int steps) async {
    for (var i = from; i <= to; i++) {
      await StepService.addManualStepsForDate(ago(i), steps, maxDaysBack: 200);
    }
  }

  Future<R> pinned<R>(Future<R> Function() body) => withClock(Clock.fixed(now), body);

  group('the service', () {
    test('the last four weeks against the last ninety', () async {
      await pinned(() async {
        await walk(1, 28, 9000);
        await walk(29, 90, 7000);
        final t = (await WalkingTrendService.load())!;
        expect(t.direction, WalkingDirection.up);
        expect(t.recentAvg, 9000);
        expect(t.baselineAvg, 7622);
        expect(t.recentDays, 28);
        expect(t.baselineDays, 90);
      });
    });

    test('it reads past the thirty-five days the dashboard holds', () async {
      await pinned(() async {
        await walk(1, 28, 9000);
        await walk(29, 90, 7000);
        await StepService.reloadFromDb();
        expect(StepService.getDataForDate(ago(60)), isNull,
            reason: 'the in-memory window is short of that');
        expect((await WalkingTrendService.load())!.baselineDays, 90);
      });
    });

    test('today is not counted: it is not over', () async {
      await pinned(() async {
        await walk(1, 90, 8000);
        final before = (await WalkingTrendService.load())!;
        await StepService.addManualStepsForDate(ago(0), 300, maxDaysBack: 200);
        final after = (await WalkingTrendService.load())!;
        expect(after.recentAvg, before.recentAvg);
        expect(after.recentDays, 28);
        expect(after.baselineDays, 90);
      });
    });

    test('a day marked rest or unwell is left out', () async {
      await pinned(() async {
        await walk(1, 90, 9000);
        // Three days of next to nothing, two of them marked.
        for (final i in [3, 4, 5]) {
          await StepService.addManualStepsForDate(ago(i), -8500, maxDaysBack: 200);
        }
        await RestDayStore.markToday(RestKind.unwell, now: ago(3));
        await RestDayStore.markToday(RestKind.rest, now: ago(4));
        final t = (await WalkingTrendService.load())!;
        expect(t.recentDays, 26, reason: 'two marked days are not walking days');
        // The unmarked low day (ago 5, 500 steps) still counts.
        expect(t.recentAvg, lessThan(9000));
        expect(t.recentAvg, greaterThan(8600));
      });
    });

    test('and every day is counted again once the marks are gone', () async {
      await pinned(() async {
        await walk(1, 90, 9000);
        await RestDayStore.markToday(RestKind.rest, now: ago(2));
        expect((await WalkingTrendService.load())!.recentDays, 27);
        await RestDayStore.clear(ago(2));
        expect((await WalkingTrendService.load())!.recentDays, 28);
      });
    });

    test('a sensor day counts as the sensor said, a typed day as typed', () async {
      await pinned(() async {
        await walk(1, 28, 9000);
        await walk(29, 39, 7000);
        // Older than the dashboard holds, written straight to the database.
        Future<void> row(int daysAgo, {int? sensor, int manual = 0}) =>
            database.stepsDao.saveDay(StepDailyData(
              id: '2026-${ago(daysAgo).month.toString().padLeft(2, '0')}-'
                  '${ago(daysAgo).day.toString().padLeft(2, '0')}',
              date: ago(daysAgo),
              sensorSteps: sensor,
              manualSteps: manual,
            ).toCompanion());
        // A watch day with a stray typed entry: the watch is the total.
        for (var i = 40; i <= 60; i++) {
          await row(i, sensor: 7000, manual: 5000);
        }
        // A day with no watch: what was typed.
        for (var i = 61; i <= 90; i++) {
          await row(i, manual: 7000);
        }
        await StepService.reloadFromDb();
        final t = (await WalkingTrendService.load())!;
        expect(t.baselineDays, 90);
        expect(t.baselineAvg, 7622, reason: '28 at 9,000 and 62 at 7,000');
      });
    });

    test('a day only the screen holds still counts', () async {
      await pinned(() async {
        await walk(1, 28, 9000);
        await walk(29, 89, 7000);
        // Day 90 is a watch day held in memory and not (yet) in the database.
        StepService.storeHealthDayForTesting(ago(90), 7000, isToday: false);
        expect((await WalkingTrendService.load())!.baselineDays, 90);
      });
    });

    test('a short record says nothing', () async {
      await pinned(() async {
        await walk(1, 30, 8000);
        expect(await WalkingTrendService.load(), isNull);
      });
    });

    test('a day of no steps is not a day of zero', () async {
      await pinned(() async {
        await walk(1, 90, 8000);
        await StepService.addManualStepsForDate(ago(6), -8000, maxDaysBack: 200);
        final t = (await WalkingTrendService.load())!;
        expect(t.recentDays, 27);
        expect(t.recentAvg, 8000);
      });
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester,
        {double width = 430,
        double scale = 1,
        Future<WalkingTrend?> Function()? load}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 2400);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: load == null
                      ? const WalkingTrendCard()
                      : WalkingTrendCard(load: load)))));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('nothing without a record to read', (tester) async {
      await pinned(() async {
        await walk(1, 20, 8000);
        await pump(tester);
        expect(find.text('WALKING TREND'), findsNothing);
      });
    });

    testWidgets('up: the figures, and nothing to ask for', (tester) async {
      await pinned(() async {
        await walk(1, 28, 9000);
        await walk(29, 90, 7000);
        await pump(tester);
        expect(find.text('WALKING TREND'), findsOneWidget);
        expect(find.byIcon(Symbols.trending_up_rounded), findsOneWidget);
        expect(find.text('Up 18% on your 90-day average'), findsOneWidget);
        expect(find.text('9,000 a day over the last 4 weeks, against 7,622 over 90 days.'),
            findsOneWidget);
        expect(find.textContaining('would turn this up'), findsNothing);
        expect(find.text('Whole days only. Rest and unwell days are left out.'),
            findsOneWidget);
      });
    });

    testWidgets('steady: what would turn it', (tester) async {
      await pinned(() async {
        await walk(1, 90, 8000);
        await pump(tester);
        expect(find.byIcon(Symbols.trending_flat_rounded), findsOneWidget);
        expect(find.text('Steady against your 90-day average'), findsOneWidget);
        expect(
            find.text('Walking about 800 more steps a day than lately, for 3 weeks, '
                'would turn this up.'),
            findsOneWidget);
      });
    });

    testWidgets('down, and within reach', (tester) async {
      await pinned(() async {
        await walk(1, 28, 7000);
        await walk(29, 90, 8000);
        await pump(tester);
        expect(find.byIcon(Symbols.trending_down_rounded), findsOneWidget);
        expect(find.text('Down 9% on your 90-day average'), findsOneWidget);
        expect(find.textContaining('about 1,700 more steps a day'), findsOneWidget);
      });
    });

    testWidgets('down, and further than 3,000 a day: it does not ask', (tester) async {
      await pinned(() async {
        await walk(1, 28, 5000);
        await walk(29, 90, 8000);
        await pump(tester);
        expect(find.text('Down 29% on your 90-day average'), findsOneWidget);
        expect(find.textContaining('would turn this up'), findsNothing);
      });
    });

    testWidgets('when holding the pace is enough, it says so', (tester) async {
      await pinned(() async {
        await walk(1, 7, 10000);
        await walk(8, 28, 8000);
        await walk(29, 90, 8200);
        await pump(tester);
        expect(find.text('Steady against your 90-day average'), findsOneWidget);
        expect(find.text('Walking as you have lately for 3 weeks would turn this up.'),
            findsOneWidget);
      });
    });

    testWidgets('it follows a change to a day that is over', (tester) async {
      await pinned(() async {
        await walk(1, 90, 8000);
        await pump(tester);
        expect(find.text('Steady against your 90-day average'), findsOneWidget);

        // 20,000 more steps typed in for yesterday.
        await StepService.addManualStepsForDate(ago(1), 20000, maxDaysBack: 200);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Up 6% on your 90-day average'), findsOneWidget);
      });
    });

    testWidgets('including the oldest day the screen holds', (tester) async {
      await pinned(() async {
        var loads = 0;
        await walk(1, 90, 8000);
        await pump(tester, load: () {
          loads++;
          return Future.value(null);
        });
        await StepService.addManualStepsForDate(ago(35), 100, maxDaysBack: 200);
        await tester.pump(const Duration(milliseconds: 100));
        expect(loads, 2);
      });
    });

    testWidgets('but not to a step on a day that is not over', (tester) async {
      await pinned(() async {
        var loads = 0;
        Future<WalkingTrend?> counted() {
          loads++;
          return WalkingTrendService.load();
        }

        await walk(1, 90, 8000);
        await pump(tester, load: counted);
        expect(loads, 1);

        for (var i = 0; i < 5; i++) {
          await StepService.addManualStepsForDate(ago(0), 100, maxDaysBack: 200);
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(loads, 1, reason: 'the sensor counts all day; the trend need not');

        // A day that is over changes: one more read, and then it is settled.
        await StepService.addManualStepsForDate(ago(2), 100, maxDaysBack: 200);
        await tester.pump(const Duration(milliseconds: 100));
        expect(loads, 2);
        await StepService.addManualStepsForDate(ago(0), 100, maxDaysBack: 200);
        await tester.pump(const Duration(milliseconds: 100));
        expect(loads, 2, reason: 'what was read is remembered');
      });
    });

    testWidgets('and the day rolling over is a change', (tester) async {
      var loads = 0;
      Future<WalkingTrend?> counted() {
        loads++;
        return Future.value(null);
      }

      await withClock(Clock.fixed(now), () async {
        // Today too, so that the window holds as many days before as after, at
        // the same steps: only the dates have moved.
        await walk(0, 90, 8000);
        await pump(tester, load: counted);
        expect(loads, 1);
      });
      // A new day: the window moves along by one, with nothing else changed.
      await withClock(Clock.fixed(now.add(const Duration(days: 1))), () async {
        await StepService.addManualStepsForDate(
            now.add(const Duration(days: 1)), 100, maxDaysBack: 200);
        await tester.pump(const Duration(milliseconds: 100));
        expect(loads, 2);
      });
    });

    testWidgets('of two reads, the later one is shown, whichever answers last',
        (tester) async {
      await pinned(() async {
        await walk(1, 90, 8000);
        final first = Completer<WalkingTrend?>();
        final second = Completer<WalkingTrend?>();
        final replies = [first, second];
        var asked = 0;
        await pump(tester, load: () => replies[asked++].future);
        expect(asked, 1);

        // A day that is over changes: a second read is asked for.
        await StepService.addManualStepsForDate(ago(1), 500, maxDaysBack: 200);
        await tester.pump();
        expect(asked, 2);

        WalkingTrend trend(WalkingDirection d, int recent) => WalkingTrend(
            recentAvg: recent,
            baselineAvg: 8000,
            direction: d,
            recentDays: 28,
            baselineDays: 90);
        second.complete(trend(WalkingDirection.up, 9000));
        await tester.pump();
        first.complete(trend(WalkingDirection.down, 6000));
        await tester.pump();

        expect(find.textContaining('Up '), findsOneWidget);
        expect(find.textContaining('Down '), findsNothing);
      });
    });

    testWidgets('a read that lands after the screen has gone does nothing',
        (tester) async {
      await pinned(() async {
        await walk(1, 90, 8000);
        final reply = Completer<WalkingTrend?>();
        await pump(tester, load: () => reply.future);
        await tester.pumpWidget(const SizedBox());
        reply.complete(const WalkingTrend(
            recentAvg: 9000,
            baselineAvg: 8000,
            direction: WalkingDirection.up,
            recentDays: 28,
            baselineDays: 90));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('and once it has gone, a change reads nothing', (tester) async {
      await pinned(() async {
        var loads = 0;
        await walk(1, 90, 8000);
        await pump(tester, load: () {
          loads++;
          return Future.value(null);
        });
        await tester.pumpWidget(const SizedBox());
        await StepService.addManualStepsForDate(ago(1), 500, maxDaysBack: 200);
        await tester.pump();
        expect(loads, 1);
      });
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('fits at 320pt and ${scale}x text', (tester) async {
        await pinned(() async {
          await walk(1, 28, 7000);
          await walk(29, 90, 8000);
          final reports = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) => reports.add(d.toString());
          try {
            await pump(tester, width: 320, scale: scale);
          } finally {
            FlutterError.onError = prev;
          }
          expect(find.text('WALKING TREND'), findsOneWidget);
          expect(reports.where((r) => r.contains('walking_trend_card.dart')), isEmpty);
        });
      });
    }
  });

  testWidgets('Steps has it, between this week and the hours', (tester) async {
    await pinned(() async {
      await walk(1, 28, 9000);
      await walk(29, 90, 7000);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 3600);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow is the responsive suite's job
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const StepsDashboardScreen()));
        for (var f = 0; f < 12; f++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.text('Up 18% on your 90-day average'), findsOneWidget);
      final week = tester.getTopLeft(find.byType(StepWeeklyChart)).dy;
      final card = tester.getTopLeft(find.byType(WalkingTrendCard)).dy;
      final hours = tester.getTopLeft(find.byType(StepHourlyChart)).dy;
      expect(week, lessThan(card));
      expect(card, lessThan(hours));
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
