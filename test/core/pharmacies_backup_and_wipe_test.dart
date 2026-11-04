import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/backup/services/medication_backup_serializer.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/recording_notification_scheduler.dart';

/// A pharmacy is typed in on its own screen, so — like a doctor — it exists nowhere
/// else: it has to ride the backup, come back with a restore, go with "Delete all
/// data", and leave no medicine pointing at it when it is deleted.
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

  Pharmacy pharmacy(String id, String name) => Pharmacy(
      id: id,
      name: name,
      phone: '0123456',
      address: '4 High Street',
      hours: '9 am – 9 pm',
      hasDelivery: true,
      notes: 'Ask for Priya');

  EnhancedMedicine medicine({String? pharmacyId, String? doctorId}) => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)]),
        pharmacyId: pharmacyId,
        doctorId: doctorId,
      );

  group('the backup', () {
    test('carries pharmacies, whole', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));

      final out = await MedicationBackupSerializer.exportJson();

      final list = out[MedicationBackupSerializer.pharmaciesKey] as List;
      expect(list, hasLength(1));
      final row = list.single as Map;
      expect(row['name'], 'Corner Chemist');
      expect(row['phone'], '0123456');
      expect(row['hasDelivery'], true);
      expect(row['notes'], 'Ask for Priya');
    });

    test('a restore puts them back by id, once, however many times', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      final backup = await MedicationBackupSerializer.exportJson();
      await MedicineCleanStorageService.deletePharmacy('p1');
      expect(await MedicineCleanStorageService.getAllPharmacies(), isEmpty, reason: 'premise');

      await MedicationBackupSerializer.importJson(backup);
      await MedicationBackupSerializer.importJson(backup);

      final back = await MedicineCleanStorageService.getAllPharmacies();
      expect(back.map((p) => p.id), ['p1']);
      expect(back.single.hours, '9 am – 9 pm');
    });

    test('an overwrite restore clears the pharmacies a current file carries', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('old', 'Old Chemist'));
      await MedicationBackupSerializer.clearRestorableRows(forBackup: {
        MedicationBackupSerializer.pharmaciesKey: <dynamic>[],
      });
      expect(await MedicineCleanStorageService.getAllPharmacies(), isEmpty,
          reason: 'a file that says it has none means none');
    });

    test('but an older file that never had the section leaves them alone', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      await MedicationBackupSerializer.clearRestorableRows(forBackup: {
        MedicationBackupSerializer.doctorsKey: <dynamic>[],
      });
      expect(await MedicineCleanStorageService.getAllPharmacies(), hasLength(1),
          reason: 'wiping a pharmacy for a file that cannot put it back is the loss '
              'this exists to prevent');
    });

    test('a damaged row is skipped and the rest come back', () async {
      await MedicationBackupSerializer.importJson({
        MedicationBackupSerializer.pharmaciesKey: [
          'not a map',
          {'id': 'bad', 'name': 5},
          {
            'id': 'ok',
            'name': 'Fine Chemist',
            'hasDelivery': false,
            'createdAt': 1700000000,
          },
        ],
      });
      final back = await MedicineCleanStorageService.getAllPharmacies();
      expect(back.map((p) => p.id), ['ok']);
    });

    test('the whole backup file has the section', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      final all = await CleanStorageService.exportAllData();
      expect((all['pharmacies'] as List).single['name'], 'Corner Chemist');
    });
  });

  test('"Delete all data" removes them', () async {
    await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));

    await CleanStorageService.clearAllPersistentData();

    expect(await MedicineCleanStorageService.getAllPharmacies(), isEmpty,
        reason: 'a name, an address and a phone number that a wipe that said '
            '"all data deleted" would have left behind');
  });

  group('deleting one', () {
    test('takes it off the medicines that named it, and says they changed', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      await MedicineCleanStorageService.saveMedicine(medicine(pharmacyId: 'p1'));
      final before = MedicineCleanStorageService.revision.value;

      await MedicineCleanStorageService.deletePharmacy('p1');

      final m = await MedicineCleanStorageService.getMedicine('m1');
      expect(m!.pharmacyId, isNull);
      expect(MedicineCleanStorageService.revision.value, greaterThan(before),
          reason: 'so a screen showing the medicine reloads it');
    });

    test('stamps the medicine updated, so the change reaches the cloud', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      await MedicineCleanStorageService.saveMedicine(medicine(pharmacyId: 'p1'));
      final saved = (await MedicineCleanStorageService.getMedicine('m1'))!.updatedAt!;

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await MedicineCleanStorageService.deletePharmacy('p1');

      final after = (await MedicineCleanStorageService.getMedicine('m1'))!.updatedAt!;
      expect(after.isAfter(saved), isTrue);
    });

    test('leaves a medicine that named another pharmacy alone', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      await MedicineCleanStorageService.addPharmacy(pharmacy('p2', 'Other'));
      await MedicineCleanStorageService.saveMedicine(medicine(pharmacyId: 'p2'));

      await MedicineCleanStorageService.deletePharmacy('p1');

      expect((await MedicineCleanStorageService.getMedicine('m1'))!.pharmacyId, 'p2');
    });

    test('does not announce a change when no medicine named it', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      final before = MedicineCleanStorageService.revision.value;
      await MedicineCleanStorageService.deletePharmacy('p1');
      expect(MedicineCleanStorageService.revision.value, before);
    });

    test('a delete whose unlink fails is undone, not left half done', () async {
      await MedicineCleanStorageService.addPharmacy(pharmacy('p1', 'Corner Chemist'));
      await MedicineCleanStorageService.saveMedicine(medicine(pharmacyId: 'p1'));
      await db.customStatement('ALTER TABLE enhanced_medicines RENAME TO enhanced_medicines_x');

      await expectLater(
          MedicineCleanStorageService.deletePharmacy('p1'), throwsA(anything));

      expect(await MedicineCleanStorageService.getAllPharmacies(), hasLength(1),
          reason: 'the pharmacy is deleted together with the unlinking, or not at all');
    });

    group('and a doctor, the same way', () {
      test('a delete whose unlink fails is undone, not left half done', () async {
        await MedicineCleanStorageService.addDoctor(Doctor(id: 'd1', name: 'Rao'));
        await MedicineCleanStorageService.saveMedicine(medicine(doctorId: 'd1'));
        await db.customStatement('ALTER TABLE enhanced_medicines RENAME TO enhanced_medicines_x');

        await expectLater(MedicineCleanStorageService.deleteDoctor('d1'), throwsA(anything));

        expect(await MedicineCleanStorageService.getAllDoctors(), hasLength(1));
      });

      test('is taken off their medicines, and the screens are told', () async {
        await MedicineCleanStorageService.addDoctor(Doctor(id: 'd1', name: 'Rao'));
        await MedicineCleanStorageService.saveMedicine(medicine(doctorId: 'd1'));
        final before = MedicineCleanStorageService.revision.value;

        await MedicineCleanStorageService.deleteDoctor('d1');

        expect((await MedicineCleanStorageService.getMedicine('m1'))!.doctorId, isNull);
        expect(MedicineCleanStorageService.revision.value, greaterThan(before),
            reason: 'so a screen showing the medicine reloads it');
      });

      test('stamps the medicine updated, so the change reaches the cloud', () async {
        await MedicineCleanStorageService.addDoctor(Doctor(id: 'd1', name: 'Rao'));
        await MedicineCleanStorageService.saveMedicine(medicine(doctorId: 'd1'));
        final saved = (await MedicineCleanStorageService.getMedicine('m1'))!.updatedAt!;

        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await MedicineCleanStorageService.deleteDoctor('d1');

        final after = (await MedicineCleanStorageService.getMedicine('m1'))!.updatedAt!;
        expect(after.isAfter(saved), isTrue);
      });

      test('leaves a medicine that named another doctor alone', () async {
        await MedicineCleanStorageService.addDoctor(Doctor(id: 'd1', name: 'Rao'));
        await MedicineCleanStorageService.addDoctor(Doctor(id: 'd2', name: 'Iyer'));
        await MedicineCleanStorageService.saveMedicine(medicine(doctorId: 'd2'));

        await MedicineCleanStorageService.deleteDoctor('d1');

        expect((await MedicineCleanStorageService.getMedicine('m1'))!.doctorId, 'd2');
      });

      test('does not announce a change when no medicine named them', () async {
        await MedicineCleanStorageService.addDoctor(Doctor(id: 'd1', name: 'Rao'));
        final before = MedicineCleanStorageService.revision.value;
        await MedicineCleanStorageService.deleteDoctor('d1');
        expect(MedicineCleanStorageService.revision.value, before);
      });
    });
  });
}
