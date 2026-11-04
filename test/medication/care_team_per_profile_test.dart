/// Doctors and clinics belong to a person.
///
/// They were one list for the whole household: a child's paediatrician showed up
/// in the account holder's appointment picker, and removing a person left their
/// doctors behind. Now each is the owner's alone unless shared with the family
/// (a family doctor), and every record saved before this stays shared, so nobody
/// loses a doctor they had.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/backup/services/medication_backup_serializer.dart';
import 'package:tablet_remainder/features/medication/models/care_team_scope.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_add_edit_clinic_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_add_edit_doctor_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/widgets/remove_person_sheet.dart';

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  Future<void> asProfile(String? id) => ActiveProfileService().setActiveDependent(id);

  Future<void> addPeople() async {
    await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-a', name: 'Maya', relationship: RelationshipType.child));
    await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-b', name: 'Sam', relationship: RelationshipType.child));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    await ActiveProfileService().init();
  });

  tearDown(() async => db.close());

  Doctor doctor(String id, {String? owner, bool shared = false, String? clinicId}) =>
      Doctor(
          id: id,
          name: 'Dr $id',
          dependentId: owner,
          sharedWithFamily: shared,
          clinicId: clinicId);

  Clinic clinic(String id, {String? owner, bool shared = false}) => Clinic(
      id: id,
      name: 'Clinic $id',
      dependentId: owner,
      sharedWithFamily: shared,
      createdAt: DateTime(2026, 1, 1));

  Future<List<String>> doctorsSeenBy(String? profile) async {
    await asProfile(profile);
    return (await MedicineCleanStorageService.getAllDoctors()).map((d) => d.id).toList()
      ..sort();
  }

  Future<List<String>> clinicsSeenBy(String? profile) async {
    await asProfile(profile);
    return (await MedicineCleanStorageService.getAllClinics()).map((c) => c.id).toList()
      ..sort();
  }

  group('the rule', () {
    test('a shared record shows to everyone; a private one only to its owner', () {
      bool v(String? owner, bool shared, String? active) =>
          CareTeamScope.visible(owner: owner, shared: shared, active: active);
      expect(v('a', true, 'b'), isTrue);
      expect(v(null, true, 'b'), isTrue);
      expect(v('a', false, 'a'), isTrue);
      expect(v('a', false, 'b'), isFalse);
      expect(v('a', false, null), isFalse);
      expect(v(null, false, null), isTrue, reason: 'the account holder owns null');
      expect(v(null, false, 'a'), isFalse);
    });

    test('only an explicit false is private', () {
      expect(CareTeamScope.cleanShared(false), isFalse);
      expect(CareTeamScope.cleanShared(true), isTrue);
      expect(CareTeamScope.cleanShared(null), isTrue, reason: 'a record from before');
      expect(CareTeamScope.cleanShared('no'), isTrue);
      expect(CareTeamScope.cleanShared(0), isTrue);
    });
  });

  group('the models', () {
    test('a doctor saved before this has an owner of nobody, shared', () {
      final d = Doctor.fromJson({'id': 'd', 'name': 'Rao'});
      expect(d.dependentId, isNull);
      expect(d.sharedWithFamily, isTrue);
      final c = Clinic.fromJson({'id': 'c', 'name': 'St Mary'});
      expect(c.dependentId, isNull);
      expect(c.sharedWithFamily, isTrue);
    });

    test('both ways round, an owner and a private flag survive', () {
      final d = Doctor.fromJson(doctor('d', owner: 'dep-a').toJson());
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', false));
      final c = Clinic.fromJson(clinic('c', owner: 'dep-a').toJson());
      expect((c.dependentId, c.sharedWithFamily), ('dep-a', false));
    });

    test('copyWith keeps the owner unless told to clear it, and can share', () {
      final d = doctor('d', owner: 'dep-a');
      expect(d.copyWith(name: 'X').dependentId, 'dep-a');
      expect(d.copyWith(clearDependentId: true).dependentId, isNull);
      expect(d.copyWith(sharedWithFamily: true).sharedWithFamily, isTrue);
      expect(d.copyWith(sharedWithFamily: true).dependentId, 'dep-a');
      final c = clinic('c', owner: 'dep-a');
      expect(c.copyWith(name: 'X').dependentId, 'dep-a');
      expect(c.copyWith(clearDependentId: true).dependentId, isNull);
      expect(c.copyWith(sharedWithFamily: true).sharedWithFamily, isTrue);
      expect(c.copyWith(sharedWithFamily: true).dependentId, 'dep-a');
    });
  });

  group('who sees what', () {
    setUp(() async {
      await addPeople();
      await MedicineCleanStorageService.saveDoctor(doctor('mine'));
      await MedicineCleanStorageService.saveDoctor(doctor('maya', owner: 'dep-a'));
      await MedicineCleanStorageService.saveDoctor(doctor('sam', owner: 'dep-b'));
      await MedicineCleanStorageService.saveDoctor(doctor('gp', owner: 'dep-a', shared: true));
      await MedicineCleanStorageService.saveClinic(clinic('mine'));
      await MedicineCleanStorageService.saveClinic(clinic('maya', owner: 'dep-a'));
      await MedicineCleanStorageService.saveClinic(clinic('sam', owner: 'dep-b'));
      await MedicineCleanStorageService.saveClinic(clinic('gp', owner: 'dep-a', shared: true));
    });

    test('doctors: each person sees their own and the shared ones', () async {
      expect(await doctorsSeenBy(null), ['gp', 'mine']);
      expect(await doctorsSeenBy('dep-a'), ['gp', 'maya']);
      expect(await doctorsSeenBy('dep-b'), ['gp', 'sam']);
    });

    test('clinics: each person sees their own and the shared ones', () async {
      expect(await clinicsSeenBy(null), ['gp', 'mine']);
      expect(await clinicsSeenBy('dep-a'), ['gp', 'maya']);
      expect(await clinicsSeenBy('dep-b'), ['gp', 'sam']);
    });

    test('an unscoped read sees every one', () async {
      await asProfile('dep-b');
      expect(
          (await MedicineCleanStorageService.getAllDoctors(scopeToActiveProfile: false))
              .map((d) => d.id)
              .toSet(),
          {'mine', 'maya', 'sam', 'gp'});
      expect(
          (await MedicineCleanStorageService.getAllClinics(scopeToActiveProfile: false))
              .map((c) => c.id)
              .toSet(),
          {'mine', 'maya', 'sam', 'gp'});
    });

    test('a doctor and a clinic can still be looked up by id from another profile',
        () async {
      await asProfile('dep-b');
      expect((await MedicineCleanStorageService.getDoctor('maya'))?.name, 'Dr maya');
      expect((await MedicineCleanStorageService.getClinic('maya'))?.name, 'Clinic maya');
    });

    test('saving a clinic while someone else is in view keeps everybody\'s', () async {
      await asProfile('dep-b');
      await MedicineCleanStorageService.saveClinic(clinic('sam2', owner: 'dep-b'));
      await MedicineCleanStorageService.saveClinic(
          clinic('sam', owner: 'dep-b').copyWith(name: 'Renamed'));
      expect(
          (await MedicineCleanStorageService.getAllClinics(scopeToActiveProfile: false))
              .map((c) => c.id)
              .toSet(),
          {'mine', 'maya', 'sam', 'sam2', 'gp'});
    });

    test('deleting a clinic while someone else is in view keeps everybody\'s',
        () async {
      await asProfile('dep-b');
      await MedicineCleanStorageService.deleteClinic('sam');
      expect(
          (await MedicineCleanStorageService.getAllClinics(scopeToActiveProfile: false))
              .map((c) => c.id)
              .toSet(),
          {'mine', 'maya', 'gp'});
    });

    test('an edit saves the owner and the flag back', () async {
      await MedicineCleanStorageService.saveDoctor(
          (await MedicineCleanStorageService.getDoctor('maya'))!
              .copyWith(sharedWithFamily: true));
      final d = (await MedicineCleanStorageService.getDoctor('maya'))!;
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', true));
      expect(await doctorsSeenBy('dep-b'), ['gp', 'maya', 'sam']);
    });

    test('a full export carries every doctor, whoever is in view', () async {
      await asProfile('dep-b');
      final out = await MedicineCleanStorageService.exportAllMedicineData();
      expect((out['doctors'] as List).length, 4);
    });
  });

  group('removing a person', () {
    setUp(() async {
      await addPeople();
      await MedicineCleanStorageService.saveDoctor(doctor('mine'));
      await MedicineCleanStorageService.saveDoctor(doctor('maya', owner: 'dep-a'));
      await MedicineCleanStorageService.saveDoctor(doctor('gp', owner: 'dep-a', shared: true));
      await MedicineCleanStorageService.saveDoctor(doctor('sam', owner: 'dep-b'));
      await MedicineCleanStorageService.saveClinic(clinic('maya', owner: 'dep-a'));
      await MedicineCleanStorageService.saveClinic(clinic('gp', owner: 'dep-a', shared: true));
      await MedicineCleanStorageService.saveClinic(clinic('sam', owner: 'dep-b'));
    });

    Future<Map<String, String?>> doctorOwners() async => {
          for (final d in await MedicineCleanStorageService.getAllDoctors(
              scopeToActiveProfile: false))
            d.id: d.dependentId
        };
    Future<Map<String, String?>> clinicOwners() async => {
          for (final c in await MedicineCleanStorageService.getAllClinics(
              scopeToActiveProfile: false))
            c.id: c.dependentId
        };

    test('keeping their records hands all their doctors and clinics to you', () async {
      await MedicineCleanStorageService.deleteDependent('dep-a');
      expect(await doctorOwners(),
          {'mine': null, 'maya': null, 'gp': null, 'sam': 'dep-b'});
      expect(await clinicOwners(), {'maya': null, 'gp': null, 'sam': 'dep-b'});
      await asProfile(null);
      expect((await MedicineCleanStorageService.getAllDoctors()).map((d) => d.id).toSet(),
          {'mine', 'maya', 'gp'});
    });

    test('deleting everything removes theirs, and the shared ones come to you',
        () async {
      await MedicineCleanStorageService.deleteRecordsOf('dep-a');
      expect(await doctorOwners(), {'mine': null, 'gp': null, 'sam': 'dep-b'});
      expect(await clinicOwners(), {'gp': null, 'sam': 'dep-b'});
    });

    test('deleting a doctor with a linked clinic still unlinks it', () async {
      await MedicineCleanStorageService.saveDoctor(
          doctor('linked', owner: 'dep-a', clinicId: 'maya'));
      await MedicineCleanStorageService.deleteRecordsOf('dep-a');
      expect(await doctorOwners(), isNot(contains('linked')));
      expect(await clinicOwners(), isNot(contains('maya')));
    });

    test('the sheet says doctors and clinics go too, and that shared ones stay', () {
      // Copy pinned by a widget test below; the enum is the contract the screen uses.
      expect(RemovePersonChoice.values, hasLength(2));
    });
  });

  group('backups', () {
    test('a backup carries the owner and the flag, and a restore puts them back',
        () async {
      await addPeople();
      await MedicineCleanStorageService.saveDoctor(doctor('maya', owner: 'dep-a'));
      await MedicineCleanStorageService.saveClinic(clinic('maya', owner: 'dep-a'));
      final out = await MedicationBackupSerializer.exportJson();
      final row = (out[MedicationBackupSerializer.doctorsKey] as List).single as Map;
      expect((row['dependentId'], row['sharedWithFamily']), ('dep-a', false));

      await db.customStatement('DELETE FROM doctors');
      await MedicineCleanStorageService.clearClinics();
      await MedicationBackupSerializer.importJson(out);
      final d = (await MedicineCleanStorageService.getDoctor('maya'))!;
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', false));
      final c = (await MedicineCleanStorageService.getClinic('maya'))!;
      expect((c.dependentId, c.sharedWithFamily), ('dep-a', false));
    });

    test('an older file, with neither field, restores its doctors as shared',
        () async {
      await MedicationBackupSerializer.importJson({
        MedicationBackupSerializer.doctorsKey: [
          {
            'id': 'old',
            'name': 'Dr Old',
            'isPrimary': false,
            'createdAt': DateTime(2025, 1, 1).millisecondsSinceEpoch,
          }
        ],
        MedicationBackupSerializer.clinicsKey: [
          {'id': 'oldc', 'name': 'Old Clinic'}
        ],
      });
      final d = (await MedicineCleanStorageService.getDoctor('old'))!;
      expect((d.dependentId, d.sharedWithFamily), (null, true));
      final c = (await MedicineCleanStorageService.getClinic('oldc'))!;
      expect((c.dependentId, c.sharedWithFamily), (null, true));
    });

    test('exporting while a profile is in view still writes every clinic', () async {
      await addPeople();
      await MedicineCleanStorageService.saveClinic(clinic('mine'));
      await MedicineCleanStorageService.saveClinic(clinic('sam', owner: 'dep-b'));
      await asProfile('dep-a');
      final out = await MedicationBackupSerializer.exportJson();
      expect(
          (out[MedicationBackupSerializer.clinicsKey] as List)
              .map((c) => (c as Map)['id'])
              .toSet(),
          {'mine', 'sam'});
    });
  });

  group('the forms', () {
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
      await tester.pumpAndSettle();
    }

    final card = find.text('Share with the family');

    testWidgets('a household of one is not asked', (tester) async {
      await pump(tester, const NunitoAddEditDoctorScreen());
      expect(card, findsNothing);
      await pump(tester, const NunitoAddEditClinicScreen());
      expect(card, findsNothing);
    });

    testWidgets('a household with family is asked, and the answer starts as no',
        (tester) async {
      await addPeople();
      await pump(tester, const NunitoAddEditDoctorScreen());
      expect(card, findsOneWidget);
      expect(find.text('Only the person it was added for sees this doctor.'),
          findsOneWidget);
    });

    testWidgets('a doctor added while Maya is in view is Maya\'s alone', (tester) async {
      await addPeople();
      await asProfile('dep-a');
      await pump(tester, const NunitoAddEditDoctorScreen());
      await tester.enterText(find.byType(TextFormField).at(0), 'Rao');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = (await MedicineCleanStorageService.getAllDoctors(
              scopeToActiveProfile: false))
          .single;
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', false));
      expect(await doctorsSeenBy(null), isEmpty);
    });

    testWidgets('turning it on makes a family doctor', (tester) async {
      await addPeople();
      await asProfile('dep-a');
      await pump(tester, const NunitoAddEditDoctorScreen());
      await tester.enterText(find.byType(TextFormField).at(0), 'Rao');
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Every profile sees this doctor.'), findsOneWidget);
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = (await MedicineCleanStorageService.getAllDoctors(
              scopeToActiveProfile: false))
          .single;
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', true));
      expect(await doctorsSeenBy(null), [d.id]);
    });

    testWidgets('editing a doctor from another profile does not hand it over',
        (tester) async {
      await addPeople();
      await MedicineCleanStorageService.saveDoctor(
          doctor('gp', owner: 'dep-a', shared: true));
      await asProfile('dep-b');
      await pump(
          tester,
          NunitoAddEditDoctorScreen(
              editDoctor: (await MedicineCleanStorageService.getDoctor('gp'))!));
      expect(find.text('Every profile sees this doctor.'), findsOneWidget,
          reason: 'it starts as the doctor is');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final d = (await MedicineCleanStorageService.getDoctor('gp'))!;
      expect((d.dependentId, d.sharedWithFamily), ('dep-a', true));
    });

    testWidgets('a clinic added while Maya is in view is Maya\'s alone', (tester) async {
      await addPeople();
      await asProfile('dep-a');
      await pump(tester, const NunitoAddEditClinicScreen());
      await tester.enterText(find.byType(TextFormField).at(0), 'St Mary');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final c = (await MedicineCleanStorageService.getAllClinics(
              scopeToActiveProfile: false))
          .single;
      expect((c.dependentId, c.sharedWithFamily), ('dep-a', false));
      expect(await clinicsSeenBy(null), isEmpty);
    });

    testWidgets('turning it on shares a clinic, and an edit keeps its owner',
        (tester) async {
      await addPeople();
      await MedicineCleanStorageService.saveClinic(clinic('maya', owner: 'dep-a'));
      await asProfile('dep-b');
      await pump(
          tester,
          NunitoAddEditClinicScreen(
              editClinic: (await MedicineCleanStorageService.getClinic('maya'))!));
      expect(find.text('Only the person it was added for sees this clinic.'),
          findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final c = (await MedicineCleanStorageService.getClinic('maya'))!;
      expect((c.dependentId, c.sharedWithFamily), ('dep-a', true));
    });

    testWidgets('editing a shared clinic from another profile keeps it shared and '
        'keeps its owner', (tester) async {
      await addPeople();
      await MedicineCleanStorageService.saveClinic(
          clinic('gp', owner: 'dep-a', shared: true));
      await asProfile('dep-b');
      await pump(
          tester,
          NunitoAddEditClinicScreen(
              editClinic: (await MedicineCleanStorageService.getClinic('gp'))!));
      expect(find.text('Every profile sees this clinic.'), findsOneWidget,
          reason: 'it starts as the clinic is');
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      final c = (await MedicineCleanStorageService.getClinic('gp'))!;
      expect((c.dependentId, c.sharedWithFamily), ('dep-a', true));
    });

    testWidgets('the removal sheet says doctors and clinics go too', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: fontFreeTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RemovePersonBody(name: 'Maya', onChoose: (_) {}, onClose: () {}),
          ),
        ),
      ));
      expect(find.textContaining('doctors and clinics stay on this device, under you'),
          findsOneWidget);
      expect(find.textContaining('Doctors and clinics shared with the family stay with you'),
          findsOneWidget);
    });
  });
}
