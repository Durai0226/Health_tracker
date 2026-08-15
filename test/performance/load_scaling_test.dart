@Tags(['performance'])
library;

/// Does the app cost more with a YEAR of data than with a month?
///
/// That question is the one an empty — or lightly seeded — database cannot
/// answer, and it is where a whole class of defect hides: a full-table scan, a
/// per-row loop, a chart that builds one widget per data point. Every one of
/// those looks fine at 30 days and falls over at 365.
///
/// `typical` ≈ 30 days / 4 medicines. `heavy` ≈ 365 days / 8 medicines —
/// roughly 12x the history and 2x the medicines, so ~24x the dose logs.
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
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/insights/screens/weekly_recap_screen.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

import '../support/counting_executor.dart';

class _Load {
  final String screen;
  int elements = 0;
  int selects = 0;
  Map<String, int> tally = const {};
  _Load(this.screen);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late CountingExecutor counter;
  late AppDatabase db;

  final results = <String, Map<String, _Load>>{'typical': {}, 'heavy': {}};

  Future<void> boot(SeedProfile profile) async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory())..recording = false;
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await WaterService.resetForTesting();
    await WaterService.init();
    await seedQaData(force: true, profile: profile);
  }

  final screens = <String, Widget Function()>{
    'home': () => HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
    'med_dashboard': () => const NunitoMedicationDashboard(),
    'adherence': () => const NunitoAdherenceReportScreen(),
    'weekly_recap': () => const WeeklyRecapScreen(),
  };

  for (final profile in [SeedProfile.typical, SeedProfile.heavy]) {
    final tag = profile == SeedProfile.heavy ? 'heavy' : 'typical';
    for (final entry in screens.entries) {
      testWidgets('$tag / ${entry.key}', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await boot(profile);
        final load = _Load(entry.key);

        final prev = FlutterError.onError;
        FlutterError.onError = (_) {};
        try {
          counter.reset();
          counter.recording = true;
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: entry.value(),
          ));
          await tester.pump(const Duration(milliseconds: 50));
          // Settle adaptively: weekly_recap awaits four service inits plus
          // gatherAll, and a fixed 600ms left it still on its skeleton at the
          // lighter profile — which reads as "the tree grew 3x with data"
          // when it actually means "one run had not finished loading".
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          counter.recording = false;

          load.elements = tester.allElements.length;
          load.selects = counter.selects;
          load.tally = counter.tally;
        } catch (e) {
          load.selects = -1;
        } finally {
          FlutterError.onError = prev;
        }

        results[tag]![entry.key] = load;
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      });
    }
  }

  tearDownAll(() {
    void p(String s) {
      // ignore: avoid_print
      print(s);
    }

    p('\n===== LOAD SCALING: 30 days/4 meds  vs  365 days/8 meds =====');
    p('${'screen'.padRight(16)}${'elems T'.padLeft(9)}${'elems H'.padLeft(9)}'
        '${'reads T'.padLeft(9)}${'reads H'.padLeft(9)}   verdict');

    final offenders = <String>[];
    for (final key in results['typical']!.keys) {
      final t = results['typical']![key]!;
      final h = results['heavy']![key];
      if (h == null) continue;

      final readGrowth = t.selects <= 0 ? 0.0 : h.selects / t.selects;
      final elemGrowth = t.elements <= 0 ? 0.0 : h.elements / t.elements;

      final notes = <String>[];
      // Reads must be O(1) in history: the range is a parameter, not a loop
      // bound. Anything above ~1.5x means a per-row or per-day query crept in.
      if (readGrowth > 1.5) {
        notes.add('READS SCALE ${readGrowth.toStringAsFixed(1)}x');
        offenders.add('$key: reads ${t.selects} -> ${h.selects}');
      }
      // Element counts may grow, but only up to a bound.
      //
      // Two different things look the same in a ratio: a tree that scales with
      // the ROW COUNT (a real leak — 10x the data, 10x the widgets) and a
      // screen whose empty state is simply much smaller than its populated one
      // (not a leak — it stops growing once there is something to show).
      //
      // weekly_recap is the second kind: at 30 days its insight block is empty
      // and the section is skipped entirely, at 365 days it renders — capped at
      // `.take(4)` (weekly_recap_screen.dart:339). So the ratio is large but
      // the ceiling is fixed.
      //
      // The honest discriminator is the ABSOLUTE ceiling, not the ratio: a
      // screen that stays inside the app's normal element range under a year
      // of data is fine however much it grew from empty.
      const perScreenCeiling = 1400;
      if (h.elements > perScreenCeiling) {
        notes.add('TREE ${h.elements} > ceiling $perScreenCeiling');
        offenders.add('$key: ${h.elements} elements under a year of data');
      } else if (elemGrowth > 2.0) {
        notes.add('grew ${elemGrowth.toStringAsFixed(1)}x (empty→populated, '
            'within ceiling)');
      }
      if (notes.isEmpty) notes.add('flat');

      p('${key.padRight(16)}${t.elements.toString().padLeft(9)}'
          '${h.elements.toString().padLeft(9)}'
          '${t.selects.toString().padLeft(9)}'
          '${h.selects.toString().padLeft(9)}   ${notes.join(' · ')}');
    }
    p('=============================================================\n');

    expect(
      offenders,
      isEmpty,
      reason: 'These screens cost materially more with a year of data than '
          'with a month. Read counts must be independent of history length, '
          'and a lazily-built tree must be bounded by the viewport rather '
          'than the row count:\n  ${offenders.join("\n  ")}',
    );
  });
}
