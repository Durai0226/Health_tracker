import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/backup/services/medication_backup_serializer.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/recording_notification_scheduler.dart';

/// Clinics are the one record in the medication feature that lives in
/// SharedPreferences rather than Drift. That put them outside every Drift-based
/// path: no backup carried them, "Delete all data" left them behind, and an
/// overwrite restore could not put them back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
  });

  tearDown(() async => db.close());

  Clinic clinic(String id, String name) => Clinic(
        id: id,
        name: name,
        address: '1 High St',
        phone: '+44 20 7946 0000',
        type: 'Hospital',
        createdAt: DateTime(2026, 1, 1),
      );

  test('the backup carries clinics', () async {
    await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary'));
    final out = await MedicationBackupSerializer.exportJson();
    final list = out[MedicationBackupSerializer.clinicsKey] as List;
    expect(list, hasLength(1));
    expect((list.single as Map)['name'], 'St Mary');
  });

  test('a restore puts them back, by id, without duplicating', () async {
    await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary'));
    final backup = await MedicationBackupSerializer.exportJson();

    await MedicineCleanStorageService.clearClinics();
    expect(await MedicineCleanStorageService.getAllClinics(), isEmpty);

    await MedicationBackupSerializer.importJson(backup);
    await MedicationBackupSerializer.importJson(backup); // twice: idempotent
    final back = await MedicineCleanStorageService.getAllClinics();
    expect(back.map((c) => c.id), ['c1']);
    expect(back.single.phone, '+44 20 7946 0000');
  });

  test('an overwrite restore clears the clinics a current file carries', () async {
    await MedicineCleanStorageService.saveClinic(clinic('old', 'Old Clinic'));
    final fileWithNone = <String, dynamic>{
      MedicationBackupSerializer.clinicsKey: <dynamic>[],
    };
    await MedicationBackupSerializer.clearRestorableRows(forBackup: fileWithNone);
    expect(await MedicineCleanStorageService.getAllClinics(), isEmpty,
        reason: 'a file that says it has no clinics means none');
  });

  test('...but an older file that never had the section leaves them alone',
      () async {
    await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary'));
    // A backup written before clinics were covered: no `clinics` key at all.
    await MedicationBackupSerializer.clearRestorableRows(
        forBackup: <String, dynamic>{
      MedicationBackupSerializer.doctorsKey: <dynamic>[],
    });
    expect(await MedicineCleanStorageService.getAllClinics(), hasLength(1),
        reason: 'wiping what the file cannot put back is the loss the section '
            'rules exist to prevent');
  });

  test('"Delete all data" removes them', () async {
    await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary'));
    await CleanStorageService.clearAllPersistentData();
    expect(await MedicineCleanStorageService.getAllClinics(), isEmpty,
        reason: 'names, addresses and phone numbers of every hospital saved');
  });
}
