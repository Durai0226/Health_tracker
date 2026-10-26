/// The one line on the Cycle screen that says when the next period is.
///
/// Found on device: on Sep 30, under a heading reading "Next period · Tue,
/// Sep 29" and beside "Day 30 of ~28 days", the card said **"Due today"**.
///
/// The countdown branched on [CycleState], which only turns `late` once today
/// is past the *window* end ("Likely Sep 27 – Oct 1"). The line itself sits
/// under the *point* estimate, so every day between the estimate and the end of
/// the window fell into an arm written `days <= 0` and was announced as today.
///
/// A cycle tracker whose headline date has already passed, and which still says
/// "today", is telling the user the opposite of what its own numbers say.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/cycle_prediction.dart';
import 'package:tablet_remainder/features/period/widgets/prediction_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// The card with [daysUntil] to go and a prediction it can render.
  Future<void> pump(
    WidgetTester tester,
    int daysUntil, {
    CycleState state = CycleState.ready,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(411, 1400);
    addTearDown(tester.view.reset);

    final start = DateTime(2026, 9, 29);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PredictionCard(
            prediction: CyclePrediction(
              predictedStart: start,
              windowStart: start.subtract(const Duration(days: 2)),
              windowEnd: start.add(const Duration(days: 2)),
              dayOfCycle: 30,
              cycleLengthEstimate: 28,
              state: state,
              daysUntilNextPeriod: daysUntil,
              completedCycles: 4,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  /// Every string the card rendered.
  String screen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' | ');

  testWidgets('the day the estimate passes is not still called today',
      (tester) async {
    // The exact device state: one day past the estimate, still inside the
    // likely window, so CycleState is `ready` rather than `late`.
    await pump(tester, -1);
    final s = screen(tester);

    expect(s, isNot(contains('Due today')),
        reason: 'the estimate was yesterday. Screen was:\n$s');
    expect(s, contains('1 day late'), reason: 'screen was:\n$s');
  });

  testWidgets('several days past the estimate counts them', (tester) async {
    await pump(tester, -3);
    final s = screen(tester);
    expect(s, contains('3 days late'), reason: 'screen was:\n$s');
    expect(s, isNot(contains('Due today')));
  });

  testWidgets('the day itself is "Due today"', (tester) async {
    await pump(tester, 0);
    expect(screen(tester), contains('Due today'));
  });

  testWidgets('a future estimate counts down', (tester) async {
    await pump(tester, 1);
    expect(screen(tester), contains('in 1 day'));
    await pump(tester, 5);
    expect(screen(tester), contains('in 5 days'));
  });

  testWidgets('the explicit late state still reads the same', (tester) async {
    // Past the window end too. This used to be the only arm that could say
    // "late", and its wording is unchanged.
    await pump(tester, -4, state: CycleState.late);
    expect(screen(tester), contains('4 days late'));
  });

  testWidgets('"Due today" never appears on a negative count', (tester) async {
    for (final d in const [-1, -2, -5, -10]) {
      await pump(tester, d);
      expect(screen(tester), isNot(contains('Due today')),
          reason: '$d days until next period rendered as today');
    }
  });
}
