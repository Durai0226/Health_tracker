import 'package:flutter/foundation.dart';

import '../../../core/utils/calendar_day.dart';
import '../models/period_day.dart';
import '../models/period_symptom.dart';
import 'cycle_predictor.dart';

/// One symptom that comes before this person's periods, and how reliably.
@immutable
class PmsSymptom {
  const PmsSymptom({
    required this.symptomId,
    required this.cyclesWith,
    required this.cyclesCounted,
    required this.typicalDaysBefore,
  });

  final String symptomId;

  /// Cycles in which it showed up in the week before the period.
  final int cyclesWith;

  /// Cycles with enough logged days in that week to say either way.
  final int cyclesCounted;

  /// The usual number of days before the period it is first logged (median
  /// across the cycles it showed up in).
  final int typicalDaysBefore;

  String get label => symptomById(symptomId)?.label ?? symptomId;

  /// "Cramps: usually from 3 days before (4 of 5 cycles)".
  String get line {
    final when = typicalDaysBefore == 1
        ? 'the day before'
        : '$typicalDaysBefore days before';
    return '$label: usually from $when ($cyclesWith of $cyclesCounted cycles)';
  }
}

/// What this person's own log says about the days before a period.
///
/// Pure Dart over logged days and the cycles already derived from them.
///
/// **What it will not do.** It does not say a symptom "is" premenstrual; it says
/// when it has been LOGGED, relative to the period that followed. And it will not
/// say anything about a symptom that is simply always there: a headache logged
/// every other day anywhere in the cycle is not a pre-period pattern, so a
/// symptom has to show up at least twice as often in the week before as it does
/// in the rest of the cycle. For the same reason it needs days logged OUTSIDE
/// that week to compare against: someone who only opens the log when they feel
/// bad would otherwise "have" a pattern in whatever week they happened to open
/// it.
class PmsPatternCheck {
  const PmsPatternCheck._();

  /// The week before a period is where it looks.
  static const int windowDays = 7;

  /// Cycles with enough logging in that week before anything is said.
  static const int minCycles = 3;

  /// Logged days a cycle needs in the window to count at all.
  static const int minLoggedDaysInWindow = 3;

  /// Logged days needed in the rest of the cycles, in all, to have a baseline.
  static const int minBaselineDays = 5;

  /// The share of counted cycles a symptom must appear in.
  static const double minShare = 0.6;

  /// How much more often (per logged day) it must show up before the period
  /// than at other times.
  static const double minRatio = 2.0;

  /// The most that are reported.
  static const int maxSymptoms = 3;

  static List<PmsSymptom> check({
    required Iterable<PeriodDay> days,
    required List<DerivedCycle> cycles,
  }) {
    final byDate = <DateTime, PeriodDay>{
      for (final d in days)
        if (d.hasData) DateTime(d.date.year, d.date.month, d.date.day): d,
    };

    // The cycles that have a next period to count back from, oldest first.
    final completed = [
      for (final c in cycles)
        if (c.cycleLengthDays != null) c,
    ]..sort((a, b) => a.start.compareTo(b.start));

    var cyclesCounted = 0;
    final cyclesWith = <String, int>{};
    final onsets = <String, List<int>>{};
    final preDays = <String, int>{};
    final restDays = <String, int>{};
    var preLogged = 0;
    var restLogged = 0;

    for (final c in completed) {
      final nextStart = dayOffset(c.start, c.cycleLengthDays!);
      // Days before the period, 1 = the day before.
      final window = <int, PeriodDay>{};
      for (var n = 1; n <= windowDays; n++) {
        final d = byDate[dayOffset(nextStart, -n)];
        if (d != null) window[n] = d;
      }
      if (window.length < minLoggedDaysInWindow) continue;
      cyclesCounted++;
      preLogged += window.length;

      final seen = <String>{};
      window.forEach((n, d) {
        for (final id in d.symptomIds.toSet()) {
          preDays[id] = (preDays[id] ?? 0) + 1;
          seen.add(id);
        }
      });
      for (final id in seen) {
        cyclesWith[id] = (cyclesWith[id] ?? 0) + 1;
        // The earliest it was logged this cycle: the largest "days before".
        var earliest = 0;
        window.forEach((n, d) {
          if (d.symptomIds.contains(id) && n > earliest) earliest = n;
        });
        onsets.putIfAbsent(id, () => []).add(earliest);
      }

      // The rest of the cycle: after the period itself, before the window.
      final restStart = dayOffset(c.start, c.periodLengthDays);
      final restEnd = dayOffset(nextStart, -(windowDays + 1));
      for (var d = restStart;
          !d.isAfter(restEnd);
          d = dayOffset(d, 1)) {
        final day = byDate[d];
        if (day == null) continue;
        restLogged++;
        for (final id in day.symptomIds.toSet()) {
          restDays[id] = (restDays[id] ?? 0) + 1;
        }
      }
    }

    if (cyclesCounted < minCycles || restLogged < minBaselineDays) {
      return const [];
    }

    final out = <PmsSymptom>[];
    for (final id in cyclesWith.keys) {
      final withCount = cyclesWith[id]!;
      if (withCount / cyclesCounted < minShare) continue;
      final pre = (preDays[id] ?? 0) / preLogged;
      final rest = (restDays[id] ?? 0) / restLogged;
      if (rest > 0 && pre < rest * minRatio) continue;
      final sorted = [...onsets[id]!]..sort();
      final median = sorted.length.isOdd
          ? sorted[sorted.length ~/ 2]
          : ((sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2)
              .round();
      out.add(PmsSymptom(
        symptomId: id,
        cyclesWith: withCount,
        cyclesCounted: cyclesCounted,
        typicalDaysBefore: median,
      ));
    }
    out.sort((a, b) {
      final share = (b.cyclesWith).compareTo(a.cyclesWith);
      return share != 0 ? share : a.symptomId.compareTo(b.symptomId);
    });
    return out.take(maxSymptoms).toList();
  }
}
