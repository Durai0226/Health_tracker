import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/onboarding/screens/welcome_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// Onboarding asks about reminders and nothing else — there is no water-goal
/// UI on any of its three panes. So finishing it must not write a hydration
/// goal, and above all must not write `useCustomGoal: true`: that is the flag
/// meaning "the user overrode the calculated goal", and it permanently stops
/// both the profile-calculated goal and `WaterService.refreshWeatherGoal()`
/// from ever applying.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
  });

  tearDown(() async => db.close());

  testWidgets('finishing onboarding leaves the hydration goal un-overridden',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const WelcomeScreen()));
    await tester.pumpAndSettle();

    // Pane 1 -> 2 -> 3, then the no-permission exit ("Skip for now"), which is
    // the shortest path through _finish().
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    // _finish() gates on the auth sheet for a user who is not signed in.
    expect(find.text('Continue as guest'), findsOneWidget);
    await tester.tap(find.text('Continue as guest'));
    // Bounded pumps rather than pumpAndSettle: _finish() ends in a
    // pushReplacement to AppShell, which is not what this test is about.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    tester.takeException();

    expect(CleanStorageService.isFirstLaunch, isFalse,
        reason: 'the finish path never ran, so nothing below proves anything');

    expect(await db.waterDao.getProfile(), isNull,
        reason: 'onboarding wrote a hydration profile it never asked about');
    expect(WaterService.getProfile().useCustomGoal, isFalse,
        reason: 'a goal the user was never shown was recorded as their own '
            'override, so the calculated and weather-adjusted goals can never '
            'apply');
  });
}
