import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';

/// A screen you can push must offer a way back.
///
/// The Health hub pushes all of these. `SleepDashboardScreen` was the only one
/// with no back affordance — it had three header `actions` and no `leading`,
/// while Water and Steps both carried one. Pushed from the hub or the Log
/// sheet, its on-screen chrome was a dead end: the only way out was the
/// platform gesture, which is not a thing a custom header can rely on.
///
/// It went unnoticed because no harness had ever PUSHED these screens. The
/// responsive sweep and the build-cost harness mount each screen as a route
/// root, where `Navigator.canPop()` is false and a back button is correctly
/// absent — so the one configuration that matters was the one never tested.
///
/// Mutation-checked: remove `leading:` from the Sleep header and this fails
/// with "Sleep has no back affordance when pushed".
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

  final screens = <String, Widget Function()>{
    'Water': () => const AquaWaterDashboard(),
    'Steps': () => const StepsDashboardScreen(),
    'Sleep': () => const SleepDashboardScreen(),
    'Period': () => const PeriodDashboard(),
    'Diary': () => const DiaryScreen(),
  };

  screens.forEach((name, build) {
    testWidgets('$name offers a way back when pushed', (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow noise is covered elsewhere
      try {
        // PUSH it — do not mount it as a route root. That distinction is the
        // whole point: `Navigator.canPop()` is what these screens gate on.
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(MaterialApp(
          navigatorKey: navKey,
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SizedBox.expand()),
        ));
        await tester.pump();

        unawaited(navKey.currentState!
            .push(MaterialPageRoute<void>(builder: (_) => build())));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(seconds: 2));

        expect(
          find.byIcon(Symbols.arrow_back_rounded),
          findsWidgets,
          reason: '$name has no back affordance when pushed. The Health hub '
              'pushes it, so its header is the only way out — a user who '
              'cannot rely on the platform gesture is stuck.',
        );
      } finally {
        FlutterError.onError = prev;
      }

      await tester.pump(const Duration(seconds: 8)); // drain pending timers
    });
  });
}

/// Local `unawaited` so this file needs no extra import.
void unawaited(Future<void> future) {}
