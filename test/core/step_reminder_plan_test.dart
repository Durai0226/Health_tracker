import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/step_reminder_plan.dart';

void main() {
  const evening = 19 * 60;
  final noon = DateTime(2026, 3, 10, 12);
  final at7pm = DateTime(2026, 3, 10, 19);
  final tomorrow7pm = DateTime(2026, 3, 11, 19);

  StepReminderPlan plan({
    DateTime? now,
    int? steps,
    int? goal,
    DateTime? asOf,
    int minute = evening,
  }) =>
      StepReminderPlanner.plan(
        now: now ?? noon,
        minuteOfDay: minute,
        stepsToday: steps,
        goal: goal,
        stepsAsOf: asOf,
      );

  group('helpers', () {
    test('a single minute is singular', () {
      final p = plan(
          now: DateTime(2026, 3, 10, 18, 50),
          steps: 7950,
          goal: 8000,
          asOf: DateTime(2026, 3, 10, 18, 49));
      expect(p.todayBody, '50 steps to go — about 1 minute of walking.');
    });

    test('walk minutes round up and are at least one', () {
      expect(StepReminderPlanner.walkMinutes(1800), 18);
      expect(StepReminderPlanner.walkMinutes(1801), 19);
      expect(StepReminderPlanner.walkMinutes(5), 1);
      expect(StepReminderPlanner.walkMinutes(0), 1);
    });

    test('thousands are grouped', () {
      expect(StepReminderPlanner.groupThousands(0), '0');
      expect(StepReminderPlanner.groupThousands(999), '999');
      expect(StepReminderPlanner.groupThousands(1800), '1,800');
      expect(StepReminderPlanner.groupThousands(12345), '12,345');
      expect(StepReminderPlanner.groupThousands(1234567), '1,234,567');
    });
  });

  group('plan', () {
    test('no step data: the old behaviour, a generic reminder from today', () {
      final p = plan();
      expect(p.todayAt, isNull);
      expect(p.repeatingFrom, at7pm);
    });

    test('an empty in-memory day is not data: no asOf, no claim', () {
      final p = plan(steps: 0, goal: 8000);
      expect(p.todayAt, isNull);
      expect(p.repeatingFrom, at7pm);
    });

    test('goal met: nothing today, the repeating reminder starts tomorrow', () {
      final p = plan(steps: 8200, goal: 8000, asOf: noon);
      expect(p.todayAt, isNull);
      expect(p.todayBody, isNull);
      expect(p.repeatingFrom, tomorrow7pm);
    });

    test('exactly the goal counts as met', () {
      expect(plan(steps: 8000, goal: 8000, asOf: noon).todayAt, isNull);
    });

    test('short of the goal with fresh numbers: says how far, and how long', () {
      final p = plan(
          now: DateTime(2026, 3, 10, 18, 15),
          steps: 6200,
          goal: 8000,
          asOf: DateTime(2026, 3, 10, 18, 10));
      expect(p.todayAt, at7pm);
      expect(p.todayBody, '1,800 steps to go — about 18 minutes of walking.');
      expect(p.repeatingFrom, tomorrow7pm);
    });

    test('numbers older than 90 minutes at fire time are not quoted', () {
      final p = plan(steps: 6200, goal: 8000, asOf: noon);
      expect(p.todayAt, at7pm);
      expect(p.todayBody, StepReminderPlanner.genericBody);
      expect(p.todayBody, isNot(contains('6')));
    });

    test('exactly 90 minutes old is still fresh; a minute more is not', () {
      final edge = DateTime(2026, 3, 10, 17, 30);
      expect(plan(steps: 6200, goal: 8000, asOf: edge).todayBody,
          contains('1,800'));
      expect(
          plan(
                  steps: 6200,
                  goal: 8000,
                  asOf: edge.subtract(const Duration(minutes: 1)))
              .todayBody,
          StepReminderPlanner.genericBody);
    });

    test('a rest or unwell day is silent, with numbers or without', () {
      for (final data in [true, false]) {
        final p = StepReminderPlanner.plan(
          now: noon,
          minuteOfDay: evening,
          stepsToday: data ? 100 : null,
          goal: data ? 8000 : null,
          stepsAsOf: data ? noon : null,
          restDay: true,
        );
        expect(p.todayAt, isNull, reason: 'data=$data');
        expect(p.repeatingFrom, tomorrow7pm,
            reason: 'tomorrow carries on, even with no step data');
      }
    });

    test('the slot already past: tomorrow, whatever the numbers say', () {
      final p = plan(
          now: DateTime(2026, 3, 10, 20),
          steps: 100,
          goal: 8000,
          asOf: DateTime(2026, 3, 10, 19, 59));
      expect(p.todayAt, isNull);
      expect(p.repeatingFrom, tomorrow7pm);
    });

    test('at the minute itself counts as past', () {
      final p = plan(now: at7pm, steps: 100, goal: 8000, asOf: at7pm);
      expect(p.todayAt, isNull);
      expect(p.repeatingFrom, tomorrow7pm);
    });

    test('tomorrow is a calendar day, across a month end', () {
      final p = plan(now: DateTime(2026, 1, 31, 20), steps: 1, goal: 2, asOf: noon);
      expect(p.repeatingFrom, DateTime(2026, 2, 1, 19));
    });

    test('a reminder at midnight-ish minute wraps hours safely', () {
      final p = plan(minute: 24 * 60 + 30); // 24:30 is read as 00:30
      expect(p.repeatingFrom.hour, 0);
      expect(p.repeatingFrom.minute, 30);
    });
  });
}
