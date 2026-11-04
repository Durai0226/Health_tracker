/// What someone usually does at this time of day.
///
/// Completed rounds that started within an hour of now, over the last sixty days;
/// one activity that clearly wins, on enough different days to be a routine and
/// not a coincidence. Anything less is silence.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/focus_habit.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';

void main() {
  final now = DateTime(2026, 9, 14, 9, 30);

  const study = 1;
  const work = 0;
  const read = 2;
  const rain = 5;
  const cafe = 6;

  /// A round [daysAgo] days before [now], starting at [hour]:[minute].
  HabitSession round(
    int daysAgo, {
    int activity = study,
    int minutes = 45,
    int hour = 9,
    int minute = 0,
    int? sound,
    bool completed = true,
  }) =>
      HabitSession(
        startedAt: DateTime(2026, 9, 14 - daysAgo, hour, minute),
        minutes: minutes,
        activity: activity,
        sound: sound,
        completed: completed,
      );

  List<HabitSession> routine({int days = 5, int activity = study, int minutes = 45, int? sound}) =>
      [for (var d = 1; d <= days; d++) round(d, activity: activity, minutes: minutes, sound: sound)];

  group('when there is a habit', () {
    test('four rounds of one activity on four days is one', () {
      final h = FocusHabits.at(routine(days: 4), now: now)!;

      expect(h.activity, study);
      expect(h.minutes, 45);
      expect(h.times, 4);
      expect(h.days, 4);
      expect(h.total, 4);
    });

    test('three rounds are not enough', () {
      expect(FocusHabits.at(routine(days: 3), now: now), isNull);
    });

    test('four rounds on two days are not a routine', () {
      final rounds = [
        round(1), round(1, hour: 10), round(2), round(2, hour: 10),
      ];
      expect(FocusHabits.at(rounds, now: now), isNull);
    });

    test('the same date in two different months is two days', () {
      // September 14th and August 14th: the same day of the month, 31 days apart.
      final rounds = [round(0), round(31), round(1), round(1, hour: 10)];
      final h = FocusHabits.at(rounds, now: now)!;
      expect(h.days, 3);
    });

    test('four rounds on three days are', () {
      final rounds = [round(1), round(1, hour: 10), round(2), round(3)];
      final h = FocusHabits.at(rounds, now: now)!;
      expect(h.days, 3);
      expect(h.times, 4);
    });

    test('the order they are given in does not matter', () {
      final rounds = [
        ...routine(days: 6),
        round(7, activity: work), round(8, activity: read),
      ];
      final a = FocusHabits.at(rounds, now: now)!;
      final b = FocusHabits.at(rounds.reversed, now: now)!;
      final c = FocusHabits.at([...rounds]..shuffle(Random(3)), now: now)!;
      for (final h in [b, c]) {
        expect(h.activity, a.activity);
        expect(h.minutes, a.minutes);
        expect(h.times, a.times);
      }
    });
  });

  group('what counts as near this time', () {
    // An hour is an hour, to the minute. Comparing the hour of the clock made "within
    // an hour" anything from nothing to nearly two: at 11:59 a round that began at
    // 10:00 counted, and at 11:00 one that began at 09:59 did not.
    List<HabitSession> startingAt(List<(int, int)> times) => [
          for (var i = 0; i < times.length; i++)
            round(i + 1, hour: times[i].$1, minute: times[i].$2),
        ];

    test('an hour either side of now, to the minute', () {
      // now is 9:30.
      final near = startingAt([(8, 45), (9, 0), (10, 15), (9, 59)]);
      expect(FocusHabits.at(near, now: now), isNotNull);

      final far = startingAt([(7, 0), (11, 0), (7, 30), (11, 30)]);
      expect(FocusHabits.at(far, now: now), isNull);
    });

    test('exactly an hour is near; a minute more is not', () {
      expect(FocusHabits.at(startingAt([(8, 30), (8, 30), (10, 30), (10, 30)]), now: now),
          isNotNull,
          reason: '60 minutes either side');
      expect(FocusHabits.at(startingAt([(8, 29), (8, 29), (10, 31), (10, 31)]), now: now),
          isNull,
          reason: '61 minutes either side');
    });

    test('a round nearly two hours before is not near, though its hour is next door', () {
      final late = DateTime(2026, 9, 14, 11, 59);
      final rounds = startingAt([(10, 0), (10, 0), (10, 0), (10, 0)]);

      expect(FocusHabits.at(rounds, now: late), isNull, reason: '119 minutes');
    });

    test('a round only sixty-one minutes before is not near either, though it began in an earlier hour',
        () {
      final at11 = DateTime(2026, 9, 14, 11, 0);

      expect(FocusHabits.at(startingAt([(9, 59), (9, 59), (9, 59), (9, 59)]), now: at11), isNull,
          reason: '61 minutes');
      expect(FocusHabits.at(startingAt([(10, 0), (10, 0), (10, 0), (10, 0)]), now: at11),
          isNotNull,
          reason: '60 minutes');
    });

    test('going round midnight: 23:30 and 01:30 are an hour from 00:30; 23:29 and 01:31 are not',
        () {
      final lateNow = DateTime(2026, 9, 14, 0, 30);
      HabitSession at(int daysAgo, int hour, int minute) => HabitSession(
            startedAt: DateTime(2026, 9, 14 - daysAgo, hour, minute),
            minutes: 30,
            activity: study,
          );

      expect(
          FocusHabits.at([at(1, 23, 30), at(2, 23, 30), at(3, 1, 30), at(4, 1, 30)], now: lateNow),
          isNotNull);
      expect(
          FocusHabits.at([at(1, 23, 29), at(2, 23, 29), at(3, 1, 31), at(4, 1, 31)], now: lateNow),
          isNull);
    });

    test('only completed rounds: an abandoned one is ambition, not routine', () {
      final rounds = [
        round(1), round(2), round(3),
        round(4, completed: false), round(5, completed: false),
      ];
      expect(FocusHabits.at(rounds, now: now), isNull,
          reason: 'three completed');
    });

    test('a round under five minutes is not one; five is', () {
      final rounds = [round(1), round(2), round(3), round(4, minutes: 4)];
      expect(FocusHabits.at(rounds, now: now), isNull);

      final five = [for (var d = 1; d <= 4; d++) round(d, minutes: 5)];
      expect(FocusHabits.at(five, now: now)!.minutes, 5);
    });

    test('sixty days back still counts; sixty-one does not', () {
      expect(FocusHabits.at([for (var d = 57; d <= 60; d++) round(d)], now: now),
          isNotNull);
      expect(FocusHabits.at([for (var d = 58; d <= 61; d++) round(d)], now: now),
          isNull,
          reason: 'one of the four is too old');
    });

    test('a round dated in the future is ignored — a clock that was changed', () {
      final rounds = [
        round(1), round(2), round(3),
        HabitSession(
            startedAt: now.add(const Duration(hours: 1)), minutes: 45, activity: study),
      ];
      expect(FocusHabits.at(rounds, now: now), isNull);
    });
  });

  group('which activity', () {
    test('a clear winner with at least half the rounds', () {
      final rounds = [...routine(days: 4), round(5, activity: work)];
      final h = FocusHabits.at(rounds, now: now)!;
      expect(h.activity, study);
      expect(h.times, 4);
      expect(h.total, 5);
    });

    test('exactly half is enough; under half is not', () {
      // 4 study + 4 of other kinds that do not tie with it: 4/8.
      final half = [
        ...routine(days: 4),
        round(5, activity: work), round(6, activity: work), round(7, activity: read),
        round(8, activity: 3),
      ];
      expect(FocusHabits.at(half, now: now)!.activity, study);

      final under = [
        ...routine(days: 4),
        round(5, activity: work), round(6, activity: work), round(7, activity: read),
        round(8, activity: 3), round(9, activity: 4),
      ];
      expect(FocusHabits.at(under, now: now), isNull, reason: '4 of 9');
    });

    test('a tie for first is not a winner', () {
      final tie = [
        for (var d = 1; d <= 4; d++) round(d, activity: study),
        for (var d = 5; d <= 8; d++) round(d, activity: work),
      ];
      expect(FocusHabits.at(tie, now: now), isNull);
    });

    test('the winner must itself have the rounds: two of four is half, but two', () {
      final rounds = [
        round(1), round(2), round(3, activity: work), round(4, activity: read),
      ];
      expect(FocusHabits.at(rounds, now: now), isNull);
    });

    test('three rounds that lead is still three: not enough, on however many days', () {
      // Study 3 of 6 (half), work 2, read 1: the clear winner, on three days — with
      // three rounds, which is one short.
      final rounds = [
        round(1), round(2), round(3),
        round(4, activity: work), round(5, activity: work), round(6, activity: read),
      ];
      expect(FocusHabits.at(rounds, now: now), isNull);
    });

    test('and the days: four rounds of it on two days is not a routine, whatever else', () {
      // Eight rounds near this time, half of them study — on two days only.
      final rounds = [
        round(1), round(1, hour: 10), round(2), round(2, hour: 10),
        round(3, activity: work), round(4, activity: read),
        round(5, activity: 3), round(6, activity: 4),
      ];
      expect(FocusHabits.at(rounds, now: now), isNull);
    });
  });

  group('how long', () {
    int usual(List<int> minutes) => FocusHabits.at([
          for (var i = 0; i < minutes.length; i++) round(i + 1, minutes: minutes[i]),
        ], now: now)!
            .minutes;

    test('the middle one, to the nearest five minutes', () {
      expect(usual([40, 45, 45, 50]), 45);
      expect(usual([20, 25, 25, 30]), 25);
      expect(usual([47, 47, 47, 47]), 45, reason: '47 is nearer 45 than 50');
      expect(usual([48, 48, 48, 48]), 50);
    });

    test('an even count averages the two in the middle', () {
      expect(usual([22, 22, 23, 23]), 25, reason: '22.5 rounds up to 25');
      expect(usual([20, 20, 22, 22]), 20, reason: '21 rounds to 20');
      expect(usual([20, 20, 28, 28]), 25, reason: '24 rounds to 25, not the 28 above it');
    });

    test('one long outlier does not drag it', () {
      expect(usual([25, 25, 25, 25, 180]), 25);
    });

    test('never over two hours', () {
      expect(usual([130, 130, 130, 130]), 120);
    });

    test('only the winning activity\'s rounds are measured', () {
      final rounds = [
        ...routine(days: 5, minutes: 25),
        round(6, activity: work, minutes: 90),
        round(7, activity: work, minutes: 90),
      ];
      expect(FocusHabits.at(rounds, now: now)!.minutes, 25);
    });
  });

  group('the card', () {
    final withSound = InsightEngine.focusHabit(
      activityName: 'Study',
      minutes: 45,
      soundName: 'Rain',
      times: 6,
      days: 5,
      total: 8,
    );
    final silent = InsightEngine.focusHabit(
      activityName: 'Study',
      minutes: 45,
      times: 6,
      days: 5,
      total: 8,
    );

    test('says what they usually do, and offers it', () {
      expect(withSound.id, 'focus_habit');
      expect(withSound.title, 'Your usual round around now');
      expect(withSound.detail, startsWith('Study for 45 minutes, with Rain'));
      expect(withSound.actionLabel, 'Use this');
    });

    test('names no sound when there is no usual one', () {
      expect(silent.detail, startsWith('Study for 45 minutes —'));
      expect(silent.detail, isNot(contains('with')));
      expect(silent.why, isNot(contains('playing')));
    });

    test('shows its working, and that nothing changes until they say so', () {
      expect(withSound.why, contains('8 focus rounds'));
      expect(withSound.why, contains('6 were Study'));
      expect(withSound.why, contains('5 different days'));
      expect(withSound.why, contains('45 minutes'));
      expect(withSound.why, contains('Rain was playing in at least half of them'));
      expect(withSound.why, contains('Nothing is changed until you tap Use this'));
    });
  });

  group('which sound', () {
    test('the one playing in at least half of them', () {
      final rounds = [
        round(1, sound: rain), round(2, sound: rain), round(3), round(4),
      ];
      expect(FocusHabits.at(rounds, now: now)!.sound, rain);
    });

    test('under half is no usual sound', () {
      final rounds = [
        round(1, sound: rain), round(2), round(3), round(4),
      ];
      expect(FocusHabits.at(rounds, now: now)!.sound, isNull);
    });

    test('silence is the commonest and is not a sound', () {
      expect(FocusHabits.at(routine(days: 5), now: now)!.sound, isNull);
    });

    test('two sounds tied: neither', () {
      final rounds = [
        round(1, sound: rain), round(2, sound: rain),
        round(3, sound: cafe), round(4, sound: cafe),
      ];
      expect(FocusHabits.at(rounds, now: now)!.sound, isNull);
    });

    test('the sound of another activity does not count', () {
      final rounds = [
        ...routine(days: 5),
        round(6, activity: work, sound: cafe),
        round(7, activity: work, sound: cafe),
      ];
      expect(FocusHabits.at(rounds, now: now)!.sound, isNull);
    });
  });
}
