import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';

/// `Reminders.isCompleted` is a single mutable boolean. Completing a repeating
/// reminder overwrote it AND rolled `scheduledTime` forward, and the add/edit
/// screen reset it to `false` on every save — so a generic reminder destroyed
/// its own history. There was no record that yesterday's 9pm reminder had ever
/// been due, let alone whether it was acted on.
///
/// Nothing "smart" is buildable on top of that. Adherence, streaks, a digest and
/// adaptive timing all need to know what happened and when, which is why this
/// table comes before any of them. Medication already had `MedicineLogs`;
/// generic reminders had nothing.
void main() {
  late AppDatabase db;
  late RemindersDao dao;

  const reminderId = 'r-1';
  final due = DateTime(2026, 6, 10, 21, 0);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.remindersDao;
  });

  tearDown(() async => db.close());

  Future<void> record(
    DateTime scheduledFor,
    ReminderOutcome outcome, {
    int snoozeCount = 0,
    String? source,
    DateTime? actedAt,
  }) =>
      dao.recordOccurrence(ReminderOccurrencesCompanion.insert(
        id: RemindersDao.occurrenceId(reminderId, scheduledFor),
        reminderId: reminderId,
        scheduledFor: scheduledFor,
        outcome: Value(outcome.name),
        snoozeCount: Value(snoozeCount),
        source: Value(source),
        actedAt: Value(actedAt),
      ));

  group('history survives what isCompleted could not', () {
    test('each occurrence of one repeating reminder is its own row', () async {
      // The exact case the old model erased: three days of a daily reminder.
      for (var d = 0; d < 3; d++) {
        await record(due.add(Duration(days: d)), ReminderOutcome.done);
      }
      final rows = await dao.occurrencesFor(reminderId);
      expect(rows.length, 3);
      expect(
        rows.map((r) => r.scheduledFor).toList(),
        [due, due.add(const Duration(days: 1)), due.add(const Duration(days: 2))],
        reason: 'occurrencesFor returns oldest first',
      );
    });

    test('recording is idempotent — a double tap is one row', () async {
      await record(due, ReminderOutcome.done);
      await record(due, ReminderOutcome.done);
      expect((await dao.occurrencesFor(reminderId)).length, 1,
          reason: 'the id is derived from (reminderId, scheduledFor), so a '
              'background action drained twice cannot invent a second row');
    });

    test('a later outcome updates the same occurrence', () async {
      await record(due, ReminderOutcome.pending);
      await record(due, ReminderOutcome.done);
      final rows = await dao.occurrencesFor(reminderId);
      expect(rows.length, 1);
      expect(rows.single.outcome, 'done');
    });

    test('two reminders due at the same instant stay separate', () async {
      await record(due, ReminderOutcome.done);
      await dao.recordOccurrence(ReminderOccurrencesCompanion.insert(
        id: RemindersDao.occurrenceId('r-2', due),
        reminderId: 'r-2',
        scheduledFor: due,
      ));
      expect((await dao.occurrencesFor(reminderId)).length, 1);
      expect((await dao.occurrencesFor('r-2')).length, 1);
    });
  });

  group('the outcome is stored by name, because these rows are history', () {
    test('every value round-trips', () async {
      for (final outcome in ReminderOutcome.values) {
        final at = due.add(Duration(minutes: outcome.index));
        await record(at, outcome);
        final row = await dao.getOccurrence(reminderId, at);
        expect(ReminderOutcome.fromName(row!.outcome), outcome);
      }
    });

    test('an unknown name degrades to pending rather than throwing', () {
      // Reordering the enum must not silently reinterpret what already
      // happened, and a row from a newer build must not crash an older one.
      expect(ReminderOutcome.fromName('teleported'), ReminderOutcome.pending);
      expect(ReminderOutcome.fromName(null), ReminderOutcome.pending);
    });

    test('skipped is not missed', () {
      // A deliberate skip is not a failure. Lumping them together would make
      // adherence punish the user for being honest about not needing a dose.
      expect(ReminderOutcome.skipped.isResolved, isTrue);
      expect(ReminderOutcome.missed.isResolved, isTrue);
      expect(ReminderOutcome.pending.isResolved, isFalse);
      expect(ReminderOutcome.skipped, isNot(ReminderOutcome.missed));
    });
  });

  group('the queries the smart features will read', () {
    test('a half-open window does not double-count a boundary', () async {
      final day = DateTime(2026, 6, 10);
      final next = DateTime(2026, 6, 11);
      await record(day, ReminderOutcome.done); // exactly at 00:00
      await record(next, ReminderOutcome.done); // exactly at the end bound
      final inDay = await dao.occurrencesBetween(day, next);
      expect(inDay.length, 1,
          reason: 'chained day windows would otherwise count midnight twice');
      expect(inDay.single.scheduledFor, day);
    });

    test('pendingBefore finds only unresolved, past occurrences', () async {
      await record(due, ReminderOutcome.pending);
      await record(due.add(const Duration(days: 1)), ReminderOutcome.done);
      await record(due.add(const Duration(days: 2)), ReminderOutcome.pending);

      final stale = await dao.pendingBefore(due.add(const Duration(days: 1)));
      expect(stale.map((r) => r.scheduledFor), [due],
          reason: 'the resolved one and the still-future one are both excluded');
    });

    test('deleting a reminder takes its history with it', () async {
      await record(due, ReminderOutcome.done);
      await dao.deleteOccurrencesFor(reminderId);
      expect(await dao.occurrencesFor(reminderId), isEmpty);
    });
  });

  group('the fields the smart features need are actually captured', () {
    test('snoozeCount is per occurrence, not per reminder', () async {
      // "You always push the 9pm one back" is only answerable if the count
      // lives on the occurrence.
      await record(due, ReminderOutcome.done, snoozeCount: 3);
      await record(due.add(const Duration(days: 1)), ReminderOutcome.done);
      final rows = await dao.occurrencesFor(reminderId);
      expect(rows.first.snoozeCount, 3);
      expect(rows.last.snoozeCount, 0);
    });

    test('source distinguishes a notification tap from opening the app', () async {
      await record(due, ReminderOutcome.done, source: 'notification');
      expect((await dao.getOccurrence(reminderId, due))!.source, 'notification');
    });

    test('a missed occurrence has no actedAt', () async {
      // Writing `now` there would make a miss look like a very late completion,
      // which is exactly the distortion adherence must not have.
      await withClock(Clock.fixed(DateTime(2026, 6, 11, 9)), () async {
        await record(due, ReminderOutcome.missed);
      });
      expect((await dao.getOccurrence(reminderId, due))!.actedAt, isNull);
    });
  });
}
