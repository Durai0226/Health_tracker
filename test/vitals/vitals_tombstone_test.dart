import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/models/weight_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Schema v13 turned vitals deletes into tombstones so the four vitals tables
/// could finally cloud-sync — a hard DELETE left nothing to distinguish "the
/// user removed this" from "this device hasn't synced yet", so the next sync
/// downloaded the reading straight back.
///
/// Tombstones bring their own trap, which is what most of this file is about:
/// saves are `insertOnConflictUpdate` and the delete-confirmation SnackBar's
/// Undo re-saves the SAME id. If a companion mapper does not clear `deletedAt`,
/// Undo appears to work and the row stays invisible forever. That is silent,
/// permanent data loss and nothing else in the suite would catch it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  final at = DateTime(2026, 3, 4, 9);

  BloodPressureReading bp(String id) => BloodPressureReading(
      id: id, systolic: 118, diastolic: 76, takenAt: at, createdAt: at);
  GlucoseReading glucose(String id) =>
      GlucoseReading(id: id, valueMgdl: 95, takenAt: at, createdAt: at);
  WeightReading weight(String id) =>
      WeightReading(id: id, valueKg: 70.5, takenAt: at, createdAt: at);
  MoodEntry mood(String id) =>
      MoodEntry(id: id, moodIndex: 1, takenAt: at, createdAt: at);

  group('delete hides the reading', () {
    test('blood pressure', () async {
      await VitalsStorageService.saveBp(bp('bp1'), syncToHealthConnect: false);
      expect(await VitalsStorageService.getAllBp(), hasLength(1));

      await VitalsStorageService.deleteBp('bp1');
      expect(await VitalsStorageService.getAllBp(), isEmpty);
    });

    test('glucose', () async {
      await VitalsStorageService.saveGlucose(glucose('g1'),
          syncToHealthConnect: false);
      await VitalsStorageService.deleteGlucose('g1');
      expect(await VitalsStorageService.getAllGlucose(), isEmpty);
    });

    test('weight', () async {
      await VitalsStorageService.saveWeight(weight('w1'),
          syncToHealthConnect: false);
      await VitalsStorageService.deleteWeight('w1');
      expect(await VitalsStorageService.getAllWeight(), isEmpty);
    });

    test('mood', () async {
      await VitalsStorageService.saveMood(mood('m1'));
      await VitalsStorageService.deleteMood('m1');
      expect(await VitalsStorageService.getAllMood(), isEmpty);
    });
  });

  group('the row survives as a tombstone, so a deletion can sync', () {
    test('delete keeps the row and stamps deletedAt', () async {
      await VitalsStorageService.saveBp(bp('bp1'), syncToHealthConnect: false);
      await VitalsStorageService.deleteBp('bp1');

      final all = await db.vitalsDao
          .getBpForRangeIncludingDeleted(at.subtract(const Duration(days: 1)),
              at.add(const Duration(days: 1)));

      expect(all, hasLength(1), reason: 'a hard delete would resurrect on sync');
      expect(all.single.deletedAt, isNotNull);
      // Cleared so the reconciler re-uploads the tombstone.
      expect(all.single.synced, isFalse);
      // Bumped so the deletion wins last-write-wins against an older cloud copy.
      expect(all.single.updatedAt.isAfter(all.single.createdAt), isTrue);
    });
  });

  group('Undo re-saves the same id and must clear the tombstone', () {
    test('blood pressure', () async {
      await VitalsStorageService.saveBp(bp('bp1'), syncToHealthConnect: false);
      await VitalsStorageService.deleteBp('bp1');
      expect(await VitalsStorageService.getAllBp(), isEmpty);

      // Exactly what the SnackBar's Undo does — same id, same values.
      await VitalsStorageService.saveBp(bp('bp1'), syncToHealthConnect: false);

      expect(await VitalsStorageService.getAllBp(), hasLength(1),
          reason: 'Undo left the tombstone standing: the reading is gone for good');
    });

    test('glucose', () async {
      await VitalsStorageService.saveGlucose(glucose('g1'),
          syncToHealthConnect: false);
      await VitalsStorageService.deleteGlucose('g1');
      await VitalsStorageService.saveGlucose(glucose('g1'),
          syncToHealthConnect: false);
      expect(await VitalsStorageService.getAllGlucose(), hasLength(1));
    });

    test('weight', () async {
      await VitalsStorageService.saveWeight(weight('w1'),
          syncToHealthConnect: false);
      await VitalsStorageService.deleteWeight('w1');
      await VitalsStorageService.saveWeight(weight('w1'),
          syncToHealthConnect: false);
      expect(await VitalsStorageService.getAllWeight(), hasLength(1));
    });

    test('mood', () async {
      await VitalsStorageService.saveMood(mood('m1'));
      await VitalsStorageService.deleteMood('m1');
      await VitalsStorageService.saveMood(mood('m1'));
      expect(await VitalsStorageService.getAllMood(), hasLength(1));
    });
  });

  test('range reads and watch streams hide tombstones too', () async {
    final from = at.subtract(const Duration(days: 1));
    final to = at.add(const Duration(days: 1));

    await VitalsStorageService.saveBp(bp('bp1'), syncToHealthConnect: false);
    await VitalsStorageService.deleteBp('bp1');

    expect(await VitalsStorageService.getBpForRange(from, to), isEmpty);
    expect(await db.vitalsDao.watchBp().first, isEmpty);
  });
}
