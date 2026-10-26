/// A vital's reminder picker takes the vital's colour, not the door's.
///
/// `VitalsReminderButton` already holds the accent of the vital it belongs to
/// — it forwards it to its own `AppIconButton` — but opened `AppTimePicker`
/// without passing it. `AppTimePicker.show` then fell back to
/// `AccentScope.swatchOf(context)` (`app_pickers.dart:24`), so the sheet's
/// colour was decided by how the user reached the screen:
///
///  * from the Health hub, `MoodScreen` arrives inside
///    `AccentScope(FeatureAccent.medicine)` (`health_browse_screen.dart:85`),
///    so the picker came up medicine purple;
///  * from the "Log something" sheet it arrived on a bare `MaterialPageRoute`
///    (`log_something_sheet.dart`), so the picker came up brand teal.
///
/// Neither is the amber the Mood screen uses everywhere else. Weight, blood
/// sugar and blood pressure mount the same widget.
///
/// The test pumps the button under a DELIBERATELY WRONG ambient scope. If the
/// button ever stops passing its own accent, the sheet silently takes that
/// scope instead — which is exactly the bug.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_bottom_sheet.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_reminder_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
  });

  tearDown(() async => db.close());

  /// Mount the button carrying [own], inside a scope claiming [ambient].
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required AccentSwatch own,
    required FeatureAccent ambient,
  }) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AccentScope(
          feature: ambient,
          child: Scaffold(
            body: Center(
              child: VitalsReminderButton(
                id: 9901,
                prefKey: 'test_vital_reminder',
                title: 'Measure',
                body: 'Time to measure',
                accent: own,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(VitalsReminderButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('the picker carries the button\'s own accent, not the ambient one',
      (tester) async {
    const ext = AppColorsExt.light;
    // period (pink) is nothing like medicine (purple), so a mix-up is obvious.
    await pumpAndOpen(tester, own: ext.period, ambient: FeatureAccent.medicine);

    final sheet = find.byType(AppBottomSheet);
    expect(sheet, findsOneWidget,
        reason: 'premise: tapping opened the time picker at all. Without this '
            'the assertion below cannot fail for the right reason.');

    expect(tester.widget<AppBottomSheet>(sheet).accent, ext.period,
        reason: 'the picker resolved its colour from the ambient AccentScope '
            'instead of from the vital it belongs to, so the same button '
            'opened a differently coloured sheet depending on whether the '
            'user arrived from the Health hub or the Log sheet');
  });

  testWidgets('and it is not merely inheriting a matching scope by luck',
      (tester) async {
    const ext = AppColorsExt.light;
    // A second, different ambient. If the button were still falling back, the
    // sheet's accent would move with this; it must not.
    await pumpAndOpen(tester, own: ext.period, ambient: FeatureAccent.water);

    final sheet = find.byType(AppBottomSheet);
    expect(sheet, findsOneWidget);
    expect(tester.widget<AppBottomSheet>(sheet).accent, ext.period,
        reason: 'the accent must be the same under any ambient scope — that '
            'invariance is the whole point');
    expect(tester.widget<AppBottomSheet>(sheet).accent, isNot(ext.water),
        reason: 'specifically it must not be the ambient one');
  });
}
