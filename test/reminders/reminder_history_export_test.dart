/// The reminder history, read out of the occurrence log and shared as a file.
///
/// The log is what the adherence percentage on the Reminders screen is computed
/// from; this is the rows behind it. What matters here is which rows, under what
/// name, and that nothing is shared when there is nothing to share.
library;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase, ReminderOccurrencesCompanion;
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_history_export.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 6, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await ReminderService.instance.resetForTesting();
    ActiveProfileService().resetForTesting();
    ReminderHistoryExport.shareOverride = null;
  });

  tearDown(() async {
    ReminderHistoryExport.shareOverride = null;
    await ReminderService.instance.resetForTesting();
    CleanStorageService.resetForTesting();
    await db.close();
  });

  Future<void> remind(String id, String title) => CleanStorageService.saveReminder(
        Reminder(id: id, title: title, body: '', scheduledTime: DateTime(2026, 6, 1, 9)),
      );

  Future<void> record(
    String reminderId,
    DateTime due,
    ReminderOutcome outcome, {
    DateTime? fired,
    DateTime? acted,
    int snoozes = 0,
  }) =>
      db.remindersDao.recordOccurrence(ReminderOccurrencesCompanion.insert(
        id: RemindersDao.occurrenceId(reminderId, due),
        reminderId: reminderId,
        scheduledFor: due,
        firedAt: Value(fired),
        actedAt: Value(acted),
        outcome: Value(outcome.name),
        snoozeCount: Value(snoozes),
      ));

  DateTime daysAgo(int d, [int hour = 9]) =>
      DateTime(now.year, now.month, now.day - d, hour);

  group('which rows', () {
    setUp(() async {
      await remind('r-1', 'Water the plants');
      // Today, five days ago, forty days ago, two hundred days ago, and over a
      // year ago.
      await record('r-1', daysAgo(0, 8), ReminderOutcome.done);
      await record('r-1', daysAgo(5), ReminderOutcome.missed);
      await record('r-1', daysAgo(40), ReminderOutcome.done);
      await record('r-1', daysAgo(200), ReminderOutcome.skipped);
      await record('r-1', daysAgo(400), ReminderOutcome.done);
    });

    test('thirty days', () async {
      final rows = await ReminderHistoryExport.rows(HistoryRange.days30, now: now);
      expect(rows.map((r) => r.scheduledFor), [daysAgo(5), daysAgo(0, 8)]);
    });

    test('ninety days', () async {
      final rows = await ReminderHistoryExport.rows(HistoryRange.days90, now: now);
      expect(rows, hasLength(3));
    });

    test('everything, however old', () async {
      final rows = await ReminderHistoryExport.rows(HistoryRange.all, now: now);
      expect(rows, hasLength(5));
      expect(rows.first.scheduledFor, daysAgo(400));
    });

    test('the start of the day thirty days back is in, the evening before it is out', () async {
      await record('r-1', DateTime(now.year, now.month, now.day - 30, 0, 0), ReminderOutcome.done);
      await record('r-1', DateTime(now.year, now.month, now.day - 31, 23, 59), ReminderOutcome.done);

      final rows = await ReminderHistoryExport.rows(HistoryRange.days30, now: now);

      expect(rows.map((r) => r.scheduledFor), contains(DateTime(2026, 5, 21)));
      expect(rows.map((r) => r.scheduledFor), isNot(contains(DateTime(2026, 5, 20, 23, 59))));
    });

    test('and the same at ninety days', () async {
      await record('r-1', DateTime(now.year, now.month, now.day - 90, 0, 0), ReminderOutcome.done);
      await record('r-1', DateTime(now.year, now.month, now.day - 91, 23, 59), ReminderOutcome.done);

      final rows = await ReminderHistoryExport.rows(HistoryRange.days90, now: now);

      expect(rows.map((r) => r.scheduledFor), contains(DateTime(2026, 3, 22)));
      expect(rows.map((r) => r.scheduledFor), isNot(contains(DateTime(2026, 3, 21, 23, 59))));
    });

    test('nothing that has not come due yet', () async {
      await record('r-1', now.add(const Duration(hours: 3)), ReminderOutcome.pending);

      final rows = await ReminderHistoryExport.rows(HistoryRange.all, now: now);

      expect(rows.any((r) => r.result == 'Pending'), isFalse);
    });

    test('and the clock decides "now" when none is given', () async {
      final rows = await withClock(
        Clock.fixed(now),
        () => ReminderHistoryExport.rows(HistoryRange.days30),
      );
      expect(rows, hasLength(2));
    });
  });

  group('what each row says', () {
    test('the reminder\'s name, and what happened to it', () async {
      await remind('r-1', 'Take a walk');
      await record(
        'r-1',
        daysAgo(1),
        ReminderOutcome.done,
        fired: daysAgo(1).add(const Duration(seconds: 2)),
        acted: daysAgo(1).add(const Duration(minutes: 7)),
        snoozes: 2,
      );

      final r = (await ReminderHistoryExport.rows(HistoryRange.all, now: now)).single;

      expect(r.title, 'Take a walk');
      expect(r.result, 'Done');
      expect(r.firedAt, daysAgo(1).add(const Duration(seconds: 2)));
      expect(r.actedAt, daysAgo(1).add(const Duration(minutes: 7)));
      expect(r.snoozeCount, 2);
    });

    test('every outcome has its own word', () async {
      await remind('r-1', 'x');
      await record('r-1', daysAgo(4), ReminderOutcome.done);
      await record('r-1', daysAgo(3), ReminderOutcome.skipped);
      await record('r-1', daysAgo(2), ReminderOutcome.missed);
      await record('r-1', daysAgo(1), ReminderOutcome.pending);

      final rows = await ReminderHistoryExport.rows(HistoryRange.all, now: now);

      expect(rows.map((r) => r.result), ['Done', 'Skipped', 'Missed', 'Pending']);
    });

    test('a reminder that has since been deleted is still in the record, and says so',
        () async {
      await record('gone', daysAgo(2), ReminderOutcome.done);

      final r = (await ReminderHistoryExport.rows(HistoryRange.all, now: now)).single;

      expect(r.title, ReminderHistoryExport.deletedTitle);
    });

    test('two reminders at the same time are told apart', () async {
      await remind('a', 'Pills');
      await remind('b', 'Stretch');
      await record('a', daysAgo(1), ReminderOutcome.done);
      await record('b', daysAgo(1), ReminderOutcome.missed);

      final rows = await ReminderHistoryExport.rows(HistoryRange.all, now: now);

      expect({for (final r in rows) r.title: r.result}, {'Pills': 'Done', 'Stretch': 'Missed'});
    });

    test('no history, no rows', () async {
      expect(await ReminderHistoryExport.rows(HistoryRange.all, now: now), isEmpty);
    });
  });

  group('sharing', () {
    String? csv;
    String? name;

    setUp(() {
      csv = null;
      name = null;
      ReminderHistoryExport.shareOverride = (c, n) async {
        csv = c;
        name = n;
      };
    });

    test('hands over the file, named for the day, and says how many lines', () async {
      await remind('r-1', 'Take a walk');
      await record('r-1', daysAgo(1), ReminderOutcome.done);

      final lines = await ReminderHistoryExport.share(HistoryRange.all, now: now);

      expect(lines, 1);
      expect(name, 'dlyminder-reminders-20260620.csv');
      expect(csv, startsWith('Reminder,Due,Notified,Answered,Result,Snoozed\r\n'));
      expect(csv, contains('Take a walk,2026-06-19 09:00,,,Done,0'));
    });

    test('opens nothing when there is nothing to share', () async {
      final lines = await ReminderHistoryExport.share(HistoryRange.all, now: now);

      expect(lines, 0);
      expect(csv, isNull);
      expect(name, isNull);
    });

    test('a range with nothing in it opens nothing, even if another range has some',
        () async {
      await remind('r-1', 'x');
      await record('r-1', daysAgo(200), ReminderOutcome.done);

      expect(await ReminderHistoryExport.share(HistoryRange.days30, now: now), 0);
      expect(csv, isNull);
      expect(await ReminderHistoryExport.share(HistoryRange.all, now: now), 1);
    });

    test('a title meant to be a formula is not one in the file', () async {
      await remind('r-1', '=SUM(A1:A9)');
      await record('r-1', daysAgo(1), ReminderOutcome.done);

      await ReminderHistoryExport.share(HistoryRange.all, now: now);

      expect(csv, contains("\r\n'=SUM(A1:A9),"));
    });
  });

  test('the file name is the date, padded', () {
    expect(ReminderHistoryExport.fileName(DateTime(2026, 1, 2)), 'dlyminder-reminders-20260102.csv');
  });

  test('the ranges are labelled for the sheet that offers them', () {
    expect(HistoryRange.values.map((r) => r.label),
        ['Last 30 days', 'Last 90 days', 'Everything']);
  });
}
