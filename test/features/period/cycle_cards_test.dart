/// The Cycle screen's pattern check, the honest line under the prediction, and
/// the sheet that sets the lengths predictions start from.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/period/widgets/cycle_lengths_sheet.dart';
import 'package:tablet_remainder/features/period/widgets/prediction_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  // Mid-cycle, a few days after the last logged start.
  final now = DateTime(2026, 5, 5, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
  });

  tearDown(() async => db.close());

  /// A one-day period on each start, one after another. [lengths] are the
  /// completed cycles; the last start opens the current one.
  Future<void> seed(List<int> lengths) async {
    var start = DateTime(2026, 1, 1);
    Future<void> log(DateTime d) => PeriodService.logDay(PeriodDay(
        id: PeriodDay.keyFor(d), date: d, flowIndex: 2));
    await log(start);
    for (final l in lengths) {
      start = DateTime(start.year, start.month, start.day + l);
      await log(start);
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3200);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const PeriodDashboard()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  void pinned(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

  group('the pattern check', () {
    pinned('cycles that varied by more than a week get a card, and a way to share',
        (tester) async {
      await seed([28, 28, 28, 36]);
      await open(tester);

      expect(find.text('Your last 4 cycles varied by 8 days'), findsOneWidget);
      expect(find.textContaining('not a diagnosis'), findsWidgets);
      expect(find.text('Share summary (PDF)'), findsOneWidget);
    });

    pinned('regular cycles get no card', (tester) async {
      await seed([28, 29, 27, 28]);
      await open(tester);

      expect(find.textContaining('varied by'), findsNothing);
      expect(find.text('Share summary (PDF)'), findsNothing);
    });

    pinned('too few cycles say nothing, however far apart', (tester) async {
      await seed([20, 45]);
      await open(tester);

      expect(find.textContaining('varied by'), findsNothing);
    });
  });

  group('the temperature shift', () {
    /// Cycles of 28 days from 1 Jan. In the cycle that began on [start] a
    /// temperature log: flat to day 15, warmer from day [rise] for three days.
    Future<void> seedTemps(DateTime start, {int rise = 16}) async {
      Future<void> temp(int cycleDay, double c) async {
        final d = DateTime(start.year, start.month, start.day + cycleDay - 1);
        final existing = PeriodService.getDay(d);
        await PeriodService.logDay((existing ?? PeriodDay.empty(d))
            .copyWith(bbtCelsius: c));
      }

      for (var d = 1; d < rise; d++) {
        await temp(d, 36.3 + (d.isEven ? 0.05 : 0.0));
      }
      for (var d = rise; d < rise + 3; d++) {
        await temp(d, 36.7);
      }
    }

    pinned('a shift in this cycle gets a card, with the day and the caveat',
        (tester) async {
      await seed([28, 28, 28, 28]); // the open cycle began on 23 Apr
      await seedTemps(DateTime(2026, 4, 23), rise: 8);
      await open(tester);
      // Day 8 of that cycle is 30 Apr: the rise is day 8, ovulation day 7.
      expect(find.text('Temperature shift'), findsOneWidget);
      expect(find.textContaining('rose on day 8'), findsOneWidget);
      expect(find.textContaining('around day 7'), findsOneWidget);
      expect(find.textContaining('not a basis for contraception'), findsOneWidget);
    });

    pinned('a log with no shift shows no card', (tester) async {
      await seed([28, 28, 28, 28]);
      final start = DateTime(2026, 4, 23);
      for (var d = 1; d <= 12; d++) {
        final day = DateTime(start.year, start.month, start.day + d - 1);
        await PeriodService.logDay((PeriodService.getDay(day) ??
                PeriodDay.empty(day))
            .copyWith(bbtCelsius: 36.3));
      }
      await open(tester);
      expect(find.text('Temperature shift'), findsNothing);
    });

    pinned('earlier cycles with a shift are listed under it', (tester) async {
      await seed([28, 28, 28, 28]);
      await seedTemps(DateTime(2026, 3, 26), rise: 16); // the cycle before
      await seedTemps(DateTime(2026, 4, 23), rise: 8);
      await open(tester);

      expect(find.textContaining('rose on day 8'), findsOneWidget);
      expect(find.textContaining('In earlier cycles with a shift, ovulation was '
          'around day 15.'), findsOneWidget);
    });

    pinned('the card fits at 320pt with large text', (tester) async {
      await seed([28, 28, 28, 28]);
      await seedTemps(DateTime(2026, 3, 26), rise: 16);
      await seedTemps(DateTime(2026, 4, 23), rise: 8);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 6000);
      addTearDown(tester.view.reset);
      // Not `open`: it swallows FlutterError, and an overflow is what this is
      // for. Every report is kept, because the screen around the card may
      // overflow at this size for reasons of its own, and only this card's
      // file is in question.
      final reports = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const PeriodDashboard()));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.text('Temperature shift'), findsOneWidget,
          reason: 'on screen, or this proved nothing');
      expect(reports.where((r) => r.contains('temperature_shift_card.dart')),
          isEmpty);
    });

    pinned('a shift from many cycles ago is history, not a card', (tester) async {
      await seed([28, 28, 28, 28]);
      await seedTemps(DateTime(2026, 1, 1), rise: 16); // four cycles back
      await open(tester);
      expect(find.text('Temperature shift'), findsNothing);
    });
  });

  group('before your period', () {
    /// Five completed 28-day cycles (and the open one), with cramps logged on
    /// the three days before four of the five periods, and quiet logged days
    /// elsewhere to compare against.
    Future<void> seedPms() async {
      await seed([28, 28, 28, 28, 28]);
      final starts = [
        for (var i = 0; i <= 5; i++) DateTime(2026, 1, 1 + 28 * i),
      ];
      Future<void> log(DateTime d, [List<String> symptoms = const []]) =>
          PeriodService.logDay(PeriodDay(
              id: PeriodDay.keyFor(d),
              date: d,
              symptomIds: symptoms,
              mood: symptoms.isEmpty ? 3 : null));
      for (var i = 0; i < 5; i++) {
        DateTime before(int n) => DateTime(
            starts[i + 1].year, starts[i + 1].month, starts[i + 1].day - n);
        for (final n in [3, 2, 1]) {
          await log(before(n), i < 4 ? ['cramps'] : const []);
        }
        // Bloating starts earlier, five days out, in the same four cycles.
        await log(before(5), i < 4 ? ['bloating'] : const []);
        for (final off in [8, 10, 12, 14, 16]) {
          await log(DateTime(
              starts[i].year, starts[i].month, starts[i].day + off));
        }
      }
    }

    testWidgets('a symptom that keeps coming before the period is named, with '
        'when to expect it next', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 6, 1, 12)), () async {
        await seedPms();
        await open(tester);

        expect(find.text('Before your period'), findsOneWidget);
        expect(find.text('Cramps: usually from 3 days before (4 of 5 cycles)'),
            findsOneWidget);
        expect(find.text('Bloating: usually from 5 days before (4 of 5 cycles)'),
            findsOneWidget);
        // Next period predicted 18 June; counted back from the EARLIEST onset,
        // five days.
        expect(find.text('Next, you may notice it from about Jun 13.'),
            findsOneWidget);
        expect(find.textContaining('not a diagnosis'), findsWidgets);
      });
    });

    pinned('without that history there is no card', (tester) async {
      await seed([28, 28, 28, 28]);
      await open(tester);
      expect(find.text('Before your period'), findsNothing);
    });
  });

  group('the line under the prediction', () {
    pinned('says how wide it is, the likeliest day, and what it rests on',
        (tester) async {
      await seed([28, 28, 28, 28]);
      await open(tester);

      expect(
          find.textContaining(RegExp(
              r'Likely .* – .*, most likely the \d+(st|nd|rd|th) · based on 4 cycles')),
          findsOneWidget);
    });

    pinned('a prediction from one cycle is called a rough guess', (tester) async {
      await seed([28]);
      await open(tester);

      expect(find.textContaining('based on 1 cycle, a rough guess'),
          findsOneWidget);
    });

    pinned('two cycles is still a rough guess; three is not', (tester) async {
      await seed([28, 28]);
      await open(tester);
      expect(find.textContaining('based on 2 cycles, a rough guess'),
          findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await PeriodService.resetForTesting();
      PeriodService.clearInMemory();
      await PeriodService.init();
      await db.customStatement('DELETE FROM period_days');
      await PeriodService.reloadFromDb();
      await seed([28, 28, 28]);
      await open(tester);
      expect(find.textContaining('based on 3 cycles'), findsOneWidget);
      expect(find.textContaining('rough guess'), findsNothing);
    });

    test('ordinals, including the teens that are all "th"', () {
      expect(
          [1, 2, 3, 4, 11, 12, 13, 14, 21, 22, 23, 24, 30, 31]
              .map(periodOrdinal),
          ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '14th', '21st',
            '22nd', '23rd', '24th', '30th', '31st']);
    });

    test('with no completed cycle it says it is a typical length', () {
      final p = CyclePrediction(
        predictedStart: DateTime(2026, 5, 29),
        windowStart: DateTime(2026, 5, 27),
        windowEnd: DateTime(2026, 5, 31),
        cycleLengthEstimate: 31,
        completedCycles: 0,
      );
      expect(predictionBasisLine(p),
          'Likely May 27 – May 31, most likely the 29th · based on a typical 31-day cycle');
    });
  });

  group('cycle lengths', () {
    Future<void> openSheet(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: CycleLengthsForm(onDone: () {}))),
      ));
      await tester.pump();
    }

    testWidgets('starts from what is saved', (tester) async {
      await openSheet(tester);
      expect(find.text('28 days'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);
      expect(find.text('14 days'), findsOneWidget);
    });

    testWidgets('steps each figure and saves all three', (tester) async {
      await openSheet(tester);
      // A frame between taps, as a finger has: each button's closure holds the
      // value it was built with.
      for (final tip in [
        'Longer cycle',
        'Longer cycle',
        'Shorter period',
        'Longer luteal phase',
      ]) {
        await tester.tap(find.byTooltip(tip));
        await tester.pump();
      }

      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 100));

      final s = PeriodService.getSettings();
      expect(s.typicalCycleLength, 30);
      expect(s.typicalPeriodLength, 4);
      expect(s.lutealPhaseLength, 15);
    });

    testWidgets('stops at the ends of each range', (tester) async {
      await openSheet(tester);
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byTooltip('Shorter cycle'));
        await tester.pump();
      }
      expect(find.text('21 days'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Longer luteal phase'));
        await tester.pump();
      }
      expect(find.text('16 days'), findsOneWidget);
    });

    testWidgets('Reset puts back 28 / 5 / 14', (tester) async {
      await openSheet(tester);
      await tester.tap(find.byTooltip('Longer cycle'));
      await tester.tap(find.byTooltip('Longer period'));
      await tester.pump();
      await tester.tap(find.text('Reset to 28 / 5 / 14'));
      await tester.pump();

      expect(find.text('28 days'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);
    });

    testWidgets('says that your own history takes over after three cycles',
        (tester) async {
      await openSheet(tester);
      expect(find.textContaining('three cycles'), findsOneWidget);
    });

    testWidgets('a saved typical length moves a prediction that has little '
        'history behind it', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await seed([]); // one logged start, no completed cycle
        final before = PeriodService.getPrediction().predictedStart!;

        await PeriodService.saveSettings(
            PeriodService.getSettings().copyWith(typicalCycleLength: 35));
        final after = PeriodService.getPrediction().predictedStart!;

        expect(after.difference(before).inDays, 7,
            reason: '28 → 35 days from the same start');
      });
    });
  });

  testWidgets('the Cycle screen offers the sheet', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await seed([28, 28]);
      await open(tester);
      expect(find.text('Adjust cycle lengths'), findsOneWidget);
      await tester.tap(find.text('Adjust cycle lengths'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Typical cycle'), findsOneWidget);
      expect(find.byIcon(Symbols.tune_rounded), findsWidgets);
    });
  });
}
