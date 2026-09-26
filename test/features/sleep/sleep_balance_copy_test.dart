/// SS-14 — the "Rest in credit" insight explained a number that no longer
/// exists.
///
/// `sleepDebtMinutes()` divides by the nights ACTUALLY LOGGED; un-logged
/// nights are not counted. `sleep_balance_low` was corrected to say so, but
/// its mirror `sleep_balance_up` still read *"What you slept over the last 7
/// nights vs your 8h nightly target × 7."* A surplus quoted against seven
/// nights when four were logged is exactly as invented as the phantom debt the
/// "× 7" formula used to produce — and the chip that carries it is the one
/// place a user can go to check whether the number is trustworthy.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

/// A plain weekday morning, pinned so the seven-night trend window and the
/// nights this test logs cannot drift apart when the date rolls over.
final _now = DateTime(2026, 3, 10, 10, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // `_load()` awaits `HealthDataService.availability()`, which awaits
    // `health.configure()`, which awaits device_info. An UNMOCKED channel in a
    // widget test never replies under fake async, so the screen sat on its
    // loading skeleton forever and the insight was never built. Mocked, the
    // reply arrives as a microtask that `pump()` drains: `configure()` throws
    // on the empty map, `_ensureConfigured` swallows it, and the load
    // finishes — which is also what happens on a desktop/simulator run.
    //
    // Driving it with `tester.runAsync` instead is a dead end here: that also
    // lets google_fonts' async load run, and this app bundles no font files,
    // so every face throws straight into the zone's uncaught-error handler
    // where `FlutterError.onError` cannot reach it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (_) async => <String, dynamic>{},
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.init();
  });

  tearDown(() async => db.close());

  /// Four nights of 11 hours in bed at quality 5 (~601 min asleep against a
  /// 480 min target), which is what `sleep_balance_up` needs: a debt of
  /// −484 and at least four logged nights.
  Future<void> logSurplusNights() async {
    for (var i = 0; i < 4; i++) {
      final wake = DateTime(_now.year, _now.month, _now.day - i, 7, 0);
      await SleepService.logManualSession(
        bedtime: wake.subtract(const Duration(minutes: 660)),
        wakeTime: wake,
        quality: 5,
      );
    }
  }

  testWidgets('the credit insight explains itself in LOGGED nights',
      (tester) async {
    // Tall enough that the whole scroller lays out, so the insight card at the
    // bottom of it is real rather than merely constructed.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Layout overflow is dropped, and only that. It is a different defect with
    // its own suite (`test/responsive/`), which renders this screen at the
    // four supported phone widths under the same wider-than-shipped fallback
    // metrics; a copy test is the wrong place to re-litigate it. Everything
    // else — a real build exception in this screen — still fails the test.
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed by')) return;
      prevOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevOnError);

    await withClock(Clock.fixed(_now), () async {
      await logSurplusNights();

      expect(SleepService.loggedNightsThisWeek(), 4);
      expect(SleepService.sleepDebtMinutes(), lessThanOrEqualTo(-120),
          reason: 'premise: this fixture must actually reach sleep_balance_up');

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SleepDashboardScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Rest in credit'), findsOneWidget,
          reason: 'wrong insight — this test would be measuring nothing');

      final why = tester.widget<WhyThisChip>(find.byType(WhyThisChip)).why;

      expect(why, contains('4 logged nights'),
          reason: 'the explanation has to name the same denominator the '
              'number was computed with');
      expect(why, contains('not counted'),
          reason: 'and say what happens to the nights that are missing');
      expect(why, isNot(contains('last 7 nights')));
      expect(why, isNot(contains('× 7')));

      // The chip is the user-facing path to that string: tapping it opens the
      // "Why you're seeing this" dialog, which renders `why` verbatim.
      await tester.tap(find.byType(WhyThisChip));
      await tester.pumpAndSettle();
      expect(find.text(why), findsOneWidget);
    });
  });
}
