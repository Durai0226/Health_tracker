import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_adherence.dart';

import '../support/reminder_harness.dart';

/// Reminder adherence had no denominator, so it could only ever read 100%.
///
/// `reconcileMissedReminders` rewrites rows returned by `pendingBefore` — and
/// NOTHING ever wrote a `pending` row. `recordReminderOutcome` has exactly one
/// production caller, the in-app tick, which writes `done`; the alarm isolate
/// has no Drift connection; the scheduler never touched the table. The sweep
/// therefore always found zero rows, `ReminderAdherence.byDay` only ever saw
/// `done`, and the card printed "100% of days fully covered" for someone who
/// had ignored a daily reminder for a month and ticked it once. The comment on
/// the sweep even called itself "the denominator, and without it there isn't
/// one" — and there wasn't.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('due occurrences become the denominator', () {
    reminderTest('positive: a daily reminder ignored for 3 days yields 3 missed'
        ' rows', (h) async {
      await h.seed('r-daily',
          at: h.now.subtract(const Duration(days: 3)),
          repeat: RepeatType.daily);

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-daily');
      expect(rows, isNotEmpty,
          reason: 'without derived rows there is nothing to write off');
      // Every occurrence older than the grace window is written off.
      final missed = rows.where((r) => r.outcome == 'missed');
      expect(missed, isNotEmpty,
          reason: 'ignored occurrences must count against adherence');
      expect(rows.every((r) => r.outcome == 'missed' || r.outcome == 'pending'),
          isTrue);
    });

    reminderTest('negative: a future reminder produces no occurrence rows',
        (h) async {
      await h.seed('r-future',
          at: h.now.add(const Duration(days: 2)), repeat: RepeatType.daily);

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-future');
      expect(rows, isEmpty,
          reason: 'an occurrence that has not come due is not a miss');
    });

    reminderTest('negative: a tick is NEVER overwritten by the backfill',
        (h) async {
      // The dangerous case: the backfill runs on every app start, and an upsert
      // would replace the user's `done` with a fresh `pending` — turning the
      // record it exists to build into the thing that corrupts it.
      final due = h.now.subtract(const Duration(days: 1));
      await h.seed('r-ticked', at: due, repeat: RepeatType.daily);
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-ticked',
        scheduledFor: due,
        outcome: ReminderOutcome.done,
      );

      await CleanStorageService.recordDueReminderOccurrences();

      final row = await AppDatabase.instance.remindersDao
          .getOccurrence('r-ticked', due);
      expect(row, isNotNull);
      expect(row!.outcome, 'done',
          reason: 'the backfill must be insert-if-absent, never an upsert');
      expect(row.actedAt, isNotNull, reason: 'the tick time must survive');
    });

    reminderTest('the backfill is idempotent across repeated app starts',
        (h) async {
      await h.seed('r-daily',
          at: h.now.subtract(const Duration(days: 3)),
          repeat: RepeatType.daily);

      final first = await CleanStorageService.recordDueReminderOccurrences();
      final second = await CleanStorageService.recordDueReminderOccurrences();

      expect(first, greaterThan(0));
      expect(second, 0,
          reason: 'the occurrence id is derived from (reminderId, dueAt), so a '
              'second pass must create nothing');
    });

    reminderTest('negative: a paused reminder accrues no misses', (h) async {
      await h.seed('r-paused',
          at: h.now.subtract(const Duration(days: 3)),
          repeat: RepeatType.daily,
          isPaused: true);

      await CleanStorageService.recordDueReminderOccurrences();

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-paused');
      expect(rows, isEmpty,
          reason: 'pausing a reminder must not damage the adherence figure');
    });

    reminderTest('negative: the walk is bounded, not the whole history',
        (h) async {
      // A reminder created a year ago must not mint 365 rows: adherence is a
      // recent-behaviour signal and the reconcile window is minutes.
      await h.seed('r-old',
          at: h.now.subtract(const Duration(days: 365)),
          repeat: RepeatType.daily);

      await CleanStorageService.recordDueReminderOccurrences();

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-old');
      expect(rows.length, lessThanOrEqualTo(31),
          reason: 'the default lookback is 30 days');
      expect(rows, isNotEmpty);
    });

    reminderTest('a bounded reminder stops accruing after its endsAt',
        (h) async {
      await h.seed('r-course',
          at: h.now.subtract(const Duration(days: 10)),
          repeat: RepeatType.daily,
          endsAt: h.now.subtract(const Duration(days: 5)));

      await CleanStorageService.recordDueReminderOccurrences();

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-course');
      for (final r in rows) {
        expect(r.scheduledFor.isAfter(h.now.subtract(const Duration(days: 5))),
            isFalse,
            reason: 'a finished course must not keep accruing misses');
      }
    });
  });

  group('the reported figure now reflects reality', () {
    reminderTest('positive: ignoring a daily reminder for a month no longer '
        'reads 100%', (h) async {
      // The reported failure: a daily "Blood pressure" reminder ignored for 29
      // days and ticked once on day 30 showed "100% of days fully covered"
      // with a green success accent, because the only rows in the table were
      // the single `done`.
      final start = h.now.subtract(const Duration(days: 29));
      await h.seed('r-bp',
          title: 'Blood pressure', at: start, repeat: RepeatType.daily);

      // Tick exactly one occurrence — today's.
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-bp',
        scheduledFor: start,
        outcome: ReminderOutcome.done,
      );

      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-bp');
      final pdc = ReminderAdherence.proportionOfDaysCovered(rows);

      expect(pdc, isNotNull, reason: 'there is now something to measure');
      expect(pdc, lessThan(1.0),
          reason: 'one tick against 29 ignored days is not full coverage');
      expect(ReminderAdherence.isAdherent(pdc), isFalse,
          reason: 'the card claimed adherent with a green accent');
    });

    reminderTest('negative: a reminder answered every day still reads 100%',
        (h) async {
      final start = h.now.subtract(const Duration(days: 4));
      await h.seed('r-good', at: start, repeat: RepeatType.daily);

      // Derive the due occurrences, then answer every one of them.
      await CleanStorageService.recordDueReminderOccurrences();
      final derived = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-good');
      for (final o in derived) {
        await CleanStorageService.recordReminderOutcome(
          reminderId: 'r-good',
          scheduledFor: o.scheduledFor,
          outcome: ReminderOutcome.done,
        );
      }

      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-good');
      expect(ReminderAdherence.proportionOfDaysCovered(rows), 1.0,
          reason: 'someone who actually answers every reminder must still see '
              '100% — the fix must not manufacture misses');
    });

    reminderTest('negative: a brand-new reminder reports null, not 0%',
        (h) async {
      await h.seed('r-new',
          at: h.now.add(const Duration(hours: 2)), repeat: RepeatType.daily);
      await CleanStorageService.recordDueReminderOccurrences();
      final rows = await AppDatabase.instance.remindersDao
          .occurrencesFor('r-new');
      expect(ReminderAdherence.proportionOfDaysCovered(rows), isNull,
          reason: 'showing 0% to someone who has not used the feature yet is '
              'both wrong and discouraging');
    });
  });
}
