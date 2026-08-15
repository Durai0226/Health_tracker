@Tags(['performance'])
library;

/// Measures the ACTUAL build cost of every screen: first-frame build time,
/// widget count, element count, and how many extra frames the screen needs
/// before it stops rebuilding.
///
/// What this can and cannot tell you:
///   CAN  — relative build cost between screens, widget-tree size, whether a
///          screen settles or keeps rebuilding, and how long its first frame
///          takes on this machine's Dart VM.
///   CANNOT — real GPU raster time, on-device frame pacing, jank under scroll,
///          startup time on real hardware, or memory. Those need DevTools
///          against a physical device and are reported separately.
///
/// Timings are wall-clock on the host, so treat them as RELATIVE signal
/// (screen A vs screen B), not as absolute device frame budget.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/dev/qa_seed.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';

import '../support/perf_rating.dart';

import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/refill_overview_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/water_statistics_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_calendar_screen.dart';
import 'package:tablet_remainder/features/water/screens/caffeine_insights_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/period/screens/period_calendar_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';
import 'package:tablet_remainder/features/insights/screens/weekly_recap_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';
import 'package:tablet_remainder/features/home/screens/health_browse_screen.dart';

class _Cost {
  final String feature;
  final String screen;
  int firstFrameMicros = 0;
  int settleMicros = 0;
  int spreadMicros = 0;
  int widgets = 0;
  int elements = 0;
  int framesToSettle = 0;
  bool neverSettles = false;
  String? error;
  _Cost(this.feature, this.screen);
}

final _screens = <List<dynamic>>[
  ['Home', 'home', () => HomeDashboard(onNavigate: (int i, {int? healthTab}) {})],
  ['Home', 'health_browse', () => const HealthBrowseScreen()],
  ['Medication', 'dashboard', () => const NunitoMedicationDashboard()],
  ['Medication', 'list', () => const NunitoMedicationListScreen()],
  ['Medication', 'adherence_report', () => const NunitoAdherenceReportScreen()],
  ['Medication', 'refill', () => const RefillOverviewScreen()],
  ['Vitals', 'blood_pressure', () => const BloodPressureScreen()],
  ['Vitals', 'blood_sugar', () => const BloodSugarScreen()],
  ['Vitals', 'weight', () => const WeightScreen()],
  ['Vitals', 'mood', () => const MoodScreen()],
  ['Water', 'dashboard', () => const AquaWaterDashboard()],
  ['Water', 'statistics', () => const WaterStatisticsScreen()],
  ['Water', 'calendar', () => const WaterCalendarScreen()],
  ['Water', 'caffeine', () => const CaffeineInsightsScreen()],
  ['Sleep', 'dashboard', () => const SleepDashboardScreen()],
  ['Steps', 'dashboard', () => const StepsDashboardScreen()],
  ['Period', 'dashboard', () => const PeriodDashboard()],
  ['Period', 'calendar', () => const PeriodCalendarScreen()],
  ['Focus', 'timer', () => const FocusScreen()],
  ['Focus', 'stats', () => const DetailedStatsScreen()],
  ['Insights', 'trends', () => const TrendsDashboardScreen()],
  ['Insights', 'weekly_recap', () => const WeeklyRecapScreen()],
  ['Reminders', 'list', () => const RemindersScreen()],
  ['Diary', 'list', () => const DiaryScreen()],
  ['Settings', 'root', () => const SettingsScreen()],
];


/// Element budget per screen, measured at the fixed 390x844 / dpr 1.0 viewport
/// with fonts pinned, AGAINST SEEDED DATA, plus ~15% headroom.
///
/// Seeded matters: on an empty database every screen renders its empty state,
/// so it measures both faster and smaller than the shipped app. These numbers
/// are 15-110% higher than the empty-database ones they replaced.
///
/// Element counts are exactly reproducible on any machine given a fixed
/// viewport and pinned fonts, which is why the budget is on counts and NOT on
/// microseconds — the harness itself observed an ~8x wall-clock swing between
/// two runs of an identical screen. A threshold that passes here and fails in
/// CI is worthless.
///
/// Numbers below are MEASURED, not guessed. Re-baseline deliberately in a
/// commit of its own when a screen legitimately grows.
///
/// **Re-baselined for the seeder gaining reminders and focus sessions.**
/// `qa_seed.dart` previously planted neither, so three screens were budgeted
/// against their EMPTY state while every other feature had a month of history:
///
///   Reminders/list   392 -> 1354   (measured 1177; the list had zero rows)
///   Focus/stats      924 -> 1148   (measured  998; no sessions to chart)
///   Insights/trends  824 ->  988   (measured  859; two more series with data)
///
/// Reminders is the big one and the number is honest: four seeded reminders at
/// ~196 elements per row is a Dismissible + card + category chip + relative
/// time + priority marker each. Budgeting a list at its zero-row size is the
/// same defect this file's header warns about, one level up.
const Map<String, int> _elementBudget = {
  'Water/calendar': 2081,
  'Water/dashboard': 2018,
  'Focus/timer': 1540,
  'Medication/dashboard': 1385,
  'Period/calendar': 1347,
  'Home/home': 1263,
  'Home/health_browse': 1116,
  'Vitals/weight': 1116,
  'Water/statistics': 1090,
  'Vitals/mood': 1074,
  'Medication/adherence_report': 975,
  'Settings/root': 959,
  'Vitals/blood_sugar': 940,
  'Focus/stats': 1148,
  'Insights/weekly_recap': 856,
  'Vitals/blood_pressure': 854,
  'Insights/trends': 988,
  'Period/dashboard': 819,
  'Medication/list': 780,
  'Water/caffeine': 731,
  'Diary/list': 714,
  'Medication/refill': 687,
  'Steps/dashboard': 394,
  'Reminders/list': 1354,
  'Sleep/dashboard': 365,
};

