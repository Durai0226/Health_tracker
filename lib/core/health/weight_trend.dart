/// A smoothed "trend weight", its weekly rate, and — when the data can bear it —
/// the date a goal weight is reached.
///
/// A scale reads 0.5–2 kg of water, salt and timing noise around the real
/// figure, so the latest reading is a poor answer to "am I losing?". The trend
/// is an exponentially smoothed series (the Hacker's Diet method: each reading
/// moves it a tenth of the way, a day at a time), which is what a weekly rate
/// and a goal date should be read from.
///
/// The rate comes from a straight line through the raw daily weights; the
/// smoothed series is for "where am I now" (see `_rate`).
///
/// Honest by construction: no rate until there are four weighed days across a
/// fortnight, no date unless the trend is actually heading toward the goal at a
/// measurable pace, and none at all when it would be more than two years out.
/// Saying nothing is better than "around 14 Dec" built from three readings.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../utils/calendar_day.dart';

/// A weigh-in: when, and kilograms.
@immutable
class WeightPoint {
  final DateTime at;
  final double kg;
  const WeightPoint(this.at, this.kg);
}

/// Where the trend stands against a goal.
enum GoalStatus {
  /// Not enough weighed days yet to say anything about direction.
  notEnoughData,

  /// Within [WeightTrend.goalToleranceKg] of the goal.
  reached,

  /// Heading toward the goal; [GoalForecast.date] is set.
  onTrack,

  /// Not moving enough to put a date on it.
  flat,

  /// Moving away from the goal.
  wrongWay,

  /// Heading toward it, but further out than [WeightTrend.maxForecastDays].
  tooFar,
}

@immutable
class GoalForecast {
  final GoalStatus status;

  /// Only for [GoalStatus.onTrack].
  final DateTime? date;
  const GoalForecast(this.status, {this.date});
}

@immutable
class WeightTrend {
  /// The smoothed weight now, kg.
  final double trendKg;

  /// kg per week (negative = losing), or null before there is enough data.
  final double? ratePerWeekKg;

  /// Weighed calendar days the trend rests on.
  final int weighedDays;

  /// The trend after each input point, in the order the points were given —
  /// readings on the same day share a value. For drawing beside the raw line.
  final List<double> perPoint;

  const WeightTrend({
    required this.trendKg,
    required this.ratePerWeekKg,
    required this.weighedDays,
    required this.perPoint,
  });

  /// How much of the way each day's weigh-in moves the trend.
  static const double dailyWeight = 0.1;

  /// Weighed days and span needed before a rate is quoted.
  static const int minDaysForRate = 4;
  static const int minSpanForRate = 14;

  /// The rate is read from this many trailing days of the trend.
  static const int rateWindowDays = 28;

  /// Slower than this is "flat" — below what a scale can resolve in a week.
  static const double flatKgPerWeek = 0.05;

  /// Within this of the goal counts as there.
  static const double goalToleranceKg = 0.3;

  /// Further out than this is not forecast.
  static const int maxForecastDays = 730;

  /// Null for no points. [points] may be in any order.
  static WeightTrend? compute(List<WeightPoint> points) {
    if (points.isEmpty) return null;

    // One value per calendar day (the day's mean), oldest first.
    final byDay = <DateTime, List<double>>{};
    for (final p in points) {
      byDay.putIfAbsent(DateTime(p.at.year, p.at.month, p.at.day), () => []).add(p.kg);
    }
    final days = byDay.keys.toList()..sort();

    // A day's weigh-in moves the trend a tenth of the way; a gap of g days with
    // no weigh-in is g such steps toward the new reading, so a reading after a
    // fortnight away counts for more than one the day after the last.
    final trendOn = <DateTime, double>{};
    var trend = _mean(byDay[days.first]!);
    trendOn[days.first] = trend;
    for (var i = 1; i < days.length; i++) {
      final gap = calendarDaysBetween(days[i - 1], days[i]);
      final alpha = 1 - math.pow(1 - dailyWeight, gap).toDouble();
      trend += alpha * (_mean(byDay[days[i]]!) - trend);
      trendOn[days[i]] = trend;
    }

    final perPoint = [
      for (final p in points)
        trendOn[DateTime(p.at.year, p.at.month, p.at.day)]!,
    ];

    return WeightTrend(
      trendKg: trend,
      ratePerWeekKg: _rate(days, [for (final d in days) _mean(byDay[d]!)]),
      weighedDays: days.length,
      perPoint: perPoint,
    );
  }

  /// Least-squares slope of the daily weights over the last [rateWindowDays], per
  /// week.
  ///
  /// Read from the raw daily weights, not from the smoothed series: a smoothed
  /// series lags a ramp, so its slope understates a real loss for the first
  /// weeks (about 0.5 kg/week where the true figure is 0.7). The smoothing is
  /// for "where am I now"; the rate is a straight line through what was weighed.
  static double? _rate(List<DateTime> days, List<double> daily) {
    final last = days.last;
    final idx = [
      for (var i = 0; i < days.length; i++)
        if (calendarDaysBetween(days[i], last) < rateWindowDays) i,
    ];
    if (idx.length < minDaysForRate) return null;
    final first = days[idx.first];
    if (calendarDaysBetween(first, last) < minSpanForRate) return null;

    final xs = [for (final i in idx) calendarDaysBetween(first, days[i]).toDouble()];
    final ys = [for (final i in idx) daily[i]];
    final xm = xs.reduce((a, b) => a + b) / xs.length;
    final ym = ys.reduce((a, b) => a + b) / ys.length;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < xs.length; i++) {
      num += (xs[i] - xm) * (ys[i] - ym);
      den += (xs[i] - xm) * (xs[i] - xm);
    }
    if (den == 0) return null;
    return num / den * 7;
  }

  /// Where this trend stands against [goalKg], as of [today].
  GoalForecast forecast(double goalKg, {required DateTime today}) {
    final gap = goalKg - trendKg;
    if (gap.abs() <= goalToleranceKg) return const GoalForecast(GoalStatus.reached);
    final rate = ratePerWeekKg;
    if (rate == null) return const GoalForecast(GoalStatus.notEnoughData);
    if (rate.abs() < flatKgPerWeek) return const GoalForecast(GoalStatus.flat);
    if (gap.sign != rate.sign) return const GoalForecast(GoalStatus.wrongWay);

    final daysAway = (gap / (rate / 7)).round();
    if (daysAway > maxForecastDays) return const GoalForecast(GoalStatus.tooFar);
    return GoalForecast(
      GoalStatus.onTrack,
      date: DateTime(today.year, today.month, today.day + daysAway),
    );
  }

  static double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
}
