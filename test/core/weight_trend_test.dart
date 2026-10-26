import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/weight_trend.dart';

void main() {
  WeightPoint p(int day, double kg, {int hour = 7}) =>
      WeightPoint(DateTime(2026, 1, 1 + day, hour), kg);

  /// One reading a day for [n] days, falling [perDay] kg a day from [from].
  List<WeightPoint> steady(int n, {double from = 80, double perDay = -0.1}) =>
      [for (var i = 0; i < n; i++) p(i, from + perDay * i)];

  group('compute', () {
    test('no readings, no trend', () {
      expect(WeightTrend.compute(const []), isNull);
    });

    test('one reading is its own trend, with no rate', () {
      final t = WeightTrend.compute([p(0, 80)])!;
      expect(t.trendKg, 80);
      expect(t.ratePerWeekKg, isNull);
      expect(t.weighedDays, 1);
    });

    test('a single spike barely moves the trend', () {
      final t = WeightTrend.compute([
        for (var i = 0; i < 10; i++) p(i, 80),
        p(10, 82), // a salty dinner
      ])!;
      expect(t.trendKg, closeTo(80.2, 0.001),
          reason: 'one day moves the trend a tenth of the way: 80 + 0.1 * 2');
    });

    test('the order of the input does not matter', () {
      final a = WeightTrend.compute(steady(20))!;
      final b = WeightTrend.compute(steady(20).reversed.toList())!;
      expect(b.trendKg, closeTo(a.trendKg, 1e-9));
      expect(b.ratePerWeekKg, closeTo(a.ratePerWeekKg!, 1e-9));
    });

    test('several readings in one day count once, as their mean', () {
      final once = WeightTrend.compute([p(0, 80), p(1, 79)])!;
      final twice = WeightTrend.compute(
          [p(0, 80), p(1, 78, hour: 7), p(1, 80, hour: 21)])!;
      expect(twice.weighedDays, 2);
      expect(twice.trendKg, closeTo(once.trendKg, 1e-9));
    });

    test('perPoint lines up with the input, same-day readings sharing a value',
        () {
      final pts = [p(0, 80), p(1, 78, hour: 7), p(1, 80, hour: 21), p(2, 79)];
      final t = WeightTrend.compute(pts)!;
      expect(t.perPoint, hasLength(4));
      expect(t.perPoint[1], t.perPoint[2]);
      expect(t.perPoint[0], 80);
      expect(t.perPoint.last, t.trendKg);
    });

    test('a long gap counts for more than a daily step', () {
      final daily = WeightTrend.compute([p(0, 80), p(1, 78)])!;
      final afterGap = WeightTrend.compute([p(0, 80), p(14, 78)])!;
      expect(afterGap.trendKg, lessThan(daily.trendKg),
          reason: 'a reading after two weeks away says more about now');
    });
  });

  group('rate', () {
    test('needs four weighed days across a fortnight', () {
      expect(WeightTrend.compute(steady(3))!.ratePerWeekKg, isNull);
      expect(WeightTrend.compute(steady(13))!.ratePerWeekKg, isNull,
          reason: 'thirteen days of data is not yet a fortnight apart');
      expect(WeightTrend.compute(steady(15))!.ratePerWeekKg, isNotNull);
    });

    test('three readings are not enough, however far apart', () {
      expect(WeightTrend.compute([p(0, 80), p(14, 79), p(27, 78)])!.ratePerWeekKg,
          isNull,
          reason: 'a line through three points is not a rate worth quoting');
    });

    test('four readings spread over a fortnight are enough', () {
      final t = WeightTrend.compute(
          [p(0, 80), p(5, 79.5), p(10, 79), p(14, 78.6)])!;
      expect(t.ratePerWeekKg, isNotNull);
      expect(t.ratePerWeekKg!, lessThan(0));
    });

    test('a steady fall of 0.1 kg a day is about −0.7 kg a week', () {
      final r = WeightTrend.compute(steady(28))!.ratePerWeekKg!;
      expect(r, closeTo(-0.7, 0.1));
    });

    test('a steady gain reads positive', () {
      expect(WeightTrend.compute(steady(28, perDay: 0.05))!.ratePerWeekKg!,
          greaterThan(0.2));
    });

    test('flat weight with noise reads close to zero', () {
      final noisy = [
        for (var i = 0; i < 28; i++) p(i, 80 + (i.isEven ? 0.6 : -0.6)),
      ];
      expect(WeightTrend.compute(noisy)!.ratePerWeekKg!.abs(), lessThan(0.1));
    });

    test('only the last four weeks count', () {
      // Fell fast for a month, then held steady for five weeks.
      final pts = [
        for (var i = 0; i < 30; i++) p(i, 90 - i * 0.3),
        for (var i = 30; i < 65; i++) p(i, 81),
      ];
      expect(WeightTrend.compute(pts)!.ratePerWeekKg!.abs(), lessThan(0.15));
    });
  });

  group('forecast', () {
    final today = DateTime(2026, 2, 1);

    WeightTrend trendOf(List<WeightPoint> pts) => WeightTrend.compute(pts)!;

    test('heading down toward a lower goal gives a date', () {
      final t = trendOf(steady(28)); // readings end at 77.3, falling 0.7/week
      final f = t.forecast(73, today: today);
      expect(f.status, GoalStatus.onTrack);
      final days = f.date!.difference(today).inDays;
      expect(days, inInclusiveRange(40, 60),
          reason: 'the trend sits a little above the latest readings (it lags a '
              'fall), so the gap to 73 is ~5 kg, at 0.7 kg/week: about 50 days');
      expect(f.date!.hour, 0);
    });

    test('heading up toward a higher goal gives a date', () {
      final t = trendOf(steady(28, from: 60, perDay: 0.05));
      expect(t.forecast(65, today: today).status, GoalStatus.onTrack);
    });

    test('already there is "reached", whatever the rate', () {
      final t = trendOf(steady(28));
      expect(t.forecast(t.trendKg + 0.2, today: today).status,
          GoalStatus.reached);
      final one = trendOf([p(0, 80)]);
      expect(one.forecast(80.1, today: today).status, GoalStatus.reached);
    });

    test('too little data says so, rather than guessing', () {
      expect(trendOf([p(0, 80), p(1, 79.5)]).forecast(70, today: today).status,
          GoalStatus.notEnoughData);
    });

    test('flat is flat', () {
      final flat = [for (var i = 0; i < 28; i++) p(i, 80.0)];
      expect(trendOf(flat).forecast(75, today: today).status, GoalStatus.flat);
    });

    test('moving away from the goal is called out, not given a date', () {
      final t = trendOf(steady(28, perDay: 0.1)); // gaining
      expect(t.forecast(70, today: today).status, GoalStatus.wrongWay);
      final down = trendOf(steady(28)); // losing
      expect(down.forecast(90, today: today).status, GoalStatus.wrongWay);
    });

    test('more than two years out is not forecast', () {
      final slow = trendOf(steady(28, perDay: -0.01)); // ~0.07 kg a week
      expect(slow.forecast(60, today: today).status, GoalStatus.tooFar);
    });

    test('the date is built on calendar days, across a month end', () {
      final t = WeightTrend(
          trendKg: 80, ratePerWeekKg: -0.7, weighedDays: 20, perPoint: const []);
      final f = t.forecast(79, today: DateTime(2026, 1, 25));
      // 1 kg at 0.1 kg/day = 10 days.
      expect(f.date, DateTime(2026, 2, 4));
    });
  });
}
