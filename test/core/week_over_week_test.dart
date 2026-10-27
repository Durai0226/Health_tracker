import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/week_over_week.dart';

void main() {
  /// A day of 500 steps in each of hours 7..16 (10 hours = 5,000 steps).
  List<int> day({int perHour = 500, int from = 7, int to = 16}) =>
      [for (var h = 0; h < 24; h++) (h >= from && h <= to) ? perHour : 0];

  final noon = DateTime(2026, 3, 10, 12, 0);

  group('stepsBy', () {
    test('adds every finished hour', () {
      expect(WeekOverWeekCalc.stepsBy(day(), noon), 5 * 500, reason: '7..11');
    });
    test('and the elapsed part of the current hour', () {
      expect(WeekOverWeekCalc.stepsBy(day(), DateTime(2026, 3, 10, 12, 30)),
          5 * 500 + 250);
    });
    test('nothing before the first step', () {
      expect(WeekOverWeekCalc.stepsBy(day(), DateTime(2026, 3, 10, 6)), 0);
    });
    test('past midnight-ish end it is the whole day', () {
      expect(WeekOverWeekCalc.stepsBy(day(), DateTime(2026, 3, 10, 23, 59)), 5000);
    });
  });

  group('compare', () {
    WeekOverWeek? cmp(int today,
            {List<int>? hourly, int? total = 5000, DateTime? now}) =>
        WeekOverWeekCalc.compare(
            stepsToday: today,
            now: now ?? noon,
            lastWeekHourly: hourly ?? day(),
            lastWeekTotal: total);

    test('ahead of the same time last week', () {
      final r = cmp(4800)!;
      expect(r.lastWeekSoFar, 2500);
      expect(r.difference, 2300);
      expect(r.isAhead, isTrue);
    });

    test('behind', () {
      final r = cmp(1500)!;
      expect(r.difference, -1000);
      expect(r.isAhead, isFalse);
    });

    test('a difference under 100 is not worth saying', () {
      expect(cmp(2550), isNull);
      expect(cmp(2450), isNull);
      expect(cmp(2600), isNotNull);
    });

    test('too early in the day to mean anything', () {
      expect(cmp(900, now: DateTime(2026, 3, 10, 7, 59)), isNull);
      expect(cmp(900, now: DateTime(2026, 3, 10, 8, 0)), isNotNull);
    });

    test('no hourly record last week, no claim', () {
      expect(cmp(3000, hourly: const []), isNull);
      expect(cmp(3000, hourly: List.filled(24, 0)), isNull);
    });

    test('no total last week, no claim', () {
      expect(cmp(3000, total: null), isNull);
      expect(cmp(3000, total: 0), isNull);
    });

    test('a partial record (synced at 3pm) is refused — it would read as '
        '"way ahead" in the evening', () {
      // Last week's day really had 9,000 steps; the app only saw the first 3,000.
      final partial = day(to: 9); // hours 7..9 = 1,500 steps recorded
      expect(cmp(6000, hourly: partial, total: 9000, now: DateTime(2026, 3, 10, 18)),
          isNull);
    });

    test('coverage of 85% or more is accepted', () {
      // 4,300 of 5,000 recorded = 86%.
      final h = day();
      h[16] = 0;
      h[15] = 200; // 500*8 + 200 = 4200 -> 84%: refused
      expect(cmp(3000, hourly: h), isNull);
      h[15] = 300; // 4300 -> 86%
      expect(cmp(3000, hourly: h), isNotNull);
    });

    test('a malformed bucket list is not trusted', () {
      expect(cmp(3000, hourly: List.filled(12, 500)), isNull);
    });
  });
}
