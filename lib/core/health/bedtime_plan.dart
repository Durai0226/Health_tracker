/// Tonight's bedtime: the wake time, less the sleep the person needs, less the
/// sleep they owe, less the time they usually lie awake.
///
/// "Aim for 10:40 PM (7 h 45 m of sleep, 20 m of catch-up, about 15 m awake in
/// bed)". A soft target with its working shown, never a prescription: the
/// catch-up is [SleepDebt]'s own gentle figure (at most an hour a night, absent
/// when the debt is too large to clear that way), and the time awake in bed is
/// the person's own, taken only from nights a device measured.
library;

import 'sleep_debt.dart';

class BedtimePlan {
  const BedtimePlan({
    required this.bedMinuteOfDay,
    required this.wakeMinuteOfDay,
    required this.needMinutes,
    required this.catchUpMinutes,
    required this.awakeMinutes,
    required this.awakeIsYours,
  });

  /// When to be in bed, as minutes of the day (0..1439).
  final int bedMinuteOfDay;
  final int wakeMinuteOfDay;

  /// The nightly sleep the person aims for.
  final int needMinutes;

  /// Extra sleep tonight toward the debt; 0 when there is none to clear.
  final int catchUpMinutes;

  /// Time expected awake in bed.
  final int awakeMinutes;

  /// Whether [awakeMinutes] comes from the person's own measured nights rather
  /// than the standard allowance.
  final bool awakeIsYours;

  int get inBedMinutes => needMinutes + catchUpMinutes + awakeMinutes;

  /// When a wind-down reminder [leadMinutes] before bed belongs, as minutes of
  /// the day.
  int windDownMinuteOfDay(int leadMinutes) => _wrap(bedMinuteOfDay - leadMinutes);

  static int _wrap(int m) {
    final r = m % 1440;
    return r < 0 ? r + 1440 : r;
  }
}

class BedtimePlans {
  const BedtimePlans._();

  /// The allowance for lying awake before sleep, until the person's own nights
  /// say otherwise.
  static const int defaultAwakeMinutes = 15;

  /// Measured nights needed before their own time awake is used.
  static const int minNightsForOwnAwake = 7;

  /// Their own figure is kept within this, so one bad week neither empties the
  /// plan of an allowance nor asks for an hour of lying awake.
  static const int minAwakeMinutes = 10;
  static const int maxAwakeMinutes = 45;

  /// Used when no target is set.
  static const int fallbackTargetMinutes = 480;

  /// The plan for the night to come.
  ///
  /// [awakeInBedMinutes] is, per MEASURED recent night, the minutes between
  /// getting into bed and being asleep and awake again; a hand-logged night's is
  /// an estimate from how it was rated, and has no place in it. [debt] is used
  /// only for its catch-up.
  static BedtimePlan compute({
    required int targetMinutes,
    required int wakeMinuteOfDay,
    SleepDebtResult? debt,
    List<int> awakeInBedMinutes = const [],
  }) {
    final need = targetMinutes <= 0 ? fallbackTargetMinutes : targetMinutes;
    final catchUp = debt?.catchUp?.minutesPerNight ?? 0;
    final own = awakeInBedMinutes.length >= minNightsForOwnAwake;
    final awake = own
        ? _roundTo5(_median(awakeInBedMinutes))
            .clamp(minAwakeMinutes, maxAwakeMinutes)
        : defaultAwakeMinutes;
    final inBed = need + catchUp + awake;
    final wake = ((wakeMinuteOfDay % 1440) + 1440) % 1440;
    return BedtimePlan(
      bedMinuteOfDay: BedtimePlan._wrap(wake - inBed),
      wakeMinuteOfDay: wake,
      needMinutes: need,
      catchUpMinutes: catchUp,
      awakeMinutes: awake,
      awakeIsYours: own,
    );
  }

  /// "8 h 20 m", "8 h", "45 m".
  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m m';
    if (m == 0) return '$h h';
    return '$h h $m m';
  }

  static int _median(List<int> values) {
    final s = [...values]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) / 2).round();
  }

  static int _roundTo5(int m) => ((m / 5).round()) * 5;
}
