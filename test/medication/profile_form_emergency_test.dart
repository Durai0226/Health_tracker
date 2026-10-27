/// The profile form's two additions: the conditions a card lists, and your own
/// emergency contact going where the card and the setup checklist read it.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/add_edit_dependent_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

import '../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<DependentProfile> addMe({List<String>? conditions, String? contact, String? phone}) async {
    final p = DependentProfile(
      id: 'self',
      name: 'Priya',
      relationship: RelationshipType.self,
      conditions: conditions,
      emergencyContact: contact,
      emergencyPhone: phone,
    );
    await MedicineCleanStorageService.addDependent(p);
    return p;
  }

  /// The form behind a push, so its own pop on save has a route to return to.
  Future<void> open(WidgetTester tester, DependentProfile? edit) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 3200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => AddEditDependentScreen(editDependent: edit))),
            child: const Text('host page'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('host page'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder field(String label) => find.descendant(
      of: find.widgetWithText(AppTextField, label), matching: find.byType(TextField));

  String textIn(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('conditions', () {
    testWidgets('written as a list and kept on the profile', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Conditions'), ' Asthma,  Type 2 diabetes ,');
      await save(tester);

      final saved = await MedicineCleanStorageService.profileFor(null);
      expect(saved?.conditions, ['Asthma', 'Type 2 diabetes']);
    });

    testWidgets('shown again when the form is opened, and removed when emptied',
        (tester) async {
      final me = await addMe(conditions: ['Asthma', 'Eczema']);
      await open(tester, me);
      expect(textIn(tester, 'Conditions'), 'Asthma, Eczema');

      await tester.enterText(field('Conditions'), '');
      await save(tester);
      expect((await MedicineCleanStorageService.profileFor(null))?.conditions, isNull);
    });

    testWidgets('saving something else no longer wipes them', (tester) async {
      final me = await addMe(conditions: ['Asthma']);
      await open(tester, me);
      await tester.enterText(field('Allergies'), 'Penicillin');
      await save(tester);

      final saved = await MedicineCleanStorageService.profileFor(null);
      expect(saved?.conditions, ['Asthma']);
      expect(saved?.allergies, ['Penicillin']);
    });
  });

  group('your own emergency contact', () {
    testWidgets('written here is the one the card and the checklist read',
        (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Contact name'), 'Arun');
      await tester.enterText(field('Phone number'), '+91 98765 43210');
      await save(tester);

      final c = EmergencyContact.get();
      expect(c?.name, 'Arun');
      expect(c?.phone, '+91 98765 43210');
      final row = await MedicineCleanStorageService.profileFor(null);
      expect(row?.emergencyPhone, '+91 98765 43210', reason: 'and on the profile, too');
    });

    testWidgets('the one set elsewhere is what the form shows', (tester) async {
      final me = await addMe(contact: 'Old', phone: '+91 11111 11111');
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
      await open(tester, me);
      expect(textIn(tester, 'Contact name'), 'Arun');
      expect(textIn(tester, 'Phone number'), '+91 98765 43210');
    });

    testWidgets('with none set elsewhere, the profile\'s own is shown', (tester) async {
      final me = await addMe(contact: 'Old', phone: '+91 11111 11111');
      await open(tester, me);
      expect(textIn(tester, 'Contact name'), 'Old');
      expect(textIn(tester, 'Phone number'), '+91 11111 11111');
    });

    testWidgets('emptying the fields removes it', (tester) async {
      final me = await addMe();
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
      await open(tester, me);
      await tester.enterText(field('Contact name'), '');
      await tester.enterText(field('Phone number'), '');
      await save(tester);

      expect(EmergencyContact.get(), isNull);
      expect(EmergencyContact.isSet, isFalse);
    });

    testWidgets('a number that cannot be dialled is not saved', (tester) async {
      final me = await addMe();
      await open(tester, me);
      await tester.enterText(field('Phone number'), 'call grandma');
      await save(tester);

      expect(find.text('Enter a phone number'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget, reason: 'the form stays open');
      expect(EmergencyContact.get(), isNull);
      expect((await MedicineCleanStorageService.profileFor(null))?.emergencyPhone, isNull);
    });
  });

  group("someone you look after", () {
    testWidgets("their contact stays on their profile and does not touch yours",
        (tester) async {
      await addMe();
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
      final kid = DependentProfile(
          id: 'kid', name: 'Aarav', relationship: RelationshipType.child);
      await MedicineCleanStorageService.addDependent(kid);

      await open(tester, kid);
      expect(textIn(tester, 'Phone number'), isEmpty, reason: 'not yours');
      await tester.enterText(field('Contact name'), 'Meera');
      await tester.enterText(field('Phone number'), '+91 99999 00000');
      await save(tester);

      expect(EmergencyContact.get()?.name, 'Arun');
      final row = await MedicineCleanStorageService.profileFor('kid');
      expect(row?.emergencyPhone, '+91 99999 00000');
    });

    testWidgets('a new family member does not touch it either', (tester) async {
      await addMe();
      await EmergencyContact.save(name: 'Arun', phone: '+91 98765 43210');
      await open(tester, null);
      await tester.enterText(field('Full name'), 'Meera');
      await tester.enterText(field('Phone number'), '+91 99999 00000');
      await save(tester);

      expect(EmergencyContact.get()?.phone, '+91 98765 43210');
    });
  });
}
