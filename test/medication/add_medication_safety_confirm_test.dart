import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppButton, AppTextField;
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// DS-13: the wizard's two save-time safety warnings (allergy conflict, drug
/// interaction) moved off `AlertDialog` onto [ConfirmationBottomSheet]. The
/// grammar changed; the CONTRACT must not.
///
/// `_confirmDrugInteractions` returns `proceed ?? false` and `_saveMedicine`
/// aborts the write on false, so the two outcomes that matter are the two this
/// file pins: a dismissed sheet (null) must leave the medicine UNSAVED and the
/// wizard usable, and "Save anyway" must write the medicine the warning was
/// about. A confirmation that silently became a no-op would block every save
/// behind a warning; one that returned true on dismissal would save a flagged
/// medicine nobody agreed to.
///
/// The allergy sheet is the same code shape one method up (same helper, same
/// `proceed ?? false`, same abort in `_saveMedicine`) but needs a dependent
/// profile with allergies on file; the interaction path reproduces the branch
/// with nothing but a second medicine, so that is the one driven here.
///
/// NOTE on pumping (same trap as add_medication_validation_test): the save path
/// puts a spinner on the primary button and then talks to the notification
/// plugin, which never answers under `flutter test` — so the tree never goes
/// idle and `pumpAndSettle()` hangs. Bounded pump()s only.
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

  /// An active medicine that the curated interaction table pairs with the one
  /// the wizard is about to add (Warfarin + Aspirin, severe).
  Future<void> seedInteractingMedicine() async {
    await MedicineCleanStorageService.addMedicine(
      EnhancedMedicine(
        id: 'warfarin1',
        name: 'Warfarin',
        strength: '5mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026),
        schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
      ),
      stampActiveProfile: false,
    );
  }

  /// Host the wizard behind a push so its own `Navigator.pop` on save has a
  /// route to return to.
  Future<void> openFlow(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
              builder: (_) => const NunitoAddMedicationFlow(),
            )),
            child: const Text('host page'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('host page'));
    await tester.pumpAndSettle();
  }

  Future<void> enterInto(WidgetTester tester, String label, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AppTextField, label),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pumpBounded(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapAndPumpBounded(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await pumpBounded(tester);
  }

  /// The wizard's own primary button — `find.text` alone is ambiguous, since
  /// the header title reads "Add medicine" as well.
  Finder button(String label) => find.widgetWithText(AppButton, label);

  Future<List<EnhancedMedicine>> saved() =>
      MedicineCleanStorageService.getAllMedicines();

  /// Fill in an interacting medicine and press the primary button, stopping
  /// with the warning on screen.
  Future<void> saveUntilWarning(WidgetTester tester) async {
    await seedInteractingMedicine();
    await openFlow(tester);
    await enterInto(tester, 'Medicine name', 'Aspirin');
    await tapVisible(tester, button('Continue')); // Info -> Dosage
    await tapVisible(tester, button('Continue')); // Dosage -> Schedule
    expect(find.text('When do you take it?'), findsOneWidget);

    await tapAndPumpBounded(tester, button('Add medicine'));
    expect(find.text('Possible drug interaction'), findsOneWidget);
  }

  testWidgets('the interaction warning is a sheet, not an AlertDialog',
      (tester) async {
    await saveUntilWarning(tester);

    expect(find.byType(AlertDialog), findsNothing);
    // The warning itself moved verbatim off the dialog's content.
    expect(find.textContaining('Increased risk of bleeding'), findsOneWidget);
    expect(button('Cancel'), findsOneWidget);
    expect(button('Save anyway'), findsOneWidget);
  });

  testWidgets('(a) dismissing the warning saves nothing and leaves the wizard open',
      (tester) async {
    await saveUntilWarning(tester);

    // Tap the barrier above the sheet — the dismissal that returns null, which
    // is the case `proceed ?? false` exists for.
    await tester.tapAt(const Offset(400, 20));
    await pumpBounded(tester);

    expect(find.text('Possible drug interaction'), findsNothing);
    expect((await saved()).map((m) => m.name), ['Warfarin'],
        reason: 'a dismissed warning must not write the flagged medicine');
    expect(find.text('When do you take it?'), findsOneWidget,
        reason: 'the wizard stays open so the user can decide again');
    expect(tester.widget<AppButton>(button('Add medicine')).onPressed, isNotNull,
        reason: 'the abort path clears _isLoading — a stuck spinner would '
            'strand the user on a screen they cannot save from');
  });

  testWidgets('(b) "Save anyway" saves the medicine the warning was about',
      (tester) async {
    await saveUntilWarning(tester);

    await tapAndPumpBounded(tester, button('Save anyway'));

    final names = (await saved()).map((m) => m.name).toList();
    expect(names, containsAll(['Warfarin', 'Aspirin']),
        reason: 'confirming must save the medicine the warning was about');
  });

  group('your own allergies', () {
    Future<void> profile(String id, RelationshipType who, List<String>? allergies) =>
        MedicineCleanStorageService.addDependent(DependentProfile(
          id: id,
          name: who == RelationshipType.self ? 'Me' : 'Kid',
          relationship: who,
          allergies: allergies,
        ));

    /// Name the medicine and press the primary button.
    Future<void> saveAspirin(WidgetTester tester) async {
      await openFlow(tester);
      await enterInto(tester, 'Medicine name', 'Aspirin');
      await tapVisible(tester, button('Continue')); // Info -> Dosage
      await tapVisible(tester, button('Continue')); // Dosage -> Schedule
      await tapAndPumpBounded(tester, button('Add medicine'));
    }

    testWidgets('a medicine of your own is checked against the allergies on your profile',
        (tester) async {
      await profile('self', RelationshipType.self, ['Aspirin']);
      await saveAspirin(tester);

      expect(find.text('Possible allergy conflict'), findsOneWidget);
      expect(find.textContaining('recorded allergy "Aspirin"'), findsOneWidget);
      expect(await saved(), isEmpty, reason: 'nothing is written until you say so');
    });

    testWidgets('dismissing it saves nothing', (tester) async {
      await profile('self', RelationshipType.self, ['Aspirin']);
      await saveAspirin(tester);

      await tester.tapAt(const Offset(400, 20));
      await pumpBounded(tester);

      expect(find.text('Possible allergy conflict'), findsNothing);
      expect(await saved(), isEmpty);
      expect(find.text('When do you take it?'), findsOneWidget);
    });

    testWidgets('"Save anyway" saves it: the warning informs, it does not forbid',
        (tester) async {
      await profile('self', RelationshipType.self, ['Aspirin']);
      await saveAspirin(tester);

      await tapAndPumpBounded(tester, button('Save anyway'));
      expect((await saved()).map((m) => m.name), ['Aspirin']);
    });

    testWidgets('no allergies on your profile: no question', (tester) async {
      await profile('self', RelationshipType.self, null);
      await saveAspirin(tester);

      expect(find.text('Possible allergy conflict'), findsNothing);
      expect((await saved()).map((m) => m.name), ['Aspirin']);
    });

    testWidgets("someone else's allergy is not yours", (tester) async {
      // Their row first, so that "the first profile" is not mistaken for yours.
      await profile('kid', RelationshipType.child, ['Aspirin']);
      await profile('self', RelationshipType.self, null);
      await saveAspirin(tester);

      expect(find.text('Possible allergy conflict'), findsNothing);
      expect((await saved()).map((m) => m.name), ['Aspirin']);
    });
  });

  group('a medicine you already take', () {
    Future<void> already(String id, String name,
            {String? dependentId, bool active = true, String? generic}) =>
        MedicineCleanStorageService.addMedicine(
          EnhancedMedicine(
            id: id,
            name: name,
            genericName: generic,
            dosageForm: DosageForm.tablet,
            dosageAmount: 1,
            createdAt: DateTime(2026),
            dependentId: dependentId,
            isActive: active,
            schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
          ),
          stampActiveProfile: false,
        );

    Future<void> saveNamed(WidgetTester tester, String name) async {
      await openFlow(tester);
      await enterInto(tester, 'Medicine name', name);
      await tapVisible(tester, button('Continue')); // Info -> Dosage
      await tapVisible(tester, button('Continue')); // Dosage -> Schedule
      await tapAndPumpBounded(tester, button('Add medicine'));
    }

    testWidgets('the same medicine again asks first, and writes nothing yet',
        (tester) async {
      await already('m1', 'Metformin');
      await saveNamed(tester, 'Metformin');

      expect(find.text('Possible duplicate'), findsOneWidget);
      expect(find.textContaining('share its active ingredient with Metformin'),
          findsOneWidget);
      expect((await saved()).map((m) => m.id), ['m1']);
    });

    testWidgets('dismissing it saves nothing and leaves the wizard open',
        (tester) async {
      await already('m1', 'Metformin');
      await saveNamed(tester, 'Metformin');

      await tester.tapAt(const Offset(400, 20));
      await pumpBounded(tester);

      expect((await saved()).map((m) => m.id), ['m1']);
      expect(find.text('When do you take it?'), findsOneWidget);
      expect(tester.widget<AppButton>(button('Add medicine')).onPressed, isNotNull,
          reason: 'no stuck spinner');
    });

    testWidgets('"Save anyway" saves it: two strengths of one medicine are real',
        (tester) async {
      await already('m1', 'Metformin');
      await saveNamed(tester, 'Metformin');

      await tapAndPumpBounded(tester, button('Save anyway'));
      expect((await saved()).map((m) => m.name), ['Metformin', 'Metformin']);
    });

    testWidgets('a different medicine: no question', (tester) async {
      await already('m1', 'Metformin');
      await saveNamed(tester, 'Vitamin D');

      expect(find.text('Possible duplicate'), findsNothing);
      expect((await saved()).map((m) => m.name), containsAll(['Metformin', 'Vitamin D']));
    });

    testWidgets("someone else's medicine of the same name is not yours", (tester) async {
      await already('k1', 'Metformin', dependentId: 'kid');
      await saveNamed(tester, 'Metformin');

      expect(find.text('Possible duplicate'), findsNothing);
      expect((await saved()).where((m) => m.dependentId == null), hasLength(1));
    });

    testWidgets('one you have stopped taking is not a duplicate', (tester) async {
      await already('m1', 'Metformin', active: false);
      await saveNamed(tester, 'Metformin');
      expect(find.text('Possible duplicate'), findsNothing);
    });

    testWidgets('editing without changing the name does not ask again', (tester) async {
      await already('m1', 'Metformin');
      await already('m2', 'Metformin');
      final edit = (await saved()).firstWhere((m) => m.id == 'm2');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => NunitoAddMedicationFlow(editMedicine: edit),
              )),
              child: const Text('host page'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('host page'));
      await tester.pumpAndSettle();
      await tapVisible(tester, button('Continue'));
      await tapVisible(tester, button('Continue'));
      await tapAndPumpBounded(tester, button('Save changes'));

      expect(find.text('Possible duplicate'), findsNothing);
    });

    testWidgets('and giving it the generic name of one you take does too', (tester) async {
      await already('m1', 'Metformin');
      await already('m2', 'Glucophage');
      final edit = (await saved()).firstWhere((m) => m.id == 'm2');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => NunitoAddMedicationFlow(editMedicine: edit),
              )),
              child: const Text('host page'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('host page'));
      await tester.pumpAndSettle();
      await enterInto(tester, 'Generic name (optional)', 'Metformin');
      await tapVisible(tester, button('Continue'));
      await tapVisible(tester, button('Continue'));
      await tapAndPumpBounded(tester, button('Save changes'));

      expect(find.text('Possible duplicate'), findsOneWidget);
    });

    testWidgets('but renaming it into one you take does', (tester) async {
      await already('m1', 'Metformin');
      await already('m2', 'Aspirin');
      final edit = (await saved()).firstWhere((m) => m.id == 'm2');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => NunitoAddMedicationFlow(editMedicine: edit),
              )),
              child: const Text('host page'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('host page'));
      await tester.pumpAndSettle();
      await enterInto(tester, 'Medicine name', 'Metformin');
      await tapVisible(tester, button('Continue'));
      await tapVisible(tester, button('Continue'));
      await tapAndPumpBounded(tester, button('Save changes'));

      expect(find.text('Possible duplicate'), findsOneWidget);
    });
  });
}
