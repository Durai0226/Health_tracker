/// Reminder ids a weekday's width apart.
///
/// A reminder that repeats on chosen days is armed under `slot + 1 … slot + 7`,
/// one notification a day — and the OS keeps one pending notification per id. The
/// allocator handed out `970000, 970001, 970002 …`, so a weekday reminder's
/// Tuesday was the next reminder's slot: the one armed second replaced the one
/// armed first, and one of the two never fired.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/reminder_slot_spacing.dart';

void main() {
  const base = 970000;
  const capacity = 1000;

  int? free(Iterable<int> taken, {int cap = capacity}) =>
      ReminderSlotSpacing.lowestFree(taken, base: base, capacity: cap);

  group('what counts as sharing an id', () {
    test('a reminder owns its slot and the seven after it', () {
      expect(ReminderSlotSpacing.span, 8);
      expect(ReminderSlotSpacing.overlap(base, base), isTrue);
      expect(ReminderSlotSpacing.overlap(base, base + 1), isTrue,
          reason: 'the old allocator\'s neighbour: base + 1 is base\'s Monday');
      expect(ReminderSlotSpacing.overlap(base, base + 7), isTrue,
          reason: 'base + 7 is base\'s Sunday');
      expect(ReminderSlotSpacing.overlap(base, base + 8), isFalse);
      expect(ReminderSlotSpacing.overlap(base + 8, base), isFalse,
          reason: 'the same either way round');
      expect(ReminderSlotSpacing.overlap(base + 7, base), isTrue);
    });
  });

  group('the next free place', () {
    test('an empty block starts at its base', () {
      expect(free(const []), base);
    });

    test('one reminder takes a whole week of ids, so the next starts after it', () {
      expect(free([base]), base + 8);
      expect(free([base, base + 8]), base + 16);
    });

    test('reminders already one apart push the next one clear of all of them', () {
      // What an install that handed out consecutive ids looks like.
      expect(free([base, base + 1, base + 2]), base + 10);
    });

    test('a place somebody left comes back first', () {
      expect(free([base + 8, base + 16]), base,
          reason: 'lowest free, so churn does not walk off the end of the block');
      expect(free([base, base + 16]), base + 8);
    });

    test('a gap too narrow for a week of ids is passed over', () {
      expect(free([base, base + 12]), base + 20,
          reason: 'base + 8 would run into base + 12\'s first day');
      expect(free([base, base + 9]), base + 17);
    });

    test('the order they are given in makes no difference', () {
      expect(free([base + 16, base, base + 8]), base + 24);
      expect(free([base + 8, base + 24, base, base + 16]), base + 32);
    });

    test('an id from somewhere else in the number space is not in the way', () {
      expect(free([1234567, 42, base + 8]), base,
          reason: 'a legacy hash id is nowhere near the block');
    });

    test('a block with no whole week left says so', () {
      expect(free([base, base + 8, base + 16], cap: 24), isNull);
      expect(free([base], cap: 16), base + 8, reason: 'exactly fills the block');
      expect(free([base, base + 8], cap: 16), isNull);
      expect(free(const [], cap: 7), isNull,
          reason: 'a block narrower than one week holds none');
    });

    test('the reserved block holds 125 reminders, each with its own week', () {
      final taken = <int>[];
      for (;;) {
        final next = free(taken);
        if (next == null) break;
        taken.add(next);
      }
      expect(taken, hasLength(125));
      expect(taken.first, base);
      expect(taken.last + 7, lessThan(base + capacity),
          reason: 'the last weekday sub-id is still inside the block');
    });
  });

  group('across a lot of adding and deleting', () {
    test('no two reminders ever share an id, and each week stays in the block', () {
      // A deterministic shuffle: add, delete a pseudo-random one, add again.
      var seed = 7;
      int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final taken = <int>[];
      for (var step = 0; step < 600; step++) {
        if (taken.length > 90 || (taken.isNotEmpty && next() % 3 == 0)) {
          taken.removeAt(next() % taken.length);
        }
        final slot = free(taken);
        if (slot == null) continue;
        taken.add(slot);

        final ids = <int>{};
        for (final s in taken) {
          expect(s, greaterThanOrEqualTo(base));
          expect(s + 7, lessThan(base + capacity));
          for (var d = 0; d <= 7; d++) {
            expect(ids.add(s + d), isTrue,
                reason: 'id ${s + d} (slot $s + $d) is used twice after step $step');
          }
        }
      }
    });
  });

  group('putting right slots that were handed out one apart', () {
    test('the first of a clashing group keeps its place, the rest move', () {
      final moved = ReminderSlotSpacing.clashing(
          [base, base + 1, base + 2, base + 10, base + 11], (s) => s);
      expect(moved, [base + 1, base + 2, base + 11]);
    });

    test('slots a week apart are left alone', () {
      expect(
          ReminderSlotSpacing.clashing([base, base + 8, base + 16], (s) => s),
          isEmpty);
    });

    test('the order given decides who stays: oldest first', () {
      final byAge = [
        (name: 'old', slot: base + 1),
        (name: 'new', slot: base),
      ];
      final moved = ReminderSlotSpacing.clashing(byAge, (r) => r.slot);
      expect(moved.map((r) => r.name), ['new'],
          reason: 'the older reminder has been armed longest, so it is the one '
              'left where it is');
    });

    test('nothing to move when there is nothing', () {
      expect(ReminderSlotSpacing.clashing(<int>[], (s) => s), isEmpty);
      expect(ReminderSlotSpacing.clashing([base], (s) => s), isEmpty);
    });

    test('a moved reminder, placed again, no longer clashes with anyone', () {
      final slots = [base, base + 1, base + 2, base + 3];
      final stay = [slots.first];
      final taken = [...stay];
      for (final _ in ReminderSlotSpacing.clashing(slots, (s) => s)) {
        taken.add(free(taken)!);
      }
      expect(taken, hasLength(4));
      expect(ReminderSlotSpacing.clashing(taken, (s) => s), isEmpty);
    });
  });
}
