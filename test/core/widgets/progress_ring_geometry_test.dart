/// The ring's geometry, not its pixels.
///
/// Every adherence/hydration/focus number in the app is ultimately drawn by one
/// painter, and it had a rounding-style bug in the *shape*: `StrokeCap.round`
/// extends the stroke half a stroke-width past each end of the arc, so the ink
/// laid down spanned `sweep + stroke/radius` radians rather than `sweep`. On the
/// 104px hero ring that overshoot is 3.4% of the circle, so every value at or
/// above ~96.6% painted as a fully CLOSED ring — a 97% day was
/// indistinguishable from a perfect one.
///
/// A golden file would not have caught this: the goldens would have been
/// generated from the buggy painter and blessed the closed ring as correct.
/// These assertions are on the arithmetic instead.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/progress_ring.dart';

/// Records the draw calls a [CustomPainter] makes instead of rasterising them.
class _RecordingCanvas implements Canvas {
  final circles = <({Offset center, double radius, Paint paint})>[];
  final arcs = <({Rect rect, double start, double sweep, Paint paint})>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add((center: c, radius: radius, paint: paint));

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter,
          Paint paint) =>
      arcs.add((rect: rect, start: startAngle, sweep: sweepAngle, paint: paint));

  // Everything else the painter might reach for is irrelevant here.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  /// Paint one ring and hand back what it drew.
  Future<_RecordingCanvas> paint(
    WidgetTester tester, {
    required double value,
    double size = 104,
    double stroke = 10,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Center(
        child: ProgressRing(
          progress: value,
          size: size,
          stroke: stroke,
          // Off, so the painter under test receives the final value rather than
          // whatever frame the tween happens to be on.
          animate: false,
        ),
      ),
    ));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CustomPainter>()
        .last;
    final canvas = _RecordingCanvas();
    painter.paint(canvas, Size.square(size));
    return canvas;
  }

  /// Ink actually laid down, in radians: the arc's own sweep plus the two round
  /// caps, each of which adds half a stroke-width of arc length.
  double inkRadians(_RecordingCanvas c, {double size = 104, double stroke = 10}) {
    if (c.arcs.isEmpty) return 0;
    final radius = (size - stroke) / 2;
    return c.arcs.single.sweep + stroke / radius;
  }

  testWidgets('a full value draws a closed circle, not a 2π arc',
      (tester) async {
    final c = await paint(tester, value: 1.0);

    expect(c.arcs, isEmpty,
        reason: 'an arc sweeping the whole way round laps its own round cap at '
            'the 12-o\'clock start, leaving a seam on the one state that has to '
            'look perfect');
    expect(c.circles, hasLength(2), reason: 'track + fill');
    expect(c.circles.last.paint.color, isNot(c.circles.first.paint.color));
  });

  testWidgets('99% leaves a visible gap instead of reading as complete',
      (tester) async {
    final c = await paint(tester, value: 0.99);

    expect(c.arcs, hasLength(1));
    final ink = inkRadians(c);
    expect(ink, lessThan(2 * math.pi),
        reason: 'BEFORE THE FIX this overshot 2π and the ring closed: the two '
            'round caps met and overlapped, so 99% looked exactly like 100%');
    // The gap has to be big enough to actually see, not just to measure.
    final gapPx = (2 * math.pi - ink) * ((104 - 10) / 2);
    expect(gapPx, greaterThan(1.0),
        reason: 'a sub-pixel gap is a closed ring to the eye');
  });

  testWidgets('ink matches the value at every level', (tester) async {
    for (final value in const [0.25, 0.5, 0.75, 0.9, 0.96, 0.97]) {
      final c = await paint(tester, value: value);
      expect(inkRadians(c), closeTo(2 * math.pi * value, 1e-9),
          reason: 'the ring is a picture of $value and must contain exactly '
              'that much ink — cap overshoot included');
    }
  });

  testWidgets('a just-started value stays visible and never inverts',
      (tester) async {
    // Below one cap's worth of arc there is no geometry left to shorten; the
    // sweep must clamp at 0 (a dot) rather than go negative, which would draw
    // the arc BACKWARDS from 12 o'clock.
    for (final value in const [0.001, 0.01, 0.03]) {
      final c = await paint(tester, value: value);
      expect(c.arcs.single.sweep, greaterThanOrEqualTo(0.0),
          reason: 'a negative sweep paints anticlockwise — the ring would show '
              'progress running the wrong way at $value');
    }
  });

  testWidgets('zero draws the track and nothing else', (tester) async {
    final c = await paint(tester, value: 0);
    expect(c.circles, hasLength(1), reason: 'track only');
    expect(c.arcs, isEmpty);
  });

  testWidgets('a stroke wider than the box does not paint a negative radius',
      (tester) async {
    final c = await paint(tester, value: 0.5, size: 20, stroke: 40);
    for (final circle in c.circles) {
      expect(circle.radius, greaterThanOrEqualTo(0.0));
    }
    for (final arc in c.arcs) {
      expect(arc.rect.width, greaterThanOrEqualTo(0.0));
    }
  });
}
