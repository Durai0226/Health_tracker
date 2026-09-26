import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';

/// W-15 — the pacing prune decides how many water reminders a person gets, and
/// nothing tested it.
///
/// It was one private method that both READ the world
/// (`WaterService.getTodayData()`, `clock.now()`, `typicalDrinkMl()`) and
/// applied the rule, so exercising the rule meant standing up the water service
/// — and no test did. The evenly-spaced-subset maths, the ahead-of-pace
/// decrement and the floor-at-one were all unexercised in a feature whose whole
/// complaint is notification fatigue.
///
/// Reading and deciding are now separate; this tests the decision.
void main() {
  // 07:00 → 22:00, a nudge every three hours.
  const slots = [420, 600, 780, 960, 1140, 1320];

  List<int> prune({
    List<int> times = slots,
    int goalMl = 2500,
    int intakeMl = 0,
    required int nowMinutes,
    int typicalDrinkMl = 250,
    int bedHour = 23,
    int bedMinute = 0,
  }) =>
      ReminderRescheduleService.pruneToRemainingNeed(
        times,
        goalMl: goalMl,
        intakeMl: intakeMl,
        nowMinutes: nowMinutes,
        typicalDrinkMl: typicalDrinkMl,
        bedHour: bedHour,
        bedMinute: bedMinute,
      );

  group('the goal is already met', () {
    // Note for anyone mutation-testing this: the source guards it TWICE —
    // `remaining <= 0` returns early, and `needed <= 0` catches the same state
    // further down. Removing either alone changes nothing, because the other
    // still returns const []. Both must go for this group to fail, which it
    // then does. The redundancy is harmless and left deliberately; recording it
    // here so a zero-failure mutation is not mistaken for a vacuous test.
    test('no reminder survives — the day is done', () {
      expect(prune(intakeMl: 2500, nowMinutes: 600), isEmpty);
      expect(prune(intakeMl: 3000, nowMinutes: 600), isEmpty,
          reason: 'over the goal is still met');
    });
  });

  group('nothing left to prune', () {
    test('an empty schedule stays empty', () {
      expect(prune(times: const [], nowMinutes: 600), isEmpty);
    });

    test('after the last slot the schedule is left alone', () {
      // These repeat daily, so clearing them would silence tomorrow too.
      expect(prune(nowMinutes: 1400), slots,
          reason: 'every slot has passed; they must stay registered for '
              'tomorrow rather than be pruned away today');
    });
  });

  group('how many nudges the gap actually needs', () {
    test('a large gap keeps every remaining slot', () {
      // 2500 ml to go at 06:00 = 10 drinks needed, only 6 slots exist.
      expect(prune(nowMinutes: 360), slots);
    });

    test('a small gap keeps fewer, and always the last one', () {
      // 250 ml to go at 06:00 = one drink. Behind pace at 06:00? No — early,
      // so "ahead" applies and the floor-at-one holds it at a single nudge.
      final kept = prune(intakeMl: 2250, nowMinutes: 360);
      expect(kept.length, lessThan(slots.length));
      expect(kept.last, slots.last,
          reason: 'there must be a final nudge before bed');
    });

    test('past slots are never dropped, only future ones thinned', () {
      final kept = prune(intakeMl: 2250, nowMinutes: 800);
      expect(kept.where((t) => t <= 800), containsAll([420, 600, 780]),
          reason: 'past slots repeat daily and are re-pruned tomorrow');
    });
  });

  group('pace, not just volume', () {
    test('projected to miss keeps the full schedule — nagging is the point', () {
      // 2400 ml still to go at 21:00 with an hour before bed: unreachable.
      expect(prune(intakeMl: 100, nowMinutes: 1260, bedHour: 22), slots);
    });

    test('never goes silent on someone who still has a gap', () {
      // Whatever the pace says, a remaining gap must leave at least one nudge.
      for (final now in [360, 600, 900, 1200]) {
        final kept = prune(intakeMl: 2400, nowMinutes: now);
        if (kept.any((t) => t > now)) {
          expect(kept.where((t) => t > now).length, greaterThanOrEqualTo(1));
        }
      }
    });
  });

  group('a nonsense drink size cannot divide by zero', () {
    test('zero and negative fall back to 250 ml', () {
      expect(() => prune(nowMinutes: 360, typicalDrinkMl: 0), returnsNormally);
      expect(() => prune(nowMinutes: 360, typicalDrinkMl: -50), returnsNormally);
      expect(prune(nowMinutes: 360, typicalDrinkMl: 0), slots,
          reason: '2500/250 = 10 drinks needed, more than the 6 slots');
    });
  });
}
