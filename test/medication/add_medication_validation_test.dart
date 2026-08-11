import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppButton, AppTextField;
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// Regression cover for two ways an unvalidated medicine could be saved by the
/// add/edit wizard:
///
///  1. From the Schedule step onward the primary button called `_saveMedicine`
///     directly, skipping every guard the Continue path enforces — so a
///     medicine could be written with an "ends on a date" duration and no end
///     date, among others.
///  2. Titration ("dose changes over time") rows were parsed with
///     `double.tryParse` alone, so a dose of 0 or -5 was accepted and then
///     APPLIED: `MedicineSchedule.effectiveDosageAmount` hands back a step's
///     dose in place of the base one from its day onward.
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
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
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

  /// The wizard's own primary button — `find.text` alone is ambiguous, since
  /// the header title reads "Add Medication" as well.
  Finder button(String label) => find.widgetWithText(AppButton, label);

  /// Step 1 (Info) -> step 2 (Dosage).
  Future<void> toDosageStep(WidgetTester tester) async {
    await openFlow(tester);
    await enterInto(tester, 'Medication Name', 'Aspirin');
    await tapVisible(tester, button('Continue'));
    expect(find.text('How much do you take?'), findsOneWidget);
  }

  /// ... -> step 3 (Schedule), leaving the pre-filled dose of 1 alone.
  Future<void> toScheduleStep(WidgetTester tester) async {
    await toDosageStep(tester);
    await tapVisible(tester, button('Continue'));
    expect(find.text('When do you take it?'), findsOneWidget);
  }

  Future<int> savedCount() async =>
      (await MedicineCleanStorageService.getAllMedicines()).length;

  group('finishing early from the Schedule step', () {
    testWidgets('still enforces the Schedule step guards', (tester) async {
      await toScheduleStep(tester);

      // "End date" mode selected, but no date picked yet.
      await tapVisible(tester, find.text('End date'));
      await tapVisible(tester, button('Add Medication'));

      expect(find.text('Please pick an end date'), findsOneWidget);
      expect(await savedCount(), 0,
          reason: 'the medicine must not be written until the step is valid');
      // Still on Schedule — the wizard did not pop.
      expect(find.text('When do you take it?'), findsOneWidget);
    });

    testWidgets('saves normally once the step is valid', (tester) async {
      await toScheduleStep(tester);
      await tapVisible(tester, button('Add Medication'));
      await tester.pumpAndSettle();

      expect(await savedCount(), 1);
    });
  });

  group('titration dose steps', () {
    Future<void> enableTitration(WidgetTester tester) async {
      await tapVisible(tester, find.text('Dose changes over time'));
      expect(find.widgetWithText(AppTextField, 'Day N+'), findsOneWidget);
    }

    testWidgets('a zero dose is rejected, not silently saved', (tester) async {
      await toDosageStep(tester);
      await enableTitration(tester);
      await enterInto(tester, 'Dose (pill(s))', '0');

      await tapVisible(tester, button('Continue'));

      expect(find.text('Step 1: dose must be greater than 0'), findsOneWidget);
      expect(find.text('How much do you take?'), findsOneWidget,
          reason: 'the wizard must not advance past an invalid dose');
      expect(find.text('When do you take it?'), findsNothing);
    });

    testWidgets('a negative dose is rejected', (tester) async {
      await toDosageStep(tester);
      await enableTitration(tester);
      await enterInto(tester, 'Dose (pill(s))', '-5');

      await tapVisible(tester, button('Continue'));

      expect(find.text('Step 1: dose must be greater than 0'), findsOneWidget);
      expect(find.text('How much do you take?'), findsOneWidget);
    });

    testWidgets('an unparseable dose is reported, not dropped', (tester) async {
      await toDosageStep(tester);
      await enableTitration(tester);
      await enterInto(tester, 'Dose (pill(s))', 'abc');

      await tapVisible(tester, button('Continue'));

      expect(find.text('Step 1: enter a valid dose'), findsOneWidget);
      expect(find.text('How much do you take?'), findsOneWidget);
    });

    testWidgets('a real dose step is accepted and persisted', (tester) async {
      await toDosageStep(tester);
      await enableTitration(tester);
      await enterInto(tester, 'Day N+', '14');
      await enterInto(tester, 'Dose (pill(s))', '2');

      await tapVisible(tester, button('Continue'));
      expect(find.text('When do you take it?'), findsOneWidget);

      await tapVisible(tester, button('Add Medication'));
      await tester.pumpAndSettle();

      final saved = await MedicineCleanStorageService.getAllMedicines();
      expect(saved, hasLength(1));
      final steps = saved.single.schedule.titrationSteps;
      expect(steps, hasLength(1));
      expect(steps!.single.startDayOffset, 14);
      expect(steps.single.dosageAmount, 2);
    });
  });
}
