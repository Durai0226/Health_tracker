/// What goes on the card, and whose it is.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';
import 'package:tablet_remainder/features/home/services/emergency_card_service.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 6, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> me({
    String name = 'Priya Nair',
    List<String>? allergies,
    List<String>? conditions,
    String? contact,
    String? phone,
  }) =>
      MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'self',
        name: name,
        relationship: RelationshipType.self,
        dateOfBirth: DateTime(1990, 1, 1),
        bloodType: 'O+',
        allergies: allergies,
        conditions: conditions,
        emergencyContact: contact,
        emergencyPhone: phone,
      ));

  Future<void> kid({List<String>? allergies, String? contact, String? phone}) =>
      MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'kid',
        name: 'Aarav',
        relationship: RelationshipType.child,
        dateOfBirth: DateTime(2018, 9, 1),
        allergies: allergies,
        emergencyContact: contact,
        emergencyPhone: phone,
      ));

  Future<void> medicine(String id, String name,
          {String? dependentId,
          bool active = true,
          bool archived = false,
          String? strength,
          double dose = 1}) =>
      MedicineCleanStorageService.addMedicine(
        EnhancedMedicine(
          id: id,
          name: name,
          strength: strength,
          dosageForm: DosageForm.tablet,
          dosageAmount: dose,
          dosageUnit: 'tablet',
          createdAt: DateTime(2026, 1, 1),
          dependentId: dependentId,
          isActive: active,
          isArchived: archived,
          schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
        ),
        stampActiveProfile: false,
      );

  Future<EmergencyCardData> load() =>
      withClock(Clock.fixed(now), () => EmergencyCardService.load(now: now));

  group('your own card', () {
    test('your profile, your medicines, your contact', () async {
      await me(allergies: ['Penicillin'], conditions: ['Asthma']);
      await medicine('m1', 'Metformin', strength: '500mg');
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');

      final c = (await load()).card;
      expect(c.name, 'Priya Nair');
      expect(c.age, 36);
      expect(c.bloodType, 'O+');
      expect(c.allergies, ['Penicillin']);
      expect(c.conditions, ['Asthma']);
      expect(c.medicines.map((m) => m.line), ['Metformin 500mg · 1 tablet']);
      expect(c.contact?.line, 'Arun · +91 98765 43210');
    });

    test('"Me" is not a name', () async {
      await me(name: 'Me');
      expect((await load()).card.name, isNull);
    });

    test('only what is taken now: not stopped, not archived, not anyone else\'s',
        () async {
      await me();
      await kid();
      await medicine('a', 'Metformin');
      await medicine('b', 'Old thing', active: false);
      await medicine('c', 'Shelved', archived: true);
      await medicine('d', 'Calpol', dependentId: 'kid');
      expect((await load()).card.medicines.map((m) => m.name), ['Metformin']);
    });

    test('as-needed medicines count: a paramedic wants them', () async {
      await me();
      await MedicineCleanStorageService.addMedicine(
        EnhancedMedicine(
          id: 'prn',
          name: 'Salbutamol',
          dosageForm: DosageForm.tablet,
          dosageAmount: 2,
          dosageUnit: 'tablet',
          createdAt: DateTime(2026, 1, 1),
          schedule: MedicineSchedule.asNeeded(),
        ),
        stampActiveProfile: false,
      );
      expect((await load()).card.medicines.map((m) => m.name), ['Salbutamol']);
    });

    test('a contact written on your profile is not used; the setup one is',
        () async {
      await me(contact: 'Old', phone: '+91 11111 11111');
      expect((await load()).card.contact, isNull);
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
      expect((await load()).card.contact?.name, 'Arun');
    });

    test('the profile is handed back to edit', () async {
      await me();
      expect((await load()).profile?.id, 'self');
    });
  });

  group("someone you look after", () {
    test("their profile, their medicines, the contact on their profile", () async {
      await me(allergies: ['Latex']);
      await kid(allergies: ['Peanuts'], contact: 'Meera', phone: '+91 99999 00000');
      await medicine('a', 'Metformin');
      await medicine('d', 'Calpol', dependentId: 'kid');
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
      await ActiveProfileService().setActiveDependent('kid');

      final data = await load();
      expect(data.profile?.id, 'kid');
      final c = data.card;
      expect(c.name, 'Aarav');
      expect(c.allergies, ['Peanuts'], reason: 'not yours');
      expect(c.medicines.map((m) => m.name), ['Calpol']);
      expect(c.contact?.line, 'Meera · +91 99999 00000',
          reason: 'not the one you set for yourself');
    });

    test('a contact that cannot be dialled is not on the card', () async {
      await kid(contact: 'Meera', phone: 'ask grandma');
      await ActiveProfileService().setActiveDependent('kid');
      expect((await load()).card.contact, isNull);
    });
  });

  group('when there is nothing', () {
    test('no profile row: an empty card, no profile to edit', () async {
      final data = await load();
      expect(data.profile, isNull);
      expect(data.card.name, isNull);
      expect(data.card.medicines, isEmpty);
    });

    test('a database that cannot be read: an empty card, not a crash', () async {
      await me(allergies: ['Penicillin']);
      await db.close();
      final data = await load();
      expect(data.card.allergies, isEmpty);
      expect(data.card.allergiesText, 'Not recorded');
    });
  });
}
