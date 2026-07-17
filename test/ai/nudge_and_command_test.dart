import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/nudge_scheduler.dart';
import 'package:tablet_remainder/core/ai/ai_types.dart';
import 'package:tablet_remainder/core/ai/rule_based_engine.dart';

void main() {
  group('NudgeScheduler', () {
    final now = DateTime(2026, 3, 15, 12);
    test('allows when no recent shows', () {
      expect(NudgeScheduler.shouldShow(recentShows: const [], now: now), isTrue);
    });
    test('blocks within the min gap', () {
      expect(
        NudgeScheduler.shouldShow(
            recentShows: [now.subtract(const Duration(hours: 2))], now: now),
        isFalse,
      );
    });
    test('blocks once the weekly cap is hit', () {
      final shows = [
        for (var i = 1; i <= 4; i++) now.subtract(Duration(days: i)),
      ];
      expect(NudgeScheduler.shouldShow(recentShows: shows, now: now, maxPerWeek: 4), isFalse);
    });
    test('old shows outside the week do not count', () {
      final shows = [for (var i = 8; i <= 12; i++) now.subtract(Duration(days: i))];
      expect(NudgeScheduler.shouldShow(recentShows: shows, now: now), isTrue);
    });
  });

  group('RuleBasedEngine.parseCommand', () {
    const e = RuleBasedEngine();

    test('blood pressure "log 150/95"', () {
      final c = e.parseCommand('log 150/95');
      expect(c.kind, CommandKind.logBloodPressure);
      expect(c.data['systolic'], 150);
      expect(c.data['diastolic'], 95);
    });
    test('bp "150 over 95"', () {
      expect(e.parseCommand('bp 150 over 95').kind, CommandKind.logBloodPressure);
    });
    test('water "drank 500ml"', () {
      final c = e.parseCommand('drank 500ml');
      expect(c.kind, CommandKind.logWater);
      expect(c.data['ml'], 500);
    });
    test('glucose mg/dL "sugar 140"', () {
      final c = e.parseCommand('sugar 140');
      expect(c.kind, CommandKind.logGlucose);
      expect(c.data['mgdl'], 140);
    });
    test('glucose mmol/L "glucose 6.5" → converted to mg/dL', () {
      final c = e.parseCommand('glucose 6.5');
      expect(c.kind, CommandKind.logGlucose);
      expect(c.data['mgdl'], inInclusiveRange(115, 119));
    });
    test('medicine "took my pill"', () {
      expect(e.parseCommand('took my pill').kind, CommandKind.takeMedicine);
    });
    test('non-command → none', () {
      expect(e.parseCommand('how are you today').kind, CommandKind.none);
    });
  });
}
