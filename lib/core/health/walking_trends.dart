/// "Up 12% on your 90-day average — 8,450 a day over the last 4 weeks against
/// 7,540 over 90" and, when it is not up, what would turn it.
///
/// Pure Dart over a list of daily step totals. Rest and unwell days are left out
/// by the caller (a paused day is not a walking day), and so is any day with no
/// steps recorded at all: a day nobody wore a phone says nothing about walking.
/// It reports a direction and a size; it does not call anything good or bad.
library;

enum WalkingDirection { up, steady, down }

class WalkingTrend {
  const WalkingTrend({
    required this.recentAvg,
    required this.baselineAvg,
    required this.direction,
    required this.recentDays,
    required this.baselineDays,
    this.extraPerDayToTurnUp,
  });

  /// The average over the last [WalkingTrends.recentWindow] days.
  final int recentAvg;

  /// The average over the last [WalkingTrends.baselineWindow] days.
  final int baselineAvg;

  final WalkingDirection direction;

  /// Days with steps in each window.
  final int recentDays;
  final int baselineDays;

  /// For a trend that is not up: the extra steps a day on today's pace, kept up
  /// for [WalkingTrends.planDays], that would turn it up (a multiple of 100;
  /// zero when holding today's pace would already do it). Null when it is
  /// already up, or would take more than [WalkingTrends.maxExtraPerDay].
  final int? extraPerDayToTurnUp;

  /// Percent the recent average is above (positive) or below the baseline. The
  /// baseline is never zero: it averages days that have steps.
  int get deltaPercent => ((recentAvg - baselineAvg) / baselineAvg * 100).round();
}

class WalkingTrends {
  const WalkingTrends._();

  static const int recentWindow = 28;
  static const int baselineWindow = 90;

  /// Days with steps needed in each window before anything is said.
  static const int minRecentDays = 14;
  static const int minBaselineDays = 45;

  /// Within this share of the baseline either way is "steady".
  static const double steadyBand = 0.05;

  /// How long the suggested lift is held, and the most it may ask.
  static const int planDays = 21;
  static const int maxExtraPerDay = 3000;

  /// The trend ending on [today], from [daily] totals keyed by calendar day.
  /// Days missing from the map, or at zero, are not walking days on record.
  static WalkingTrend? compute(Map<DateTime, int> daily, {required DateTime today}) {
    final end = _day(today);
    final now = _read(daily, end);
    if (now == null) return null;
    final direction = _direction(now.recent, now.baseline);
    return WalkingTrend(
      recentAvg: now.recent.round(),
      baselineAvg: now.baseline.round(),
      direction: direction,
      recentDays: now.recentDays,
      baselineDays: now.baselineDays,
      extraPerDayToTurnUp: direction == WalkingDirection.up
          ? null
          : _extraToTurnUp(daily, end, now.recent),
    );
  }

  /// The two averages ending on [end], or null without enough walking days.
  static _Reading? _read(Map<DateTime, num> daily, DateTime end) {
    List<num> window(int days) => [
          for (var i = 0; i < days; i++)
            if ((daily[DateTime(end.year, end.month, end.day - i)] ?? 0) > 0)
              daily[DateTime(end.year, end.month, end.day - i)]!,
        ];
    final recent = window(recentWindow);
    final baseline = window(baselineWindow);
    if (recent.length < minRecentDays || baseline.length < minBaselineDays) {
      return null;
    }
    return _Reading(_mean(recent), _mean(baseline), recent.length, baseline.length);
  }

  static WalkingDirection _direction(double recent, double baseline) {
    if (recent >= baseline * (1 + steadyBand)) return WalkingDirection.up;
    if (recent <= baseline * (1 - steadyBand)) return WalkingDirection.down;
    return WalkingDirection.steady;
  }

  /// The smallest extra (a multiple of 100, which may be none at all) such that
  /// walking [recentAvg] + extra on each of the next [planDays] days leaves the
  /// trend "up" when those days are in.
  ///
  /// It plays the plan forward on a copy of the record and reads it with the
  /// same windows and rules as today's trend, so the two cannot drift apart. Of
  /// the 28 days it reads, 21 are the plan, so it always has days enough to say.
  static int? _extraToTurnUp(
      Map<DateTime, num> daily, DateTime end, double recentAvg) {
    final later = DateTime(end.year, end.month, end.day + planDays);
    for (var extra = 0; extra <= maxExtraPerDay; extra += 100) {
      final plan = recentAvg + extra;
      final future = {
        ...daily,
        for (var i = 1; i <= planDays; i++)
          DateTime(end.year, end.month, end.day + i): plan,
      };
      final then = _read(future, later)!;
      if (_direction(then.recent, then.baseline) == WalkingDirection.up) {
        return extra;
      }
    }
    return null;
  }

  static double _mean(List<num> v) => v.reduce((a, b) => a + b) / v.length;
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _Reading {
  const _Reading(this.recent, this.baseline, this.recentDays, this.baselineDays);

  final double recent;
  final double baseline;
  final int recentDays;
  final int baselineDays;
}
