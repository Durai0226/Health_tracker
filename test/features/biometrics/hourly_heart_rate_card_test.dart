/// Heart rate through the day, hour by hour — with gaps left as gaps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/design/app_colors_ext.dart';
import 'package:tablet_remainder/features/biometrics/widgets/hourly_heart_rate_card.dart';

import '../../support/font_free_theme.dart';

void main() {
  /// A day with [over] (hour → bpm) set and everything else unknown.
  List<int?> day(Map<int, int> over) =>
      [for (var h = 0; h < 24; h++) over[h]];

  Future<void> pump(
    WidgetTester tester,
    List<int?> hourly, {
    double width = 400,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1200);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: HourlyHeartRateCard(hourly: hourly)),
      ),
    ));
    await tester.pump();
  }

  group('extremes', () {
    test('the lowest and highest hour, with their values', () {
      final e = HourlyHeartRateCard.extremes(day({3: 52, 9: 71, 17: 128, 20: 88}))!;
      expect((e.lowHour, e.low), (3, 52));
      expect((e.highHour, e.high), (17, 128));
    });

    test('a tie goes to the earlier hour', () {
      final e = HourlyHeartRateCard.extremes(day({4: 60, 10: 60, 12: 90, 14: 90}))!;
      expect(e.lowHour, 4);
      expect(e.highHour, 12);
    });

    test('one hour is both ends', () {
      final e = HourlyHeartRateCard.extremes(day({8: 70}))!;
      expect(e.lowHour, 8);
      expect(e.highHour, 8);
    });

    test('no hour with a value is nothing', () {
      expect(HourlyHeartRateCard.extremes(day({})), isNull);
      expect(HourlyHeartRateCard.extremes(const []), isNull);
    });
  });

  group('words', () {
    test('hours', () {
      expect(HourlyHeartRateCard.hourLabel(0), '12 am');
      expect(HourlyHeartRateCard.hourLabel(3), '3 am');
      expect(HourlyHeartRateCard.hourLabel(12), '12 pm');
      expect(HourlyHeartRateCard.hourLabel(17), '5 pm');
    });
  });

  testWidgets('names the quietest and busiest hour, and says what a bar is',
      (tester) async {
    await pump(tester, day({3: 52, 9: 71, 17: 128}));
    expect(find.text('Heart rate by hour'), findsOneWidget);
    expect(find.textContaining('Lowest 52 bpm around 3 am'), findsOneWidget);
    expect(find.textContaining('highest 128 bpm around 5 pm'), findsOneWidget);
    expect(find.textContaining("an hour's average"), findsOneWidget);
  });

  testWidgets('a day with no hourly heart rate shows nothing at all', (tester) async {
    await pump(tester, day({}));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('and neither does a list that is not a day', (tester) async {
    await pump(tester, const [60, 62, 64]);
    expect(find.byType(Text), findsNothing,
        reason: 'twelve values on a 24-hour axis would put every one on the wrong hour');
  });

  testWidgets('it reads aloud as one summary, not 24 bars', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, day({3: 52, 17: 128}));
    expect(
        find.bySemanticsLabel(RegExp('Heart rate by hour. Lowest 52 beats per minute around 3 am')),
        findsOneWidget);
    handle.dispose();
  });

  group('where the bars go', () {
    // 24 slots of 10 px, so every bar is 7 px wide in a 3 px gap.
    const area = Size(240, 96);

    test('only the hours with a value have a bar: a gap is empty space', () {
      final bars = HourlyHeartRateCard.barRects(day({3: 52, 17: 128}), area);
      expect(bars, hasLength(24));
      expect([for (var h = 0; h < 24; h++) if (bars[h] != null) h], [3, 17],
          reason: 'twenty-two hours had no sample, and a short bar there would be '
              'a measurement no device made');
    });

    test('the highest hour stands tallest, the lowest shortest', () {
      final bars = HourlyHeartRateCard.barRects(day({3: 52, 9: 90, 17: 128}), area);
      expect(bars[3]!.height, lessThan(bars[9]!.height));
      expect(bars[9]!.height, lessThan(bars[17]!.height));
    });

    test('the axis starts a little under the lowest hour, so the spread shows', () {
      final bars = HourlyHeartRateCard.barRects(day({3: 52, 17: 128}), area);
      expect(bars[3]!.height, closeTo(10 / 86 * 92, 0.01),
          reason: 'a floor of 42, not 0: the lowest hour is short, not a sliver');
      expect(bars[17]!.height, closeTo(92, 0.01),
          reason: 'the highest hour reaches the top of the bars');
    });

    test('one hour is a full-height bar: it is both ends', () {
      final bars = HourlyHeartRateCard.barRects(day({8: 70}), area);
      expect(bars[8]!.height, closeTo(92, 0.01));
    });

    test('every bar stands on the one baseline, in its own slot', () {
      final bars = HourlyHeartRateCard.barRects(
          day({0: 60, 5: 55, 12: 100, 23: 80}), area);
      for (final (h, bar) in [for (var h = 0; h < 24; h++) (h, bars[h])]) {
        if (bar == null) continue;
        expect(bar.bottom, area.height, reason: 'hour $h');
        expect(bar.width, 7, reason: 'hour $h');
        expect(bar.left, greaterThanOrEqualTo(h * 10.0), reason: 'hour $h');
        expect(bar.right, lessThanOrEqualTo((h + 1) * 10.0), reason: 'hour $h');
      }
    });

    test('a bar is never taller than the area, or shorter than three pixels', () {
      for (final size in const [Size(240, 96), Size(240, 40), Size(480, 200)]) {
        for (final bar
            in HourlyHeartRateCard.barRects(day({1: 40, 2: 250, 3: 120}), size)) {
          if (bar == null) continue;
          expect(bar.height, lessThanOrEqualTo(size.height));
          expect(bar.height, greaterThanOrEqualTo(3));
          expect(bar.top, greaterThanOrEqualTo(0));
        }
      }
    });

    test('an absurd reading cannot push a bar past the headroom', () {
      final bars = HourlyHeartRateCard.barRects(day({1: 20, 2: 400}), area);
      expect(bars[2]!.height, closeTo(92, 0.01),
          reason: 'a reading far above the rest is capped, not drawn off the top');
    });

    test('an area with no height still draws without throwing', () {
      expect(
          () => HourlyHeartRateCard.barRects(day({3: 52, 17: 128}), Size.zero),
          returnsNormally);
      expect(
          () => HourlyHeartRateCard.barRects(
              day({3: 52, 17: 128}), const Size(240, 2)),
          returnsNormally,
          reason: 'a sliver shorter than the minimum bar must not cross the '
              'bounds of clamp');
    });

    test('nothing at all when it is not a day, or the day is empty', () {
      expect(HourlyHeartRateCard.barRects(const [60, 62, 64], area), isEmpty);
      expect(HourlyHeartRateCard.barRects(day({}), area), isEmpty);
    });
  });

  testWidgets('paints a bar for each hour with a value, and for no other',
      (tester) async {
    await pump(tester, day({3: 52, 17: 128}));
    final painted = tester.renderObject(find.byKey(HourlyHeartRateCard.barsKey));
    expect(painted, paintsExactlyCountTimes(#drawRRect, 2));

    await pump(tester, day({1: 60, 2: 61, 3: 62, 9: 90, 20: 70}));
    expect(tester.renderObject(find.byKey(HourlyHeartRateCard.barsKey)),
        paintsExactlyCountTimes(#drawRRect, 5));
  });

  testWidgets('each bar is the rounded rectangle the geometry says, in the card\'s colour',
      (tester) async {
    await pump(tester, day({3: 52, 17: 128}), width: 400);
    final painted =
        tester.renderObject<RenderBox>(find.byKey(HourlyHeartRateCard.barsKey));
    final bars = HourlyHeartRateCard.barRects(day({3: 52, 17: 128}), painted.size);
    RRect round(Rect r) =>
        RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 3));
    final colour = AppColorsExt.light.mark(AppColorsExt.light.medicine);

    expect(
        painted,
        paints
          ..rrect(rrect: round(bars[3]!), color: colour)
          ..rrect(rrect: round(bars[17]!), color: colour));
  });

  test('it repaints only when what it draws has changed', () {
    final a = HourlyBarsPainter(hourly: day({3: 52}), color: Colors.red);
    expect(
        a.shouldRepaint(HourlyBarsPainter(hourly: day({3: 52}), color: Colors.red)),
        isFalse,
        reason: 'the same day in the same colour: nothing to redraw');
    expect(
        a.shouldRepaint(HourlyBarsPainter(hourly: day({3: 53}), color: Colors.red)),
        isTrue);
    expect(
        a.shouldRepaint(HourlyBarsPainter(hourly: day({3: 52}), color: Colors.blue)),
        isTrue);
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
    testWidgets('fits $width wide at ${scale}x text', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await pump(tester, day({3: 52, 17: 128}), width: width, scale: scale);
      } finally {
        FlutterError.onError = prev;
      }
      expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
    });
  }
}
