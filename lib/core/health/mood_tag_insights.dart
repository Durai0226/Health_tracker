/// "Mood tends to be better on days with a walk (+0.8 · 14 vs 11 days)."
///
/// Compares the days a tag is on with the days it is not, on a day's average mood
/// score (0 worst, 4 best). Same arithmetic, same minimums and same honesty as the
/// other cross-day patterns in [CorrelationEngine]: two group means, a floor on
/// each group's size and on the gap, no claim of cause, and the sample in the
/// open on the card.
library;

import 'insight.dart';
import 'mood_tags.dart';

/// One day: its average mood, and every tag on any entry that day.
class DayMood {
  const DayMood({required this.day, required this.score, required this.tags});

  final DateTime day;

  /// 0 (the worst the scale offers) to 4 (the best).
  final double score;

  final Set<String> tags;
}

class MoodTagInsights {
  const MoodTagInsights._();

  /// Days with the tag, and days without, each of which it needs.
  static const int minDaysPerGroup = 5;

  /// The smallest gap in average mood (out of 4) worth mentioning.
  static const double minDelta = 0.5;

  /// The most that are surfaced, largest gap first.
  static const int maxInsights = 3;

  static List<Insight> insights(List<DayMood> days) {
    final tags = {for (final d in days) ...d.tags};
    final found = <({String tag, double delta, int with_, int without,
        double meanWith, double meanWithout})>[];

    for (final tag in tags) {
      final withTag = [for (final d in days) if (d.tags.contains(tag)) d.score];
      final without = [for (final d in days) if (!d.tags.contains(tag)) d.score];
      if (withTag.length < minDaysPerGroup || without.length < minDaysPerGroup) {
        continue;
      }
      final mw = _mean(withTag);
      final mo = _mean(without);
      final delta = mw - mo;
      if (delta.abs() < minDelta) continue;
      found.add((
        tag: tag,
        delta: delta,
        with_: withTag.length,
        without: without.length,
        meanWith: mw,
        meanWithout: mo,
      ));
    }

    found.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
    return [
      for (final f in found.take(maxInsights)) _build(f),
    ];
  }

  static Insight _build(
      ({String tag, double delta, int with_, int without,
          double meanWith, double meanWithout}) f) {
    final better = f.delta > 0;
    final phrase = MoodTags.phrase(f.tag);
    final sign = better ? '+' : '-';
    final total = f.with_ + f.without;
    String one(double v) => v.toStringAsFixed(1);
    return Insight(
      id: 'mood_tag_${f.tag}',
      feature: InsightFeature.crossCutting,
      // A better-mood pattern is a win; a lower one is a note, not an alarm.
      severity: better ? InsightSeverity.good : InsightSeverity.info,
      title: better
          ? 'Mood tends to be better on days with $phrase'
          : 'Mood tends to be lower on days with $phrase',
      detail: 'Across $total days you logged, your mood averaged '
          '${one(f.meanWith)} out of 4 on the ${f.with_} days with $phrase and '
          '${one(f.meanWithout)} on the other ${f.without}. That is a pattern in '
          'your own entries, not a sign that one causes the other.',
      metric: '$sign${one(f.delta.abs())}',
      why: 'Average mood score (0 worst to 4 best) on days tagged '
          '"${MoodTags.label(f.tag)}" versus days without it. It needs at least '
          '$minDaysPerGroup days on each side and a gap of at least '
          '${one(minDelta)}.',
      rank: 34,
      evidence: PatternEvidence(
        groupA: f.with_,
        groupB: f.without,
        effectRatio: f.delta.abs() / minDelta,
      ),
    );
  }

  static double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
}
