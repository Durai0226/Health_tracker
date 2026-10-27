/// The 0–100 sleep score and the three parts it is made of.
///
/// 60 points for how long you slept against your target, 25 for how much of
/// your time in bed was asleep, 15 for how steady your bedtime has been. The
/// score has always been this sum; what it never did was say so, so "72" asked
/// to be taken on trust. Showing the parts is what makes it something a person
/// can act on — a 72 that is all duration points reads very differently from one
/// that lost them to a ragged bedtime.
library;

import 'package:flutter/foundation.dart';

@immutable
class SleepScoreParts {
  /// Whole points, which add up to [total] exactly.
  final int duration;
  final int efficiency;
  final int regularity;

  const SleepScoreParts(this.duration, this.efficiency, this.regularity);

  int get total => duration + efficiency + regularity;

  @override
  String toString() => 'SleepScoreParts($duration/60, $efficiency/25, $regularity/15)';
}

class SleepScore {
  const SleepScore._();

  static const int maxDuration = 60;
  static const int maxEfficiency = 25;
  static const int maxRegularity = 15;

  /// The score itself, 0–100.
  ///
  /// [efficiency] and [regularity] are fractions in 0..1.
  static int score({
    required int asleepMinutes,
    required int targetMinutes,
    required double efficiency,
    required double regularity,
  }) {
    final target = targetMinutes <= 0 ? 480 : targetMinutes;
    final durationRatio = (asleepMinutes / target).clamp(0.0, 1.0);
    final raw = durationRatio * maxDuration +
        efficiency.clamp(0.0, 1.0) * maxEfficiency +
        regularity.clamp(0.0, 1.0) * maxRegularity;
    return raw.round().clamp(0, 100);
  }

  /// The three parts of a stored [total] score, in whole points that sum to it.
  ///
  /// Duration and efficiency are worked out from the night itself. Regularity is
  /// what is left of the stored score: it depends on the bedtimes of the nights
  /// around this one, which have moved on since the score was saved, and a
  /// breakdown that does not add up to the number on the ring would be worse
  /// than none. The remainder is clamped to its 15 points; anything above that is
  /// given to duration, then efficiency, up to their caps.
  static SleepScoreParts parts({
    required int total,
    required int asleepMinutes,
    required int targetMinutes,
    required double efficiency,
  }) {
    final target = targetMinutes <= 0 ? 480 : targetMinutes;
    final t = total.clamp(0, 100);

    var duration =
        ((asleepMinutes / target).clamp(0.0, 1.0) * maxDuration).round();
    var eff = (efficiency.clamp(0.0, 1.0) * maxEfficiency).round();

    // Never let the two exact parts claim more than the whole score.
    if (duration + eff > t) {
      var over = duration + eff - t;
      final fromDuration = over.clamp(0, duration);
      duration -= fromDuration;
      over -= fromDuration;
      eff -= over.clamp(0, eff);
    }

    var regularity = t - duration - eff;
    if (regularity > maxRegularity) {
      // The stored score is higher than these two parts plus a full bedtime can
      // explain — the target moved since. Hand the excess to duration first,
      // then efficiency, each up to its own cap. The caps total 100, so a score
      // of 0–100 always fits.
      var excess = regularity - maxRegularity;
      regularity = maxRegularity;
      final toDuration = excess.clamp(0, maxDuration - duration);
      duration += toDuration;
      excess -= toDuration;
      eff += excess.clamp(0, maxEfficiency - eff);
    }
    return SleepScoreParts(duration, eff, regularity);
  }
}
