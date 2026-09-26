import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show
        AppDatabase,
        DiaryEntriesCompanion,
        MedicineLogsCompanion,
        MenstrualCyclesCompanion,
        PeriodDaysCompanion,
        SleepSessionsCompanion,
        StepManualEntriesCompanion;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

/// Restoring a backup must never destroy data the backup cannot restore.
///
/// The destructive restore path (Settings -> Cloud Backup -> Restore) called
/// `clearAllPersistentData()`, which wipes 18 tables, and then `importData()`,
/// which only ever restores a subset. Everything in the gap was deleted with
/// nothing to put it back — dose/adherence history, period history, sleep
/// sessions and manual step entries — while the UI reported "Backup restored
/// successfully". The rollback used the same lossy snapshot, so the failure path
/// could not recover them either.
///
/// The invariant is a containment one, and it has been satisfied from both
/// directions in turn. Per-drink water logs went first: the format always
/// carried them and only the restore dropped them, so `enhancedWaterLogs` moved
/// from "must survive" to "may be cleared" once the restore actually wrote them
/// (see `water_backup_roundtrip_test.dart`). Sleep, period days, step days and
/// hand-typed step entries followed, when `HealthBackupSerializer` put them in
/// the backup at all (see `backup_roundtrip_test.dart`).
///
/// The invariant itself never moves: the set of tables the restore is allowed to
/// clear must never exceed the set `importData` can repopulate. If someone
/// extends the backup format, both lists move together — and if someone extends
/// only the clear list, one of these tests goes red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  final at = DateTime(2026, 3, 1, 8);

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
    // Dose logs ARE exported — nested under their medicine, see
    // `doseLogsBackupKey`. The table still must not be cleared: the export
    // groups logs by `medicineId`, so a log whose medicine no longer exists
    // travels in no backup and could not be put back.
    await db.into(db.medicineLogs).insert(
          MedicineLogsCompanion.insert(
            id: 'log-1',
            medicineId: 'med-1',
            scheduledTime: at,
            isTaken: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );

    await CleanStorageService.clearRestorableData();

    expect(await db.select(db.medicineLogs).get(), isNotEmpty);
  });

  test('clearRestorableData leaves derived cycles intact', () async {
    // Menstrual cycles are derived from period days and recomputed by
    // PeriodService, so they are deliberately not exported — which puts them on
    // the "must not be cleared" side of the same rule.
    await db.into(db.menstrualCycles).insert(
          MenstrualCyclesCompanion.insert(
            id: 'cycle-1',
            startDate: at,
            createdAt: at,
            updatedAt: at,
          ),
          mode: InsertMode.insertOrReplace,
        );

    await CleanStorageService.clearRestorableData();

    expect(await db.select(db.menstrualCycles).get(), isNotEmpty);
  });

  test('clearRestorableData DOES clear what the backup can restore', () async {
    await db.into(db.diaryEntries).insert(
          DiaryEntriesCompanion.insert(
            id: 'entry-1',
            title: const Value('x'),
            body: 'y',
            entryAt: at,
            createdAt: at,
          ),
          mode: InsertMode.insertOrReplace,
        );
    // These three joined the backup format in the same change that added them
    // here. Seeded rather than asserted-on-empty: the tests they replace read
    // two empty tables and compared their lengths, which is 0 == 0 and could
    // never fail.
    await db.into(db.periodDays).insert(
          PeriodDaysCompanion.insert(
            id: '2026-03-01',
            date: at,
            createdAt: at,
            updatedAt: at,
          ),
          mode: InsertMode.insertOrReplace,
        );
    await db.into(db.sleepSessions).insert(
          SleepSessionsCompanion.insert(
            id: 'sleep-1',
            dateKey: '2026-03-01',
            bedtime: at,
            wakeTime: at.add(const Duration(hours: 7)),
            inBedMinutes: 420,
            asleepMinutes: 400,
            createdAt: at,
            updatedAt: at,
          ),
          mode: InsertMode.insertOrReplace,
        );
    await db.into(db.stepManualEntries).insert(
          StepManualEntriesCompanion.insert(
            id: 'manual-1',
            dailyDataId: '2026-03-01',
            time: at,
            steps: 1200,
            createdAt: at,
            updatedAt: at,
          ),
          mode: InsertMode.insertOrReplace,
        );

    await CleanStorageService.clearRestorableData();

    // "Overwrite" has to mean overwrite, or a restore silently becomes a merge
    // and the user keeps rows they thought they had replaced.
    expect(await db.select(db.diaryEntries).get(), isEmpty);
    expect(await db.select(db.periodDays).get(), isEmpty);
    expect(await db.select(db.sleepSessions).get(), isEmpty);
    expect(await db.select(db.stepManualEntries).get(), isEmpty,
        reason: 'hand-typed step entries are cleared only because the backup '
            'now carries them — see backup_roundtrip_test.dart');
  });
}