/// Screens allowed to animate forever. Empty on purpose: a perpetual animation
/// costs battery whether or not anyone is looking at it.
const Set<String> _neverSettlesAllowlist = {};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final costs = <_Cost>[];

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The first screen measured was absorbing one-time VM/theme/DB warmup and
  // reported ~15x the median, which is an instrument artifact, not a slow
  // screen. Burn that cost on a throwaway render first.
  testWidgets('warmup (not measured)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
      ));
      await tester.pump(const Duration(milliseconds: 16));
    } catch (_) {} finally {
      FlutterError.onError = prev;
    }
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    // Measure against REAL data. On an empty database every screen renders its
    // empty state, so it looks both fast and small — element budgets and read
    // counts taken that way are understatements of the shipped app.
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await seedQaData(force: true);
  });

  tearDown(() async => db.close());

  for (final entry in _screens) {
    final feature = entry[0] as String;
    final name = entry[1] as String;
    final builder = entry[2] as Widget Function();

    testWidgets('$feature/$name build cost', (tester) async {
      final c = _Cost(feature, name);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow/exception noise covered elsewhere
      try {
        // Wall-clock on a shared host swings wildly (~8x observed between two
        // runs of the identical screen), so a single sample is meaningless.
        // Build the screen repeatedly and keep the MEDIAN.
        const samples = 7;
        final runs = <int>[];
        for (var s = 0; s < samples; s++) {
          final sw0 = Stopwatch()..start();
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: builder(),
          ));
          runs.add(sw0.elapsedMicroseconds);
          // Force a genuinely fresh subtree next iteration, otherwise Flutter
          // reuses elements and every sample after the first measures nothing.
          await tester.pumpWidget(const SizedBox.shrink());
        }
        runs.sort();
        c.firstFrameMicros = runs[runs.length ~/ 2];
        c.spreadMicros = runs.last - runs.first;

        final sw = Stopwatch()..start();
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: builder(),
        ));

        // How many frames until the tree stops changing? A screen that never
        // settles is running a perpetual animation, which costs battery.
        var lastCount = tester.allWidgets.length;
        var stable = 0;
        for (var i = 0; i < 40 && stable < 3; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final n = tester.allWidgets.length;
          if (n == lastCount) {
            stable++;
          } else {
            stable = 0;
            lastCount = n;
          }
          c.framesToSettle = i + 1;
        }
        c.neverSettles = stable < 3;
        c.settleMicros = sw.elapsedMicroseconds;
        c.widgets = tester.allWidgets.length;
        c.elements = tester.allElements.length;
      } catch (e) {
        c.error = e.toString().split('\n').first;
      } finally {
        FlutterError.onError = prev;
      }
      // Several screens guard init with `.timeout(...)` or run a periodic
      // tick, leaving a pending Timer that trips the teardown assertion
      // ("A Timer is still pending even after the widget tree was disposed").
      // Advance the fake clock AFTER all measurement so the numbers above are
      // unaffected — this costs no real wall time.
      await tester.pump(const Duration(seconds: 8));
      costs.add(c);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  tearDownAll(() {
    void p(String s) {
      // ignore: avoid_print
      print(s);
    }

    p('\n===== SCREEN BUILD COST (390x844, host VM, relative signal) =====');
    p('${'feature'.padRight(12)}${'screen'.padRight(18)}'
        '${'1st(ms)'.padLeft(8)}${'widgets'.padLeft(9)}${'elems'.padLeft(7)}'
        '${'frames'.padLeft(7)}${'spread'.padLeft(8)}  notes');
    final sorted = [...costs]
      ..sort((a, b) => b.firstFrameMicros.compareTo(a.firstFrameMicros));
    for (final c in sorted) {
      final notes = <String>[];
      if (c.error != null) notes.add('ERROR: ${c.error}');
      if (c.neverSettles) notes.add('NEVER SETTLES (perpetual animation)');
      if (c.widgets > 1200) notes.add('very large tree');
      p('${c.feature.padRight(12)}${c.screen.padRight(18)}'
          '${(c.firstFrameMicros / 1000).toStringAsFixed(1).padLeft(8)}'
          '${c.widgets.toString().padLeft(9)}'
          '${c.elements.toString().padLeft(7)}'
          '${c.framesToSettle.toString().padLeft(7)}'
          '${(c.spreadMicros / 1000).toStringAsFixed(0).padLeft(8)}'
          '  ${notes.join(' · ')}');
    }

    final ok = costs.where((c) => c.error == null).toList();
    final elementCounts = ok.map((c) => c.elements).toList()..sort();
    final medianElements =
        elementCounts.isEmpty ? 1 : elementCounts[elementCounts.length ~/ 2];
    if (ok.isNotEmpty) {
      final times = ok.map((c) => c.firstFrameMicros / 1000).toList()..sort();
      final median = times[times.length ~/ 2];
      p('\nmedian first frame: ${median.toStringAsFixed(1)}ms   '
          'slowest: ${times.last.toStringAsFixed(1)}ms   '
          'total widgets across all screens: ${ok.fold<int>(0, (a, c) => a + c.widgets)}');
      final never = ok.where((c) => c.neverSettles).map((c) => '${c.feature}/${c.screen}');
      p('never settles (${never.length}): ${never.join(', ')}');
    }
    p('=================================================================\n');

    // ---- rating -----------------------------------------------------------
    final findings = <Finding>[];
    for (final c in costs) {
      final name = '${c.feature}/${c.screen}';
      if (c.error != null) {
        findings.add(Finding(
          feature: c.feature, screen: c.screen, dimension: 'build-error',
          sev: Sev.p0, detail: c.error!, source: 'binary: it threw'));
        continue;
      }
      if (c.neverSettles) {
        findings.add(Finding(
          feature: c.feature, screen: c.screen, dimension: 'never-settles',
          sev: Sev.p1,
          detail: 'still rebuilding after ${c.framesToSettle} idle frames',
          source: 'binary: a perpetual animation costs battery unobserved'));
      }
      final budget = _elementBudget[name];
      if (budget != null && c.elements > budget) {
        findings.add(Finding(
          feature: c.feature, screen: c.screen, dimension: 'element-budget',
          sev: c.elements > budget * 1.5 ? Sev.p0 : Sev.p2,
          detail: '${c.elements} elements vs budget $budget',
          source: 'measured baseline + 15% (this repo)'));
      }
      // Relative to the run's own median, so it means the same on any machine.
      if (c.elements > medianElements * 3) {
        findings.add(Finding(
          feature: c.feature, screen: c.screen, dimension: 'tree-size',
          sev: c.elements > medianElements * 5 ? Sev.p0 : Sev.p1,
          detail: '${c.elements} elements vs run median $medianElements '
              '(${(c.elements / medianElements).toStringAsFixed(1)}x)',
          source: 'within-run ratio (machine-independent)'));
      }
    }
    for (final f in findings) {
      emitFinding(f);
    }
    p(renderRatingTable(findings, deviceMeasured: false));

    // THE GATE.
    //
    // Until now this file had no `expect()` at all — it measured, printed a
    // table, and always passed. That is the same defect that let a visibly
    // broken header ship past "564 combinations, NO OVERFLOWS": a report
    // generator wearing a test's clothes.
    //
    // Deliberately NOT gated on absolute microseconds. Those are debug-mode
    // wall clock on a shared host and swing ~8x run to run (see :150). The
    // three gates below are machine-independent: a count, a boolean, and a
    // ratio taken within this same run.
    expect(
      costs.where((c) => c.error != null).map((c) => '${c.feature}/${c.screen}: ${c.error}'),
      isEmpty,
      reason: 'A screen threw while building. Previously this was caught, '
          'printed, and passed.',
    );

    final perpetual = costs
        .where((c) => c.neverSettles && c.error == null)
        .map((c) => '${c.feature}/${c.screen}')
        .where((n) => !_neverSettlesAllowlist.contains(n))
        .toList();
    expect(perpetual, isEmpty,
        reason: 'These screens never stop rebuilding while idle, which burns '
            'battery whether or not the user is looking: $perpetual');

    final over = <String>[];
    for (final c in costs.where((c) => c.error == null)) {
      final name = '${c.feature}/${c.screen}';
      final budget = _elementBudget[name];
      if (budget == null) {
        over.add('$name has NO budget entry (add one: measured ${c.elements})');
      } else if (c.elements > budget) {
        over.add('$name ${c.elements} elements > budget $budget');
      }
    }
    expect(over, isEmpty,
        reason: 'Element budgets exceeded, or a screen was added without one. '
            'Every entry is a measured number plus ~15%:\n  ${over.join("\n  ")}');
  });
}
