import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/insights/screens/weekly_recap_screen.dart';
import 'package:tablet_remainder/features/insights/services/weekly_recap_service.dart';

/// The recap's Retry used to be `setState(() => _future = load())`. That
/// closure returns the Future it assigns, and `setState` asserts in a debug
/// build that its callback returned nothing — so Retry threw on every debug run
/// and worked in release, the one place nobody sees the assertion.
///
/// Drives the real `onRetry` the screen hands the failure panel, which is
/// exactly what a tap on "Try again" runs, rather than trying to force a
/// failure that an in-memory database will not produce.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Retry reloads the recap without throwing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    addTearDown(() async => db.close());
    ActiveProfileService().resetForTesting();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);

    await withClock(Clock.fixed(DateTime(2026, 8, 26, 12)), () async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WeeklyRecapScreen(),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      final section = tester.widget<AsyncSection<WeeklyRecap>>(
          find.byType(AsyncSection<WeeklyRecap>));
      expect(section.onRetry, isNotNull, reason: 'premise');

      section.onRetry!();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(tester.takeException(), isNull,
          reason: 'Retry must not hand setState a Future');
    });
  });
}
