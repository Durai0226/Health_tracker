import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/health/week_over_week.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/utils/step_format.dart';

/// "2,300 steps ahead of this time last week" — on the Steps screen, only when
/// last week's day has an hourly record that accounts for most of its steps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;

  // A Thursday afternoon.
  final now = DateTime(2026, 3, 12, 14, 0);
  final lastWeek = DateTime(2026, 3, 5);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

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

  test('the sentence', () {
    expect(weekOverWeekLine(const WeekOverWeek(2300, 2500)),
        '2,300 steps ahead of this time last week');
    expect(weekOverWeekLine(const WeekOverWeek(-1000, 2500)),
        '1,000 steps behind this time last week');
  });

  /// 500 steps in each hour 7..16.
  List<int> hourly() =>
      [for (var h = 0; h < 24; h++) (h >= 7 && h <= 16) ? 500 : 0];

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow is the responsive suite's job
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const StepsDashboardScreen()));
      for (var f = 0; f < 8; f++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('ahead of the same hour last week', (tester) async {
    await withClock(Clock.fixed(now), () async {
      // By 14:00 last week: hours 7..13 = 3,500. Today: 5,800.
      StepService.storeHealthDayForTesting(lastWeek, 5000,
          isToday: false, hourly: hourly());
      StepService.storeHealthDayForTesting(now, 5800, isToday: true);
      await open(tester);
      expect(find.text('2,300 steps ahead of this time last week'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('behind', (tester) async {
    await withClock(Clock.fixed(now), () async {
      StepService.storeHealthDayForTesting(lastWeek, 5000,
          isToday: false, hourly: hourly());
      StepService.storeHealthDayForTesting(now, 2500, isToday: true);
      await open(tester);
      expect(find.text('1,000 steps behind this time last week'),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('no hourly record last week: no claim', (tester) async {
    await withClock(Clock.fixed(now), () async {
      StepService.storeHealthDayForTesting(lastWeek, 5000, isToday: false);
      StepService.storeHealthDayForTesting(now, 5800, isToday: true);
      await open(tester);
      expect(find.textContaining('this time last week'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('a partial record last week (synced in the morning): no claim',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      final partial = [for (var h = 0; h < 24; h++) (h >= 7 && h <= 9) ? 500 : 0];
      StepService.storeHealthDayForTesting(lastWeek, 5000,
          isToday: false, hourly: partial);
      StepService.storeHealthDayForTesting(now, 5800, isToday: true);
      await open(tester);
      expect(find.textContaining('this time last week'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('not on a rest day: the goal is paused, so the comparison is '
      'beside the point', (tester) async {
    await withClock(Clock.fixed(now), () async {
      StepService.storeHealthDayForTesting(lastWeek, 5000,
          isToday: false, hourly: hourly());
      StepService.storeHealthDayForTesting(now, 5800, isToday: true);
      await RestDayStore.markToday(RestKind.unwell);
      await open(tester);
      expect(find.textContaining('this time last week'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
