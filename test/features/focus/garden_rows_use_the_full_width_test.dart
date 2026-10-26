/// A day section must not be one small tile under a full-width header.
///
/// The garden drew each session as a `width: 100` card inside a `Wrap`. A
/// session writes exactly one plant, so a day section almost always held a
/// single tile: 100pt of a 363pt content row, leaving 72% of the row blank
/// beneath a header that spanned all of it. A `Wrap` with one fixed-width
/// child is a `Row` with one child and no alignment.
///
/// The measurable signature is where the duration sits. In the tile it was
/// centred inside the 100pt card hard against the left margin (~74dp on a
/// 411dp phone); in a full-width row it trails at the right edge (~360dp).
/// Anything still in the left half means the tile is back.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final now = DateTime(2026, 9, 30, 11, 0);

  /// The phone the rest of this screen's tests measure against.
  const width = 411.0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  /// One plant on one day — the ordinary case, and the one that looked worst.
  Future<void> pumpOneSession(WidgetTester tester) async {
    await CleanStorageService.setAppPreference('focusGarden', [
      FocusPlant(
        id: 'p1',
        type: PlantType.values.first,
        plantedAt: DateTime(2026, 9, 28, 10, 15),
        durationMinutes: 35,
        isAlive: true,
        growthProgress: 1.0,
      ).toJson(),
    ]);
    await FocusService().init();

    tester.view.devicePixelRatio = 1.0;
    // MediaQuery size is not layout size unless the view is set too.
    tester.view.physicalSize = const Size(width, 900);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(const MaterialApp(home: FocusGardenScreen()));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('a session spans the content width, not a 100pt tile',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpOneSession(tester);

      final duration = find.text('35m');
      expect(duration, findsOneWidget,
          reason: 'premise: the session rendered at all. Without this the '
              'assertion below cannot fail for the right reason.');

      final dx = tester.getCenter(duration).dx;
      expect(dx, greaterThan(width / 2),
          reason: 'the duration sits at ${dx.toStringAsFixed(0)}dp on a '
              '${width.toInt()}dp screen. In the old Wrap tile it was centred '
              'in a 100pt card at the left margin (~74dp), which is the '
              'layout that left 72% of every row empty.');
    });
  });

  testWidgets('the row carries the species name the tile had no room for',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pumpOneSession(tester);

      // The tile showed only an emoji, a duration and a time; the species was
      // left entirely to the glyph, which is exactly what a screen reader and
      // an unfamiliar user cannot resolve.
      expect(find.text(PlantType.values.first.name), findsOneWidget,
          reason: 'the full-width row exists to carry this. If it is gone the '
              'row has been narrowed back toward the tile.');
    });
  });

  testWidgets('an abandoned session is labelled, not just faded',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await CleanStorageService.setAppPreference('focusGarden', [
        FocusPlant(
          id: 'dead',
          type: PlantType.values.first,
          plantedAt: DateTime(2026, 9, 28, 10, 15),
          durationMinutes: 1,
          isAlive: false,
          growthProgress: 0.2,
        ).toJson(),
      ]);
      await FocusService().init();

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(width, 900);
      addTearDown(tester.view.reset);

      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(const MaterialApp(home: FocusGardenScreen()));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));
      } finally {
        FlutterError.onError = prev;
      }

      expect(find.text('Given up'), findsOneWidget,
          reason: 'a withered plant was distinguished only by a 🥀 glyph at '
              '50% opacity — invisible to a screen reader and ambiguous to '
              'anyone who has not seen a living one beside it');
    });
  });
}
