/// "Your readings after breakfast often run high" — where in the day a person's
/// glucose tends to leave its range, from their own readings.
///
/// Pure Dart. Groups the last 30 days of readings by the moment they were taken
/// for (fasting, bedtime, before or after a named meal, overnight) and says so
/// when a group is big enough and often enough out of range. It reports what was
/// logged; it does not diagnose, and it never suggests a dose or a change to
/// medicine.
library;

import 'insight.dart';
import 'vitals_analyzer.dart';

/// One reading, as the pattern check needs it.
class GlucoseSample {
  const GlucoseSample(this.mgdl, this.context, this.at);

  final int mgdl;
  final GlucoseContext context;
  final DateTime at;
}

/// A group of readings that leaves its range often enough to mention.
class GlucosePattern {
  const GlucosePattern({
    required this.id,
    required this.title,
    required this.detail,
    required this.isLow,
    required this.count,
    required this.flagged,
  });

  /// Stable: `glucose_pattern_fasting_high`, `glucose_pattern_overnight_low`.
  final String id;
  final String title;
  final String detail;

  /// A lows pattern (the one that matters more) rather than a highs one.
  final bool isLow;

  /// Readings in the group, and how many of them were out of range.
  final int count;
  final int flagged;

  /// The pattern as an insight card. A lows pattern is worth attention; a highs
  /// one is a note.
  Insight toInsight() => Insight(
        id: id,
        feature: InsightFeature.bloodSugar,
        severity: isLow ? InsightSeverity.attention : InsightSeverity.info,
        title: title,
        detail: detail,
        metric: '$flagged of $count',
        why: 'Your readings from the last ${GlucosePatternCheck.windowDays} '
            'days, grouped by what they were for (fasting, bedtime, before or '
            'after a meal, overnight). A group needs at least '
            '${GlucosePatternCheck.minReadings} readings before anything is '
            'said about it.',
        rank: isLow ? 72 : 52,
      );
}

class GlucosePatternCheck {
  const GlucosePatternCheck._();

  static const int windowDays = 30;

  /// Readings a group needs before anything is said about it.
  static const int minReadings = 5;

  /// A group runs high when at least this share of it is above range.
  static const double highShare = 0.5;

  /// It runs low when at least this many readings, and this share, are below
  /// 70 mg/dL — a lower bar than the highs, because a low is the one that hurts
  /// sooner.
  static const int minLows = 2;
  static const double lowShare = 0.2;

  /// The most that are reported, lows first.
  static const int maxPatterns = 3;

  /// Overnight, for the lows that happen while asleep.
  static const int overnightFromHour = 23;
  static const int overnightToHour = 5;

  /// Patterns in [readings] over the [windowDays] before [now]. [format] says a
  /// value in the person's unit ("138 mg/dL" or "7.7 mmol/L").
  static List<GlucosePattern> check(
    Iterable<GlucoseSample> readings, {
    required DateTime now,
    required String Function(int mgdl) format,
  }) {
    final since = DateTime(now.year, now.month, now.day - windowDays + 1);
    final recent = [
      for (final r in readings)
        if (!r.at.isBefore(since) && !r.at.isAfter(now)) r,
    ];

    final groups = <String, _Group>{};
    void add(String key, String name, bool lowOnly, GlucoseSample r) {
      (groups[key] ??= _Group(key, name, lowOnly)).samples.add(r);
    }

    for (final r in recent) {
      final hour = r.at.hour;
      if (hour >= overnightFromHour || hour < overnightToHour) {
        add('overnight', 'Overnight', true, r);
      }
      switch (r.context) {
        case GlucoseContext.fasting:
          add('fasting', 'Fasting', false, r);
        case GlucoseContext.bedtime:
          add('bedtime', 'Bedtime', false, r);
        case GlucoseContext.beforeMeal:
          final m = _meal(hour);
          if (m != null) add('before_$m', 'Before $m', false, r);
        case GlucoseContext.afterMeal:
          final m = _meal(hour);
          if (m != null) add('after_$m', 'After $m', false, r);
        case GlucoseContext.random:
          break;
      }
    }

    final out = <GlucosePattern>[];
    for (final g in groups.values) {
      final n = g.samples.length;
      if (n < minReadings) continue;
      final lows = g.samples.where(_isLow).toList();
      final highs = g.samples.where(_isHigh).toList();

      if (lows.length >= minLows && lows.length / n >= lowShare) {
        final lowest = lows.map((s) => s.mgdl).reduce((a, b) => a < b ? a : b);
        out.add(GlucosePattern(
          id: 'glucose_pattern_${g.key}_low',
          title: g.lowOnly
              ? 'Lows tend to happen overnight'
              : '${g.name} readings sometimes run low',
          detail: '${lows.length} of $n ${g.name.toLowerCase()} readings in the '
              'last $windowDays days were below ${format(70)} (lowest '
              '${format(lowest)}). Worth mentioning to your doctor.',
          isLow: true,
          count: n,
          flagged: lows.length,
        ));
      }
      if (!g.lowOnly && highs.length / n >= highShare) {
        final avg =
            (highs.map((s) => s.mgdl).reduce((a, b) => a + b) / highs.length)
                .round();
        out.add(GlucosePattern(
          id: 'glucose_pattern_${g.key}_high',
          title: '${g.name} readings often run high',
          detail: '${highs.length} of $n ${g.name.toLowerCase()} readings in the '
              'last $windowDays days were above range (those averaged '
              '${format(avg)}). Worth mentioning to your doctor.',
          isLow: false,
          count: n,
          flagged: highs.length,
        ));
      }
    }

    // Lows first, then the larger share, then the larger sample.
    out.sort((a, b) {
      if (a.isLow != b.isLow) return a.isLow ? -1 : 1;
      final byShare = (b.flagged / b.count).compareTo(a.flagged / a.count);
      return byShare != 0 ? byShare : b.count.compareTo(a.count);
    });
    return out.take(maxPatterns).toList();
  }

  static bool _isLow(GlucoseSample s) {
    final c = VitalsAnalyzer.classifyGlucose(s.mgdl, s.context);
    return c == GlucoseClass.low || c == GlucoseClass.severeLow;
  }

  static bool _isHigh(GlucoseSample s) {
    final c = VitalsAnalyzer.classifyGlucose(s.mgdl, s.context);
    return c == GlucoseClass.high || c == GlucoseClass.veryHigh;
  }

  /// The meal a reading at [hour] belongs to, or null in the small hours.
  static String? _meal(int hour) {
    if (hour >= 5 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 16) return 'lunch';
    if (hour >= 16 && hour < 23) return 'dinner';
    return null;
  }
}

class _Group {
  _Group(this.key, this.name, this.lowOnly);

  final String key;
  final String name;

  /// Only lows are reported for it (overnight: a high at 2 am is not "a pattern
  /// of the night").
  final bool lowOnly;
  final List<GlucoseSample> samples = [];
}
