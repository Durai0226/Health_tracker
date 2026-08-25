import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rrule/rrule.dart';
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_recurrence.dart';

/// Smart Add is the only way to CREATE an RFC 5545 repeat today — there is no
/// picker for one yet — so the parser is the feature's entry point, not a
/// convenience on top of it.
///
/// The parser is deliberately narrow. A wrong rule is a reminder that fires on
/// the wrong days indefinitely, which is worse than falling back to a plain
/// weekly one the user can see and correct on the form.
void main() {
  const coach = CoachText();

  /// Parse, then feed the result through the same recurrence engine the app
  /// uses — an RRULE string that does not survive that round trip is useless.
  List<DateTime> occurrencesFor(String phrase, DateTime start, {int limit = 4}) {
    final parsed = coach.parseReminder(phrase);
    final r = ReminderRecurrence.parse(
      parsed.recurrenceRule,
      fallback: RepeatType.none,
    );
    return r.preview(start: start, limit: limit);
  }

  group('phrases the six-value vocabulary could not express', () {
    test('"every other tuesday" becomes a real fortnightly rule', () {
      final got = occurrencesFor(
          'physio every other tuesday at 9am', DateTime(2026, 6, 2, 9),
          limit: 3);
      expect(got, [
        DateTime(2026, 6, 2, 9),
        DateTime(2026, 6, 16, 9),
        DateTime(2026, 6, 30, 9),
      ]);
    });

    test('"every 3 days"', () {
      expect(
        occurrencesFor('water the plants every 3 days', DateTime(2026, 6, 1, 8),
            limit: 3),
        [DateTime(2026, 6, 1, 8), DateTime(2026, 6, 4, 8), DateTime(2026, 6, 7, 8)],
      );
    });

    test('"every 2 weeks"', () {
      expect(
        occurrencesFor('bins out every 2 weeks', DateTime(2026, 6, 1, 7),
            limit: 3),
        [
          DateTime(2026, 6, 1, 7),
          DateTime(2026, 6, 15, 7),
          DateTime(2026, 6, 29, 7),
        ],
      );
    });

    test('"monthly" and "every other week"', () {
      expect(coach.parseReminder('pay rent monthly').recurrenceRule,
          contains('FREQ=MONTHLY'));
      expect(coach.parseReminder('call mum every other week').recurrenceRule,
          allOf(contains('FREQ=WEEKLY'), contains('INTERVAL=2')));
    });
  });

  group('end conditions', () {
    test('"5 times" becomes COUNT and actually stops', () {
      final parsed = coach.parseReminder('take antibiotics daily 5 times');
      expect(parsed.occurrenceLimit, 5);
      expect(parsed.recurrenceRule, contains('COUNT=5'));
      expect(
        occurrencesFor('take antibiotics daily 5 times', DateTime(2026, 6, 1, 8),
            limit: 20),
        hasLength(5),
      );
    });

    test('"until 5 july" becomes UNTIL', () {
      withClock(Clock.fixed(DateTime(2026, 6, 1, 10)), () {
        final parsed = coach.parseReminder('stretch daily until 5 july');
        expect(parsed.endsAt, DateTime(2026, 7, 5, 23, 59, 59));
        expect(parsed.recurrenceRule, contains('UNTIL='));
      });
    });

    test('a month/day with no year means the NEXT one, never a past date', () {
      // "until 5 january" said in June must mean next January, or the reminder
      // would be born already expired.
      withClock(Clock.fixed(DateTime(2026, 6, 1, 10)), () {
        expect(coach.parseReminder('stretch daily until 5 january').endsAt,
            DateTime(2027, 1, 5, 23, 59, 59));
      });
    });

    test('"until 2026-07-05" (ISO) works too', () {
      withClock(Clock.fixed(DateTime(2026, 6, 1, 10)), () {
        expect(coach.parseReminder('stretch daily until 2026-07-05').endsAt,
            DateTime(2026, 7, 5, 23, 59, 59));
      });
    });
  });

  group('it declines rather than guesses', () {
    test('an ordinary daily phrase produces no rule', () {
      // The legacy path handles it and produces a cheaper repeating
      // notification — one OS request instead of a materialised series.
      final parsed = coach.parseReminder('stretch every day at 8am');
      expect(parsed.recurrenceRule, isNull);
      expect(parsed.repeat, 'daily');
    });

    test('"every 1 day" is just daily, not an INTERVAL=1 rule', () {
      expect(coach.parseReminder('stretch every 1 day').recurrenceRule, isNull);
    });

    test('an absurd interval is refused', () {
      expect(coach.parseReminder('ping every 5000 days').recurrenceRule, isNull);
    });

    test('a phrase with no repeat at all produces nothing', () {
      final parsed = coach.parseReminder('call the dentist tomorrow at 2pm');
      expect(parsed.recurrenceRule, isNull);
      expect(parsed.occurrenceLimit, isNull);
      expect(parsed.endsAt, isNull);
    });
  });

  group('every produced rule is valid RFC 5545', () {
    test('the engine can parse everything the parser emits', () {
      const phrases = [
        'physio every other tuesday',
        'water plants every 3 days',
        'bins every 2 weeks',
        'rent monthly',
        'review yearly',
        'antibiotics daily 5 times',
        'stretch daily until 2026-07-05',
        'call mum every other week until 12 december',
      ];
      for (final phrase in phrases) {
        final rule = coach.parseReminder(phrase).recurrenceRule;
        expect(rule, isNotNull, reason: phrase);
        // Throws on a malformed rule — which would otherwise silently degrade
        // to the legacy fallback and quietly lose the user's intent.
        expect(() => RecurrenceRule.fromString(rule!), returnsNormally,
            reason: phrase);
      }
    });
  });
}
