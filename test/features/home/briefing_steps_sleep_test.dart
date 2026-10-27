/// The briefing strip on Today reads steps and last night's sleep from the live
/// services. `coach_text_briefing_signals_test.dart` pins the sentences; this
/// pins that the screen hands them the real numbers, and the rest-day flag.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/rest_days.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/rest_day_store.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  DateTime at(int hour) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, hour);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await StepService.resetForTesting();
    await SleepService.resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
  });

  tearDown(() async => database.close());

  void pinned(String description, int hour,
      Future<void> Function(WidgetTester) body) {
    testWidgets(description,
        (tester) => withClock(Clock.fixed(at(hour)), () => body(tester)));
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 3200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  /// Water already at goal today, so the water lines do not come first.
  Future<void> waterDone() async {
    final today = at(0);
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: Value(WaterService.dateKeyFor(today)),
      date: Value(today),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(3000),
      effectiveHydrationMl: const Value(3000),
    ));
    await WaterService.init();
  }

  pinned('a short night is named in the morning, with the real hours', 9,
      (tester) async {
    // 02:00 to 07:00 in bed, an estimated 88% of it asleep: 4h 24m.
    final now = clock.now();
    await SleepService.logManualSession(
      bedtime: DateTime(now.year, now.month, now.day, 2),
      wakeTime: DateTime(now.year, now.month, now.day, 7),
    );
    await pumpHome(tester);

    expect(find.textContaining('A short night — 4h 24m'), findsOneWidget);
  });

  pinned('a full night says nothing about sleep', 9, (tester) async {
    final now = clock.now();
    await SleepService.logManualSession(
      bedtime: DateTime(now.year, now.month, now.day - 1, 23),
      wakeTime: DateTime(now.year, now.month, now.day, 7),
    );
    await pumpHome(tester);

    expect(find.textContaining('short night'), findsNothing);
  });

  pinned('steps short of the goal in the early evening are counted down', 18,
      (tester) async {
    await waterDone();
    StepService.storeHealthDayForTesting(clock.now(), 6200, isToday: true);
    await pumpHome(tester);

    expect(find.textContaining('1,800 steps to go — about 18 minutes'),
        findsOneWidget);
  });

  pinned('on a rest day the strip does not chase the step goal', 18,
      (tester) async {
    await waterDone();
    StepService.storeHealthDayForTesting(clock.now(), 6200, isToday: true);
    await RestDayStore.markToday(RestKind.rest, now: clock.now());
    await pumpHome(tester);

    expect(find.textContaining('steps to go'), findsNothing);
  });

  pinned('no steps read today is not a shortfall', 18, (tester) async {
    await waterDone();
    await pumpHome(tester);

    expect(find.textContaining('steps to go'), findsNothing);
  });
}
