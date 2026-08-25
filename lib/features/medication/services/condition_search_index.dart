/// Search over the condition library, widened past name-and-aliases.
///
/// ## What was missing
///
/// `ConditionInfo.matches` tests `name` and `aliases` only. Verified against all
/// 14 names and 34 aliases: **"chest pain", "swelling" and "statin" all return
/// the empty state**, even though the words are right there in the entries —
/// "chest pain" and "swelling" in `commonSymptoms`, "statin" in a self-care tip
/// on the cholesterol page. Someone searching a symptom is the most likely
/// visitor this screen has, and it was the one query shape it could not serve.
///
/// ## Weighted, so the right entry is first rather than merely present
///
/// Widening a search naively makes it worse: match everything and the ranking
/// becomes arbitrary. Fields are weighted by how strongly a hit in them implies
/// the user meant *this* condition — a name match outranks a passing mention in
/// a self-care tip by a wide margin.
///
/// ## Precomputed once
///
/// The old predicate re-lowercased on every keystroke. At 14 conditions that
/// cost nothing measurable, and pretending otherwise would be the wrong reason
/// to build this; the index exists because it is where the **drug-name hop**
/// lives, and that genuinely cannot be done per-keystroke.
library;

import 'package:flutter/foundation.dart';

import '../data/condition_library_data.dart';
import '../models/condition_info.dart';
import 'condition_taxonomy.dart';

/// One condition's searchable text, flattened and weighted.
@immutable
class _Entry {
  final ConditionInfo condition;
  final String name;
  final List<String> aliases;
  final String overview;
  final String symptoms;
  final String tips;
  final String redFlags;

  /// Generic drug names whose class links to this condition, plus the family
  /// phrases — so "statin", "metformin" or "calcium channel blocker" finds the
  /// page even though the curated copy never names them.
  final String drugs;

  const _Entry({
    required this.condition,
    required this.name,
    required this.aliases,
    required this.overview,
    required this.symptoms,
    required this.tips,
    required this.redFlags,
    required this.drugs,
  });
}

@immutable
class ConditionHit {
  final ConditionInfo condition;
  final int score;

  /// Which field carried the strongest hit — so the UI can say *why* an entry
  /// came back for "statin" when the word appears nowhere on the card.
  final String matchedIn;

  const ConditionHit(this.condition, this.score, this.matchedIn);
}

abstract final class ConditionSearchIndex {
  static List<_Entry>? _entries;

  /// Weights. A name hit must beat any number of body hits.
  static const _wName = 100;
  static const _wAlias = 80;
  static const _wDrug = 60;
  static const _wSymptom = 40;
  static const _wOverview = 25;
  static const _wRedFlag = 20;
  static const _wTip = 10;

  /// Build the index. Idempotent; safe to call from a widget's `initState`.
  ///
  /// [genericsForCondition] is injectable so a test can pin the drug hop
  /// without loading the 160-monograph asset.
  static void build({
    Map<String, List<String>> Function()? genericsForCondition,
  }) {
    final drugs = genericsForCondition?.call() ?? const {};
    _entries = [
      for (final c in conditionLibrary)
        _Entry(
          condition: c,
          name: c.name.toLowerCase(),
          aliases: [for (final a in c.aliases) a.toLowerCase()],
          overview: c.overview.toLowerCase(),
          symptoms: c.commonSymptoms.join(' ').toLowerCase(),
          tips: c.selfCareTips.join(' ').toLowerCase(),
          redFlags: c.whenToSeekHelp.join(' ').toLowerCase(),
          drugs: (drugs[c.id] ?? const []).join(' ').toLowerCase(),
        ),
    ];
  }

  static bool get isBuilt => _entries != null;

  /// Ranked matches for [rawQuery], best first.
  ///
  /// An empty query returns the whole library in its curated order — the browse
  /// case, not a search with no results.
  static List<ConditionHit> search(String rawQuery) {
    final entries = _entries;
    if (entries == null) {
      // Not built yet: fall back to the model's own predicate rather than
      // returning nothing, so a mis-ordered init degrades to the old behaviour
      // instead of an empty screen.
      final q = rawQuery.trim().toLowerCase();
      return [
        for (final c in conditionLibrary)
          if (c.matches(q)) ConditionHit(c, _wName, 'name'),
      ];
    }

    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) {
      return [for (final e in entries) ConditionHit(e.condition, 0, 'all')];
    }

    final hits = <ConditionHit>[];
    for (final e in entries) {
      var score = 0;
      var best = '';
      void consider(String haystack, int weight, String label) {
        if (haystack.contains(q)) {
          score += weight;
          if (weight > (best.isEmpty ? -1 : _weightOf(best))) best = label;
        }
      }

      consider(e.name, _wName, 'name');
      for (final a in e.aliases) {
        if (a.contains(q)) {
          score += _wAlias;
          if (best.isEmpty || _weightOf(best) < _wAlias) best = 'alias';
          break;
        }
      }
      consider(e.drugs, _wDrug, 'medicine');
      consider(e.symptoms, _wSymptom, 'symptom');
      consider(e.overview, _wOverview, 'overview');
      consider(e.redFlags, _wRedFlag, 'warning sign');
      consider(e.tips, _wTip, 'self-care');

      if (score > 0) hits.add(ConditionHit(e.condition, score, best));
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      // Ties break on the curated order, never on hash order — two runs of the
      // same query must not reshuffle.
      return byScore != 0
          ? byScore
          : conditionLibrary
              .indexWhere((c) => c.id == a.condition.id)
              .compareTo(
                  conditionLibrary.indexWhere((c) => c.id == b.condition.id));
    });
    return hits;
  }

  static int _weightOf(String label) => switch (label) {
        'name' => _wName,
        'alias' => _wAlias,
        'medicine' => _wDrug,
        'symptom' => _wSymptom,
        'overview' => _wOverview,
        'warning sign' => _wRedFlag,
        'self-care' => _wTip,
        _ => 0,
      };

  /// Build the drug half of the index from a monograph list.
  ///
  /// Takes `(generic, class)` pairs rather than reading the asset itself, so
  /// the caller owns the load and this stays a pure function.
  static Map<String, List<String>> drugTermsFrom(
      Iterable<({String generic, String klass})> monographs) {
    final out = <String, List<String>>{};
    for (final m in monographs) {
      final family = ConditionTaxonomy.familyPhrase(m.klass);
      for (final id in ConditionTaxonomy.conditionsForClass(m.klass)) {
        final list = out.putIfAbsent(id, () => []);
        list.add(m.generic);
        // The whole class string as well as the family phrase: "statin" lives
        // in "Cholesterol-lowering medicine (statin)" either way, but "blood
        // pressure medicine" only matches the full string.
        list.add(m.klass);
        if (family != null) list.add(family);
      }
    }
    return out;
  }

  @visibleForTesting
  static void resetForTesting() => _entries = null;
}
