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

/// MED-UI-08 — the add/edit wizard's dose fields were `TextInputType.number`,
/// a DIGITS-ONLY keypad with no separator key, while the value behind them is
/// parsed as a `double`. "Half a tablet" and "2.5 ml" were therefore ordinary
/// prescriptions the form could not accept.
///
/// Two halves, both covered here:
///   1. the keypad has to offer a separator at all, and
///   2. the parse has to accept the separator the keypad actually shows — on a
///      comma-decimal locale that is ',', which `double.tryParse` rejects
///      outright, so "2,5" came back as "Please enter a valid dosage".
///
/// (`AppTextField` exposes no `inputFormatters` and none exist anywhere in
/// `lib/`, so nothing strips the separator back out again — the keypad and the
/// parse are the whole of it.)
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

  Finder fieldNamed(String label) => find.descendant(
        of: find.widgetWithText(AppTextField, label),
        matching: find.byType(TextField),
      );

  Future<void> enterInto(WidgetTester tester, String label, String text) async {
    await tester.enterText(fieldNamed(label), text);
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Tap and pump a bounded number of frames instead of settling: the save path
  /// puts a spinner on the button and then talks to the notification plugin,
  /// which never answers under `flutter test`. The medicine row is written
  /// before any of that.
  Future<void> tapAndPump(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The wizard's own primary button — `find.text` alone is ambiguous, since
  /// the header title reads "Add medicine" as well.
  Finder button(String label) => find.widgetWithText(AppButton, label);

  /// Step 1 (Info) -> step 2 (Dosage).
  Future<void> toDosageStep(WidgetTester tester) async {
    await openFlow(tester);
    await enterInto(tester, 'Medicine name', 'Aspirin');
    await tapVisible(tester, button('Continue'));
    expect(find.text('How much do you take?'), findsOneWidget);
  }

  Future<void> enableTitration(WidgetTester tester) async {
    await tapVisible(tester, find.text('Dose changes over time'));
    expect(find.widgetWithText(AppTextField, 'Day N+'), findsOneWidget);
  }

  TextInputType? keyboardOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(fieldNamed(label)).keyboardType;

  group('the dose keypad offers a decimal separator', () {
    testWidgets('on the Amount field', (tester) async {
      await toDosageStep(tester);

      expect(
        keyboardOf(tester, 'Amount'),
        const TextInputType.numberWithOptions(decimal: true),
        reason: 'dosageAmount is a double; a digits-only keypad has no "." key',
      );
    });

    testWidgets('on a titration step dose', (tester) async {
      await toDosageStep(tester);
      await enableTitration(tester);

      expect(
        keyboardOf(tester, 'Dose (pill(s))'),
        const TextInputType.numberWithOptions(decimal: true),
      );
      // Scope check: the fields that really are whole numbers keep the plain
      // numeric keypad — a day offset and a pill count are not fractional.
      expect(keyboardOf(tester, 'Day N+'), TextInputType.number);
      expect(keyboardOf(tester, 'Current quantity'), TextInputType.number);
    });
  });

  group('a comma-locale decimal separator is understood', () {
    testWidgets('"2,5" is a valid dose, not an error', (tester) async {
      await toDosageStep(tester);
      await enterInto(tester, 'Amount', '2,5');

      await tapVisible(tester, button('Continue'));

      expect(find.text('Please enter a valid dosage'), findsNothing);
      expect(find.text('When do you take it?'), findsOneWidget,
          reason: 'the keypad offers "," — the parse has to accept it');

      await tapAndPump(tester, button('Add medicine'));

      final saved = await MedicineCleanStorageService.getAllMedicines();
      expect(saved, hasLength(1));
      expect(saved.single.dosageAmount, 2.5);
    });

    testWidgets('and works for a titration step too', (tester) async {
      await toDosageStep(tester);
      await enableTitration(tester);
      await enterInto(tester, 'Day N+', '14');
      await enterInto(tester, 'Dose (pill(s))', '1,5');

      await tapVisible(tester, button('Continue'));

      expect(find.text('Step 1: enter a valid dose'), findsNothing);
      expect(find.text('When do you take it?'), findsOneWidget);

      await tapAndPump(tester, button('Add medicine'));

      final saved = await MedicineCleanStorageService.getAllMedicines();
      expect(saved, hasLength(1));
      expect(saved.single.schedule.titrationSteps!.single.dosageAmount, 1.5);
    });

    testWidgets('a dot still works, and junk is still rejected',
        (tester) async {
      await toDosageStep(tester);
      await enterInto(tester, 'Amount', '0.5');
      await tapVisible(tester, button('Continue'));
      expect(find.text('When do you take it?'), findsOneWidget);

      // Back to Dosage, and prove the comma path did not turn the guard off.
      await tapVisible(tester, button('Back'));
      await enterInto(tester, 'Amount', '1,2,3');
      await tapVisible(tester, button('Continue'));
      expect(find.text('Please enter a valid dosage'), findsOneWidget);
      expect(find.text('How much do you take?'), findsOneWidget);
    });
  });
}
