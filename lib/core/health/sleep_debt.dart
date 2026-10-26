/// Sleep debt that weighs RECENT nights more, can't be wiped out by one lie-in,
/// and says what it would take to clear.
///
/// A plain total over the last week treats a bad night six days ago the same as
/// last night, and lets one 11-hour Sunday cancel a week of 6-hour nights. Real
/// recovery does neither, so:
///
///  * the window is 14 nights, each weighted by `0.5^(age / 7)` — last night
///    counts fully, a week ago half, two weeks ago a quarter;
///  * a night's surplus is credited at most [maxCreditPerNight] minutes, so a
///    lie-in pays back an hour of debt, not a whole week's;
///  * only nights that were LOGGED count. An unlogged night is missing data, not
///    zero sleep (the defect `sleep_debt_honesty_test` exists for).
library;

import 'package:flutter/foundation.dart';

/// One logged night: how many nights before today it was, and minutes asleep.
typedef LoggedNight = ({int ageDays, int asleepMinutes});

@immutable
class SleepCatchUp {
  /// Extra minutes of sleep per night, a multiple of 5.
  final int minutesPerNight;

  /// How long to spread it over: 7 or 14 days.
  final int days;
  const SleepCatchUp(this.minutesPerNight, this.days);
}

@immutable
class SleepDebtResult {
  /// Weighted debt in minutes. Positive is behind; never negative, because a
  /// capped credit is not a measure of how far AHEAD someone is.
  final int debtMinutes;

  /// Logged nights in the window the debt is quoted over.
  final int nights;

  /// What clears it at a sensible pace, or null when there is no debt or it is
  /// too large to clear by sleeping a little more each night.
  final SleepCatchUp? catchUp;

  const SleepDebtResult({
    required this.debtMinutes,
    required this.nights,
    required this.catchUp,
  });

  static const none = SleepDebtResult(debtMinutes: 0, nights: 0, catchUp: null);

  static String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// "4h 20m behind over 14 nights — about 25 extra minutes a night for a week
  /// clears it." Gentle and specific; no guilt word.
  String get behindLine {
    final over = '$nights night${nights == 1 ? '' : 's'}';
    final c = catchUp;
    if (c == null) {
      return '${_hm(debtMinutes)} behind over $over — spreading some extra '
          'rest across the next couple of weeks would help.';
    }
    final span = c.days == 7 ? 'a week' : 'two weeks';
    return '${_hm(debtMinutes)} behind over $over — about '
        '${c.minutesPerNight} extra minutes a night for $span clears it.';
  }
}

class SleepDebt {
  const SleepDebt._();

  static const int windowDays = 14;
  static const double halfLifeDays = 7;

  /// The most one night can pay back.
  static const int maxCreditPerNight = 60;

  /// Fewest logged nights the debt is quoted from (the callers' gate).
  static const int minNights = 4;

  /// A catch-up asking for more than this a night is not a realistic plan.
  static const int maxCatchUpPerNight = 60;

  static double _weight(int ageDays) =>
      _pow2neg(ageDays / halfLifeDays);

  // 0.5^x without dart:math's generic pow dependency on a double exponent
  // rounding quirk: exp/ln form is exact enough and keeps this file import-free.
  static double _pow2neg(double x) {
    // 0.5^x = e^(-x ln 2)
    const ln2 = 0.6931471805599453;
    return _exp(-x * ln2);
  }

  static double _exp(double x) {
    // Range here is [-ln2*2, 0]; a 20-term Taylor series is well within 1e-12.
    var term = 1.0, sum = 1.0;
    for (var i = 1; i < 24; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }

  /// [nights] are the LOGGED nights within the last [windowDays]; nights outside
  /// it or with no sleep are ignored. [targetMinutes] is the nightly goal.
  static SleepDebtResult compute({
    required List<LoggedNight> nights,
    required int targetMinutes,
  }) {
    final used = nights
        .where((n) =>
            n.ageDays >= 0 && n.ageDays < windowDays && n.asleepMinutes > 0)
        .toList();
    if (used.isEmpty || targetMinutes <= 0) return SleepDebtResult.none;

    var weighted = 0.0;
    var weightSum = 0.0;
    for (final n in used) {
      final deficit = targetMinutes - n.asleepMinutes;
      // A surplus pays back at most an hour.
      final d = deficit < -maxCreditPerNight ? -maxCreditPerNight : deficit;
      final w = _weight(n.ageDays);
      weighted += w * d;
      weightSum += w;
    }
    // Mean weighted nightly shortfall, scaled back up to the number of nights
    // quoted so the figure reads like a total ("behind over 14 nights").
    final debt = ((weighted / weightSum) * used.length).round();
    if (debt <= 0) {
      return SleepDebtResult(debtMinutes: 0, nights: used.length, catchUp: null);
    }
    return SleepDebtResult(
        debtMinutes: debt, nights: used.length, catchUp: _catchUp(debt));
  }

  static SleepCatchUp? _catchUp(int debt) {
    int perNight(int days) => ((debt / days) / 5).ceil() * 5;
    final week = perNight(7);
    if (week <= maxCatchUpPerNight) return SleepCatchUp(week, 7);
    final fortnight = perNight(14);
    if (fortnight <= maxCatchUpPerNight) return SleepCatchUp(fortnight, 14);
    return null;
  }
}
