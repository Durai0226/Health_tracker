import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/screens/hydration_profile_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// W9 — the hydration profile could be filled in but not emptied, and the one
/// number with a clinical meaning had no bounds at all.
///
///  * Clearing the weight or age box did nothing: the screen handed
///    `double.tryParse('')` — null — to a `??` copyWith, which put the old
///    value straight back. Someone who had entered a wrong weight could change
///    it but never take it out, and the goal kept being computed from it.
///  * The prescribed fluid ceiling was accepted on nothing but `ml > 0`, and
///    was never re-checked on save, so "50000" was stored as a daily limit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final now = DateTime(2026, 9, 26, 14, 0);

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
  });

  tearDown(() async => database.close());

  group('the model can express "no longer set"', () {
    test('clearWeight / clearAge actually clear', () {
      final filled = HydrationProfile(
        id: 'profile',
        createdAt: now,
        weightKg: 82,
        age: 41,
      );

      expect(filled.copyWith(weightKg: null).weightKg, 82,
          reason: 'a bare null still means "argument omitted" — that is the '
              'whole reason the flags have to exist');

      final cleared = filled.copyWith(clearWeight: true, clearAge: true);
      expect(cleared.weightKg, isNull);
      expect(cleared.age, isNull);
    });

    test('clearing one field leaves the other alone', () {
      final filled = HydrationProfile(
        id: 'profile',
        createdAt: now,
        weightKg: 82,
        age: 41,
      );
      final cleared = filled.copyWith(clearWeight: true);
      expect(cleared.weightKg, isNull);
      expect(cleared.age, 41);
    });
  });

  Future<void> openScreen(WidgetTester tester) async {
    // Tall enough that the whole form — including the Save button at the very
    // bottom — is laid out and hit-testable. `scrollUntilVisible` throws on
    // this app's scrolling screens, and a MediaQuery size alone does not set
    // the layout size.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 4400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HydrationProfileScreen(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder fieldWithLabel(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextField),
      );

  testWidgets('emptying the weight box removes the stored weight',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await WaterService.init();
      await WaterService.saveProfile(HydrationProfile(
        id: 'profile',
        createdAt: now,
        weightKg: 82,
        age: 41,
      ));

      await openScreen(tester);
      expect(find.text('82.0'), findsOneWidget,
          reason: 'the stored weight is what the box starts on');

      await tester.enterText(fieldWithLabel('Weight (kg)'), '');
      await tester.pump();
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(WaterService.getProfile().weightKg, isNull,
          reason: 'an emptied box means "do not use this", not "keep what you '
              'had" — the goal is computed from it');
      expect(WaterService.getProfile().age, 41,
          reason: 'only the field that was emptied is cleared');
    });
  });

  testWidgets('a fluid ceiling above the ceiling bound is refused',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await WaterService.init();
      await WaterService.saveProfile(HydrationProfile(
        id: 'profile',
        createdAt: now,
        fluidCeilingMl: 1500,
      ));

      await openScreen(tester);
      await tester.enterText(fieldWithLabel('Daily limit (ml)'), '50000');
      await tester.pump();
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
          find.textContaining(
              'between ${_HydrationProfileBounds.min} and '
              '${_HydrationProfileBounds.max}'),
          findsOneWidget,
          reason: 'a mistyped limit must be caught, not saved — this number '
              'is the one a clinician gave the user');
      expect(WaterService.getProfile().fluidCeilingMl, 1500,
          reason: 'the rejected value must not reach storage');
    });
  });

  testWidgets('a ceiling inside the bounds still saves', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await WaterService.init();
      await WaterService.saveProfile(HydrationProfile(
        id: 'profile',
        createdAt: now,
        fluidCeilingMl: 1500,
      ));

      await openScreen(tester);
      await tester.enterText(fieldWithLabel('Daily limit (ml)'), '1200');
      await tester.pump();
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(WaterService.getProfile().fluidCeilingMl, 1200,
          reason: 'every real prescription has to go through untouched');
    });
  });
}

/// Mirrors the screen's own bounds so the assertion above reads as a range
/// rather than two magic numbers.
class _HydrationProfileBounds {
  static const int min = 250;
  static const int max = 5000;
}
