import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/app_shell.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';

/// `AppShell` mounts the tab it was ASKED to open.
///
/// The bug this pins: `_mounted` was `final Set<int> _mounted = {0}` while
/// `_slot` was `widget.initialIndex`. `IndexedStack` renders
/// `SizedBox.shrink()` for any index not in `_mounted`, so
/// `AppShell(initialIndex: 1)` selected stack child 1 and then rendered
/// nothing there.
///
/// That is the exact call in `welcome_screen.dart` — every brand-new user
/// finished onboarding onto a blank screen. The lazy-mount optimisation and
/// the non-zero initial tab were each correct in isolation.
///
/// Mutation-checked: restore `_mounted = {0}` and
/// "lands on Meds, not a blank body" fails with
/// `NunitoMedicationDashboard not mounted`.
void main() {
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Future<void> pumpShell(WidgetTester tester, int initialIndex) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow noise is covered elsewhere
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: AppShell(initialIndex: initialIndex),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('initialIndex 1 lands on Meds, not a blank body', (tester) async {
    await pumpShell(tester, 1);

    expect(
      find.byType(NunitoMedicationDashboard),
      findsOneWidget,
      reason: 'welcome_screen.dart finishes onboarding into '
          'AppShell(initialIndex: 1). If the Meds dashboard is not mounted, '
          'every brand-new user sees a blank screen after onboarding.',
    );

    await tester.pump(const Duration(seconds: 8)); // drain pending timers
  });

  testWidgets('initialIndex 0 still lazy-mounts only Today', (tester) async {
    await pumpShell(tester, 0);

    expect(find.byType(HomeDashboard), findsOneWidget);
    expect(
      find.byType(NunitoMedicationDashboard),
      findsNothing,
      reason: 'The lazy first-mount optimisation must survive the fix: '
          'landing on Today must NOT build the Meds dashboard, which also '
          'writes (it drains queued dose actions and reconciles missed doses).',
    );

    await tester.pump(const Duration(seconds: 8));
  });

  test('slot 2 is rejected as an initial tab', () {
    // Slot 2 is the Log action and never becomes the selection, so accepting
    // it would select stack child 2 (Health) while highlighting the Log button.
    expect(() => AppShell(initialIndex: 2), throwsAssertionError);
    expect(() => AppShell(initialIndex: 5), throwsAssertionError);
  });
}
