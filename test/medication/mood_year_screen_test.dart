import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/vitals_theme.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_year_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final now = DateTime(2026, 6, 15, 12);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  Future<void> mood(DateTime at, int index, {String? id}) =>
      VitalsStorageService.saveMood(MoodEntry(
          id: id ?? 'm${at.microsecondsSinceEpoch}',
          moodIndex: index,
          takenAt: at,
          createdAt: at));

  /// A day's cell, by the label it announces. Found on the widget rather than in
  /// the merged semantics tree, where neighbouring squares fold into one node.
  Finder cell(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label);

  Future<void> open(WidgetTester tester, {Widget? screen}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: screen ?? const MoodYearScreen()));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('an empty year says so, and the legend still shows',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Nothing logged this year yet.'), findsOneWidget);
      expect(find.text('Great · 0'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('logged days are counted and the legend adds them up',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2026, 3, 4, 9), 0);
      await mood(DateTime(2026, 3, 4, 20), 0, id: 'b');
      await mood(DateTime(2026, 3, 5, 9), 0, id: 'c');
      await mood(DateTime(2026, 4, 1, 9), 3, id: 'd');
      await open(tester);
      expect(find.text('3 days logged'), findsOneWidget);
      expect(find.text('Great · 2'), findsOneWidget);
      expect(find.text('Bad · 1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('tapping a logged day says which day and how it felt',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2026, 3, 4, 9), 1);
      await open(tester);
      await tester.tap(cell('Mar 4, Good'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Mar 4, Good'), findsWidgets);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('a tap lands on the day under the finger, at both ends of the grid',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      // First and last column, first and a later row: a pitch that is off by
      // the gap, or a row taller than its squares, drifts to the wrong day
      // (or off the grid) by the time it reaches these.
      await mood(DateTime(2026, 1, 31, 9), 0);
      await mood(DateTime(2026, 6, 15, 9), 3, id: 'b');
      await mood(DateTime(2026, 3, 1, 9), 4, id: 'c');
      await open(tester);
      for (final label in ['Jan 31, Great', 'Jun 15, Bad', 'Mar 1, Terrible']) {
        await tester.tap(cell(label));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(label), findsWidgets, reason: 'tapped $label');
        await tester.pump(const Duration(seconds: 8));
      }
    });
  });

  testWidgets('a tap on an empty square says nothing', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2026, 3, 4, 9), 1);
      await open(tester);
      // Mar 5 is in the grid, right beside Mar 4, and unlogged.
      final at = tester.getCenter(cell('Mar 4, Good')) + const Offset(11, 0);
      await tester.tapAt(at);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Mar 5'), findsNothing);
      expect(find.text('Mar 4, Good'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('each square is the colour of how the day felt', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2026, 3, 4, 9), 0);
      await mood(DateTime(2026, 3, 5, 9), 2, id: 'b');
      await mood(DateTime(2026, 3, 6, 9), 4, id: 'c');
      await open(tester);
      // A square is a plain coloured box, which Container builds as a
      // ColoredBox; its `decoration` stays null.
      Color colorOf(String label) => tester
          .widget<ColoredBox>(find
              .descendant(of: cell(label), matching: find.byType(ColoredBox))
              .first)
          .color;

      expect(colorOf('Mar 4, Great'), VitalsColors.moodBand(false, 0));
      expect(colorOf('Mar 5, Okay'), VitalsColors.moodBand(false, 2));
      expect(colorOf('Mar 6, Terrible'), VitalsColors.moodBand(false, 4));
      expect(colorOf('Mar 4, Great'), isNot(colorOf('Mar 6, Terrible')));
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('a period day is marked and explained', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2026, 3, 4, 9), 2);
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(DateTime(2026, 3, 4)),
          date: DateTime(2026, 3, 4),
          flowIndex: 2));
      await open(tester);
      expect(cell('Mar 4, Okay, period'), findsOneWidget);
      expect(find.text('Period'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets("a family member's year never shows the account holder's period",
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(DateTime(2026, 3, 4)),
          date: DateTime(2026, 3, 4),
          flowIndex: 2));
      await ActiveProfileService().setActiveDependent('dep1');
      // Saved while the family member is active, so it is theirs.
      await mood(DateTime(2026, 3, 4, 9), 2);
      await open(tester);
      expect(cell('Mar 4, Okay'), findsOneWidget,
          reason: 'their own mood is there');
      expect(cell('Mar 4, Okay, period'), findsNothing);
      expect(find.text('Period'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('no period legend when there are no period days', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2026, 3, 4, 9), 2);
      await open(tester);
      expect(find.text('Period'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('years with data can be stepped through; others are not offered',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await mood(DateTime(2025, 12, 31, 9), 4);
      await open(tester);
      expect(find.text('2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Earlier year'));
      await tester.pump();
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('1 day logged'), findsOneWidget);
      expect(find.text('Terrible · 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Later year'));
      await tester.pump();
      expect(find.text('2026'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  testWidgets('the Mood screen has a way in', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester, screen: const MoodScreen());
      await tester.tap(find.byTooltip('Year in pixels'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MoodYearScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}
