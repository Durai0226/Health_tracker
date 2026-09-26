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

/// Widening the CSV exports to the whole stored history (W11) turned them from
/// a synchronous read of an in-memory map into disk I/O — and the export
/// sheet's `onTap` awaited that OUTSIDE the try/catch that reports a failure.
///
/// So the one new way for an export to fail was the one way that said nothing:
/// the sheet closed, no file was produced, no share sheet appeared, and an
/// unhandled exception in an async callback is invisible in release.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  var closed = false;
  final now = DateTime(2026, 9, 26, 14, 0);

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    closed = false;
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async {
    if (!closed) await database.close();
  });

  Future<void> seedToday() async {
    const key = '2026-09-26';
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: const Value(key),
      date: Value(now),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(500),
      effectiveHydrationMl: const Value(500),
      totalCaffeineMg: const Value(0),
      alcoholicDrinksCount: const Value(0),
      goalReached: const Value(false),
    ));
  }

  Future<void> openExportSheet(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WaterStatisticsScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byTooltip('Export data'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Summary CSV'), findsOneWidget);
  }

  testWidgets('an export that cannot be built says so', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedToday();
      await WaterService.init();
      await openExportSheet(tester);

      // The one failure the widened export actually has: the read itself.
      await database.close();
      closed = true;

      await tester.tap(find.text('Summary CSV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Could not export'), findsOneWidget,
          reason: 'the sheet has already closed by the time the read runs — '
              'without a message the tap simply does nothing');
    });
  });

  testWidgets('the detailed export reports its failure too', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seedToday();
      await WaterService.init();
      await openExportSheet(tester);

      await database.close();
      closed = true;

      await tester.tap(find.text('Detailed CSV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Could not export'), findsOneWidget);
    });
  });
}
