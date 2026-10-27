import 'package:clock/clock.dart';

import '../../../core/health/insight.dart';
import '../../../core/services/clean_storage_service.dart';

/// The insights that describe a PATTERN across days — trends and correlations —
/// as opposed to a nudge about today.
///
/// The engine works all of these out on every refresh and, until the Patterns
/// section, showed none of them anywhere: the Today nudge only ever takes the
/// single most urgent `attention`+ insight, and the weekly recap shows an
/// allow-list of week-scoped ones. These sit between the two — too slow-moving
/// for a nudge, not tied to one week.
///
/// An allow-list, like `WeeklyRecapService.weekScopedInsightIds`: a new insight
/// is NOT a pattern until someone decides it is, which is the safe default for a
/// section whose heading promises "across your days".
class PatternInsights {
  const PatternInsights._();

  static const Set<String> ids = {
    'water_trend',
    'steps_trend',
    'sleep_vs_avg',
    'correlation_mood_adherence',
    'correlation_bp_adherence',
    'correlation_focus_sleep',
    'correlation_hydration_sleep',
    'correlation_hydration_adherence',
  };

  /// "What goes with better days" makes one insight per tag, so its ids are
  /// `mood_tag_walk`, `mood_tag_short_night` and so on: a family, not a list.
  static const String moodTagPrefix = 'mood_tag_';

  /// Blood sugar by meal and hour makes one insight per group
  /// (`glucose_pattern_after_breakfast_high`): a family as well.
  static const String glucosePrefix = 'glucose_pattern_';

  /// What goes with longer and shorter nights, one insight per factor
  /// (`sleep_mover_late_caffeine`).
  static const String sleepMoverPrefix = 'sleep_mover_';

  static bool isPattern(String id) =>
      ids.contains(id) ||
      id.startsWith(moodTagPrefix) ||
      id.startsWith(glucosePrefix) ||
      id.startsWith(sleepMoverPrefix);

  /// How many are shown, so the section stays a glance and not a feed.
  static const int maxShown = 6;

  /// Sort and bucket [insights] into the three groups the section shows.
  ///
  /// Only ids in [ids] and not in [hidden]. Within a group, most important
  /// first. `good` and `info` stay separate because "something worth noticing"
  /// and "something worth celebrating" are different cards.
  static PatternGroups group(Iterable<Insight> insights,
      {Set<String> hidden = const {}}) {
    final picked = insights
        .where((i) => isPattern(i.id) && !hidden.contains(i.id))
        .toList()
      ..sort((a, b) => b.rank.compareTo(a.rank));
    final capped = picked.take(maxShown).toList();
    return PatternGroups(
      needsAttention: [
        for (final i in capped)
          if (i.severity.index >= InsightSeverity.attention.index) i
      ],
      patterns: [
        for (final i in capped)
          if (i.severity == InsightSeverity.info) i
      ],
      wins: [
        for (final i in capped)
          if (i.severity == InsightSeverity.good) i
      ],
    );
  }
}

class PatternGroups {
  final List<Insight> needsAttention;
  final List<Insight> patterns;
  final List<Insight> wins;
  const PatternGroups(
      {required this.needsAttention, required this.patterns, required this.wins});

  bool get isEmpty => needsAttention.isEmpty && patterns.isEmpty && wins.isEmpty;
  int get length => needsAttention.length + patterns.length + wins.length;
}

/// "Not useful" on a pattern: hidden for 30 days, then free to come back.
class HiddenPatterns {
  const HiddenPatterns._();

  static const _key = 'trends_hidden_patterns';
  static const Duration hideFor = Duration(days: 30);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<String> _entries() {
    final v = CleanStorageService.getAppPreference(_key, const <String>[]);
    return v is List ? v.map((e) => e.toString()).toList() : const [];
  }

  /// Ids currently hidden as of [now].
  static Set<String> current({DateTime? now}) {
    final t = now ?? clock.now();
    final today = DateTime(t.year, t.month, t.day);
    final out = <String>{};
    for (final e in _entries()) {
      final i = e.lastIndexOf('|');
      if (i <= 0) continue;
      final on = DateTime.tryParse(e.substring(i + 1));
      if (on != null && today.difference(on) < hideFor) out.add(e.substring(0, i));
    }
    return out;
  }

  static Future<void> hide(String id, {DateTime? now}) async {
    final t = now ?? clock.now();
    final kept = [
      for (final e in _entries())
        if (!e.startsWith('$id|')) e,
      '$id|${_fmt(t)}',
    ];
    await CleanStorageService.setAppPreference(_key, kept);
  }
}
