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
        progress: adherence,
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
        progress: adherence,
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
    // Guard: don't cry "behind" from an empty day. With zero intake logged the
    // intraday pacer reports the whole day's expected amount as a deficit
    // (e.g. "1821ml behind"), which reads as alarming nonsense before the user
    // has logged anything. Only surface it once they've started drinking.
    if (behind && deficitMl >= 250 && intakeMl > 0) {
      return Insight(
        id: 'water_behind',
        feature: InsightFeature.water,
        severity: InsightSeverity.attention,
        title: 'Behind on water',
        detail: 'You\'re about ${deficitMl}ml behind pace for this point in the day — a drink now catches you up.',
        metric: '${deficitMl}ml behind',
        progress: goalMl > 0 ? intakeMl / goalMl : null,
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
        progress: intakeMl / goalMl,
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

  static String _hm(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

  /// Step-count insight. Inputs are primitives (core stays free of feature deps).
  static Insight? steps({
    required int steps,
    required int goal,
    int streakDays = 0,
  }) {
    if (goal > 0 && steps >= goal) {
      return Insight(
        id: 'steps_goal',
        feature: InsightFeature.steps,
        severity: InsightSeverity.good,
        title: 'Step goal reached',
        detail: 'You hit your $goal-step goal today — nice work staying active.',
        metric: '${(steps / goal * 100).round()}%',
        progress: steps / goal,
        why: "Today's steps vs your daily goal.",
        rank: 24,
      );
    }
    if (streakDays >= 3) {
      return Insight(
        id: 'steps_streak',
        feature: InsightFeature.steps,
        severity: InsightSeverity.good,
        title: 'Active streak going',
        detail: 'A $streakDays-day streak of hitting your step goal — keep moving.',
        metric: '$streakDays-day',
        why: 'Consecutive days you reached your step goal.',
        rank: 22,
      );
    }
    if (goal > 0 && steps > 0 && steps < goal) {
      final short = goal - steps;
      return Insight(
        id: 'steps_short',
        feature: InsightFeature.steps,
        severity: InsightSeverity.info,
        title: 'A short walk closes the gap',
        detail: "You're about $short steps from today's goal — a brief walk gets you there.",
        metric: '$short to go',
        progress: steps / goal,
        why: "Today's steps vs your daily goal.",
        rank: 30,
      );
    }
    return null;
  }

  /// Sleep insight from last night + weekly context. [loggedNights] is how many
  /// of the last 7 nights actually have sleep data — the weekly-context branches
  /// (debt, regularity) require enough of them so an empty week can't fabricate
  /// a huge "56h debt" (every un-logged night would otherwise count as a full
  /// 8h shortfall).
  static Insight? sleep({
    required int lastNightMinutes,
    required int targetMinutes,
    int debtMinutes = 0,
    double regularity = 1,
    int loggedNights = 0,
  }) {
    if (lastNightMinutes > 0 && lastNightMinutes < targetMinutes - 60) {
      return Insight(
        id: 'sleep_short',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.attention,
        title: 'Short on sleep last night',
        detail:
            'You slept about ${((targetMinutes - lastNightMinutes) / 60).toStringAsFixed(1)}h under your target — an earlier night would help.',
        metric: _hm(lastNightMinutes),
        why: "Last night's asleep time vs your target.",
        rank: 50,
      );
    }
    // Sleep balance — a gentle, non-guilt note (never "debt"). Symmetric: we
    // also acknowledge a surplus so it's never only a downside frame.
    if (debtMinutes >= 180 && loggedNights >= 4) {
      return Insight(
        id: 'sleep_balance_low',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.info,
        title: 'A little behind on rest',
        detail:
            "You're about ${(debtMinutes / 60).round()}h under your target across the week — an earlier night or two helps you get ahead.",
        metric: '${(debtMinutes / 60).round()}h under',
        why: 'What you slept over your logged nights vs your nightly target.',
        rank: 34,
      );
    }
    if (debtMinutes <= -120 && loggedNights >= 4) {
      return Insight(
        id: 'sleep_balance_up',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.good,
        title: 'Rest in credit',
        detail:
            "You're about ${(-debtMinutes / 60).round()}h over your target this week — nicely rested.",
        metric: '${(-debtMinutes / 60).round()}h ahead',
        why: 'What you slept over your logged nights vs your nightly target.',
        rank: 20,
      );
    }
    if (regularity < 0.5 && loggedNights >= 4) {
      return Insight(
        id: 'sleep_regularity',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.info,
        title: 'Irregular bedtimes',
        detail:
            'Your bedtime varies a lot night to night — a steadier schedule improves sleep quality.',
        why: 'Variability of your bedtimes over the last week.',
        rank: 34,
      );
    }
    if (lastNightMinutes >= targetMinutes) {
      return Insight(
        id: 'sleep_good',
        feature: InsightFeature.sleep,
        severity: InsightSeverity.good,
        title: 'Well rested',
        detail: 'You met your sleep target last night — great for recovery.',
        metric: _hm(lastNightMinutes),
        why: "Last night's asleep time vs your target.",
        rank: 22,
      );
    }
    return null;
  }

  /// Menstrual-cycle insight. Honest, non-diagnostic; fertility is labelled an
  /// estimate and not for contraception.
  static Insight? period({
    int? daysUntilNextPeriod,
    bool inFertileWindow = false,
    bool isLate = false,
    int lateDays = 0,
    bool irregular = false,
    bool pregnancyMode = false,
  }) {
    if (pregnancyMode) return null;
    if (isLate && lateDays >= 1) {
      return Insight(
        id: 'period_late',
        feature: InsightFeature.period,
        severity: InsightSeverity.info,
        title: 'Period may be late',
        detail:
            'Your period is about $lateDays day${lateDays == 1 ? '' : 's'} past the predicted date. Cycles vary — log any flow to update your prediction.',
        metric: '$lateDays day${lateDays == 1 ? '' : 's'} late',
        why: 'Today is past your predicted next-period window with no flow logged.',
        rank: 48,
      );
    }
    if (daysUntilNextPeriod != null &&
        daysUntilNextPeriod >= 0 &&
        daysUntilNextPeriod <= 3) {
      return Insight(
        id: 'period_soon',
        feature: InsightFeature.period,
        severity: InsightSeverity.attention,
        title: daysUntilNextPeriod == 0 ? 'Period likely today' : 'Period expected soon',
        detail: daysUntilNextPeriod == 0
            ? 'Based on your logged cycles, your period is likely to start today.'
            : 'Your period is estimated in about $daysUntilNextPeriod day${daysUntilNextPeriod == 1 ? '' : 's'}. This is an estimate from your own history.',
        metric: daysUntilNextPeriod == 0 ? 'Today' : 'in $daysUntilNextPeriod d',
        why: 'Predicted from your average cycle length across recent logged cycles.',
        rank: 44,
      );
    }
    if (inFertileWindow) {
      return Insight(
        id: 'period_fertile',
        feature: InsightFeature.period,
        severity: InsightSeverity.info,
        title: 'Estimated fertile window',
        detail:
            'You may be in your estimated fertile window. This is a calendar estimate — not reliable for contraception.',
        metric: 'Fertile (est.)',
        why: 'Estimated from ovulation ~14 days before your predicted next period.',
        rank: 36,
      );
    }
    if (irregular) {
      return Insight(
        id: 'period_irregular',
        feature: InsightFeature.period,
        severity: InsightSeverity.info,
        title: 'Cycle looks irregular',
        detail:
            'Your recent cycles vary a lot, so predictions are less certain. If irregularity persists, consider checking with a clinician.',
        why: 'High variability in your recent cycle lengths.',
        rank: 30,
      );
    }
    return null;
  }

  /// Period-over-period comparison: the last 7 complete days vs the 7 before
  /// them. Deliberately excludes today (a partial day would always look low).
  /// Only fires with real data in BOTH windows and a meaningful (≥8%) change,
  /// so it reflects a genuine trend rather than noise or an empty history —
  /// this is the honest "week vs week" the empty-data deficit numbers weren't.
  static Insight? trend({
    required InsightFeature feature,
    required String id,
    required String label, // lowercase noun: "steps", "water"
    required num thisWeek,
    required num lastWeek,
    required bool higherIsBetter,
  }) {
    if (lastWeek <= 0 || thisWeek <= 0) return null;
    final pct = ((thisWeek - lastWeek) / lastWeek * 100).round();
    if (pct.abs() < 8) return null;
    final up = pct > 0;
    final better = up == higherIsBetter;
    final cap = label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    return Insight(
      id: id,
      feature: feature,
      severity: better ? InsightSeverity.good : InsightSeverity.info,
      title: '$cap ${up ? 'up' : 'down'} vs last week',
      detail:
          'Your $label over the last 7 days is about ${pct.abs()}% ${up ? 'higher' : 'lower'} than the previous 7 days.',
      metric: '${up ? '+' : '-'}${pct.abs()}%',
      why: 'Total over the last 7 complete days vs the 7 days before that.',
      rank: better ? 28 : 38,
    );
  }

  /// Last night vs your recent nightly average — an honest daily-granularity
  /// trend. Needs a few logged nights and a ≥30-min difference to be notable.
  static Insight? sleepVsAverage({
    required int lastNightMinutes,
    required int avgMinutes,
    required int nightsLogged,
  }) {
    if (lastNightMinutes <= 0 || avgMinutes <= 0 || nightsLogged < 3) return null;
    final diff = lastNightMinutes - avgMinutes;
    if (diff.abs() < 30) return null;
    final more = diff > 0;
    return Insight(
      id: 'sleep_vs_avg',
      feature: InsightFeature.sleep,
      severity: more ? InsightSeverity.good : InsightSeverity.info,
      title: more ? 'More sleep than usual' : 'Less sleep than usual',
      detail:
          'Last night you slept about ${(diff.abs() / 60).toStringAsFixed(1)}h ${more ? 'more' : 'less'} than your recent average.',
      metric: '${more ? '+' : '-'}${_hm(diff.abs())}',
      why: "Last night's asleep time vs your average over recent logged nights.",
      rank: 32,
    );
  }

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
