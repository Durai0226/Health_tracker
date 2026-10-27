/// When the day's last caffeine should be, working back from bedtime.
///
/// Caffeine's half-life is roughly five to six hours, so a coffee drunk eight
/// hours before bed still leaves about a third of it in the body at lights-out,
/// and one drunk at four in the afternoon leaves more than half. The common
/// sleep-hygiene advice is to stop about eight hours ahead; this applies it to
/// the bedtime the app already knows, rather than to a fixed "after 2 pm".
///
/// A note, never a block: the drink is already logged, and nobody is told what to
/// do with their evening.
library;

import 'package:flutter/foundation.dart';

@immutable
class CaffeineWarning {
  const CaffeineWarning({required this.cutoff, required this.bedtime});

  /// The time after which caffeine is likely to cut into this sleep.
  final DateTime cutoff;

  /// The bedtime it is measured against.
  final DateTime bedtime;
}

class CaffeineCutoff {
  const CaffeineCutoff._();

  /// How long before bed the last caffeine should be.
  static const int hoursBeforeBed = 8;

  /// Past bedtime, still a note: someone up late goes to bed later, and the
  /// caffeine does not wait for the usual hour. Two hours, then it is no longer
  /// about tonight's sleep.
  static const Duration graceAfterBedtime = Duration(hours: 2);

  /// Under this a drink is not worth a word: decaf, a little in a tea.
  static const int meaningfulMg = 20;

  /// [bedtime] minus [hoursBeforeBed].
  static DateTime cutoffFor(DateTime bedtime) =>
      bedtime.subtract(const Duration(hours: hoursBeforeBed));

  /// A warning for a drink of [caffeineMg] logged at [now], given a usual
  /// bedtime of [bedtimeMinutes] after midnight; null when there is nothing to
  /// say.
  ///
  /// The bedtime considered is whichever of yesterday's, today's and tomorrow's
  /// puts [now] inside its window — so a 00:30 bedtime is "tonight's" at seven
  /// in the evening, and a drink at 02:00 against a 22:30 bedtime is nobody's
  /// business.
  static CaffeineWarning? check({
    required DateTime now,
    required int bedtimeMinutes,
    required int caffeineMg,
  }) {
    if (caffeineMg < meaningfulMg) return null;
    for (final dayShift in const [0, 1, -1]) {
      // Through the constructor so a minute count past 24 hours, or a day
      // shift across a month end, normalises instead of overflowing a field.
      final bedtime = DateTime(
          now.year, now.month, now.day + dayShift, 0, bedtimeMinutes);
      final cutoff = cutoffFor(bedtime);
      final inWindow = !now.isBefore(cutoff) &&
          now.isBefore(bedtime.add(graceAfterBedtime));
      if (inWindow) return CaffeineWarning(cutoff: cutoff, bedtime: bedtime);
    }
    return null;
  }
}
