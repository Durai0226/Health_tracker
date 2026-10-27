import 'package:flutter/foundation.dart';

import '../../../core/health/caffeine_cutoff.dart';
import '../models/enhanced_water_log.dart';

/// A coffee that is late enough to cost sleep, and the two times that say so.
@immutable
class LateCaffeine {
  const LateCaffeine({
    required this.drink,
    required this.cutoff,
    required this.bedtime,
  });

  /// What was drunk, as the person logged it ("Coffee").
  final String drink;
  final DateTime cutoff;
  final DateTime bedtime;
}

/// Two quiet things worth saying about what has been drunk today, worked out
/// from today's log and nothing else.
///
/// Derived, not stored: a note that is true is shown, one that stops being true
/// (a glass of water was drunk, bedtime came) goes away by itself, and nothing
/// has to remember to take it down. They used to be a toast, which cannot
/// stack: the next toast replaces the last, and the one it replaced was the
/// "Undo" for the drink that was just logged.
class DrinkNotes {
  const DrinkNotes._();

  /// A glass of water.
  static const int chaserMl = 250;

  /// An alcoholic drink is "recent" for this long.
  static const Duration chaserWindow = Duration(hours: 3);

  /// Whether a glass of water is owed: an alcoholic drink inside
  /// [chaserWindow], and less than [chaserMl] of anything non-alcoholic logged
  /// since the latest one.
  ///
  /// Any non-alcoholic drink counts, not only water: a tea beside a beer is the
  /// same thing the note is asking for.
  static bool chaserDue(List<EnhancedWaterLog> logs, DateTime now) {
    EnhancedWaterLog? lastAlcohol;
    for (final l in logs) {
      if (!l.isAlcoholic || l.time.isAfter(now)) continue;
      if (lastAlcohol == null || l.time.isAfter(lastAlcohol.time)) {
        lastAlcohol = l;
      }
    }
    if (lastAlcohol == null) return false;
    if (now.difference(lastAlcohol.time) > chaserWindow) return false;

    // Anything logged after the latest alcoholic drink is, by definition, not
    // alcoholic: it would be the latest.
    var since = 0;
    for (final l in logs) {
      if (l.time.isAfter(now)) continue;
      if (l.time.isAfter(lastAlcohol.time)) since += l.amountMl;
    }
    return since < chaserMl;
  }

  /// The latest caffeinated drink logged inside tonight's cut-off window, while
  /// that bedtime is still ahead; null when there is none.
  static LateCaffeine? lateCaffeine(
    List<EnhancedWaterLog> logs,
    DateTime now, {
    required int bedtimeMinutes,
  }) {
    LateCaffeine? latest;
    DateTime? latestAt;
    for (final l in logs) {
      if (l.time.isAfter(now)) continue;
      final w = CaffeineCutoff.check(
          now: l.time,
          bedtimeMinutes: bedtimeMinutes,
          caffeineMg: l.caffeineAmount);
      if (w == null || !now.isBefore(w.bedtime)) continue;
      if (latestAt == null || l.time.isAfter(latestAt)) {
        latestAt = l.time;
        latest = LateCaffeine(
            drink: l.beverageName, cutoff: w.cutoff, bedtime: w.bedtime);
      }
    }
    return latest;
  }
}
