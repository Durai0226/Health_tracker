/// "On nights after caffeine after 2 pm you slept 38 min less (9 vs 21 nights)."
///
/// What goes with a person's longer and shorter nights, worked out from their own
/// log. One factor at a time — the day before: caffeine in the afternoon, an
/// evening drink with alcohol, a day the step goal was met — compared on the time
/// they were asleep. The same restraint as every other cross-day pattern: a floor
/// on each group and on the gap, the sample on the card, and no claim that one
/// causes the other.
library;

import 'insight.dart';

/// One night, and what the day before it held. A factor is null when the app has
/// no record of that kind for the day: not "no", just not known, and such a night
/// is left out of that factor's comparison rather than counted as a "no".
class NightFactors {
  const NightFactors({
    required this.night,
    required this.asleepMinutes,
    this.lateCaffeine,
    this.eveningAlcohol,
    this.activeDay,
  });

  /// The night's wake-up date.
  final DateTime night;

  final int asleepMinutes;

  /// Caffeine (20 mg or more) logged between 14:00 and midnight the day before.
  final bool? lateCaffeine;

  /// Alcohol logged after 17:00 the day before.
  final bool? eveningAlcohol;

  /// The day before met its step goal.
  final bool? activeDay;
}

class SleepMoverInsights {
  const SleepMoverInsights._();

  /// Nights with the factor, and nights without it, each of which it needs.
  static const int minNightsPerGroup = 5;

  /// The smallest gap in average time asleep worth mentioning.
  static const int minDifferenceMinutes = 20;

  /// The most that are reported, largest gap first.
  static const int maxInsights = 2;

  static List<Insight> insights(List<NightFactors> nights) {
    final out = <({Insight insight, int gap})>[];

    void factor(
      String id,
      String phrase,
      bool? Function(NightFactors) of,
    ) {
      final withF = <int>[];
      final without = <int>[];
      for (final n in nights) {
        final f = of(n);
        if (f == null) continue;
        (f ? withF : without).add(n.asleepMinutes);
      }
      if (withF.length < minNightsPerGroup || without.length < minNightsPerGroup) {
        return;
      }
      final mw = _mean(withF);
      final mo = _mean(without);
      final delta = (mw - mo).round();
      if (delta.abs() < minDifferenceMinutes) return;
      final less = delta < 0;
      out.add((
        gap: delta.abs(),
        insight: Insight(
          id: id,
          feature: InsightFeature.sleep,
          severity: less ? InsightSeverity.info : InsightSeverity.good,
          title: 'On nights after $phrase you slept ${_dur(delta.abs())} '
              '${less ? 'less' : 'more'}',
          detail: 'You slept ${_hm(mw.round())} on average on the '
              '${withF.length} nights after $phrase, against ${_hm(mo.round())} '
              'on the other ${without.length}. That is a pattern in your own '
              'nights, not a sign that one causes the other.',
          metric: '${less ? '-' : '+'}${_dur(delta.abs())}',
          why: 'Average time asleep on nights after a day with this, against '
              'nights after a day without it. It needs at least '
              '$minNightsPerGroup nights on each side and a gap of at least '
              '$minDifferenceMinutes minutes.',
          rank: 36,
          evidence: PatternEvidence(
            groupA: withF.length,
            groupB: without.length,
            effectRatio: delta.abs() / minDifferenceMinutes,
            unit: 'nights',
          ),
        ),
      ));
    }

    factor('sleep_mover_late_caffeine', 'caffeine after 2 pm',
        (n) => n.lateCaffeine);
    factor('sleep_mover_evening_alcohol', 'an evening drink with alcohol',
        (n) => n.eveningAlcohol);
    factor('sleep_mover_active_day', 'an active day (step goal met)',
        (n) => n.activeDay);

    out.sort((a, b) => b.gap.compareTo(a.gap));
    return [for (final o in out.take(maxInsights)) o.insight];
  }

  static double _mean(List<int> v) => v.reduce((a, b) => a + b) / v.length;

  /// "38 min", or "1 h 5 min" from an hour up.
  static String _dur(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// "6h 40m".
  static String _hm(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';
}
