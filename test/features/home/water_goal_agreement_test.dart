/// The Today dashboard has TWO opinions about hydration in one widget: the
/// Water ring's "%" caption, and whether the day's water pillar counts towards
/// "n OF 4". They must never disagree.
///
/// They could not, until the weather adjustment was wired up. `goalReached` is
/// stamped on the day ROW against that row's own `dailyGoalMl`, which
/// `refreshWeatherGoal` re-stamps from the feels-like temperature; the caption
/// was divided by `getDailyGoal()`, which recomputes from the PROFILE and only
/// ever sees the climate dropdown's band midpoint. On a hot afternoon the ring
/// read 100% beside a pillar that was still open; on a cool morning the pillar
/// closed while the ring still read 99%.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/utils/percent_format.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart' show KpiCell;
import 'package:tablet_remainder/core/widgets/app/progress_ring.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => db.close());

  /// Today's real DATE at midday. The date is kept because every service the
  /// dashboard reads resolves "today" through its own calendar reads; the time
  /// is pinned so the run is hour-independent.
  final pinnedNow = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 12, 0);
  }();

  void pinnedTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description,
        (tester) => withClock(Clock.fixed(pinnedNow), () => body(tester)));
  }

  final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');

  /// A plain profile on the default `moderate` climate band, so its goal is
  /// computed at that band's 18 °C midpoint and nothing else.
  final profile = HydrationProfile(
    id: 'profile',
    weightKg: 70,
    age: 35,
    createdAt: pinnedNow.subtract(const Duration(days: 30)),
  );

  /// A fresh reading in the cache, so `HydrationWeatherService.current()`
  /// answers from disk and never touches the network.
  Future<void> seedWeather(double apparentC) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hydration_weather_enabled', true);
    await prefs.setString('hydration_weather_place', 'Chennai, India');
    await prefs.setDouble('hydration_weather_lat', 13.0827);
    await prefs.setDouble('hydration_weather_lon', 80.2707);
    await prefs.setDouble('hydration_weather_temp_c', apparentC);
    await prefs.setInt('hydration_weather_at', clock.now().millisecondsSinceEpoch);
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Drop the previous tree first: these tests pump the same screen twice, and
    // the pulse row's rings only sweep in on their first paint.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The Water cell of the 4-up pulse row: the "%" caption and its ring fill.
  KpiCell waterCell(WidgetTester tester) => tester.widget<KpiCell>(
      find.byWidgetPredicate((w) => w is KpiCell && w.label == 'Water'));

  /// The at-a-glance hero's "n OF 4" numerator, read off the ring it fills.
  /// This is the only place `waterDone` is visible, and it is a FIXED 104px
  /// circle, which is what makes it findable.
  int heroDone(WidgetTester tester) {
    final ring = tester.widget<ProgressRing>(
        find.byWidgetPredicate((w) => w is ProgressRing && w.size == 104));
    return (ring.progress * 4).round();
  }

  /// Drives the shared scenario: stamp today from [profile], take a baseline
  /// reading with nothing drunk, let [apparentC] move the stored goal, drink
  /// [intakeMl], and hand back what the screen then says.
  Future<({KpiCell cell, int done, int baselineDone, int storedGoal})> run(
    WidgetTester tester, {
    required double apparentC,
    required int intakeMl,
  }) async {
    await WaterService.saveProfile(profile);
    await seedWeather(apparentC);
    await WaterService.refreshWeatherGoal();

    // Baseline: the same day with nothing drunk, so the water pillar is known
    // to be open and every other pillar's contribution is held constant.
    await pumpHome(tester);
    final baselineDone = heroDone(tester);

    await WaterService.addWaterLog(amountMl: intakeMl, beverage: water);
    await pumpHome(tester);

    final today = WaterService.getTodayData();
    expect(today.effectiveHydrationMl, intakeMl,
        reason: 'plain water hydrates at 100%, so the seed must land whole');
    return (
      cell: waterCell(tester),
      done: heroDone(tester),
      baselineDone: baselineDone,
      storedGoal: today.dailyGoalMl,
    );
  }

  pinnedTest('a hot day cannot caption the Water ring 100% with the pillar open',
      (tester) async {
    // 32 °C pushes the stored goal well above the profile's 18 °C figure, so
    // an intake that clears the profile number is nowhere near the real one.
    final profileGoal = profile.effectiveGoalMl;
    final hotGoal = profile.goalBreakdown(ambientC: 32).totalMl;
    expect(hotGoal, greaterThan(profileGoal),
        reason: 'the scenario only exists if the weather moved the goal up');
    final intake = profileGoal + 50; // over the profile, under the real goal
    expect(intake, lessThan(hotGoal));

    final r = await run(tester, apparentC: 32, intakeMl: intake);

    expect(r.storedGoal, hotGoal,
        reason: 'the weather refresh is what this test is about');
    expect(WaterService.getTodayData().goalReached, isFalse);
    expect(r.done, r.baselineDone,
        reason: 'the day is not hydrated, so the pillar must stay open');

    // The invariant. Pre-fix the caption divided by the profile's 3.1 L and
    // read 100% while the pillar above it stayed open.
    expect(r.cell.value == '100%', r.done == r.baselineDone + 1,
        reason: 'the Water ring said ${r.cell.value} while the hero counted '
            '${r.done} of 4 (nothing drunk: ${r.baselineDone})');
    expect(r.cell.value, '${Pct.of(intake / hotGoal)}%',
        reason: "the caption must divide by the goal the day is JUDGED by");
    expect(r.cell.progress, lessThan(1.0));
  });

  pinnedTest('a cool day that the app already recorded as met reads 100%',
      (tester) async {
    // The mirror image: below the band midpoint the sweat term shrinks, so the
    // stored goal drops BELOW the profile's and an intake the app has already
    // banked as "goal reached" was still being captioned 99%.
    final profileGoal = profile.effectiveGoalMl;
    final coolGoal = profile.goalBreakdown(ambientC: 0).totalMl;
    expect(coolGoal, lessThan(profileGoal),
        reason: 'the scenario only exists if the weather moved the goal down');
    final intake = coolGoal + 10; // over the real goal, under the profile's
    expect(intake, lessThan(profileGoal));

    final r = await run(tester, apparentC: 0, intakeMl: intake);

    expect(r.storedGoal, coolGoal);
    expect(WaterService.getTodayData().goalReached, isTrue,
        reason: 'this is a day the app has ALREADY banked as met');
    expect(r.done, r.baselineDone + 1,
        reason: 'the pillar closed — the streak and the badge already did');

    expect(r.cell.value == '100%', r.done == r.baselineDone + 1,
        reason: 'the Water ring said ${r.cell.value} while the hero counted '
            '${r.done} of 4 (nothing drunk: ${r.baselineDone})');
    expect(r.cell.value, '100%');
    expect(r.cell.progress, 1.0);
  });
}
