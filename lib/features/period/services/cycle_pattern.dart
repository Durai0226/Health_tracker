/// Whether recent cycles vary enough to be worth mentioning at a check-up.
///
/// Pure Dart over the cycles [CyclePredictor.deriveCycles] already makes.
///
/// What is said, and what is not. This reports a spread in what was LOGGED:
/// "your last 6 cycles ran from 24 to 36 days". It does not call anything
/// irregular, abnormal or a condition, and it says in as many words that it is
/// not a diagnosis. The thresholds below are common clinical rules of thumb, not
/// a screening standard, and want a clinician's review before they are relied on.
library;

import 'package:flutter/foundation.dart';

import 'cycle_predictor.dart';

enum CycleFlag {
  /// The shortest and longest of the recent cycles are far apart.
  varied,

  /// Several cycles shorter than [CyclePatternCheck.shortCycleDays].
  short,

  /// Several cycles longer than [CyclePatternCheck.longCycleDays].
  long,

  /// Several periods lasting longer than [CyclePatternCheck.longPeriodDays].
  longPeriod,
}

@immutable
class CyclePattern {
  const CyclePattern({
    required this.cyclesCounted,
    required this.shortest,
    required this.longest,
    required this.flags,
  });

  /// How many completed cycles it looked at.
  final int cyclesCounted;

  /// Shortest and longest cycle length among them, in days.
  final int shortest;
  final int longest;

  final Set<CycleFlag> flags;

  /// Longest minus shortest.
  int get spread => longest - shortest;

  /// One line, for the card.
  String get headline {
    if (flags.contains(CycleFlag.varied)) {
      return 'Your last $cyclesCounted cycles varied by $spread days';
    }
    if (flags.contains(CycleFlag.short)) {
      return 'Several of your last $cyclesCounted cycles were short';
    }
    if (flags.contains(CycleFlag.long)) {
      return 'Several of your last $cyclesCounted cycles were long';
    }
    return 'Several of your recent periods lasted longer than a week';
  }

  /// What it means, and what it does not.
  String get detail {
    final range = 'They ran from $shortest to $longest days.';
    final String why;
    if (flags.contains(CycleFlag.varied)) {
      why = 'A spread of more than about a week is worth mentioning at a '
          'check-up.';
    } else if (flags.contains(CycleFlag.short)) {
      why = 'Cycles under ${CyclePatternCheck.shortCycleDays} days are worth '
          'mentioning at a check-up.';
    } else if (flags.contains(CycleFlag.long)) {
      why = 'Cycles over ${CyclePatternCheck.longCycleDays} days are worth '
          'mentioning at a check-up.';
    } else {
      why = 'Periods lasting more than ${CyclePatternCheck.longPeriodDays} '
          'days are worth mentioning at a check-up.';
    }
    return '$range $why This is a pattern in what you logged, not a diagnosis.';
  }
}

class CyclePatternCheck {
  const CyclePatternCheck._();

  /// Completed cycles needed before anything is said.
  static const int minCycles = 4;

  /// The most recent this many are looked at.
  static const int window = 6;

  /// Shortest-to-longest, in days, from which the variation is worth a word:
  /// more than a week.
  static const int variedSpreadDays = 8;

  static const int shortCycleDays = 21;
  static const int longCycleDays = 38;
  static const int longPeriodDays = 8;

  /// How many of the recent cycles must be short, long, or have a long period
  /// before it is a pattern rather than one odd month.
  static const int repeatsNeeded = 2;

  /// The pattern in [cycles] (any order, open cycle included), or null when
  /// there are too few completed cycles or nothing worth saying.
  static CyclePattern? check(List<DerivedCycle> cycles) {
    final completed = [
      for (final c in cycles)
        if (c.cycleLengthDays != null) c,
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (completed.length < minCycles) return null;

    final recent = completed.length <= window
        ? completed
        : completed.sublist(completed.length - window);
    final lengths = [for (final c in recent) c.cycleLengthDays!];
    final shortest = lengths.reduce((a, b) => a < b ? a : b);
    final longest = lengths.reduce((a, b) => a > b ? a : b);

    final flags = <CycleFlag>{
      if (longest - shortest >= variedSpreadDays) CycleFlag.varied,
      if (lengths.where((l) => l < shortCycleDays).length >= repeatsNeeded)
        CycleFlag.short,
      if (lengths.where((l) => l > longCycleDays).length >= repeatsNeeded)
        CycleFlag.long,
      if (recent.where((c) => c.periodLengthDays > longPeriodDays).length >=
          repeatsNeeded)
        CycleFlag.longPeriod,
    };
    if (flags.isEmpty) return null;
    return CyclePattern(
      cyclesCounted: recent.length,
      shortest: shortest,
      longest: longest,
      flags: flags,
    );
  }
}
