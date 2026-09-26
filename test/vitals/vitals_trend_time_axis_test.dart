import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_trend_chart.dart';

/// The vitals trend chart used to place every reading by its ORDINAL, so three
/// readings an hour apart and three a month apart drew the same picture — the
/// one thing a trend chart exists to distinguish. A chart whose every drawn
/// series carries `times` is now laid out on a real time axis; one where any
/// series does not (a seven-day run of daily totals, say, where index spacing
/// is already the truth) keeps the old even spacing exactly.
///
/// The assertions drive the REAL painter the REAL widget built — reached via
/// `RenderCustomPaint.painter` — through a canvas that records dot centres, so
/// they measure this chart's geometry and not a reimplementation of it.

/// Records the dot centres and swallows everything else the painter draws
/// (band, gridlines, polyline, axis labels), which this file never asks about.
class _DotRecorder implements Canvas {
  final List<Offset> dots = <Offset>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => dots.add(c);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  /// Pumps the chart and returns where its dots landed, plus the plot's own
  /// size so absolute edges can be asserted without guessing the gutter.
  Future<({List<double> xs, Size size})> plot(
    WidgetTester tester,
    List<VitalsSeries> series,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: VitalsTrendChart(
              series: series,
              minY: 40,
              maxY: 260,
              bandColor: const Color(0xFF4CAF50),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final rcp = tester.renderObject<RenderCustomPaint>(find.descendant(
      of: find.byType(VitalsTrendChart),
      matching: find.byType(CustomPaint),
    ));
    final rec = _DotRecorder();
    rcp.painter!.paint(rec, rcp.size);
    return (xs: rec.dots.map((o) => o.dx).toList(), size: rcp.size);
  }

  // Literal timestamps rather than Duration stepping — see
  // lib/core/utils/calendar_day.dart's rationale. Same wall-clock hour on each
  // day, so the span is a real interval however the host's DST falls.
  final march1at8 = DateTime(2026, 3, 1, 8);
  final march1at9 = DateTime(2026, 3, 1, 9);
  final march1at10 = DateTime(2026, 3, 1, 10);
  final march25at8 = DateTime(2026, 3, 25, 8);
  final march31at8 = DateTime(2026, 3, 31, 8);

  VitalsSeries glucose(List<double> values, {List<DateTime>? times}) =>
      VitalsSeries(
        values: values,
        times: times,
        color: const Color(0xFF2196F3),
        label: 'Blood sugar',
      );

  testWidgets('a month-long gap draws as a gap, not as one more step',
      (tester) async {
    // Two readings an hour apart, then nothing for a month. By ordinal these
    // three are equidistant; on a time axis the first pair all but touch.
    final r = await plot(tester, [
      glucose(const [120, 130, 140],
          times: [march1at8, march1at9, march31at8]),
    ]);

    expect(r.xs.length, 3);
    final burst = r.xs[1] - r.xs[0];
    final gap = r.xs[2] - r.xs[1];
    expect(burst, greaterThan(0));
    expect(burst, lessThan(gap / 50),
        reason: 'one hour out of a month must not draw as a third of the '
            'chart — got $burst vs $gap');

    // The series still spans the full plot: oldest on the left edge of the
    // gutter, newest on the right edge of the canvas.
    expect(r.xs.last, closeTo(r.size.width, 0.01));
    expect(r.xs.first, greaterThan(0));
  });

  testWidgets('an untimed series keeps exactly even index spacing',
      (tester) async {
    // The caffeine chart and the other untimed callers pass one point per
    // bucket, where even spacing IS the honest layout. They must not move.
    final r = await plot(tester, [glucose(const [120, 130, 140])]);

    expect(r.xs.length, 3);
    expect(r.xs[1] - r.xs[0], closeTo(r.xs[2] - r.xs[1], 0.01));
    expect(r.xs.last, closeTo(r.size.width, 0.01));
  });

  testWidgets('evenly spaced stamps land where index spacing put them',
      (tester) async {
    // The time axis has to degrade to the old picture when the readings really
    // are evenly spaced, or every bucketed series would shift on adoption.
    final timed = await plot(tester, [
      glucose(const [120, 130, 140],
          times: [march1at8, march1at9, march1at10]),
    ]);
    final untimed = await plot(tester, [glucose(const [120, 130, 140])]);

    expect(timed.xs.length, untimed.xs.length);
    for (var i = 0; i < timed.xs.length; i++) {
      expect(timed.xs[i], closeTo(untimed.xs[i], 0.01));
    }
  });

  testWidgets('two series on one chart share a single axis', (tester) async {
    // Systolic/diastolic, or any pair: the second series is positioned in the
    // FIRST one's domain. Mar 25 is 24/30 of the way from Mar 1 to Mar 31, so
    // the lone second-series dot belongs at 0.8 of the plot — not centred,
    // which is where a per-series (or ordinal) layout would drop it.
    final r = await plot(tester, [
      glucose(const [100, 200], times: [march1at8, march31at8]),
      VitalsSeries(
        values: const [150],
        times: [march25at8],
        color: const Color(0xFF9E9E9E),
        label: 'Second',
      ),
    ]);

    expect(r.xs.length, 3, reason: 'two dots then one');
    final left = r.xs[0];
    final width = r.xs[1] - left;
    expect(r.xs[2], closeTo(left + 0.8 * width, 1.5));
  });

  testWidgets('one untimed series drops the WHOLE chart to index spacing',
      (tester) async {
    // The axis is all-or-nothing. A stamped systolic beside an unstamped
    // diastolic would draw the same pixel column as two different moments —
    // worse than spacing both by index, and invisible to the reader. So the
    // stamped series gives up its axis rather than the chart telling a lie.
    final r = await plot(tester, [
      glucose(const [120, 130, 140],
          times: [march1at8, march1at9, march31at8]),
      const VitalsSeries(
        values: [100, 110, 120],
        color: Color(0xFF9E9E9E),
        label: 'Untimed',
      ),
    ]);

    expect(r.xs.length, 6, reason: 'three dots per series');
    final timed = r.xs.sublist(0, 3);
    final untimed = r.xs.sublist(3);
    for (var i = 0; i < 3; i++) {
      expect(timed[i], closeTo(untimed[i], 0.01),
          reason: 'both series must sit on ONE x scale — got $timed vs '
              '$untimed');
    }
    // And that one scale is the even one, since the chart cannot place the
    // untimed points in time.
    expect(timed[1] - timed[0], closeTo(timed[2] - timed[1], 0.01));
  });

  testWidgets('an empty series does not veto the time axis', (tester) async {
    // paint() skips a series with no values, so it must not drag the drawn
    // series off the time axis on its way past.
    final r = await plot(tester, [
      glucose(const [120, 130, 140],
          times: [march1at8, march1at9, march31at8]),
      const VitalsSeries(
        values: [],
        color: Color(0xFF9E9E9E),
        label: 'Nothing logged',
      ),
    ]);

    expect(r.xs.length, 3);
    expect(r.xs[1] - r.xs[0], lessThan((r.xs[2] - r.xs[1]) / 50));
  });

  testWidgets('a times list that does not match the values is ignored',
      (tester) async {
    // Defensive: a caller that filters values but forgets the stamps gets the
    // old even spacing, not a crash and not a silently wrong axis.
    final r = await plot(tester, [
      glucose(const [120, 130, 140], times: [march1at8, march31at8]),
    ]);

    expect(tester.takeException(), isNull);
    expect(r.xs.length, 3);
    expect(r.xs[1] - r.xs[0], closeTo(r.xs[2] - r.xs[1], 0.01));
  });

  testWidgets('readings logged at the same instant do not collapse onto one x',
      (tester) async {
    // A zero-length domain is a divide-by-zero waiting to happen; it falls
    // back to even spacing instead.
    final r = await plot(tester, [
      glucose(const [120, 130, 140],
          times: [march1at8, march1at8, march1at8]),
    ]);

    expect(r.xs.length, 3);
    expect(r.xs.every((x) => x.isFinite), isTrue);
    expect(r.xs[1] - r.xs[0], closeTo(r.xs[2] - r.xs[1], 0.01));
    expect(r.xs[0], lessThan(r.xs[2]));
  });
}
