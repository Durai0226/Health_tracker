import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppTextField;
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_add_edit_appointment_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_add_edit_clinic_screen.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/add_edit_dependent_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_add_edit_doctor_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

/// QA — a save that fails has to tell the user what to do next instead of
/// reading the exception out, and it must still leave a trace in the log.
///
/// Every add/edit form under medication ended its catch with
/// `context.toastError('Error: $e')`, so a closed database or a dropped
/// platform channel surfaced as "Error: DatabaseException(...)" — unreadable
/// and unactionable — and the dependent form did not even log it.
///
/// The same forms are checked here for the two field-level defects that came
/// with that audit: a name validator that accepted whitespace, and a
/// `TextEditingController` allocated inside `build()`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
  });

  /// Make the next write fail the way a real one does — the storage layer
  /// rethrows, so what the user sees is the screen's own catch.
  ///
  /// Dropping the table rather than closing the database: `close()` on a
  /// Drift executor that has not been opened yet is a no-op, and the first
  /// query afterwards simply opens and migrates it, so nothing throws.
  Future<void> breakStorage(String table) async {
    await MedicineCleanStorageService.init();
    // Forces onCreate, so the table exists to be dropped.
    await MedicineCleanStorageService.getAllDependents();
    await db.customStatement('DROP TABLE $table');
    addTearDown(() => db.close());
  }

  Finder fieldLabelled(String label) => find.byWidgetPredicate(
      (w) => w is AppTextField && w.label == label,
      description: 'AppTextField("$label")');

  Future<void> typeInto(WidgetTester tester, String label, String text) =>
      tester.enterText(
        find.descendant(
            of: fieldLabelled(label), matching: find.byType(TextFormField)),
        text,
      );

  /// Every string the currently-built tree would show the user.
  List<String> visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();

  Future<void> open(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('a doctor that could not be saved is reported in plain language',
      (tester) async {
    await breakStorage('doctors');
    await open(tester, const NunitoAddEditDoctorScreen());

    await typeInto(tester, 'Name', 'Dr Rao');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save this doctor. Please try again.'),
        findsOneWidget,
        reason: 'the user needs the next step, not the exception');
    expect(visibleText(tester).where((s) => s.startsWith('Error: ')), isEmpty,
        reason: 'no toast may read the caught exception out to the user');
  });

  testWidgets(
      'an appointment that could not be saved is reported in plain language',
      (tester) async {
    await breakStorage('appointments');
    await open(tester, const NunitoAddEditAppointmentScreen());

    await typeInto(tester, 'Doctor / reason', 'Dr Patel');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save this appointment. Please try again.'),
        findsOneWidget);
    expect(visibleText(tester).where((s) => s.startsWith('Error: ')), isEmpty);
  });

  testWidgets('a profile that could not be saved is reported in plain language',
      (tester) async {
    await breakStorage('dependent_profiles');
    await open(tester, const AddEditDependentScreen());

    await typeInto(tester, 'Full name', 'Asha');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save this profile. Please try again.'),
        findsOneWidget);
    expect(visibleText(tester).where((s) => s.contains('saving profile: ')),
        isEmpty,
        reason: 'the exception belongs in the log, not in the toast');
  });

  testWidgets('a failed profile save is still written to the log',
      (tester) async {
    await breakStorage('dependent_profiles');
    final logged = <String>[];
    final original = debugPrint;
    // Restored inside the body, not in a tearDown: the framework checks the
    // foundation debug variables before tearDowns run and fails the test.
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logged.add(message);
    };
    try {
      await open(tester, const AddEditDependentScreen());
      await typeInto(tester, 'Full name', 'Asha');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    } finally {
      debugPrint = original;
    }

    expect(logged.where((m) => m.startsWith('Error saving profile: ')),
        isNotEmpty,
        reason: 'a friendly toast must not cost the diagnosis — this catch '
            'swallowed the exception entirely');
  });

  testWidgets('a clinic name of only spaces is rejected', (tester) async {
    await MedicineCleanStorageService.init();
    addTearDown(() => db.close());
    await open(tester, const NunitoAddEditClinicScreen());

    await typeInto(tester, 'Name', '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget,
        reason: 'the name is saved trimmed, so spaces would store a nameless '
            'clinic the user cannot tell from any other');
    expect(await MedicineCleanStorageService.getAllClinics(), isEmpty);
  });

  testWidgets('the date-of-birth field keeps one controller and disposes it',
      (tester) async {
    await MedicineCleanStorageService.init();
    addTearDown(() => db.close());
    await open(tester, const AddEditDependentScreen());

    TextEditingController dob() =>
        tester.widget<AppTextField>(fieldLabelled('Date of birth')).controller!;

    final first = dob();

    // Any rebuild would do; picking a relationship is the cheapest one the
    // user actually performs on this form.
    await tester.tap(find.textContaining('Parent').first);
    await tester.pumpAndSettle();

    expect(identical(dob(), first), isTrue,
        reason: 'a controller built inside build() is re-allocated on every '
            'frame, so nothing can hold or dispose it');

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(() => first.addListener(() {}), throwsFlutterError,
        reason: 'the screen must dispose the controller it owns');
  });

  /// The same rule, across every medication screen rather than the handful
  /// this file drives: a guard that enumerates four files is one refactor away
  /// from missing the fifth.
  test('no medication screen interpolates the caught error into a toast', () {
    final offenders = <String>[];
    final files = Directory('lib/features/medication/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    // The caught binding, by every name these screens give it.
    final caught = RegExp(r'\$\{?(e|err|error|ex|exception)\}?\b');

    for (final f in files) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r'context\.toast\w+\(').allMatches(src)) {
        // Walk to the matching ")" so a call split across lines is read whole.
        var depth = 1;
        var i = m.end;
        while (i < src.length && depth > 0) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') depth--;
          i++;
        }
        final call = src.substring(m.end, i - 1);
        if (caught.hasMatch(call)) {
          offenders.add('${f.path}: ${call.split('\n').first.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'an exception is not a message to a user — log it and say '
            'what they can do instead');
  });
}
