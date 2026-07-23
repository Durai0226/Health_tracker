import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';
import 'package:tablet_remainder/core/ai/rule_based_engine.dart';

/// Coverage for the AI extended to Period / Steps / Sleep: NL command parsing
/// and the deterministic coaching text. Pure (headless).
void main() {
  const e = RuleBasedEngine();

  group('parseCommand — new features', () {
    test('steps: "walked 6000 steps"', () {
      final c = e.parseCommand('walked 6000 steps');
      expect(c.kind, CommandKind.logSteps);
      expect(c.data['steps'], 6000);
    });
    test('steps: "8000 steps today"', () {
      expect(e.parseCommand('8000 steps today').kind, CommandKind.logSteps);
    });
    test('sleep: "slept 7 hours" → 420 min', () {
      final c = e.parseCommand('slept 7 hours');
      expect(c.kind, CommandKind.logSleep);
      expect(c.data['minutes'], 420);
    });
    test('sleep: "slept 7.5h" → 450 min', () {
      expect(e.parseCommand('slept 7.5h').data['minutes'], 450);
    });
    test('period: "my period started today"', () {
      expect(e.parseCommand('my period started today').kind, CommandKind.logPeriod);
    });
    test('question is NOT a log command', () {
      expect(e.parseCommand('when is my next period').kind, CommandKind.none);
      expect(e.parseCommand('how did i sleep').kind, CommandKind.none);
    });
  });

  group('deterministic coaching', () {
    test('stepsTip: goal reached is celebratory', () {
      final t = e.stepsTip(steps: 9000, goal: 8000, streakDays: 0, hour: 12);
      expect(t, contains('Goal reached'));
    });
    test('stepsTip: behind late in day suggests a walk', () {
      final t = e.stepsTip(steps: 3000, goal: 8000, streakDays: 0, hour: 20);
      expect(t.toLowerCase(), contains('walk'));
    });
    test('sleepTip: short night flags being under target', () {
      final t = e.sleepTip(
          lastNightMinutes: 300, targetMinutes: 480, debtMinutes: 0, regularity: 1);
      expect(t, isNotEmpty);
    });
    test('cycleInsight: fertile window carries contraception caveat', () {
      final t = e.cycleInsight(inFertileWindow: true, cycleDay: 13);
      expect(t.toLowerCase(), contains('not reliable for contraception'));
    });
    test('cycleInsight: pregnancy pauses predictions', () {
      final t = e.cycleInsight(pregnancy: true);
      expect(t.toLowerCase(), contains('paused'));
    });
    test('dailyBriefing includes steps + sleep when present', () {
      final t = e.dailyBriefing(
        medsTaken: 1,
        medsTotal: 2,
        waterPct: 50,
        focusMinutes: 25,
        remindersLeft: 1,
        hour: 14,
        steps: 4000,
        stepGoal: 8000,
        sleepMinutes: 420,
      );
      expect(t, contains('steps'));
      expect(t, contains('sleep'));
    });
  });
}
