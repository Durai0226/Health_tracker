import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/critical_follow_up.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// `EnhancedMedicine.criticalAlert` was carried by the form and read by nothing
/// that stored it: there was no column, so a "must-take" medicine came back as
/// an ordinary one after every save. Schema v21 adds it.
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

  final now = DateTime.now();

  EnhancedMedicine med(String id, {required bool critical}) => EnhancedMedicine(
        id: id,
        name: 'Med $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        criticalAlert: critical,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
          startDate: now.subtract(const Duration(days: 1)),
        ),
        createdAt: now.subtract(const Duration(days: 1)),
      );

  test('a must-take medicine is still must-take after a save and a read',
      () async {
    await MedicineCleanStorageService.saveMedicine(med('c', critical: true));
    final read = await MedicineCleanStorageService.getMedicine('c');
    expect(read!.criticalAlert, isTrue);
  });

  test('an ordinary medicine stays ordinary', () async {
    await MedicineCleanStorageService.saveMedicine(med('o', critical: false));
    final read = await MedicineCleanStorageService.getMedicine('o');
    expect(read!.criticalAlert, isFalse);
  });

  test('what comes back from the database still drives the follow-up chain',
      () async {
    await MedicineCleanStorageService.saveMedicine(med('c', critical: true));
    final read = (await MedicineCleanStorageService.getMedicine('c'))!;
    expect(nudgeMinutesForDose(read, read.schedule.times.first),
        [8 * 60, 8 * 60 + 15, 8 * 60 + 30]);
  });

  group('upgrading a v20 database', () {
    test('a database from before the column opens and defaults to ordinary',
        () async {
      // A fresh in-memory database is created at the current version, so go the
      // long way: create it, drop the column's effect by reading a row written
      // without it.
      await db.customStatement(
          "INSERT INTO enhanced_medicines (id, name, dosage_form, start_date, "
          "created_at, updated_at, schedule_json) VALUES "
          "('legacy', 'Old', 0, 0, 0, 0, "
          "'{\"frequencyType\":0,\"times\":[{\"hour\":8,\"minute\":0}]}')");
      final m = await db.medicationDao.getMedicine('legacy');
      expect(m!.criticalAlert, isFalse,
          reason: 'an upgrade must not make every existing medicine insistent');
    });
  });
}
