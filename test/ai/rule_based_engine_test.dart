import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/rule_based_engine.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';

void main() {
  const engine = RuleBasedEngine();

  group('parseReminder', () {
    test('"take vitamin D every morning at 8am" -> daily @ 8, clean title', () {
      final r = engine.parseReminder('take vitamin D every morning at 8am');
      expect(r.title.toLowerCase(), contains('vitamin d'));
      // Time words should be stripped from the title.
      expect(r.title.toLowerCase(), isNot(contains('8am')));
      expect(r.title.toLowerCase(), isNot(contains('morning')));
      expect(r.repeat, 'daily');
      expect(r.time, isNotNull);
      expect(r.time!.hour, 8);
    });

    test('"call mom tomorrow at 5pm" -> none @ 17, tomorrow', () {
      final r = engine.parseReminder('call mom tomorrow at 5pm');
      expect(r.repeat, 'none');
      expect(r.time, isNotNull);
      expect(r.time!.hour, 17);

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));
      expect(r.time!.year, tomorrow.year);
      expect(r.time!.month, tomorrow.month);
      expect(r.time!.day, tomorrow.day);
    });

    test('"gym every monday" -> weekly', () {
      final r = engine.parseReminder('gym every monday');
      expect(r.repeat, 'weekly');
    });

    test('"urgent: pay rent" -> high priority', () {
      final r = engine.parseReminder('urgent: pay rent');
      expect(r.priority, 'high');
    });
  });

  group('parseMedicine', () {
    test('"Metformin 500mg twice a day" -> parsed fields', () {
      final m = engine.parseMedicine('Metformin 500mg twice a day');
      expect((m['name'] as String).toLowerCase(), contains('metformin'));
      expect(m['dosageAmount'], 500);
      expect(m['dosageUnit'], 'mg');
      expect(m['frequency'], 'twice daily');
    });
  });

  group('hydrationTip', () {
    test('goal reached -> success cue', () {
      final tip = engine.hydrationTip(
        intakeMl: 2500,
        goalMl: 2000,
        streakDays: 3,
        hour: 14,
      );
      expect(tip.toLowerCase(), contains('goal reached'));
    });

    test('well behind -> mentions remaining ml', () {
      final tip = engine.hydrationTip(
        intakeMl: 400,
        goalMl: 2000,
        streakDays: 0,
        hour: 14,
      );
      // remaining = 1600ml
      expect(tip, contains('1600ml'));
    });
  });

  group('focusCoach', () {
    test('zero minutes -> start prompt', () {
      final msg = engine.focusCoach(
        todayMinutes: 0,
        streakDays: 0,
        totalSessions: 0,
      );
      expect(msg.toLowerCase(), contains('start'));
    });
  });

  group('suggestWaterGoal', () {
    test('70kg -> reasonable range (~2310)', () {
      final goal = engine.suggestWaterGoal(weightKg: 70);
      expect(goal, greaterThanOrEqualTo(1500));
      expect(goal, lessThanOrEqualTo(4000));
      expect(goal, closeTo(2310, 1));
    });

    test('hot climate increases the goal', () {
      final base = engine.suggestWaterGoal(weightKg: 70);
      final hot = engine.suggestWaterGoal(weightKg: 70, climate: 'hot');
      expect(hot, greaterThan(base));
    });
  });

  group('explainInteractions', () {
    test('non-empty list -> bullet lines', () {
      final out = engine.explainInteractions(
        ['Avoid alcohol with X', 'Space Y and Z by 2 hours'],
      );
      expect(out, contains('- Avoid alcohol with X'));
      expect(out, contains('- Space Y and Z by 2 hours'));
    });

    test('empty list -> no notable string', () {
      final out = engine.explainInteractions(const []);
      expect(out.toLowerCase(), contains('no notable'));
    });
  });
}
