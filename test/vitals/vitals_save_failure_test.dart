import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';

/// PV-19 — every vitals log form set `_saving = true` and then awaited the
/// write with no try/catch. A failed write left the Save button spinning
/// forever, the sheet open, and nothing on screen saying the reading had not
/// been recorded: for a health record, indistinguishable from "still saving".
///
/// The failure is provoked by closing the database under the open sheet, which
/// is the shape of every real cause (a disk error, a closed handle after a
/// restore) as far as the form can tell: the awaited write throws.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  var dbClosed = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    dbClosed = false;
  });

  tearDown(() async {
    if (!dbClosed) await db.close();
  });

  Future<void> breakTheDatabase() async {
    await db.close();
    dbClosed = true;
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  /// The two halves of the bug, asserted together: the button has stopped
  /// spinning (its label is back — [AppButton] swaps the label OUT for the
  /// spinner while `loading`), and the form says what happened.
  void expectFailureIsVisible(WidgetTester tester, String saveLabel, String copy) {
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the Save button must stop spinning when the write fails');
    expect(find.text(saveLabel), findsOneWidget,
        reason: 'the form stays open and retryable');
    expect(find.text(copy), findsOneWidget,
        reason: 'the user must be told the reading was not recorded');
  }

  testWidgets('blood pressure: a failed save is surfaced, not swallowed',
      (tester) async {
    await pump(tester, const BloodPressureScreen());
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '120');
    await tester.enterText(find.byType(TextFormField).at(1), '80');
    await breakTheDatabase();

    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expectFailureIsVisible(
        tester, 'Save reading', 'Could not save this reading. Try again.');
  });

  testWidgets('blood sugar: a failed save is surfaced, not swallowed',
      (tester) async {
    await pump(tester, const BloodSugarScreen());
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '100');
    await breakTheDatabase();

    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expectFailureIsVisible(
        tester, 'Save reading', 'Could not save this reading. Try again.');
  });

  testWidgets('weight: a failed save is surfaced, not swallowed',
      (tester) async {
    await pump(tester, const WeightScreen());
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '70.5');
    await breakTheDatabase();

    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expectFailureIsVisible(
        tester, 'Save reading', 'Could not save this reading. Try again.');
  });

  testWidgets('mood: a failed save is surfaced, not swallowed', (tester) async {
    await pump(tester, const MoodScreen());
    await tester.tap(find.text('Log mood'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    await breakTheDatabase();

    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expectFailureIsVisible(
        tester, 'Save entry', 'Could not save this entry. Try again.');
  });
}
