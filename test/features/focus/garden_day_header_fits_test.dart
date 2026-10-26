/// The garden's day headers have to keep their date.
///
/// The header row caps the label at one line with an ellipsis so it cannot
/// push the minutes total off the right edge — which is right, and the comment
/// there says so. But it used `DateFormats.weekdayDayMonthLong`, and at the
/// DEFAULT text size on a 411dp phone "Monday, September 28" was already too
/// wide: every day older than yesterday rendered as "Monday, Septemb…", losing
/// the one thing a date header is for.
///
/// Abbreviating the month keeps the date. Ellipsising it did not.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  // A Wednesday, so the seeded days land on the long weekday names.
  final now = DateTime(2026, 9, 30, 11, 0);

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

  testWidgets('a day header is never ellipsised at the default text size',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      // Two plants, several days back, so the headers take the dated form
      // rather than "Today" / "Yesterday".
      await CleanStorageService.setAppPreference('focusGarden', [
        FocusPlant(
          id: 'p1',
          type: PlantType.values.first,
          plantedAt: DateTime(2026, 9, 28, 10, 15),
          durationMinutes: 35,
          isAlive: true,
          growthProgress: 1.0,
        ).toJson(),
        FocusPlant(
          id: 'p2',
          type: PlantType.values.first,
          plantedAt: DateTime(2026, 9, 27, 11, 15),
          durationMinutes: 45,
          isAlive: true,
          growthProgress: 1.0,
        ).toJson(),
      ]);
      await FocusService().init();

      tester.view.devicePixelRatio = 1.0;
      // The real phone this was measured on.
      tester.view.physicalSize = const Size(411, 900);
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

      final dated = find.textContaining('Sep 28');
      expect(dated, findsWidgets,
          reason: 'premise: a dated header rendered at all. If the format '
              'changed this test is measuring nothing.');

      // The header must show the full date, not an ellipsis.
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final s = t.data ?? '';
        if (!s.contains('Sep')) continue;
        expect(s, isNot(contains('…')), reason: 'header text itself is cut');
      }

      // Deliberately NOT asserting `RenderParagraph.didExceedMaxLines`.
      //
      // flutter_test substitutes a fallback font whose metrics are wider than
      // the real one, so that flag reads true here for a string the device
      // renders in full — verified on a 420dpi emulator, where the semantics
      // tree reports "Monday, Sep 28" complete. This repo's responsive
      // baselines already blame the same font for the same reason.
      //
      // What IS font-independent, and what the fix actually was, is which
      // formatter builds the label: the Long form ("Monday, September 28")
      // did not fit and was ellipsised on a real phone.
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((s) => s.contains('Sep'))
          .toList();

      expect(labels, contains('Monday, Sep 28'),
          reason: 'the abbreviated month is what makes the date fit. Labels '
              'were: $labels');
      expect(labels.any((s) => s.contains('September')), isFalse,
          reason: 'the Long form is the one that got cut to '
              '"Monday, Septemb…" on a 411dp phone. Labels were: $labels');
    });
  });
}
