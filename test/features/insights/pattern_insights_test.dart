import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/mood_tag_insights.dart';
import 'package:tablet_remainder/features/insights/services/pattern_insights.dart';

Insight ins(String id, InsightSeverity s, {double rank = 0}) => Insight(
      id: id,
      feature: InsightFeature.crossCutting,
      severity: s,
      title: id,
      detail: 'd',
      why: 'w',
      rank: rank,
    );

void main() {
  group('which insights are patterns', () {
    test('every correlation the engine produces is one', () {
      // Derived from the engine, not listed by hand: a new correlation must
      // either be a pattern or have been consciously left out, never forgotten.
      final src = File('lib/core/health/correlation_engine.dart').readAsStringSync();
      final produced = RegExp(r"id: '(correlation_[a-z_]+)'")
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toSet();
      expect(produced, isNotEmpty, reason: 'the regex should find them');
      expect(PatternInsights.ids.containsAll(produced), isTrue,
          reason: 'missing: ${produced.difference(PatternInsights.ids)}');
    });

    test('every id in the list is actually produced by an engine', () {
      final engines = [
        'lib/core/health/correlation_engine.dart',
        'lib/core/health/insight_engine.dart',
        'lib/features/insights/services/insight_service.dart',
      ].map((p) => File(p).readAsStringSync()).join('\n');
      for (final id in PatternInsights.ids) {
        expect(engines, contains("'$id'"),
            reason: '$id is in the list but nothing produces it');
      }
    });

    test('every mood-tag insight the engine produces is one', () {
      final days = [
        for (var i = 0; i < 6; i++) ...[
          DayMood(day: DateTime(2026, 3, 1 + i), score: 4, tags: {'walk'}),
          DayMood(day: DateTime(2026, 3, 11 + i), score: 1, tags: const {}),
        ],
      ];
      final produced = MoodTagInsights.insights(days);
      expect(produced, isNotEmpty, reason: 'the fixture should make one');
      final g = PatternInsights.group(produced);
      expect(g.length, produced.length);
      expect(g.wins.single.id, 'mood_tag_walk');
    });

    test('and only ids that START with the prefix', () {
      expect(PatternInsights.isPattern('mood_tag_walk'), isTrue);
      expect(PatternInsights.isPattern('x_mood_tag_walk'), isFalse);
      expect(PatternInsights.isPattern('mood_tags'), isFalse);
    });

    test('a today-scoped insight is not a pattern', () {
      final g = PatternInsights.group([
        ins('water_behind', InsightSeverity.attention, rank: 90),
        ins('med_refill', InsightSeverity.urgent, rank: 99),
      ]);
      expect(g.isEmpty, isTrue);
    });
  });

  group('grouping', () {
    final all = [
      ins('correlation_bp_adherence', InsightSeverity.attention, rank: 60),
      ins('correlation_focus_sleep', InsightSeverity.info, rank: 30),
      ins('water_trend', InsightSeverity.good, rank: 20),
      ins('steps_trend', InsightSeverity.info, rank: 40),
    ];

    test('attention, then info, then good — each its own bucket', () {
      final g = PatternInsights.group(all);
      expect(g.needsAttention.map((i) => i.id), ['correlation_bp_adherence']);
      expect(g.patterns.map((i) => i.id), ['steps_trend', 'correlation_focus_sleep']);
      expect(g.wins.map((i) => i.id), ['water_trend']);
    });

    test('most important first within a bucket', () {
      final g = PatternInsights.group(all);
      expect(g.patterns.first.rank, greaterThan(g.patterns.last.rank));
    });

    test('urgent counts as needing attention', () {
      final g = PatternInsights.group(
          [ins('correlation_bp_adherence', InsightSeverity.urgent)]);
      expect(g.needsAttention, hasLength(1));
    });

    test('hidden ids are left out', () {
      final g = PatternInsights.group(all, hidden: {'steps_trend'});
      expect(g.patterns.map((i) => i.id), ['correlation_focus_sleep']);
    });

    test('nothing to show is empty, not a card of placeholders', () {
      expect(PatternInsights.group(const []).isEmpty, isTrue);
    });

    test('the section is capped', () {
      final many = [
        for (final id in PatternInsights.ids) ins(id, InsightSeverity.info),
      ];
      expect(PatternInsights.group(many).length, PatternInsights.maxShown);
    });
  });
}
