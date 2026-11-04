/// What counts as leaving the app mid-round, and when leaving is a habit.
///
/// The OS reports that the app was backgrounded and nothing about why — another
/// app, the screen timing out and the power button look the same. These tests pin
/// the rules that keep the other explanations out of the count, and the bar a
/// pattern has to clear before anyone is told "you usually step away at minute 22".
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/insight_engine.dart';
import 'package:tablet_remainder/features/focus/services/focus_drift.dart';

void main() {
  final now = DateTime(2026, 9, 14, 12);

  /// A departure [daysAgo] days before [now], at minute [minute] of a round.
  DriftEvent ev(int daysAgo, int minute, {int planned = 25, int hour = 10}) =>
      DriftEvent(
        at: DateTime(2026, 9, 14 - daysAgo, hour),
        minute: minute,
        plannedMinutes: planned,
      );

  group('leaving: what could ever count', () {
    DriftLeave? leave(int seconds, {int planned = 25}) => DriftRules.leaving(
          now: now,
          phaseKey: 1,
          elapsedSeconds: seconds,
          plannedMinutes: planned,
        );

    test('under ten minutes in is not kept — start-and-switch and the screen timeout live here',
        () {
      expect(leave(599), isNull);
      expect(leave(0), isNull);
    });

    test('ten minutes in exactly is kept', () {
      expect(leave(600), isNotNull);
    });

    test('the last tenth of the round is not kept', () {
      // 25 minutes = 1500 s; nine tenths of it is 1350 s.
      expect(leave(1349), isNotNull);
      expect(leave(1350), isNull);
      expect(leave(1499), isNull);
    });

    test('a round with no length is never kept', () {
      expect(leave(900, planned: 0), isNull);
    });

    test('it remembers when, how far in, and which round', () {
      final l = DriftRules.leaving(
        now: now,
        phaseKey: 42,
        elapsedSeconds: 1320,
        plannedMinutes: 25,
      )!;
      expect(l.at, now);
      expect(l.elapsedSeconds, 1320);
      expect(l.plannedMinutes, 25);
      expect(l.phaseKey, 42);
    });
  });

  group('coming back: whether it counts', () {
    final left = DriftLeave(
      at: now,
      elapsedSeconds: 22 * 60 + 59,
      plannedMinutes: 25,
      phaseKey: 7,
    );

    DriftEvent? back(
      Duration away, {
      int phaseKey = 7,
      int remaining = 100,
    }) =>
        left.returnedAt(now.add(away), phaseKey: phaseKey, remainingSeconds: remaining);

    test('back a couple of minutes later, round still running: it counts', () {
      final e = back(const Duration(minutes: 2))!;
      expect(e.at, now, reason: 'the time they LEFT');
      expect(e.plannedMinutes, 25);
    });

    test('the minute is whole minutes done, not rounded up', () {
      expect(back(const Duration(minutes: 2))!.minute, 22);
    });

    test('a different round is not matched', () {
      expect(back(const Duration(minutes: 2), phaseKey: 8), isNull);
    });

    test('the round ended while they were away: not a drift, a phone put down', () {
      expect(back(const Duration(minutes: 2), remaining: 0), isNull);
      expect(back(const Duration(minutes: 2), remaining: -30), isNull);
    });

    test('one second left still counts', () {
      expect(back(const Duration(minutes: 2), remaining: 1), isNotNull);
    });

    test('under five seconds is an overlay, not leaving', () {
      expect(back(const Duration(seconds: 4)), isNull);
      expect(back(const Duration(seconds: 5)), isNotNull);
    });

    test('over ten minutes is a phone in a pocket', () {
      expect(back(const Duration(minutes: 10)), isNotNull);
      expect(back(const Duration(minutes: 10, seconds: 1)), isNull);
    });
  });

  group('an event, stored', () {
    test('survives a round trip through JSON', () {
      final e = ev(3, 22);
      final back = DriftEvent.tryParse(e.toJson())!;
      expect(back.at, e.at);
      expect(back.minute, 22);
      expect(back.plannedMinutes, 25);
    });

    test('a number that came back as a double is still read', () {
      final e = DriftEvent.tryParse({
        'at': DateTime(2026, 9, 1).millisecondsSinceEpoch.toDouble(),
        'minute': 22.0,
        'planned': 25.0,
      })!;
      expect(e.minute, 22);
      expect(e.plannedMinutes, 25);
    });

    test('anything that is not one is dropped rather than thrown', () {
      final good = ev(1, 20).toJson();
      for (final bad in <Object?>[
        null,
        'x',
        42,
        <String, dynamic>{},
        {...good}..remove('at'),
        {...good}..remove('minute'),
        {...good}..remove('planned'),
        {...good, 'minute': 'twenty'},
        {...good, 'minute': -1},
        {...good, 'planned': 0},
        {...good, 'minute': 0, 'planned': 0},
        {...good, 'minute': 30, 'planned': 25},
      ]) {
        expect(DriftEvent.tryParse(bad), isNull, reason: '$bad');
      }
    });
  });

  group('a pattern', () {
    List<DriftEvent> habit({int days = 5, int minute = 22}) =>
        [for (var d = 1; d <= days; d++) ev(d, minute)];

    test('five times on five days at the same minute is one', () {
      final p = DriftAnalysis.find(habit(), now: now)!;
      expect(p.minute, 22);
      expect(p.times, 5);
      expect(p.days, 5);
      expect(p.total, 5);
    });

    test('four times is not enough', () {
      expect(DriftAnalysis.find(habit(days: 4), now: now), isNull);
    });

    test('five times on three days is not enough: one bad afternoon is not a habit', () {
      final events = [
        ev(1, 22), ev(1, 22, hour: 14),
        ev(2, 22), ev(2, 22, hour: 14),
        ev(3, 22),
      ];
      expect(DriftAnalysis.find(events, now: now), isNull);
    });

    test('five times on four days is enough', () {
      final events = [
        ev(1, 22), ev(1, 22, hour: 14),
        ev(2, 22), ev(3, 22), ev(4, 22),
      ];
      final p = DriftAnalysis.find(events, now: now)!;
      expect(p.days, 4);
      expect(p.times, 5);
    });

    test('the same time of day on different dates is different days', () {
      // Days are told apart by DATE, not by hour.
      final events = [for (var d = 1; d <= 5; d++) ev(d, 22, hour: 9)];
      expect(DriftAnalysis.find(events, now: now)!.days, 5);
    });

    test('minutes within three either side agree; four does not', () {
      final within = [ev(1, 19), ev(2, 20), ev(3, 22), ev(4, 24), ev(5, 25)];
      expect(DriftAnalysis.find(within, now: now), isNotNull,
          reason: '19 and 25 are each three from 22');
      final outside = [ev(1, 18), ev(2, 20), ev(3, 22), ev(4, 24), ev(5, 26)];
      expect(DriftAnalysis.find(outside, now: now), isNull,
          reason: 'no seven-minute stretch holds five of them');
    });

    test('the usual minute is the middle of those that agree', () {
      final events = [ev(1, 19), ev(2, 21), ev(3, 22), ev(4, 23), ev(5, 25)];
      expect(DriftAnalysis.find(events, now: now)!.minute, 22);
    });

    test('with an even number the middle is rounded', () {
      // 21 and 22 are the two in the middle: 21.5 rounds to 22.
      final events = [
        ev(1, 20), ev(2, 21), ev(3, 22), ev(4, 23), ev(5, 21), ev(6, 22),
      ];
      expect(DriftAnalysis.find(events, now: now)!.minute, 22);
    });

    test('a few strays among many that agree do not hide it', () {
      final events = [
        for (var d = 1; d <= 6; d++) ev(d, 22),
        ev(7, 11),
        ev(8, 40, planned: 50),
      ];
      final p = DriftAnalysis.find(events, now: now)!;
      expect(p.minute, 22);
      expect(p.times, 6);
      expect(p.total, 8);
    });

    test('six of ten is exactly the bar; five of ten is under it', () {
      List<DriftEvent> mixed(int agree) => [
            for (var d = 1; d <= agree; d++) ev(d, 22),
            // Strays far from 22 and from each other, so they never form a
            // stretch of their own or fall inside the one at 22.
            for (var i = 0; i < 10 - agree; i++)
              ev(10 + i, const [10, 40, 50, 60, 70][i], planned: 90),
          ];
      expect(DriftAnalysis.find(mixed(6), now: now), isNotNull);
      expect(DriftAnalysis.find(mixed(5), now: now), isNull);
    });

    test('two habits and neither the majority: nothing is said', () {
      final events = [
        for (var d = 1; d <= 5; d++) ev(d, 12),
        for (var d = 6; d <= 10; d++) ev(d, 22),
      ];
      expect(DriftAnalysis.find(events, now: now), isNull,
          reason: 'the median is 17 — where nobody ever leaves');
    });

    test('two habits and one clearly the bigger: that one is named', () {
      final events = [
        for (var d = 1; d <= 7; d++) ev(d, 12),
        for (var d = 8; d <= 11; d++) ev(d, 22),
      ];
      final p = DriftAnalysis.find(events, now: now)!;
      expect(p.minute, 12);
      expect(p.times, 7);
    });

    test('two stretches of the same size: the earlier minute is named, in any order', () {
      // 10, 10, 10, 12, 14, 16, 16, 16 — the stretch around 12 and the one around
      // 14 each hold five; their middles are 10 and 16.
      final events = [
        for (var d = 1; d <= 3; d++) ev(d, 10),
        ev(4, 12),
        ev(5, 14),
        for (var d = 6; d <= 8; d++) ev(d, 16),
      ];
      for (final order in [events, events.reversed.toList()]) {
        final p = DriftAnalysis.find(order, now: now)!;
        expect(p.minute, 10);
        expect(p.times, 5);
        expect(p.total, 8);
      }
    });

    test('the same date in two different months is two days', () {
      // September 14th and August 14th: the same day of the month, 31 days apart.
      final events = [
        ev(0, 22), ev(31, 22), ev(1, 22), ev(2, 22), ev(2, 22, hour: 15),
      ];
      final p = DriftAnalysis.find(events, now: now)!;
      expect(p.days, 4);
      expect(p.times, 5);
    });

    test('the order they are stored in does not change the answer', () {
      final events = [
        for (var d = 1; d <= 7; d++) ev(d, 12 + d % 3),
        for (var d = 8; d <= 10; d++) ev(d, 30, planned: 45),
      ];
      final a = DriftAnalysis.find(events, now: now)!;
      final b = DriftAnalysis.find(events.reversed, now: now)!;
      final shuffled = [...events]..shuffle(Random(7));
      final c = DriftAnalysis.find(shuffled, now: now)!;
      for (final p in [b, c]) {
        expect(p.minute, a.minute);
        expect(p.times, a.times);
        expect(p.days, a.days);
      }
    });

    group('how far back', () {
      test('forty-five days ago is still how they focus', () {
        // Five days, the oldest of them exactly forty-five days back.
        final events = [for (var d = 41; d <= 45; d++) ev(d, 22)];
        expect(DriftAnalysis.find(events, now: now), isNotNull);
      });

      test('forty-six days ago is not', () {
        final events = [for (var d = 42; d <= 46; d++) ev(d, 22)];
        expect(DriftAnalysis.find(events, now: now), isNull,
            reason: 'one of the five is too old, leaving four');
      });

      test('old ones are not counted in the total either', () {
        final events = [
          for (var d = 1; d <= 5; d++) ev(d, 22),
          for (var d = 60; d <= 70; d++) ev(d, 11),
        ];
        final p = DriftAnalysis.find(events, now: now)!;
        expect(p.total, 5);
      });

      test('a date in the future is ignored — a clock that was changed', () {
        final events = [
          for (var d = 1; d <= 4; d++) ev(d, 22),
          DriftEvent(at: now.add(const Duration(days: 3)), minute: 22, plannedMinutes: 25),
        ];
        expect(DriftAnalysis.find(events, now: now), isNull);
      });
    });

    test('the cap keeps the newest', () {
      final many = [
        for (var i = 0; i < 250; i++)
          DriftEvent(at: DateTime(2026, 1, 1).add(Duration(minutes: i)), minute: i % 60, plannedMinutes: 90),
      ];
      final kept = DriftAnalysis.capped(many);
      expect(kept, hasLength(200));
      expect(kept.first.at, many[50].at);
      expect(kept.last.at, many.last.at);
      final few = many.sublist(0, 10);
      expect(DriftAnalysis.capped(few), hasLength(10));
    });
  });

  group('the round to suggest', () {
    DriftPattern at(int minute) =>
        DriftPattern(minute: minute, times: 5, days: 5, total: 5);

    test('ends before the usual minute, in steps of five', () {
      expect(at(22).suggestedWorkMinutes, 20);
      expect(at(29).suggestedWorkMinutes, 25);
      expect(at(19).suggestedWorkMinutes, 15);
      expect(at(47).suggestedWorkMinutes, 45);
    });

    test('STRICTLY before: a usual minute that is a multiple of five is not where it ends', () {
      // Rounded down it was: 25 -> 25, so the round ended at the minute they leave.
      expect(at(25).suggestedWorkMinutes, 20);
      expect(at(30).suggestedWorkMinutes, 25);
      expect(at(45).suggestedWorkMinutes, 40);
      for (var minute = 10; minute <= 55; minute++) {
        final w = at(minute).suggestedWorkMinutes;
        if (minute > 10) expect(w, lessThan(minute), reason: 'minute $minute');
        expect(w % 5, 0, reason: 'minute $minute: steps of five');
      }
    });

    test('never under ten minutes', () {
      expect(at(10).suggestedWorkMinutes, 10);
      expect(at(12).suggestedWorkMinutes, 10);
      expect(at(14).suggestedWorkMinutes, 10);
      expect(at(7).suggestedWorkMinutes, 10, reason: 'cannot happen — the rules start at ten');
    });

    test('and a five-minute break', () {
      expect(at(22).suggestedBreakMinutes, 5);
    });
  });

  group('the card', () {
    final insight = InsightEngine.focusDrift(
      usualMinute: 22,
      workMinutes: 20,
      breakMinutes: 5,
      times: 6,
      days: 5,
      total: 8,
    );

    test('says the minute and offers the round', () {
      expect(insight.id, 'focus_drift');
      expect(insight.title, 'You often step away around minute 22');
      expect(insight.actionLabel, 'Try 20 + 5');
      expect(insight.detail, contains('22-minute'));
      expect(insight.detail, contains('20-minute round'));
      expect(insight.detail, contains('5-minute break'));
    });

    test('shows its working, including that the screen turning off counts', () {
      expect(insight.why, contains('8 times'));
      expect(insight.why, contains('6 of them'));
      expect(insight.why, contains('minute 22'));
      expect(insight.why, contains('5 different days'));
      expect(insight.why, contains('The screen turning off counts as leaving'));
    });

    test('calls it leaving, never distraction — the phone cannot know', () {
      final words = '${insight.title} ${insight.detail} ${insight.why}'.toLowerCase();
      expect(words, isNot(contains('distract')));
      expect(words, isNot(contains('failed')));
    });
  });
}
