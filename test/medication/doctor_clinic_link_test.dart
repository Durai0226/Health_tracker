/// A doctor and the clinic they work at, linked.
///
/// "Hospital / Clinic" was a typed name with no connection to the clinic records, so a
/// doctor at a hospital that was already saved under Clinics was typed in a second time,
/// and renaming one never reached the other.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/backup/services/medication_backup_serializer.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_add_edit_doctor_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Clinic clinic(String id, String name) =>
      Clinic(id: id, name: name, type: 'Hospital', createdAt: DateTime(2026, 1, 1));

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  Finder field(int i) => find.byType(TextFormField).at(i); // name, specialty, hospital

  Future<Doctor> stored() async =>
      (await MedicineCleanStorageService.getAllDoctors()).single;

  group('choosing a clinic for a doctor', () {
    testWidgets('is offered only when there is a clinic to choose', (tester) async {
      await pump(tester, const NunitoAddEditDoctorScreen());
      expect(find.text('Choose from my clinics'), findsNothing);
    });

    testWidgets('fills the name and links the record', (tester) async {
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary Hospital'));
      await pump(tester, const NunitoAddEditDoctorScreen());

      await tester.enterText(field(0), 'Rao');
      await tester.tap(find.text('Choose from my clinics'));
      await tester.pumpAndSettle();
      expect(find.text('Select clinic'), findsOneWidget);
      await tester.tap(find.text('St Mary Hospital'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'St Mary Hospital'), findsOneWidget);
      expect(find.text('Change clinic'), findsOneWidget);
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = await stored();
      expect((d.clinicId, d.clinicName), ('c1', 'St Mary Hospital'));
    });

    testWidgets('typing over the name is a different place, and unlinks', (tester) async {
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary Hospital'));
      await pump(tester, const NunitoAddEditDoctorScreen());
      await tester.enterText(field(0), 'Rao');
      await tester.tap(find.text('Choose from my clinics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('St Mary Hospital'));
      await tester.pumpAndSettle();

      await tester.enterText(field(2), 'Rao Clinic');
      await tester.pump();
      expect(find.text('Choose from my clinics'), findsOneWidget, reason: 'unlinked again');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = await stored();
      expect((d.clinicId, d.clinicName), (null, 'Rao Clinic'));
    });

    testWidgets('a name typed without choosing is saved with no link, as before', (tester) async {
      await pump(tester, const NunitoAddEditDoctorScreen());
      await tester.enterText(field(0), 'Rao');
      await tester.enterText(field(2), 'Somewhere');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      final d = await stored();
      expect((d.clinicId, d.clinicName), (null, 'Somewhere'));
    });
  });

  group('editing a doctor who is linked', () {
    testWidgets('shows the clinic under the name it has now, and saves that', (tester) async {
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary Hospital'));
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd1', name: 'Rao', clinicName: 'St Mary Hospital', clinicId: 'c1'));
      // Renamed since.
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary\'s Hospital'));

      await pump(
          tester,
          NunitoAddEditDoctorScreen(
              editDoctor: (await MedicineCleanStorageService.getDoctor('d1'))!));

      expect(find.widgetWithText(TextFormField, 'St Mary\'s Hospital'), findsOneWidget);
      expect(find.text('Change clinic'), findsOneWidget, reason: 'still linked');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = await stored();
      expect((d.clinicId, d.clinicName), ('c1', 'St Mary\'s Hospital'));
    });

    testWidgets('a clinic list that cannot be read does not unlink the doctor', (tester) async {
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd1', name: 'Rao', clinicName: 'St Mary\'s Hospital', clinicId: 'c1'));
      SharedPreferences.setMockInitialValues({'medication_clinics': 'not json'});

      await pump(
          tester,
          NunitoAddEditDoctorScreen(
              editDoctor: (await MedicineCleanStorageService.getDoctor('d1'))!));
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = await stored();
      expect((d.clinicId, d.clinicName), ('c1', 'St Mary\'s Hospital'),
          reason: 'nothing was compared with, so nothing is known to be gone');
    });

    testWidgets('a clinic that has been deleted leaves the typed name, with no link',
        (tester) async {
      await MedicineCleanStorageService.saveClinic(clinic('keep', 'Other Clinic'));
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd1', name: 'Rao', clinicName: 'Gone Hospital', clinicId: 'gone'));

      await pump(
          tester,
          NunitoAddEditDoctorScreen(
              editDoctor: (await MedicineCleanStorageService.getDoctor('d1'))!));
      expect(find.widgetWithText(TextFormField, 'Gone Hospital'), findsOneWidget);
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = await stored();
      expect((d.clinicId, d.clinicName), (null, 'Gone Hospital'));
    });
  });

  group('the doctors list', () {
    testWidgets('names the clinic as it is now', (tester) async {
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary\'s Hospital'));
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd1', name: 'Rao', clinicName: 'St Mary Hospital', clinicId: 'c1'));
      await pump(tester, const NunitoDoctorListScreen());
      expect(find.text('St Mary\'s Hospital'), findsOneWidget);
      expect(find.text('St Mary Hospital'), findsNothing, reason: 'the stale typed name');
    });

    testWidgets('falls back to the typed name for a doctor with no link', (tester) async {
      await MedicineCleanStorageService.saveDoctor(
          Doctor(id: 'd1', name: 'Rao', clinicName: 'Typed Place'));
      await pump(tester, const NunitoDoctorListScreen());
      expect(find.text('Typed Place'), findsOneWidget);
    });
  });

  group('deleting a clinic', () {
    test('unlinks the doctors who worked there, and they keep the name', () async {
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary Hospital'));
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd1', name: 'Rao', clinicName: 'St Mary Hospital', clinicId: 'c1'));
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd2', name: 'Iyer', clinicName: 'Other', clinicId: 'c2'));

      await MedicineCleanStorageService.deleteClinic('c1');

      final d1 = (await MedicineCleanStorageService.getDoctor('d1'))!;
      expect((d1.clinicId, d1.clinicName), (null, 'St Mary Hospital'));
      expect((await MedicineCleanStorageService.getDoctor('d2'))!.clinicId, 'c2',
          reason: 'another clinic\'s doctors are not touched');
    });

    test('a database that fails leaves the clinic where it was, for a retry', () async {
      await MedicineCleanStorageService.saveClinic(clinic('c1', 'St Mary Hospital'));
      await db.customStatement('ALTER TABLE doctors RENAME TO doctors_x');

      await expectLater(MedicineCleanStorageService.deleteClinic('c1'), throwsA(anything));

      expect(await MedicineCleanStorageService.getAllClinics(), hasLength(1),
          reason: 'deleted from the list but still linked would be a link to nothing');
    });
  });

  group('the backup', () {
    test('carries the link', () async {
      await MedicineCleanStorageService.saveDoctor(Doctor(
          id: 'd1', name: 'Rao', clinicName: 'St Mary Hospital', clinicId: 'c1'));
      final out = await MedicationBackupSerializer.exportJson();
      expect(((out[MedicationBackupSerializer.doctorsKey] as List).single as Map)['clinicId'],
          'c1');

      await MedicineCleanStorageService.deleteDoctor('d1');
      await MedicationBackupSerializer.importJson(out);
      expect((await stored()).clinicId, 'c1');
    });

    test('a file from before the link comes back as a doctor with none', () async {
      await MedicationBackupSerializer.importJson({
        MedicationBackupSerializer.doctorsKey: [
          {
            'id': 'old',
            'name': 'Old Doc',
            'hospital': 'Somewhere',
            'isPrimary': false,
            'createdAt': 1700000000,
            // no 'clinicId': the column did not exist
          },
        ],
      });
      final d = await stored();
      expect((d.clinicId, d.clinicName), (null, 'Somewhere'));
    });
  });
}
