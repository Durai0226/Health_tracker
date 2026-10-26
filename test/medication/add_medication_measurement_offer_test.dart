import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppButton, AppTextField;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/services/measurement_plan_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// The offer's hook in the wizard: a NEW blood-pressure, diabetes or water pill
/// opens the "Track what … affects?" sheet after it is saved; an unrelated one,
/// and any EDIT, does not.
///
/// Same pumping rules as `add_medication_safety_confirm_test`: the save path
/// talks to the notification plugin, so the tree never goes idle and
/// `pumpAndSettle()` after the save would hang. The offer also reads a bundled
/// asset, which needs the real clock — but `tester.runAsync` while widgets are
/// built lets google_fonts' async load throw (this app bundles no font files),
/// so the catalogue is preloaded BEFORE any widget exists and everything after
/// is plain pumps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  /// Memoised, so the offer's own `ensureLoaded` is then a microtask.
  Future<void> preloadCatalog(WidgetTester tester) =>
      tester.runAsync(DrugNameCatalog.ensureLoaded);

  tearDown(() async => db.close());

  Future<void> openFlow(WidgetTester tester, {EnhancedMedicine? edit}) async {
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
  }

  Future<void> enterName(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AppTextField, 'Medicine name'),
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

  Finder button(String label) => find.widgetWithText(AppButton, label);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> addNew(WidgetTester tester, String name) async {
    await preloadCatalog(tester);
    await openFlow(tester);
    await enterName(tester, name);
    await tapVisible(tester, button('Continue'));
    await tapVisible(tester, button('Continue'));
    expect(find.text('When do you take it?'), findsOneWidget);
    await tester.ensureVisible(button('Add medicine'));
    await tester.pump();
    await tester.tap(button('Add medicine'));
    await settle(tester);
  }

  testWidgets('a new blood-pressure pill opens the offer after saving',
      (tester) async {
    await addNew(tester, 'Amlodipine');

    expect(find.text('Track what Amlodipine affects?'), findsOneWidget);
    expect(find.text('Blood pressure, morning and evening'), findsOneWidget);
    expect((await MedicineCleanStorageService.getAllMedicines()).map((m) => m.name),
        ['Amlodipine'],
        reason: 'the offer comes AFTER the save, never in place of it');
    // The wizard is still underneath until the offer is answered.
    expect(find.text('Add medicine'), findsWidgets);
  });

  testWidgets('answering "Not now" closes the offer and the wizard',
      (tester) async {
    await addNew(tester, 'Amlodipine');
    await tester.tap(find.text('Not now'));
    await settle(tester);

    expect(find.text('Track what Amlodipine affects?'), findsNothing);
    expect(find.text('host page'), findsOneWidget,
        reason: 'the wizard pops once the offer is answered');
    expect(MeasurementPlanService.declined(), isNotEmpty);
  });

  testWidgets('an unrelated medicine saves with no offer', (tester) async {
    await addNew(tester, 'Paracetamol');

    expect(find.textContaining('Track what'), findsNothing);
    expect(find.text('host page'), findsOneWidget,
        reason: 'no offer, so the wizard closes straight away');
    expect((await MedicineCleanStorageService.getAllMedicines()).map((m) => m.name),
        ['Paracetamol']);
  });

  testWidgets('editing a blood-pressure pill does not offer anything',
      (tester) async {
    final existing = EnhancedMedicine(
      id: 'amlo1',
      name: 'Amlodipine',
      strength: '5mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: DateTime(2026),
      schedule: MedicineSchedule.onceDaily(hour: 8, minute: 0),
    );
    await MedicineCleanStorageService.addMedicine(existing,
        stampActiveProfile: false);

    await preloadCatalog(tester);
    await openFlow(tester, edit: existing);
    // Edit opens on the first step; walk to the end like a user would.
    await tapVisible(tester, button('Continue'));
    await tapVisible(tester, button('Continue'));
    await tester.ensureVisible(button('Save changes'));
    await tester.pump();
    await tester.tap(button('Save changes'));
    await settle(tester);

    expect(find.textContaining('Track what'), findsNothing);
  });
}
