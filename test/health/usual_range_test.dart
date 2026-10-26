import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/usual_range.dart';

void main() {
  group('UsualRangeCalc', () {
    test('needs 7 values before it says anything', () {
      expect(UsualRangeCalc.compute(List.filled(6, 60.0)), isNull);
      expect(UsualRangeCalc.compute(List.filled(7, 60.0)), isNotNull);
    });

    test('is the mean plus and minus one sample standard deviation', () {
      // mean 60, sample SD = sqrt(((-2)^2*... )) computed by hand below.
      final v = [58.0, 62.0, 58.0, 62.0, 58.0, 62.0, 60.0];
      final r = UsualRangeCalc.compute(v)!;
      expect(r.mean, closeTo(60, 1e-9));
      // squares of deviations: 4*6 + 0 = 24; /(7-1) = 4; sqrt = 2
      expect(r.low, closeTo(58, 1e-9));
      expect(r.high, closeTo(62, 1e-9));
      expect(r.n, 7);
    });

    test('a perfectly steady series does not collapse to a line', () {
      final steady = List.filled(10, 58.0);
      final bare = UsualRangeCalc.compute(steady)!;
      expect(bare.low, bare.high, reason: 'premise: zero spread');
      final r = UsualRangeCalc.compute(steady, minHalfWidth: 2)!;
      expect(r.low, 56);
      expect(r.high, 60);
      expect(r.statusOf(59), RangeStatus.within,
          reason: '59 is not "above your usual" when yours is a flat 58');
    });

    test('statusOf places a value below, within or above', () {
      final r = UsualRangeCalc.compute(
          [58, 62, 58, 62, 58, 62, 60].map((e) => e.toDouble()).toList())!;
      expect(r.statusOf(57.9), RangeStatus.below);
      expect(r.statusOf(58), RangeStatus.within);
      expect(r.statusOf(62), RangeStatus.within);
      expect(r.statusOf(62.1), RangeStatus.above);
    });
  });

  group('HrvStatus', () {
    final today = DateTime(2026, 3, 29);
    DateTime day(int back) => DateTime(2026, 3, 29 - back);

    /// 7 recent nights at [recentMs], and 21 earlier at 38..51 alternating.
    List<({DateTime date, double ms})> series(double recentMs) => [
          for (var i = 0; i < 7; i++) (date: day(i), ms: recentMs),
          for (var i = 7; i < 28; i++)
            (date: day(i), ms: i.isEven ? 51.0 : 38.0),
        ];

    test('within the usual range', () {
      final s = HrvStatus.evaluate(series(44), today: today)!;
      expect(s.status, RangeStatus.within);
      expect(s.sevenDayAvgMs, 44);
      expect(s.message, startsWith('HRV within your usual range (7-day avg 44 ms; usual '));
    });

    test('above and below say so', () {
      expect(HrvStatus.evaluate(series(80), today: today)!.status, RangeStatus.above);
      expect(HrvStatus.evaluate(series(20), today: today)!.status, RangeStatus.below);
      expect(HrvStatus.evaluate(series(20), today: today)!.message,
          contains('below your usual range'));
    });

    test('the recent week is NOT part of its own reference range', () {
      // If the week were included, 7 very low nights would drag the range down
      // and read as "within".
      final s = HrvStatus.evaluate(series(10), today: today)!;
      expect(s.range.low, greaterThan(30));
      expect(s.status, RangeStatus.below);
    });

    test('too few recent nights, or too little history, says nothing', () {
      final fewRecent = [
        for (var i = 0; i < 3; i++) (date: day(i), ms: 44.0),
        for (var i = 7; i < 28; i++) (date: day(i), ms: i.isEven ? 51.0 : 38.0),
      ];
      expect(HrvStatus.evaluate(fewRecent, today: today), isNull);

      final fewReference = [
        for (var i = 0; i < 7; i++) (date: day(i), ms: 44.0),
        for (var i = 7; i < 12; i++) (date: day(i), ms: 40.0),
      ];
      expect(HrvStatus.evaluate(fewReference, today: today), isNull);
    });

    test('four recent nights is enough; three is not', () {
      List<({DateTime date, double ms})> withRecent(int n) => [
            for (var i = 0; i < n; i++) (date: day(i), ms: 44.0),
            for (var i = 7; i < 28; i++) (date: day(i), ms: i.isEven ? 51.0 : 38.0),
          ];
      expect(HrvStatus.evaluate(withRecent(4), today: today), isNotNull);
      expect(HrvStatus.evaluate(withRecent(3), today: today), isNull);
    });

    test('readings older than four weeks are ignored', () {
      final stale = [
        for (var i = 0; i < 7; i++) (date: day(i), ms: 44.0),
        for (var i = 40; i < 61; i++) (date: day(i), ms: 40.0),
      ];
      expect(HrvStatus.evaluate(stale, today: today), isNull);
    });
  });
}
