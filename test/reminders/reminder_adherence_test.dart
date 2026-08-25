import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show ReminderOccurrence;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_adherence.dart';

/// PDC — proportion of days covered — is what the Pharmacy Quality Alliance
/// prefers over MPR, because MPR counts supply dispensed rather than days
/// actually covered and so can exceed 100%. ≥80% is the conventional adherent
/// threshold.
///
/// Two deliberate deviations from the clinical definition, both following the
/// honesty rules the rest of `lib/core/health/` already enforces: an unresolved
/// day is excluded rather than scored zero, and a deliberate skip does not count
/// against the user.
void main() {
  ReminderOccurrence row(DateTime at, ReminderOutcome outcome) =>
      ReminderOccurrence(
        id: RemindersDao.occurrenceId('r-1', at),
        reminderId: 'r-1',
        scheduledFor: at,
        outcome: outcome.name,
        snoozeCount: 0,
      );

  DateTime day(int d, [int hour = 9]) => DateTime(2026, 6, d, hour);

  group('a day only counts once something is known about it', () {
    test('a pending day is excluded, not scored zero', () {
      // Someone who has not opened the app today has an unknown day, not a
      // failure. Scoring it zero would measure app-opening, not adherence.
      final rows = [
        row(day(1), ReminderOutcome.done),
        row(day(2), ReminderOutcome.pending),
      ];
      expect(ReminderAdherence.byDay(rows), hasLength(1));
      expect(ReminderAdherence.proportionOfDaysCovered(rows), 1.0);
    });

    test('a deliberate skip does not count against you', () {
      // An adherence figure that punishes honesty teaches people to stop being
      // honest — so a skipped-only day drops out of both numerator and
      // denominator.
      final rows = [
        row(day(1), ReminderOutcome.done),
        row(day(2), ReminderOutcome.skipped),
      ];
      expect(ReminderAdherence.byDay(rows), hasLength(1));
      expect(ReminderAdherence.proportionOfDaysCovered(rows), 1.0);
    });

    test('no history at all returns null, never 0%', () {
      // "0% adherence" shown to someone who has not used the feature yet is
      // both wrong and discouraging.
      expect(ReminderAdherence.proportionOfDaysCovered(const []), isNull);
      expect(ReminderAdherence.proportionOfOccurrencesDone(const []), isNull);
      expect(ReminderAdherence.isAdherent(null), isFalse);
    });

    test('a missed day counts, and counts against', () {
      final rows = [
        row(day(1), ReminderOutcome.done),
        row(day(2), ReminderOutcome.missed),
      ];
      expect(ReminderAdherence.proportionOfDaysCovered(rows), 0.5);
    });
  });

  group('a day is covered only when every due occurrence was done', () {
    test('three of four doses in one day is an UNCOVERED day', () {
      final rows = [
        row(day(1, 8), ReminderOutcome.done),
        row(day(1, 12), ReminderOutcome.done),
        row(day(1, 16), ReminderOutcome.done),
        row(day(1, 20), ReminderOutcome.missed),
      ];
      expect(ReminderAdherence.proportionOfDaysCovered(rows), 0.0);
      // ...but the per-occurrence rate is 75%. Both numbers are true about
      // different things, which is exactly why both exist.
      expect(ReminderAdherence.proportionOfOccurrencesDone(rows), 0.75);
    });

    test('all four done is a covered day', () {
      final rows = [
        for (final h in [8, 12, 16, 20]) row(day(1, h), ReminderOutcome.done),
      ];
      expect(ReminderAdherence.proportionOfDaysCovered(rows), 1.0);
      expect(ReminderAdherence.proportionOfOccurrencesDone(rows), 1.0);
    });

    test('occurrences are grouped by their scheduled day, not by insertion', () {
      final rows = [
        row(day(3), ReminderOutcome.done),
        row(day(1), ReminderOutcome.missed),
        row(day(2), ReminderOutcome.done),
      ];
      final days = ReminderAdherence.byDay(rows);
      expect(days.map((d) => d.date.day), [1, 2, 3], reason: 'oldest first');
    });
  });

  group('the 80% threshold', () {
    List<ReminderOccurrence> ofWhich({required int done, required int missed}) => [
          for (var i = 0; i < done; i++) row(day(i + 1), ReminderOutcome.done),
          for (var i = 0; i < missed; i++)
            row(day(done + i + 1), ReminderOutcome.missed),
        ];

    test('exactly 80% is adherent', () {
      final pdc = ReminderAdherence.proportionOfDaysCovered(
          ofWhich(done: 8, missed: 2));
      expect(pdc, 0.8);
      expect(ReminderAdherence.isAdherent(pdc), isTrue);
    });

    test('just under is not', () {
      final pdc = ReminderAdherence.proportionOfDaysCovered(
          ofWhich(done: 7, missed: 3));
      expect(ReminderAdherence.isAdherent(pdc), isFalse);
    });
  });

  group('the streak reuses the app\'s own forgiveness', () {
    test('one miss in a week does not break it', () {
      // StreakEngine forgives one miss per rolling week, and the shield being
      // visible before the miss is a deliberate design worth inheriting rather
      // than reimplementing.
      final rows = [
        for (var d = 1; d <= 7; d++)
          row(day(d), d == 4 ? ReminderOutcome.missed : ReminderOutcome.done),
      ];
      final s = ReminderAdherence.streak(rows, today: day(7));
      expect(s.current, greaterThan(1));
      expect(s.usedGrace, isTrue);
    });

    test('only covered days feed the streak', () {
      final rows = [
        row(day(1, 8), ReminderOutcome.done),
        row(day(1, 20), ReminderOutcome.missed), // day 1 is NOT covered
        row(day(2), ReminderOutcome.done),
      ];
      final s = ReminderAdherence.streak(rows, today: day(2));
      expect(s.current, 1);
    });
  });

  group('export rows', () {
    test('are plain records, oldest first', () {
      final rows = [
        row(day(2), ReminderOutcome.done),
        row(day(1), ReminderOutcome.missed),
      ];
      final out = ReminderAdherence.exportRows(rows);
      expect(out.map((r) => r.date), ['2026-06-01', '2026-06-02']);
      expect(out.first.covered, isFalse);
      expect(out.last.covered, isTrue);
    });
  });
}
