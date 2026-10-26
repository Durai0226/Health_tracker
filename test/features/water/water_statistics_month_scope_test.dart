import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/screens/water_statistics_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// W12 — the Statistics screen stacked six cards under a month selector and
/// only two of them honoured it.
///
/// The hourly chart read `WaterService.getTodayData()`, so paging back to March
/// drew September's drinks under a header saying "March". It is scoped to the
/// selected month now; the remaining live cards ("This Week", the current
/// streak, the hour-of-day insights) are about the present by definition and
/// are separated from the month section rather than faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  /// Pinned. The screen opens on the current month and the seeded days are
  /// placed relative to the same instant.
  final now = DateTime(2026, 9, 26, 14, 0);
  final pastMonthDay = DateTime(2026, 3, 15);

  setUpAll(() {
    // Same reason as the responsive harness: asynchronous font resolution makes
    // a laid-out chart depend on whether it happened to finish between pumps.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  String keyFor(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// One stored day with a single drink at [hour].
  Future<void> seedDay(DateTime date,
      {required String logId, required int hour, int amountMl = 500}) async {
    final key = keyFor(date);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(key),
      date: Value(date),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: Value(amountMl),
      effectiveHydrationMl: Value(amountMl),
      totalCaffeineMg: const Value(0),
      alcoholicDrinksCount: const Value(0),
      goalReached: const Value(false),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: Value(logId),
      dailyDataId: Value(key),
      time: Value(DateTime(date.year, date.month, date.day, hour)),
      amountMl: Value(amountMl),
      effectiveHydrationMl: Value(amountMl),
      beverageId: const Value('water'),
      beverageName: const Value('Water'),
      beverageEmoji: const Value('💧'),
      hydrationPercent: const Value(100),
      caffeineAmount: const Value(0),
      isAlcoholic: const Value(false),
    ));
  }

  /// The rendered height of one hour's bar. Zero when nothing was drunk in that
  /// hour across whatever days the chart is drawn from.
  double barHeight(WidgetTester tester, int hour) =>
      tester.getSize(find.byKey(ValueKey('waterHourBar$hour'))).height;

  Future<void> openScreen(WidgetTester tester) async {
    // The chart's bar heights are proportional to a Row of 24 columns, so the
    // view has to be wide enough for the row to lay out at all — a MediaQuery
    // size alone does not set the layout size.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WaterStatisticsScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('paging back a month redraws the hourly chart from that month',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      // Today: one drink at 09:00. March: one drink at 20:00.
      await seedDay(now, logId: 'today-log', hour: 9);
      await seedDay(pastMonthDay, logId: 'march-log', hour: 20);
      await WaterService.init();

      await openScreen(tester);

      expect(barHeight(tester, 9), greaterThan(0),
          reason: 'September is the selected month on open, and its only '
              'drink was at 09:00');
      expect(barHeight(tester, 20), 0);

      // Six taps back: September -> March.
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(find.text('March 2026'), findsOneWidget,
          reason: 'the selector must actually be on March for the rest of '
              'this to mean anything');
      expect(barHeight(tester, 20), greaterThan(0),
          reason: "March's drink was at 20:00 and this card is under a header "
              'saying March');
      expect(barHeight(tester, 9), 0,
          reason: "today's 09:00 drink is not part of March and must not be "
              'drawn as though it were');
    });
  });

  testWidgets('the cards the month selector does not govern are separated',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedDay(now, logId: 'today-log', hour: 9);
      await seedDay(pastMonthDay, logId: 'march-log', hour: 20);
      await WaterService.init();

      await openScreen(tester);
      expect(find.text('Right now'), findsOneWidget,
          reason: 'on the current month there is nothing to disambiguate');

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(find.text('Right now, not March 2026'), findsOneWidget,
          reason: '"This Week", the streak and the insights below this header '
              'are live numbers — under a March header, with no label, they '
              'read as March\'s');
      // The live cards are still there; they are labelled, not hidden.
      expect(find.text('This Week'), findsOneWidget);
    });
  });

  testWidgets('bars stand on one baseline and hour labels on another',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      // Three drinks in the selected month, at three hours, in three sizes, so
      // the bars come out at three different heights. A baseline bug is only
      // visible when the bars disagree about how tall they are.
      await seedDay(DateTime(2026, 9, 10),
          logId: 'tall', hour: 8, amountMl: 900);
      await seedDay(DateTime(2026, 9, 11),
          logId: 'mid', hour: 12, amountMl: 500);
      await seedDay(DateTime(2026, 9, 12),
          logId: 'short', hour: 20, amountMl: 200);
      await WaterService.init();

      await openScreen(tester);

      // The premise: the heights really do differ. Without this the alignment
      // assertions below would pass on a chart of 24 identical bars.
      expect({barHeight(tester, 8), barHeight(tester, 12), barHeight(tester, 20)}
          .length, 3,
          reason: 'the three seeded hours must produce three distinct bar '
              'heights for this test to be able to fail');

      final barBottoms = <double>{
        for (var hour = 0; hour < 24; hour++)
          tester.getRect(find.byKey(ValueKey('waterHourBar$hour'))).bottom,
      };
      expect(barBottoms.length, 1,
          reason: 'a histogram encodes its value as height, which is only '
              'readable if every bar starts from the same line. These '
              'bottoms: $barBottoms');

      final labelBottoms = <double>{
        for (final hour in const [0, 4, 8, 12, 16, 20])
          tester.getRect(find.byKey(ValueKey('waterHourLabel$hour'))).bottom,
      };
      expect(labelBottoms.length, 1,
          reason: 'the hour axis is one row of labels and must sit on one '
              'baseline. These bottoms: $labelBottoms');

      // ...and the axis belongs under the bars, not through them.
      expect(labelBottoms.single,
          greaterThan(barBottoms.single),
          reason: 'the hour labels label the axis, so they sit below it');
    });
  });
}
