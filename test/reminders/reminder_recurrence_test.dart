import 'package:flutter_test/flutter_test.dart';
import 'package:rrule/rrule.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_recurrence.dart';

/// The old `RepeatType` could express daily, weekly, weekdays, weekends and a
/// day-of-week set — and nothing else. No "every other Tuesday", no monthly, no
/// "last Friday of the month", no end date, no occurrence count. Every
/// comparable app has had all of those for years.
///
/// The risk in adding RFC 5545 here is time zones, not expressiveness: `rrule`
/// requires `isUtc: true` and states it "doesn't care about any time-zone-related
/// stuff", while a reminder is a WALL-CLOCK promise. The floating-time
/// convention is what reconciles those, and it is the thing most worth pinning.
void main() {
  ReminderRecurrence rule(String s) =>
      ReminderRecurrence.rrule(RecurrenceRule.fromString(s));

  group('what the old enum could not express', () {
    test('every other week on a Tuesday', () {
      final r = rule('RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
      final start = DateTime(2026, 6, 2, 9); // a Tuesday
      expect(
        r.preview(start: start, limit: 3),
        [DateTime(2026, 6, 2, 9), DateTime(2026, 6, 16, 9), DateTime(2026, 6, 30, 9)],
      );
    });

    test('every 3 days', () {
      final r = rule('RRULE:FREQ=DAILY;INTERVAL=3');
      final start = DateTime(2026, 6, 1, 8);
      expect(r.preview(start: start, limit: 3),
          [DateTime(2026, 6, 1, 8), DateTime(2026, 6, 4, 8), DateTime(2026, 6, 7, 8)]);
    });

    test('monthly on the 15th', () {
      final r = rule('RRULE:FREQ=MONTHLY;BYMONTHDAY=15');
      final start = DateTime(2026, 1, 15, 7);
      final got = r.preview(start: start, limit: 3);
      expect(got.map((d) => '${d.year}-${d.month}-${d.day}'),
          ['2026-1-15', '2026-2-15', '2026-3-15']);
    });

    test('the last Friday of every month (BYSETPOS)', () {
      final r = rule('RRULE:FREQ=MONTHLY;BYDAY=FR;BYSETPOS=-1');
      final got = r.preview(start: DateTime(2026, 1, 30, 17), limit: 3);
      for (final d in got) {
        expect(d.weekday, DateTime.friday);
        // A last Friday is always within the final 7 days of its month.
        expect(DateTime(d.year, d.month + 1, 0).day - d.day, lessThan(7));
      }
    });

    test('an end date stops the series (UNTIL)', () {
      final r = rule('RRULE:FREQ=DAILY;UNTIL=20260605T000000Z');
      final start = DateTime(2026, 6, 1, 0);
      expect(r.preview(start: start, limit: 10).length, 5);
      expect(
        r.nextAfter(start: start, after: DateTime(2026, 6, 10)),
        isNull,
        reason: 'null means stop scheduling, not error',
      );
    });

    test('an occurrence count stops the series (COUNT)', () {
      final r = rule('RRULE:FREQ=WEEKLY;COUNT=3');
      final start = DateTime(2026, 6, 1, 9);
      expect(r.preview(start: start, limit: 10).length, 3);
      expect(r.nextAfter(start: start, after: DateTime(2026, 7, 1)), isNull);
    });
  });

  group('the floating-time convention', () {
    test('a rule keeps its wall-clock time across many months', () {
      // The naive local→UTC→local round trip would shift this by an hour on
      // either side of a DST transition. These assertions hold in ANY zone,
      // which is the point; the zone-specific proof is in the DST probe.
      final r = rule('RRULE:FREQ=MONTHLY;BYMONTHDAY=10');
      for (final d in r.preview(start: DateTime(2026, 1, 10, 8, 30), limit: 12)) {
        expect(d.hour, 8);
        expect(d.minute, 30);
      }
    });

    test('generated instances are local, not UTC', () {
      // Leaking a UTC DateTime out of here would silently shift every
      // comparison against `clock.now()`.
      final got = rule('RRULE:FREQ=DAILY')
          .preview(start: DateTime(2026, 6, 1, 8), limit: 2);
      expect(got.every((d) => !d.isUtc), isTrue);
    });

    test('nextAfter is strictly after, never equal', () {
      final start = DateTime(2026, 6, 1, 8);
      expect(
        rule('RRULE:FREQ=DAILY').nextAfter(start: start, after: start),
        DateTime(2026, 6, 2, 8),
        reason: 'returning the same instant would re-fire the occurrence the '
            'user just completed',
      );
    });
  });

  group('legacy rules keep working, unchanged', () {
    test('every legacy type still steps correctly', () {
      final wed = DateTime(2026, 6, 10, 9); // a Wednesday
      DateTime? next(RepeatType t, [List<int>? days]) => ReminderRecurrence
          .legacy(t, days)
          .nextAfter(start: wed, after: wed);

      expect(next(RepeatType.daily), DateTime(2026, 6, 11, 9));
      expect(next(RepeatType.weekly), DateTime(2026, 6, 17, 9));
      expect(next(RepeatType.custom, const [1, 3]), DateTime(2026, 6, 15, 9));
      // Friday jumps the weekend.
      expect(
        ReminderRecurrence.legacy(RepeatType.weekdays).nextAfter(
            start: DateTime(2026, 6, 12, 9), after: DateTime(2026, 6, 12, 9)),
        DateTime(2026, 6, 15, 9),
      );
    });

    test('none does not repeat', () {
      final r = ReminderRecurrence.legacy(RepeatType.none);
      expect(r.repeats, isFalse);
      expect(
          r.nextAfter(start: DateTime(2026, 6, 1), after: DateTime(2026, 6, 1)),
          isNull);
    });

    test('custom with no days does not hang', () {
      // The bounded loop matters: an unbounded one here would freeze the
      // reminders list rather than fail visibly.
      final r = ReminderRecurrence.legacy(RepeatType.custom, const []);
      expect(
        r.nextAfter(
            start: DateTime(2026, 6, 1, 9), after: DateTime(2026, 6, 1, 9)),
        DateTime(2026, 6, 2, 9),
      );
    });
  });

  group('parsing a stored rule never takes the list down', () {
    test('a valid rule string round-trips', () {
      final r = ReminderRecurrence.parse('RRULE:FREQ=DAILY;INTERVAL=2',
          fallback: RepeatType.none);
      expect(r.isRrule, isTrue);
      expect(r.asStoredString, contains('INTERVAL=2'));
    });

    test('garbage falls back to the legacy rule rather than throwing', () {
      // A rule written by a newer build, or a corrupted row, must degrade to the
      // reminder still repeating on its old schedule.
      final r = ReminderRecurrence.parse('RRULE:FREQ=TELEPATHY',
          fallback: RepeatType.daily);
      expect(r.isRrule, isFalse);
      expect(
        r.nextAfter(
            start: DateTime(2026, 6, 1, 9), after: DateTime(2026, 6, 1, 9)),
        DateTime(2026, 6, 2, 9),
      );
    });

    test('null and empty mean "use the legacy rule"', () {
      for (final s in [null, '', '   ']) {
        expect(ReminderRecurrence.parse(s, fallback: RepeatType.weekly).isRrule,
            isFalse);
      }
    });
  });

  group('human-readable descriptions', () {
    test('an RRULE describes itself', () async {
      final text = await rule('RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU').describe();
      expect(text.toLowerCase(), contains('week'));
    });

    test('legacy types have labels too', () async {
      expect(await ReminderRecurrence.legacy(RepeatType.weekdays).describe(),
          'Weekdays');
      expect(
          await ReminderRecurrence.legacy(RepeatType.custom, const [1, 3])
              .describe(),
          'Mon, Wed');
      expect(await ReminderRecurrence.legacy(RepeatType.none).describe(),
          'Does not repeat');
    });
  });
}
