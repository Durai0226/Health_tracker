/// A bedtime derived from the nights that actually went well, not from the
/// average of all of them.
///
/// `SleepService.averageActualSchedule` already gives the mean bedtime across
/// recent nights — useful for "when do you usually sleep", useless as a target,
/// because it averages the good nights together with the 2am ones the user is
/// trying to stop having. Oura's Bedtime Guidance takes the other approach:
/// look at the nights with the highest sleep scores and point at what those had
/// in common.
///
/// Deterministic and on-device, like everything else in this directory. It is
/// arithmetic over the user's own logged nights, and the honesty rules the rest
/// of the engines follow apply here too — too little history, or no meaningful
/// difference, returns null rather than inventing advice.
library;

/// One night, reduced to what the calculation needs.
class BedtimeNight {
  const BedtimeNight({required this.bedMinutes, required this.score});

  /// Bedtime as minutes-since-midnight.
  final int bedMinutes;

  /// The night's sleep score, 0..100.
  final int score;
}

class BedtimeSuggestion {
  const BedtimeSuggestion({
    required this.bedMinutes,
    required this.shiftMinutes,
    required this.sampleCount,
    required this.averageScoreOfBest,
  });

  /// The suggested bedtime, minutes-since-midnight.
  final int bedMinutes;

  /// Signed minutes from the user's usual bedtime (− = earlier).
  final int shiftMinutes;

  /// How many good nights it is based on.
  final int sampleCount;

  final double averageScoreOfBest;

  bool get isEarlier => shiftMinutes < 0;
}

class BedtimeGuidance {
  const BedtimeGuidance._();

  /// Minutes-since-midnight values near midnight split across the 0/1440
  /// boundary, so a 23:40 and a 00:10 bedtime average to midday. Shifting
  /// pre-noon times by +24h clusters them correctly — the same technique
  /// `SleepService.regularityIndex` and `averageActualSchedule` already use.
  static int _shifted(int bedMinutes) =>
      bedMinutes < 12 * 60 ? bedMinutes + 24 * 60 : bedMinutes;

  static int _meanOfDay(Iterable<int> bedMinutes) {
    final pts = bedMinutes.map(_shifted).toList();
    final mean = pts.reduce((a, b) => a + b) / pts.length;
    return mean.round() % (24 * 60);
  }

  /// The bedtime the user's best-scoring nights had in common.
  ///
  /// Returns null when there is nothing trustworthy to say:
  ///
  /// * fewer than [minNights] logged nights — a suggestion from three nights is
  ///   a coincidence with a confident voice;
  /// * a shift smaller than [minShiftMinutes] — telling someone to go to bed
  ///   seven minutes earlier is noise dressed as insight;
  /// * best nights that are not actually better ([minScoreGap]) — if every night
  ///   scores the same, the "best" ones are just the ones that happened first.
  static BedtimeSuggestion? fromBestNights(
    List<BedtimeNight> nights, {
    int minNights = 7,
    int topCount = 5,
    int minShiftMinutes = 20,
    int maxShiftMinutes = 120,
    double minScoreGap = 5,
  }) {
    if (nights.length < minNights) return null;

    final ranked = [...nights]..sort((a, b) => b.score.compareTo(a.score));
    final best = ranked.take(topCount).toList();
    final rest = ranked.skip(topCount).toList();
    if (best.isEmpty || rest.isEmpty) return null;

    double avg(List<BedtimeNight> xs) =>
        xs.map((n) => n.score).reduce((a, b) => a + b) / xs.length;
    final bestAvg = avg(best);
    if (bestAvg - avg(rest) < minScoreGap) return null;

    final usual = _meanOfDay(nights.map((n) => n.bedMinutes));
    final target = _meanOfDay(best.map((n) => n.bedMinutes));

    // Signed distance the short way round the clock, so "40 minutes earlier"
    // does not come out as "1400 minutes later".
    const day = 24 * 60;
    var shift = (target - usual) % day;
    if (shift > day ~/ 2) shift -= day;

    if (shift.abs() < minShiftMinutes) return null;
    if (shift.abs() > maxShiftMinutes) return null;

    return BedtimeSuggestion(
      bedMinutes: target,
      shiftMinutes: shift,
      sampleCount: best.length,
      averageScoreOfBest: bestAvg,
    );
  }
}
