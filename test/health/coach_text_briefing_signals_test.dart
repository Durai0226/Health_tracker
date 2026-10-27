/// The Today briefing used to be handed steps and last night's sleep and say
/// nothing about either: both arrived in `dailyBriefing` and were dropped on the
/// floor. These pin what it says now, and when it keeps quiet.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';

void main() {
  const coach = CoachText();

  /// A day where nothing else has anything to say: no doses, water fine, focus
  /// done, no reminders. So whatever comes back is about steps or sleep.
  String brief({
    required int hour,
    int steps = 0,
    int stepGoal = 0,
    int sleepMinutes = 0,
    bool restDay = false,
    int waterPct = 100,
    int medsOutstanding = 0,
    int medsTotal = 0,
  }) =>
      coach.dailyBriefing(
        medsOutstanding: medsOutstanding,
        medsTotal: medsTotal,
        waterPct: waterPct,
        focusMinutes: 40,
        remindersLeft: 0,
        hour: hour,
        steps: steps,
        stepGoal: stepGoal,
        sleepMinutes: sleepMinutes,
        restDay: restDay,
      );

  group('a short night', () {
    test('is named in the morning, with the hours', () {
      final b = brief(hour: 9, sleepMinutes: 5 * 60 + 10);
      expect(b, contains('short night'));
      expect(b, contains('5h 10m'));
    });

    test('is dropped by the afternoon: it is only useful early', () {
      expect(brief(hour: 14, sleepMinutes: 300), isNot(contains('short night')));
      expect(brief(hour: 15, sleepMinutes: 300), isNot(contains('short night')));
    });

    test('is the last hour of the morning, not the first of the afternoon', () {
      expect(brief(hour: 13, sleepMinutes: 300), contains('short night'));
    });

    test('six hours is not short; five hours fifty-nine is', () {
      expect(brief(hour: 9, sleepMinutes: 360), isNot(contains('short night')));
      expect(brief(hour: 9, sleepMinutes: 359), contains('short night'));
    });

    test('no recorded night means nothing is claimed', () {
      expect(brief(hour: 9, sleepMinutes: 0), isNot(contains('short night')));
    });

    test('outranks the water line, which most mornings would otherwise win',
        () {
      final b = brief(hour: 9, sleepMinutes: 300, waterPct: 5);
      expect(b, contains('short night'));
    });

    test('but not an unfinished dose in the evening', () {
      // Evening is never "morning", so the two cannot meet; the dose line is
      // still the top of the list.
      final b = brief(
          hour: 19, sleepMinutes: 300, medsOutstanding: 1, medsTotal: 2);
      expect(b, contains('dose'));
    });
  });

  group('steps to go', () {
    test('early evening, short of the goal: how far, and what it is in walking',
        () {
      final b = brief(hour: 18, steps: 6200, stepGoal: 8000);
      expect(b, contains('1,800 steps to go'));
      expect(b, contains('about 18 minutes of walking'));
    });

    test('one minute reads as one minute', () {
      final b = brief(hour: 18, steps: 7950, stepGoal: 8000);
      expect(b, contains('about 1 minute of walking'));
    });

    test('not before 17:00, and not from 21:00', () {
      expect(brief(hour: 16, steps: 6200, stepGoal: 8000),
          isNot(contains('steps to go')));
      expect(brief(hour: 17, steps: 6200, stepGoal: 8000),
          contains('steps to go'));
      expect(brief(hour: 20, steps: 6200, stepGoal: 8000),
          contains('steps to go'));
      expect(brief(hour: 21, steps: 6200, stepGoal: 8000),
          isNot(contains('steps to go')));
    });

    test('no steps read at all is not "8,000 behind"', () {
      expect(brief(hour: 18, steps: 0, stepGoal: 8000),
          isNot(contains('steps to go')));
    });

    test('a rest or unwell day has no goal to chase', () {
      expect(brief(hour: 18, steps: 6200, stepGoal: 8000, restDay: true),
          isNot(contains('steps to go')));
    });

    test('a goal that is met says so, in the all-clear', () {
      final b = brief(hour: 18, steps: 9000, stepGoal: 8000);
      expect(b, contains('on track'));
      expect(b, contains('step goal is done'));
    });

    test('a met goal on a rest day is the plain all-clear', () {
      final b = brief(hour: 18, steps: 9000, stepGoal: 8000, restDay: true);
      expect(b, contains('on track'));
      expect(b, isNot(contains('step goal')));
    });

    test('water behind still comes first', () {
      final b = brief(hour: 18, steps: 6200, stepGoal: 8000, waterPct: 20);
      expect(b.toLowerCase(), contains('water'));
      expect(b, isNot(contains('steps to go')));
    });

    test('an unfinished dose in the evening still comes first', () {
      final b = brief(
          hour: 18,
          steps: 6200,
          stepGoal: 8000,
          medsOutstanding: 1,
          medsTotal: 1);
      expect(b, contains('dose'));
    });
  });

  test('with no steps or sleep given, nothing changes', () {
    expect(brief(hour: 15), contains('on track'));
    expect(brief(hour: 15), isNot(contains('step goal')));
  });
}
