import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase, EnhancedMedicine;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart'
    as domain;
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Medicine cloud sync was a facade that reported success.
///
///  * It uploaded ONLY while the cloud collection was empty, so the first
///    document ever written froze the upload direction forever — a medicine
///    added afterwards never left the device.
///  * It uploaded the Drift row shape and parsed it back with the LEGACY
///    `Medicine.fromJson`, whose first act is `DateTime.parse(json['time'])`;
///    that key does not exist in a row, so every download threw.
///  * The throw landed in `CleanStorageService.addMedicineFromModel`, a stub
///    whose whole body was a `debugPrint`.
///
/// Net effect: a returning user on a new phone saw an empty medicine list while
/// the log said "Successfully downloaded all data from cloud" and Settings said
/// "Cloud sync on".
///
/// The fix routes medicines through the same `syncLwwCollection` helper every
/// other collection uses, on the generated row. These tests pin the two
/// properties that made the old version unfixable — a real JSON round trip, and
/// a tombstone the syncer can see — without needing a Firestore fake, by
/// exercising exactly the `toJson`/`fromJson`/reader trio the syncer is wired to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  final now = DateTime(2026, 3, 10, 9);

  domain.EnhancedMedicine med(String id, {String name = 'Metformin'}) =>
      domain.EnhancedMedicine(
        id: id,
        name: name,
        dosageForm: DosageForm.tablet,
        dosageAmount: 2,
        dosageUnit: 'tablet',
        currentStock: 30,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.twiceDaily,
          times: [
            ScheduledTime(hour: 8, minute: 0),
            ScheduledTime(hour: 20, minute: 0),
          ],
          startDate: now,
        ),
        createdAt: now,
        updatedAt: now,
      );

  test('positive: a medicine survives the exact JSON round trip the syncer uses',
      () async {
    await MedicineCleanStorageService.saveMedicine(med('m1'));

    // Upload side: the row's own toJson, which is what _syncMedicines writes.
    final row = (await db.medicationDao.getAllMedicinesIncludingDeleted())
        .singleWhere((r) => r.id == 'm1');
    final wire = row.toJson();

    // Download side, onto a device that has never seen it.
    await db.medicationDao.deleteMedicine('m1');
    await db
        .into(db.enhancedMedicines)
        .insertOnConflictUpdate(EnhancedMedicine.fromJson(wire).toCompanion(false));

    final restored = await MedicineCleanStorageService.getMedicine('m1');
    expect(restored, isNotNull,
        reason: 'the old path parsed rows with the legacy model and threw, so '
            'a returning user got nothing');
    expect(restored!.name, 'Metformin');
    expect(restored.dosageAmount, 2);
    expect(restored.currentStock, 30);
    expect(restored.schedule.times, hasLength(2));
    expect(restored.schedule.times.first.hour, 8);
    expect(restored.reminderEnabled, isTrue);
  });

  test('negative: a deleted medicine is a tombstone the syncer can see',
      () async {
    await MedicineCleanStorageService.saveMedicine(med('m2'));
    await db.medicationDao.deleteMedicine('m2');

    expect(await MedicineCleanStorageService.getMedicine('m2'), isNull,
        reason: 'the UI must not show a deleted medicine');

    final forSync = await db.medicationDao.getAllMedicinesIncludingDeleted();
    final tomb = forSync.where((r) => r.id == 'm2');
    expect(tomb, hasLength(1),
        reason: 'a hard delete leaves nothing to propagate, so the next sync '
            'downloads the medicine back — alarms and all');
    expect(tomb.single.deletedAt, isNotNull);
  });

  test('negative: deleting a medicine still removes its dose logs', () async {
    await MedicineCleanStorageService.saveMedicine(med('m3'));
    await db.medicationDao.deleteMedicine('m3');
    final logs = await db.medicationDao.getLogsForMedicine('m3');
    expect(logs, isEmpty,
        reason: 'orphaned taken logs would inflate the adherence numerator '
            'against a denominator that no longer includes the medicine');
  });

  test('positive: re-adding a tombstoned id clears the tombstone', () async {
    await MedicineCleanStorageService.saveMedicine(med('m4'));
    await db.medicationDao.deleteMedicine('m4');
    expect(await MedicineCleanStorageService.getMedicine('m4'), isNull);

    await MedicineCleanStorageService.saveMedicine(med('m4', name: 'Again'));
    final back = await MedicineCleanStorageService.getMedicine('m4');
    expect(back, isNotNull,
        reason: 'without an explicit clear the row stays invisible forever');
    expect(back!.name, 'Again');
  });

  test('the sync no longer depends on the deleted legacy model or the stub',
      () async {
    // Both were the mechanism of the silent failure; their absence is the
    // guarantee it cannot come back by accident.
    expect(
      await _fileExists('lib/features/medication/models/medicine.dart'),
      isFalse,
      reason: 'the legacy Medicine model could not parse a Drift row',
    );
    final src = await _read('lib/core/services/clean_storage_service.dart');
    expect(src.contains('addMedicineFromModel'), isFalse,
        reason: 'the stub only debugPrinted, so downloads wrote nothing while '
            'reporting success');
  });
}

Future<bool> _fileExists(String p) => File(p).exists();
Future<String> _read(String p) => File(p).readAsString();
