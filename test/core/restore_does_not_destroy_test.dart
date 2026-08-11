import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// Restoring a backup must never destroy data the backup cannot restore.
///
/// The destructive restore path (Settings -> Cloud Backup -> Restore) called
/// `clearAllPersistentData()`, which wipes 18 tables, and then `importData()`,
/// which only ever restores a subset. Everything in the gap was deleted with
/// nothing to put it back — dose/adherence history, period history, sleep
/// sessions, manual step entries and per-drink water logs — while the UI
/// reported "Backup restored successfully". The rollback used the same lossy
/// snapshot, so the failure path could not recover them either.
///
/// These tests pin the invariant that made that possible: the set of tables the
/// restore is allowed to clear must never exceed the set `importData` can
/// repopulate. If someone extends the backup format, both lists move together.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDownAll(() async => db.close());

  test('clearRestorableData leaves dose history intact', () async {
    await db.into(db.medicineLogs).insert(
          MedicineLogsCompanion.insert(
            id: 'log-1',
            medicineId: 'med-1',
            scheduledTime: DateTime(2026, 3, 1, 8),
            status: 'taken',
          ),
          mode: InsertMode.insertOrReplace,
        );

    await CleanStorageService.clearRestorableData();

    final logs = await db.select(db.medicineLogs).get();
    expect(
      logs,
      isNotEmpty,
      reason: 'Dose history is not in the backup format, so a restore must not '
          'delete it — there would be nothing to put it back.',
    );
  });

  test('clearRestorableData leaves period history intact', () async {
    final before = await db.select(db.periodDays).get();
    await CleanStorageService.clearRestorableData();
    final after = await db.select(db.periodDays).get();
    expect(after.length, before.length,
        reason: 'Period days are not exported, so they must not be cleared.');
  });

  test('clearRestorableData leaves sleep and manual step entries intact', () async {
    final sleepBefore = await db.select(db.sleepSessions).get();
    final stepsBefore = await db.select(db.stepManualEntries).get();

    await CleanStorageService.clearRestorableData();

    expect((await db.select(db.sleepSessions).get()).length, sleepBefore.length);
    expect((await db.select(db.stepManualEntries).get()).length,
        stepsBefore.length,
        reason: 'Hand-typed step entries cannot be regenerated from Health '
            'Connect, so losing them is unrecoverable.');
  });

  test('clearRestorableData DOES clear what the backup can restore', () async {
    await db.into(db.diaryEntries).insert(
          DiaryEntriesCompanion.insert(
            id: 'entry-1',
            title: 'x',
            body: 'y',
            createdAt: DateTime(2026, 3, 1),
            updatedAt: DateTime(2026, 3, 1),
          ),
          mode: InsertMode.insertOrReplace,
        );

    await CleanStorageService.clearRestorableData();

    expect(
      await db.select(db.diaryEntries).get(),
      isEmpty,
      reason: 'Diary IS in the backup format, so an overwrite restore should '
          'clear it — otherwise "overwrite" silently becomes "merge".',
    );
  });
}
