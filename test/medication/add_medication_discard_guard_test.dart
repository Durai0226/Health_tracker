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

/// MED-UI-07 — the five-step add/edit wizard threw away everything the user had
/// entered the moment they pressed back or the close button, with no prompt.
///
/// There are two reachable ways out of this screen and the guard has to cover
/// both: the system back gesture (which is all `PopScope` sees) and the
/// header's close button, which calls `Navigator.pop` imperatively and so pops
/// regardless of `canPop`. ("Back" on step 1 is a third in the source, but the
/// Back button only renders past step 0, so there is no scenario to test.)
///
/// The other half of the requirement is that an UNTOUCHED form must not prompt,
/// so the "no changes" cases are asserted too: a confirmation on a form nobody
/// typed into is its own annoyance, and the edit case must count as clean until
/// the user actually changes something.
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

  /// Host the wizard behind a push, so "did it leave?" is observable: the
  /// hosting page's own button comes back into view when the wizard pops.
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
    expect(find.text('host page'), findsNothing);
  }

  Future<void> enterInto(WidgetTester tester, String label, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AppTextField, label),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The header's close affordance, found by its tooltip:
  /// `Symbols.close_rounded` is also the "clear expiry date" button deeper in
  /// the form.
  Finder closeButton() => find.byTooltip('Close');

  /// The Android system back gesture, as the framework delivers it.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  /// A stored medicine to open the wizard on in edit mode.
  EnhancedMedicine existingMedicine() => EnhancedMedicine(
        id: 'med-1',
        name: 'Aspirin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  Finder discardSheet() => find.text('Discard this medicine?');
  Finder button(String label) => find.widgetWithText(AppButton, label);

  group('an untouched wizard leaves without asking', () {
    testWidgets('via the close button', (tester) async {
      await openFlow(tester);

      await tapVisible(tester, closeButton());

      expect(discardSheet(), findsNothing,
          reason: 'nothing was typed — there is nothing to confirm');
      expect(find.text('host page'), findsOneWidget);
    });

    testWidgets('via the system back gesture', (tester) async {
      await openFlow(tester);

      await systemBack(tester);

      expect(discardSheet(), findsNothing);
      expect(find.text('host page'), findsOneWidget);
    });

    testWidgets('and an edit counts as untouched until it is changed',
        (tester) async {
      await openFlow(tester, edit: existingMedicine());
      expect(find.text('Edit medicine'), findsOneWidget);

      await tapVisible(tester, closeButton());

      expect(find.text('Discard changes?'), findsNothing,
          reason: 'the baseline is captured AFTER the medicine is loaded');
      expect(find.text('host page'), findsOneWidget);
    });
  });

  group('a wizard with unsaved work asks first', () {
    testWidgets('the close button prompts, and "Keep editing" stays put',
        (tester) async {
      await openFlow(tester);
      await enterInto(tester, 'Medicine name', 'Metformin');

      await tapVisible(tester, closeButton());

      expect(discardSheet(), findsOneWidget);
      expect(find.text('host page'), findsNothing,
          reason: 'the wizard must not have popped behind the sheet');

      await tapVisible(tester, button('Keep editing'));

      expect(find.text('host page'), findsNothing);
      expect(find.text('What medicine are you adding?'), findsOneWidget);
      expect(find.text('Metformin'), findsOneWidget,
          reason: 'the typed name survives "Keep editing"');
    });

    testWidgets('the system back gesture prompts too', (tester) async {
      await openFlow(tester);
      await enterInto(tester, 'Medicine name', 'Metformin');

      await systemBack(tester);

      expect(discardSheet(), findsOneWidget);
      expect(find.text('host page'), findsNothing);
    });

    testWidgets('from a later step, where the work is even bigger',
        (tester) async {
      await openFlow(tester);
      await enterInto(tester, 'Medicine name', 'Metformin');
      await tapVisible(tester, button('Continue'));
      expect(find.text('How much do you take?'), findsOneWidget);

      await systemBack(tester);

      expect(discardSheet(), findsOneWidget);
      expect(find.text('How much do you take?'), findsOneWidget,
          reason: 'still on the Dosage step, behind the sheet');
      expect(find.text('host page'), findsNothing);
    });

    testWidgets('"Discard" actually leaves', (tester) async {
      await openFlow(tester);
      await enterInto(tester, 'Medicine name', 'Metformin');

      await tapVisible(tester, closeButton());
      await tapVisible(tester, button('Discard'));

      expect(find.text('host page'), findsOneWidget);
    });

    testWidgets('even from a field nothing else listens to', (tester) async {
      await openFlow(tester);
      // Deliberately NOT the medicine-name field: that one already rebuilds
      // the screen through the drug-name typeahead listener, which would hide
      // a broken dirty flag. `PopScope.canPop` is captured at build time and a
      // plain text field rebuilds nothing above itself, so this is the case
      // that needs the controller listener to exist.
      await enterInto(tester, 'Generic name (optional)', 'Metformin HCl');

      await systemBack(tester);

      expect(discardSheet(), findsOneWidget,
          reason: 'canPop must not still be reading the form as untouched');
      expect(find.text('host page'), findsNothing);
    });

    testWidgets('and an edit that HAS been changed asks too', (tester) async {
      await openFlow(tester, edit: existingMedicine());
      // Generic name for the same reason as the test above — no other
      // listener — and in edit mode this controller was filled by
      // `_loadExistingMedicine` BEFORE the dirty-check listeners were
      // attached, which is a different path from the add case every other
      // dirty test here takes.
      await enterInto(
          tester, 'Generic name (optional)', 'Acetylsalicylic acid');

      await tapVisible(tester, closeButton());

      expect(find.text('Discard changes?'), findsOneWidget,
          reason: 'the guard has to cover editing too — every other dirty '
              'case here is an ADD, so a guard switched off for edits would '
              'go unnoticed');
      expect(find.text('host page'), findsNothing);

      await tapVisible(tester, button('Keep editing'));
      expect(find.text('Acetylsalicylic acid'), findsOneWidget,
          reason: 'the typed generic name survives "Keep editing"');
    });

    testWidgets('a change made with no typing counts too', (tester) async {
      await openFlow(tester);
      // Dosage FORM is a chip, not a text field — the dirty check has to see
      // setState-driven controls, not just controller text.
      await tapVisible(tester, find.text('Capsule'));

      await systemBack(tester);

      expect(discardSheet(), findsOneWidget);
      expect(find.text('host page'), findsNothing);
    });
  });
}
