import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/backup/services/health_backup_serializer.dart';
import 'package:tablet_remainder/features/backup/services/medication_backup_serializer.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// "Export a copy" was lossy, and silently.
///
/// `exportAllData` carried eight sections — settings, medicines (with dose
/// logs), focus, reminders, water, vitals, diary, preferences. Sleep, period,
/// steps and the shared health profile were in NONE of them, and neither were
/// the doctors, appointments and household profiles typed into the medication
/// feature — so a user who exported a backup, wiped the phone and restored it
/// got their medicines back and lost every night they had logged, their whole
/// cycle history, their hand-typed step entries, their body profile, their
/// consultant's phone number and their child's allergy list. Nothing in the UI
/// said so.
///
/// These tests seed one row in every table the backup claims to cover, run the
/// real export → wipe → import that a CLEARING restore runs
/// (`restoreBackup(..., clearExisting: true)`, which is the cloud restore in
/// `core/services/backup_service.dart`), and demand the data come back.
///
/// Named for the behaviour rather than a button: the local file restore on
/// `backup_settings_screen` leaves `clearExisting` at false and is a pure
/// merge, and used to be mislabelled "Restore & overwrite" for it. The round trip is the only assertion that can catch a
/// section being added to the export but not the import, or cleared by the
/// restore but not restored by it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  final seededAt = DateTime(2026, 3, 1, 9);

  Future<void> seedEverything() async {
    // ---- Medicines + dose history -----------------------------------------
    await database.into(database.enhancedMedicines).insert(
          db.EnhancedMedicinesCompanion.insert(
            id: 'med-1',
            name: 'Metformin',
            dosageForm: 0,
            startDate: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
            scheduleJson: '{}',
            currentStock: const Value(30),
          ),
        );
    await database.into(database.medicineLogs).insert(
          db.MedicineLogsCompanion.insert(
            id: 'log-1',
            medicineId: 'med-1',
            scheduledTime: seededAt,
            isTaken: const Value(true),
            dosageTaken: const Value(2),
          ),
        );

    // ---- Doctors, appointments, household profiles ------------------------
    // Hand-typed and re-derivable from nowhere: a consultant's phone number,
    // the date and place of a hospital appointment, a child's blood type.
    await database.into(database.doctors).insert(
          db.DoctorsCompanion.insert(
            id: 'doc-1',
            name: 'Dr Anand',
            specialty: const Value('Endocrinology'),
            phone: const Value('+44 20 7946 0000'),
            hospital: const Value('St Mary'),
            isPrimary: const Value(true),
            createdAt: seededAt,
          ),
        );
    await database.into(database.dependentProfiles).insert(
          db.DependentProfilesCompanion.insert(
            id: 'dep-1',
            name: 'Ada',
            relationshipType: 1,
            dateOfBirth: Value(DateTime(2014, 6, 2)),
            bloodType: const Value('O+'),
            allergiesJson: Value(jsonEncode(const ['penicillin'])),
            createdAt: seededAt,
          ),
        );
    await database.into(database.appointments).insert(
          db.AppointmentsCompanion.insert(
            id: 'appt-1',
            title: 'Six-month review',
            doctorId: const Value('doc-1'),
            dependentId: const Value('dep-1'),
            appointmentDateTime: DateTime(2026, 4, 14, 10, 30),
            location: const Value('St Mary, clinic 3'),
            createdAt: seededAt,
          ),
        );

    // ---- Reminders ---------------------------------------------------------
    await database.into(database.reminders).insert(
          db.RemindersCompanion.insert(
            id: 'rem-1',
            title: 'Refill prescription',
            body: 'Pharmacy closes at 6',
            scheduledTime: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );

    // ---- Water: a day and the drinks behind it ----------------------------
    await database.waterDao.saveDailyData(db.DailyWaterDataTableCompanion(
      id: const Value('2026-03-01'),
      date: Value(seededAt),
      dailyGoalMl: const Value(2500),
      totalIntakeMl: const Value(500),
      effectiveHydrationMl: const Value(500),
    ));
    await database.waterDao.addWaterLog(db.EnhancedWaterLogsCompanion(
      id: const Value('2026-03-01-0'),
      dailyDataId: const Value('2026-03-01'),
      time: Value(seededAt),
      amountMl: const Value(500),
      effectiveHydrationMl: const Value(500),
      beverageId: const Value('water'),
      beverageName: const Value('Water'),
      hydrationPercent: const Value(100),
    ));

    // ---- Vitals ------------------------------------------------------------
    await database.into(database.bloodPressureReadings).insert(
          db.BloodPressureReadingsCompanion.insert(
            id: 'bp-1',
            systolic: 118,
            diastolic: 76,
            takenAt: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );
    await database.into(database.glucoseReadings).insert(
          db.GlucoseReadingsCompanion.insert(
            id: 'gl-1',
            valueMgdl: 96,
            takenAt: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );
    await database.into(database.weightReadings).insert(
          db.WeightReadingsCompanion.insert(
            id: 'wt-1',
            valueKg: 71.4,
            takenAt: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );
    await database.into(database.moodEntries).insert(
          db.MoodEntriesCompanion.insert(
            id: 'mood-1',
            moodIndex: 4,
            takenAt: seededAt,
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );

    // ---- Diary -------------------------------------------------------------
    await database.into(database.diaryEntries).insert(
          db.DiaryEntriesCompanion.insert(
            id: 'diary-1',
            title: const Value('Good day'),
            body: 'Walked to the clinic.',
            entryAt: seededAt,
            createdAt: seededAt,
          ),
        );

    // ---- Sleep -------------------------------------------------------------
    await database.into(database.sleepSessions).insert(
          db.SleepSessionsCompanion.insert(
            id: 'sleep-1',
            dateKey: '2026-03-01',
            bedtime: DateTime(2026, 2, 28, 23, 15),
            wakeTime: DateTime(2026, 3, 1, 7, 5),
            inBedMinutes: 470,
            asleepMinutes: 441,
            sleepScore: const Value(82),
            efficiency: const Value(93.8),
            qualityIndex: const Value(4),
            note: const Value('woke once'),
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );

    // ---- Period: a logged day and the tracking settings -------------------
    await database.into(database.periodDays).insert(
          db.PeriodDaysCompanion.insert(
            id: '2026-03-01',
            date: seededAt,
            flowIndex: const Value(2),
            mood: const Value(3),
            symptomIdsJson: Value(jsonEncode(const ['cramps'])),
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );
    await database.into(database.periodSettingsTable).insert(
          db.PeriodSettingsTableCompanion.insert(
            id: 'settings',
            typicalCycleLength: const Value(30),
            typicalPeriodLength: const Value(6),
            // The consent flag, deliberately ON, so the round trip can prove a
            // restore file never gets to decide it.
            cloudSyncEnabled: const Value(true),
            updatedAt: seededAt,
          ),
        );

    // ---- Steps: a day, a hand-typed entry, and the body profile -----------
    await database.into(database.stepDailyData).insert(
          db.StepDailyDataCompanion.insert(
            id: '2026-03-01',
            date: seededAt,
            goalSteps: const Value(9000),
            sensorSteps: const Value(6200),
            manualSteps: const Value(1500),
            distanceMeters: const Value(5940.5),
            activeCalories: const Value(212.0),
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );
    await database.into(database.stepManualEntries).insert(
          db.StepManualEntriesCompanion.insert(
            id: 'manual-1',
            dailyDataId: '2026-03-01',
            time: seededAt,
            steps: 1500,
            note: const Value('treadmill, phone on the desk'),
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );
    await database.into(database.healthProfiles).insert(
          db.HealthProfilesCompanion.insert(
            id: 'profile',
            weightKg: const Value(71.4),
            heightCm: const Value(174),
            age: const Value(41),
            strideLengthCm: const Value(74.5),
            targetSleepMinutes: const Value(450),
            bedtimeHour: const Value(23),
            wakeHour: const Value(6),
            createdAt: seededAt,
            updatedAt: seededAt,
          ),
        );

    // ---- An app preference (the 'preferences' section) --------------------
    await CleanStorageService.setAppPreference('steps.reminderEnabled', true);
  }

  /// Every table the backup claims to cover, as `toJson()` maps so a failure
  /// prints the differing field rather than an opaque row instance.
  Future<Map<String, List<Map<String, dynamic>>>> snapshotTables() async {
    Future<List<Map<String, dynamic>>> rows(Future<List<dynamic>> q) async =>
        [for (final r in await q) r.toJson() as Map<String, dynamic>];

    return {
      'medicines': await rows(database.select(database.enhancedMedicines).get()),
      'medicineLogs': await rows(database.select(database.medicineLogs).get()),
      'doctors': await rows(database.select(database.doctors).get()),
      'appointments': await rows(database.select(database.appointments).get()),
      'dependents':
          await rows(database.select(database.dependentProfiles).get()),
      'reminders': await rows(database.select(database.reminders).get()),
      'waterDays':
          await rows(database.select(database.dailyWaterDataTable).get()),
      'waterLogs': await rows(database.select(database.enhancedWaterLogs).get()),
      'bloodPressure':
          await rows(database.select(database.bloodPressureReadings).get()),
      'glucose': await rows(database.select(database.glucoseReadings).get()),
      'weight': await rows(database.select(database.weightReadings).get()),
      'mood': await rows(database.select(database.moodEntries).get()),
      'diary': await rows(database.select(database.diaryEntries).get()),
      'sleep': await rows(database.select(database.sleepSessions).get()),
      'periodDays': await rows(database.select(database.periodDays).get()),
      'periodSettings':
          await rows(database.select(database.periodSettingsTable).get()),
      'stepDays': await rows(database.select(database.stepDailyData).get()),
      'stepManualEntries':
          await rows(database.select(database.stepManualEntries).get()),
      'healthProfile': await rows(database.select(database.healthProfiles).get()),
    };
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await CleanStorageService.init();
    await seedEverything();
    // Re-read every cache from the rows just seeded — `getReminders()` and the
    // medicine list are served from memory, so a direct Drift insert is
    // invisible to the export until the caches reload.
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => database.close());

  /// The whole point of a backup: take one, lose the phone, get it all back.
  ///
  /// The wipe is [CleanStorageService.clearAllPersistentData] — the real
  /// "delete everything" — not the narrower `clearRestorableData`. Only a total
  /// wipe can tell a lossless backup from a lossy one: if the export skips a
  /// section, restoring a narrower wipe leaves those rows sitting there
  /// untouched and the round trip "passes" having proved nothing.
  Future<Map<String, List<Map<String, dynamic>>>> exportWipeImport() async {
    final backup = await CleanStorageService.exportAllData();
    await CleanStorageService.clearAllPersistentData();

    // Premise guard: the wipe has to have actually emptied everything, or the
    // import below is being credited with rows it never wrote.
    final wiped = await snapshotTables();
    for (final entry in wiped.entries) {
      expect(entry.value, isEmpty,
          reason: '${entry.key} survived the wipe, so the restore cannot be '
              'what put it back');
    }

    await CleanStorageService.importData(backup);
    return snapshotTables();
  }

  test('every seeded table comes back after a wipe and restore', () async {
    final before = await snapshotTables();
    // Premise guard: a round trip over empty tables proves nothing.
    for (final entry in before.entries) {
      expect(entry.value, isNotEmpty,
          reason: '${entry.key} was not seeded, so it cannot be tested');
    }

    final after = await exportWipeImport();

    for (final key in before.keys) {
      expect(after[key], isNotEmpty,
          reason: '$key does not survive a backup and restore — it is either '
              'missing from the export or missing from the import');
    }
  });

  test('the restored rows are the same rows, field for field', () async {
    final before = await snapshotTables();

    final after = await exportWipeImport();

    // These travel as whole Drift rows through HealthBackupSerializer and
    // MedicationBackupSerializer, so they must come back byte-identical —
    // nothing about them is derived or re-stamped on the way in.
    for (final key in const [
      'sleep',
      'periodDays',
      'stepDays',
      'stepManualEntries',
      'healthProfile',
      'doctors',
      'appointments',
      'dependents',
    ]) {
      expect(after[key], equals(before[key]),
          reason: '$key must round-trip losslessly');
    }
  });

  test('the export itself carries the sleep/period/steps sections', () async {
    // Read the file, not just the round trip: this is the assertion that fails
    // if the sections are quietly dropped from `exportAllData` again.
    final backup = await CleanStorageService.exportAllData();

    expect(backup['version'], greaterThanOrEqualTo(7));
    expect(backup[HealthBackupSerializer.sleepKey], hasLength(1));
    expect((backup[HealthBackupSerializer.periodKey] as Map)['days'],
        hasLength(1));
    expect((backup[HealthBackupSerializer.stepsKey] as Map)['days'],
        hasLength(1));
    expect(
        (backup[HealthBackupSerializer.stepsKey] as Map)['manualEntries'],
        hasLength(1),
        reason: 'hand-typed step entries cannot be re-fetched from Health '
            'Connect, so the backup is their only copy');
    expect(backup[HealthBackupSerializer.healthProfileKey], isA<Map>());
    expect(backup[MedicationBackupSerializer.doctorsKey], hasLength(1));
    expect(backup[MedicationBackupSerializer.appointmentsKey], hasLength(1));
    expect(backup[MedicationBackupSerializer.dependentsKey], hasLength(1),
        reason: "a household member's blood type and allergies were typed in "
            'once and exist nowhere else either');
  });

  test('a restore file cannot switch on period cloud sync', () async {
    // Consent is a device decision, never a payload one — the same rule
    // `kNeverLeaveTheDevice` enforces for the app-lock PIN and cloudSyncEnabled.
    final backup = await CleanStorageService.exportAllData();
    final period = backup[HealthBackupSerializer.periodKey] as Map;
    final settings = period['settings'] as Map;

    expect(settings.containsKey(HealthBackupSerializer.periodConsentField),
        isFalse,
        reason: 'the opt-in must not be written into a file that gets emailed '
            'or uploaded');

    // Turn it off locally and move the cycle length away from the backup's, so
    // the import has something visible to do. Without that second change the
    // assertion below holds even if the whole period section is never imported
    // — the local row would simply still say 30.
    await database.into(database.periodSettingsTable).insertOnConflictUpdate(
          db.PeriodSettingsTableCompanion.insert(
            id: 'settings',
            typicalCycleLength: const Value(21),
            cloudSyncEnabled: const Value(false),
            updatedAt: seededAt,
          ),
        );

    await CleanStorageService.importData(backup);

    final restored = await database.periodDao.getSettings();
    expect(restored!.cloudSyncEnabled, isFalse,
        reason: 'a backup may restore the cycle-length settings around it, but '
            'never re-enable the upload the user turned off');
    expect(restored.typicalCycleLength, 30,
        reason: 'the rest of the settings still restore');
  });

  test('a pre-v6 backup restores exactly as it used to', () async {
    // Forward compatibility in the other direction: a file written before the
    // sleep/period/steps sections existed must not fail, and must not be read
    // as "these sections are empty, delete them".
    final backup = await CleanStorageService.exportAllData()
      ..remove(HealthBackupSerializer.sleepKey)
      ..remove(HealthBackupSerializer.periodKey)
      ..remove(HealthBackupSerializer.stepsKey)
      ..remove(HealthBackupSerializer.healthProfileKey);
    backup['version'] = 5;

    await CleanStorageService.importData(backup);

    expect(await database.select(database.sleepSessions).get(), isNotEmpty,
        reason: 'an absent section means "unknown", never "empty"');
    expect(await database.select(database.periodDays).get(), isNotEmpty);
    expect(await database.select(database.stepManualEntries).get(), isNotEmpty);
  });

  /// The other half of the contract, and the one the round trip above cannot
  /// see: `clearRestorableData` is what a clearing restore wipes first, and a
  /// section added to the export but not to that list turns an overwrite
  /// restore into a silent merge.
  test('a clearing restore really overwrites doctors and appointments',
      () async {
    final backup = await CleanStorageService.exportAllData();

    // Typed in AFTER the backup was taken, so nothing can put them back.
    await database.into(database.doctors).insert(
          db.DoctorsCompanion.insert(
            id: 'doc-later',
            name: 'Dr Later',
            createdAt: seededAt,
          ),
        );
    await database.into(database.appointments).insert(
          db.AppointmentsCompanion.insert(
            id: 'appt-later',
            title: 'Added after the backup',
            appointmentDateTime: DateTime(2026, 5, 2, 9),
            createdAt: seededAt,
          ),
        );
    await database.into(database.dependentProfiles).insert(
          db.DependentProfilesCompanion.insert(
            id: 'dep-later',
            name: 'Added after the backup',
            relationshipType: 2,
            createdAt: seededAt,
          ),
        );

    await CleanStorageService.restoreBackup(backup, clearExisting: true);

    final doctorIds = [
      for (final d in await database.select(database.doctors).get()) d.id
    ];
    final appointmentIds = [
      for (final a in await database.select(database.appointments).get()) a.id
    ];
    expect(doctorIds, ['doc-1'],
        reason: 'an overwrite restore that leaves the newer rows behind is a '
            'merge wearing the word "overwrite"');
    expect(appointmentIds, ['appt-1']);

    // Dependents are the documented exception: the table is upserted, never
    // wiped, because ActiveProfileService's well-known "self" row lives in it
    // and a pre-v7 file would take it with it. See
    // MedicationBackupSerializer.clearRestorableRows.
    final dependentIds = [
      for (final d in await database.select(database.dependentProfiles).get())
        d.id
    ];
    expect(dependentIds, containsAll(<String>['dep-1', 'dep-later']));
  });

  /// The hazard that arrives WITH a widened backup format, and the one the
  /// round trip above structurally cannot see: it always restores a file the
  /// current code just wrote, so every section is present.
  ///
  /// Every backup already sitting in someone's Firestore or Drive was written
  /// by an older build and omits the newest sections. An overwrite restore of
  /// one of those clears the tables anyway and the import puts nothing back —
  /// so adding `sleep`/`period`/`steps`/`doctors`/`appointments` to the export
  /// would have made restoring an OLD backup destroy exactly the data the new
  /// sections were added to protect.
  test('an overwrite restore of an older backup keeps what that file omits',
      () async {
    final backup = await CleanStorageService.exportAllData()
      ..remove(HealthBackupSerializer.sleepKey)
      ..remove(HealthBackupSerializer.periodKey)
      ..remove(HealthBackupSerializer.stepsKey)
      ..remove(HealthBackupSerializer.healthProfileKey)
      ..remove(MedicationBackupSerializer.doctorsKey)
      ..remove(MedicationBackupSerializer.appointmentsKey)
      ..remove(MedicationBackupSerializer.dependentsKey)
      ..remove('diary');
    backup['version'] = 5;

    await CleanStorageService.restoreBackup(backup, clearExisting: true);

    for (final section in <String, Future<List<dynamic>>>{
      'sleep sessions': database.select(database.sleepSessions).get(),
      'period days': database.select(database.periodDays).get(),
      'step days': database.select(database.stepDailyData).get(),
      'hand-typed step entries':
          database.select(database.stepManualEntries).get(),
      'doctors': database.select(database.doctors).get(),
      'appointments': database.select(database.appointments).get(),
      'diary entries': database.select(database.diaryEntries).get(),
    }.entries) {
      expect(await section.value, isNotEmpty,
          reason: 'restoring a file that carries no ${section.key} wiped them '
              'anyway — an absent section means "unknown", never "delete"');
    }

    // The sections the file DOES carry still overwrite, or this would be a
    // merge and the test would pass by doing nothing at all.
    expect(await database.select(database.enhancedMedicines).get(), isNotEmpty);
  });

  /// The mirror image, so the guard above cannot be satisfied by simply never
  /// clearing anything: a section that is present but EMPTY is a real "the
  /// user has none of these", and an overwrite restore must honour it.
  test('an empty section in a current backup still overwrites', () async {
    // One section owned by CleanStorageService itself (diary) and one owned by
    // a serializer (doctors): the presence test is written out separately in
    // each, so an assertion on only one of them leaves the other free to use
    // the wrong predicate.
    await database.delete(database.doctors).go();
    await database.delete(database.appointments).go();
    await database.delete(database.diaryEntries).go();
    final backup = await CleanStorageService.exportAllData();
    expect(backup[MedicationBackupSerializer.doctorsKey], isEmpty,
        reason: 'the premise: this file carries the key with no rows behind it');
    expect(backup['diary'], isEmpty);

    // Typed in after that empty backup was taken.
    await database.into(database.doctors).insert(
          db.DoctorsCompanion.insert(
            id: 'doc-later',
            name: 'Dr Later',
            createdAt: seededAt,
          ),
        );
    await database.into(database.diaryEntries).insert(
          db.DiaryEntriesCompanion.insert(
            id: 'diary-later',
            body: 'Written after the backup.',
            entryAt: seededAt,
            createdAt: seededAt,
          ),
        );

    await CleanStorageService.restoreBackup(backup, clearExisting: true);

    expect(await database.select(database.doctors).get(), isEmpty,
        reason: '"I have no doctors" is data too — an overwrite restore of an '
            'empty section must empty the table');
    expect(await database.select(database.diaryEntries).get(), isEmpty,
        reason: 'same rule for a section CleanStorageService clears itself');
  });
}
