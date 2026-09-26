/// PV-22 — the cycle "Avg" tiles were showing medians.
///
/// The tile read `stats.medianCycleLength` and called it "Avg cycle". For a
/// regular cycle the two coincide and the mislabel is invisible; the assertions
/// below therefore use a sample whose mean and median are DIFFERENT, which is
/// the only shape in which this defect exists — and the shape an irregular
/// cycle actually has.
///
/// The label moved rather than the maths: the median is what
/// `CyclePredictor._learnedCycleLength` feeds the prediction, so a mean on this
/// card would contradict the "~28" the dashboard prints two cards above it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/services/cycle_predictor.dart';
import 'package:tablet_remainder/features/period/widgets/cycle_stats_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// Six cycles of 26, 27, 28, 30, 33 and 35 days — median 29, mean 30.
  ///
  /// A right-skewed but not outlying spread, deliberately: a 60-day cycle is
  /// the obvious way to separate a mean from a median and MAD rejection throws
  /// it straight out, leaving the two equal again and the assertions below
  /// vacuous. This sample survives rejection intact, so the split is real by
  /// the time the card sees it. Built through `deriveCycles`/`computeStats`
  /// rather than by hand, so these are the numbers the pipeline actually
  /// produces.
  CycleStats irregularStats() {
    final base = DateTime(2026, 1, 1);
    var start = base;
    final days = <FlowDay>[];
    for (final len in [26, 27, 28, 30, 33, 35]) {
      for (var d = 0; d < 5; d++) {
        days.add(FlowDay(start.add(Duration(days: d)), 2));
      }
      start = start.add(Duration(days: len));
    }
    days.addAll([for (var d = 0; d < 5; d++) FlowDay(start.add(Duration(days: d)), 2)]);
    return CyclePredictor.computeStats(CyclePredictor.deriveCycles(days));
  }

  Future<void> pump(WidgetTester tester, CycleStats stats) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: CycleStatsCard(stats: stats)),
    ));
    await tester.pump();
  }

  test('the fixture is actually a mean/median split', () {
    final stats = irregularStats();
    // Without this the widget assertions below could pass against a sample
    // where "Avg" and "Median" name the same number — which is how the
    // mislabel survived: on a 28/28/28 history it is undetectable.
    expect(stats.medianCycleLength, isNotNull);
    expect(stats.avgCycleLength, isNotNull);
    expect(stats.avgCycleLength!.round(),
        isNot(equals(stats.medianCycleLength)),
        reason: 'mean ${stats.avgCycleLength} vs median '
            '${stats.medianCycleLength} — if these converge the fixture has '
            'stopped testing anything');
  });

  testWidgets('the tile showing a median is labelled a median', (tester) async {
    final stats = irregularStats();
    await pump(tester, stats);

    expect(find.text('${stats.medianCycleLength}d'), findsOneWidget);
    expect(find.text('Median cycle'), findsOneWidget);
    expect(find.text('Median period'), findsOneWidget);
  });

  testWidgets('no tile claims an average it is not showing', (tester) async {
    await pump(tester, irregularStats());

    // The whole defect in one assertion: the word and the number disagreed.
    expect(find.textContaining('Avg'), findsNothing);
  });

  testWidgets('the median, not the mean, is the number on screen',
      (tester) async {
    final stats = irregularStats();
    await pump(tester, stats);

    // Pinned in both directions. "Median cycle" over `avgCycleLength` would be
    // the same bug with the words swapped, and the label assertion alone
    // cannot see it.
    expect(find.text('${stats.avgCycleLength!.round()}d'), findsNothing,
        reason: 'the mean (${stats.avgCycleLength!.round()}d) must not be what '
            'the card renders');
  });

  testWidgets('an empty history still renders the em dash placeholders',
      (tester) async {
    await pump(tester, CycleStats.empty);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('Median cycle'), findsOneWidget);
  });
}
