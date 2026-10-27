/// "Up 12% on your 90-day average", and what would turn a flat or falling trend.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/walking_trends.dart';

void main() {
  final today = DateTime(2026, 6, 30);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  /// [steps] on each of the last [days] days, from [from] days ago.
  Map<DateTime, int> run(int steps, {int days = 90, int from = 0}) =>
      {for (var i = from; i < from + days; i++) ago(i): steps};

  Map<DateTime, int> merge(List<Map<DateTime, int>> parts) =>
      {for (final p in parts) ...p};

  WalkingTrend? trend(Map<DateTime, int> d) =>
      WalkingTrends.compute(d, today: today);
  WalkingTrend? trend2(Map<DateTime, int> d, {required DateTime today}) =>
      WalkingTrends.compute(d, today: today);

  group('the direction', () {
    test('up: the last four weeks above the 90 days by more than 5%', () {
      // 62 older days at 7,000, the last 28 at 9,000.
      final t = trend(merge([run(9000, days: 28), run(7000, days: 62, from: 28)]))!;
      expect(t.direction, WalkingDirection.up);
      expect(t.recentAvg, 9000);
      expect(t.baselineAvg, 7622); // (28*9000 + 62*7000) / 90
      expect(t.deltaPercent, 18);
      expect(t.extraPerDayToTurnUp, isNull, reason: 'it is already up');
    });

    test('down', () {
      final t = trend(merge([run(5000, days: 28), run(8000, days: 62, from: 28)]))!;
      expect(t.direction, WalkingDirection.down);
      expect(t.deltaPercent, lessThan(-5));
    });

    test('steady: within 5% either way', () {
      final t = trend(merge([run(8200, days: 28), run(8000, days: 62, from: 28)]))!;
      expect(t.direction, WalkingDirection.steady);
    });

    test('the band is 5% of the 90-day average, to the step', () {
      // 62 older days at 10,000 and the last 28 at R. The 90-day average moves
      // with R, so up begins where R >= 1.05 * (28R + 62 * 10000) / 90.
      WalkingDirection at(int r) => trend(
              merge([run(r, days: 28), run(10000, days: 62, from: 28)]))!
          .direction;
      expect(at(10743), WalkingDirection.up);
      expect(at(10742), WalkingDirection.steady);
      // And down begins where R <= 0.95 * (28R + 62 * 10000) / 90.
      expect(at(9291), WalkingDirection.steady);
      expect(at(9290), WalkingDirection.down);
    });
  });

  group('the figures', () {
    test('averages and the percentage are rounded, not cut', () {
      // 28 days at 9,201, the older 62 at 7,000: the 90-day mean is 7,684.78.
      final up = trend(merge([run(9201, days: 28), run(7000, days: 62, from: 28)]))!;
      expect(up.recentAvg, 9201);
      expect(up.baselineAvg, 7685);
      expect(up.deltaPercent, 20); // 19.73
      // And below: 7,000 against a mean of 7,688.89 is 8.96% under.
      final down = trend(merge([run(7000, days: 28), run(8000, days: 62, from: 28)]))!;
      expect(down.baselineAvg, 7689);
      expect(down.deltaPercent, -9);
    });

    test('a recent average that is not whole is rounded', () {
      // 27 days at 9,000 and one at 9,020: 9,000.71.
      final d = merge([
        run(9000, days: 28)..[ago(2)] = 9020,
        run(7000, days: 62, from: 28),
      ]);
      expect(trend(d)!.recentAvg, 9001);
    });

    test('the days counted are those with steps', () {
      final t = trend(merge([run(9000, days: 28), run(7000, days: 62, from: 28)]))!;
      expect(t.recentDays, 28);
      expect(t.baselineDays, 90);
    });
  });

  group('what it needs before it speaks', () {
    test('fourteen walking days in the last four weeks, forty-five in 90', () {
      Map<DateTime, int> every(int step, {int count = 90}) => {
            for (var i = 0; i < count; i += step) ago(i): 8000,
          };
      expect(trend(run(8000, days: 90)), isNotNull);
      // Every other day: 14 in 28, 45 in 90: just enough.
      expect(trend(every(2)), isNotNull);
      // Every third day: 10 in 28.
      expect(trend(every(3)), isNull);
    });

    test('thirteen is not fourteen', () {
      final d = merge([
        {for (var i = 0; i < 13; i++) ago(i): 8000},
        run(8000, days: 62, from: 28),
      ]);
      expect(trend(d), isNull);
    });

    test('44 days in 90 is not 45', () {
      final d = merge([
        run(8000, days: 28),
        {for (var i = 28; i < 44; i++) ago(i): 8000},
      ]);
      expect(trend(d), isNull);
      final d45 = merge([d, {ago(44): 8000}]);
      expect(trend(d45), isNotNull);
    });

    test('no data is no trend', () {
      expect(trend(const {}), isNull);
    });
  });

  group('days that do not count', () {
    test('a day with no steps is not a day of zero', () {
      // 28 days at 9,000 with two days of 0 and the rest of the 90 at 7,000.
      final d = merge([
        run(9000, days: 28),
        {ago(3): 0, ago(10): 0},
        run(7000, days: 62, from: 28),
      ]);
      final t = trend(d)!;
      expect(t.recentAvg, 9000, reason: 'two zero days are left out, not averaged');
      expect(t.recentDays, 26);
    });

    test('a day the caller left out (rest, unwell) is simply missing', () {
      final d = run(9000, days: 28)..remove(ago(5));
      final t = trend(merge([d, run(7000, days: 62, from: 28)]))!;
      expect(t.recentDays, 27);
    });

    test('days before the window are ignored', () {
      final d = merge([run(8000, days: 90), run(100, days: 30, from: 90)]);
      expect(trend(d)!.baselineAvg, 8000);
    });

    test('and days after today are too', () {
      final d = merge([run(8000, days: 90), {ago(-3): 30000}]);
      expect(trend(d)!.recentAvg, 8000);
    });
  });

  group('what would turn it up', () {
    test('a steady trend: how much more a day, held for three weeks', () {
      final t = trend(merge([run(8000, days: 28), run(8000, days: 62, from: 28)]))!;
      expect(t.direction, WalkingDirection.steady);
      expect(t.extraPerDayToTurnUp, isNotNull);
      expect(t.extraPerDayToTurnUp! % 100, 0);
      expect(t.extraPerDayToTurnUp, greaterThan(0));
    });

    test('it is the smallest multiple of 100 that does it', () {
      final d = merge([run(8000, days: 28), run(8000, days: 62, from: 28)]);
      final extra = trend(d)!.extraPerDayToTurnUp!;

      // Play it out: three weeks at 8,000 + extra, then read the trend again.
      WalkingDirection after(int e) => trend2(
            {...d, for (var i = 1; i <= 21; i++) ago(-i): 8000 + e},
            today: ago(-21),
          )!
              .direction;

      expect(after(extra), WalkingDirection.up);
      expect(after(extra - 100), isNot(WalkingDirection.up),
          reason: '100 fewer would not turn it');
    });

    test('the plan starts tomorrow: today keeps its own steps', () {
      // Steady at 8,000, but today alone is 16,000. Today stays in the last
      // week that carries into the plan, so it lowers what is needed.
      final plain = merge([run(8000, days: 28), run(8000, days: 62, from: 28)]);
      final spiked = {...plain, ago(0): 16000};
      expect(trend(plain)!.extraPerDayToTurnUp, 800);
      expect(trend(spiked)!.direction, WalkingDirection.steady);
      expect(trend(spiked)!.extraPerDayToTurnUp, lessThan(800));
    });

    test('a bad week inside the month is counted in what the plan carries', () {
      // Three good weeks and then a week at 5,000 against 7,000 before them:
      // steady. The bad week is still in the last seven days when the plan
      // starts, and three weeks of plan make up the rest of the month.
      final d = merge([
        run(5000, days: 7),
        run(8000, days: 21, from: 7),
        run(7000, days: 62, from: 28),
      ]);
      final t = trend(d)!;
      expect(t.direction, WalkingDirection.steady);
      expect(t.extraPerDayToTurnUp, 1600);

      // The same, falling.
      final down = merge([
        run(6000, days: 7),
        run(6000, days: 21, from: 7),
        run(8000, days: 62, from: 28),
      ]);
      expect(trend(down)!.direction, WalkingDirection.down);
      expect(trend(down)!.extraPerDayToTurnUp, 2500);
    });

    test('holding today\'s pace can be enough, and says so with zero', () {
      // The last week is stronger than the three before it: steady today, but
      // three more weeks at the four-week average would turn it up.
      final d = merge([
        run(10000, days: 7),
        run(8000, days: 21, from: 7),
        run(8200, days: 62, from: 28),
      ]);
      final t = trend(d)!;
      expect(t.direction, WalkingDirection.steady);
      expect(t.extraPerDayToTurnUp, 0);
    });

    test('a falling trend needs more than a steady one', () {
      final steady = trend(merge([run(8000, days: 28), run(8000, days: 62, from: 28)]))!;
      final down = trend(merge([run(7000, days: 28), run(8000, days: 62, from: 28)]))!;
      expect(down.direction, WalkingDirection.down);
      expect(steady.extraPerDayToTurnUp, 800);
      expect(down.extraPerDayToTurnUp, 1700);
    });

    test('an already-up trend asks for nothing', () {
      final t = trend(merge([run(10000, days: 28), run(7000, days: 62, from: 28)]))!;
      expect(t.extraPerDayToTurnUp, isNull);
    });

    test('a gap too big to close is not offered', () {
      // 5,000 against 8,000 would take 3,400 more a day: past the 3,000 cap.
      final t = trend(merge([run(5000, days: 28), run(8000, days: 62, from: 28)]))!;
      expect(t.direction, WalkingDirection.down);
      expect(t.extraPerDayToTurnUp, isNull);
    });

    test('the cap itself is allowed, 100 more is not', () {
      // The last four weeks at 5,000. Against older days at 7,600 the smallest
      // lift that turns it up is 2,958, so 3,000; against 7,700 it is 3,053,
      // so 3,100: past the cap.
      Map<DateTime, int> d(int older) =>
          merge([run(5000, days: 28), run(older, days: 62, from: 28)]);
      expect(trend(d(7600))!.extraPerDayToTurnUp, WalkingTrends.maxExtraPerDay);
      expect(trend(d(7700))!.extraPerDayToTurnUp, isNull);
    });
  });
}
