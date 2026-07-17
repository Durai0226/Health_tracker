import 'insight.dart';
import 'focus_insights.dart';
import 'vitals_pattern_detector.dart';

/// Cross-feature "one big thing" engine. Pure Dart: each builder turns a
/// feature's already-computed stats (from AdherenceAnalyzer, StreakEngine,
/// HydrationPacer, FocusInsights, RefillPredictor, VitalsPatternDetector…) into
/// a ranked [Insight]. [rankAll] orders them for the hub / nudges. All
/// deterministic → free, offline, unit-testable.
class InsightEngine {
  const InsightEngine._();

  /// Top medicine insight from adherence %, miss-risk, dose streak, supply.
  static Insight? medicine({
    double? adherence, // 0..1
    double missRisk = 0, // 0..1
    int streakDays = 0,
    int? daysOfSupply,
  }) {
    if (daysOfSupply != null && daysOfSupply >= 0 && daysOfSupply <= 3) {
      return Insight(
        id: 'med_refill',
        feature: InsightFeature.medicine,
        severity: InsightSeverity.urgent,
        title: 'Refill soon',
        detail: 'You have about $daysOfSupply ${daysOfSupply == 1 ? 'day' : 'days'} of medicine left — reorder now to avoid a gap.',
        metric: '$daysOfSupply d left',
        why: 'Current stock ÷ your recent daily consumption rate.',
        rank: 90,
      );
    }
    if (adherence != null && adherence < 0.7) {
      return Insight(
        id: 'med_adherence',
        feature: InsightFeature.medicine,
        severity: InsightSeverity.attention,
        title: 'Adherence slipping',
        detail: 'You\'ve taken about ${(adherence * 100).round()}% of scheduled doses lately. Small routines (pairing with a meal) help.',
        metric: '${(adherence * 100).round()}%',
        why: 'Doses taken ÷ doses due over your recent history.',
        rank: 72,
      );
    }
    if (missRisk >= 0.5) {
      return Insight(
        id: 'med_missrisk',
        feature: InsightFeature.medicine,
        severity: InsightSeverity.attention,
        title: 'Doses often missed at this time',
        detail: 'This dose slot is missed more than most. Consider moving the reminder or the time.',
        metric: '${(missRisk * 100).round()}% miss',
        why: 'Smoothed miss-rate for this dose\'s weekday/hour bucket.',
        rank: 64,
      );
    }
    if (streakDays >= 3) {
      return Insight(
        id: 'med_streak',
        feature: InsightFeature.medicine,
        severity: InsightSeverity.good,
        title: 'On a roll with your meds',
        detail: 'A $streakDays-day streak of taking your doses — nicely done.',
        metric: '$streakDays-day',
        why: 'Consecutive days (with grace) all doses were taken.',
        rank: 30,
      );
    }
    if (adherence != null && adherence >= 0.9) {
      return Insight(
        id: 'med_adherence_good',
        feature: InsightFeature.medicine,
        severity: InsightSeverity.good,
        title: 'Great medication adherence',
        detail: 'About ${(adherence * 100).round()}% of doses taken on schedule — keep it up.',
        metric: '${(adherence * 100).round()}%',
        why: 'Doses taken ÷ doses due over your recent history.',
        rank: 26,
      );
    }
    return null;
  }

  static Insight? water({
    required int intakeMl,
    required int goalMl,
    int streakDays = 0,
    bool behind = false,
    int deficitMl = 0,
  }) {
    if (behind && deficitMl >= 250) {
      return Insight(
        id: 'water_behind',
        feature: InsightFeature.water,
        severity: InsightSeverity.attention,
        title: 'Behind on water',
        detail: 'You\'re about ${deficitMl}ml behind pace for this point in the day — a drink now catches you up.',
        metric: '${deficitMl}ml behind',
        why: 'Expected intake for the elapsed waking hours vs your actual intake.',
        rank: 52,
      );
    }
    if (goalMl > 0 && intakeMl >= goalMl) {
      return Insight(
        id: 'water_goal',
        feature: InsightFeature.water,
        severity: InsightSeverity.good,
        title: 'Hydration goal reached',
        detail: 'You hit your ${goalMl}ml goal today — great consistency.',
        metric: '${(intakeMl / goalMl * 100).round()}%',
        why: 'Today\'s intake vs your daily goal.',
        rank: 24,
      );
    }
    if (streakDays >= 3) {
      return Insight(
        id: 'water_streak',
        feature: InsightFeature.water,
        severity: InsightSeverity.good,
        title: 'Hydration streak going',
        detail: 'A $streakDays-day hydration streak — keep the momentum.',
        metric: '$streakDays-day',
        why: 'Consecutive days (with grace) your water goal was met.',
        rank: 22,
      );
    }
    return null;
  }

  static Insight? focus({
    int? bestFocusHour,
    double completionRate = 1,
    int sessionCount = 0,
    int streakDays = 0,
  }) {
    if (sessionCount >= 4 && completionRate < 0.5) {
      return Insight(
        id: 'focus_completion',
        feature: InsightFeature.focus,
        severity: InsightSeverity.info,
        title: 'Try shorter focus sessions',
        detail: 'Under half your sessions finish. A shorter target can make it easier to complete and build momentum.',
        metric: '${(completionRate * 100).round()}%',
        why: 'Completed sessions ÷ total sessions.',
        rank: 42,
      );
    }
    if (bestFocusHour != null) {
      return Insight(
        id: 'focus_besthour',
        feature: InsightFeature.focus,
        severity: InsightSeverity.info,
        title: 'Your best focus hour',
        detail: 'You focus most around ${FocusInsights.hourLabel(bestFocusHour)}. Protect that window for deep work.',
        metric: FocusInsights.hourLabel(bestFocusHour),
        why: 'Hour of day with the most accumulated focus minutes.',
        rank: 34,
      );
    }
    if (streakDays >= 3) {
      return Insight(
        id: 'focus_streak',
        feature: InsightFeature.focus,
        severity: InsightSeverity.good,
        title: 'Focus streak going',
        detail: 'A $streakDays-day focus streak — consistency compounds.',
        metric: '$streakDays-day',
        why: 'Consecutive days (with grace) you completed a focus session.',
        rank: 23,
      );
    }
    return null;
  }

  static Insight? bloodPressure(List<BpPoint> points) =>
      _top(VitalsPatternDetector.analyzeBp(points));

  static Insight? bloodSugar(List<GlucosePoint> points) =>
      _top(VitalsPatternDetector.analyzeGlucose(points));

  /// Rank a set of insights for the hub / nudges: most-severe-and-important
  /// first, then by rank.
  static List<Insight> rankAll(List<Insight?> insights) {
    final list = insights.whereType<Insight>().toList();
    list.sort((a, b) {
      final s = b.severity.index.compareTo(a.severity.index);
      if (s != 0) return s;
      return b.rank.compareTo(a.rank);
    });
    return list;
  }

  static Insight? _top(List<Insight> list) => list.isEmpty ? null : list.first;
}
