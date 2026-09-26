import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppButton, AppTextField;
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
}
