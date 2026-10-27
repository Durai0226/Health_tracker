/// The notes under the gauge: late caffeine against bedtime, and a glass of water
/// after alcohol. The rules are in `drink_notes_test`; this is that they reach
/// the screen, can be put away for the day, and are never put to someone on a
/// fluid limit.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/services/drink_notes.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/widgets/drink_notes_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late db.AppDatabase database;

  // Saturday 14 March 2026, 17:00. The default bedtime is 22:30, so the cut-off
  // is 14:30.
  final now = DateTime(2026, 3, 14, 17, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await SleepService.resetForTesting();
    await WaterService.init();
  });

  tearDown(() async => database.close());

  BeverageType beverage(String id) =>
      BeverageType.defaultBeverages.firstWhere((b) => b.id == id);

  Future<void> drank(String id, DateTime at, {int ml = 200}) =>
      WaterService.addWaterLogForDate(
          date: at, amountMl: ml, beverage: beverage(id), time: at);

  group('the strip', () {
    Future<void> pumpStrip(
      WidgetTester tester, {
      LateCaffeine? late,
      bool chaser = false,
      VoidCallback? onWater,
      ValueChanged<DrinkNoteKind>? onDismiss,
    }) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DrinkNotesStrip(
            lateCaffeine: late,
            showChaser: chaser,
            onAddWater: onWater ?? () {},
            onDismiss: onDismiss ?? (_) {},
          ),
        ),
      ));
      await tester.pump();
    }

    final caffeine = LateCaffeine(
        drink: 'Coffee',
        cutoff: DateTime(2026, 3, 14, 14, 30),
        bedtime: DateTime(2026, 3, 14, 22, 30));

    testWidgets('says nothing when there is nothing to say', (tester) async {
      await pumpStrip(tester);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('late caffeine names the drink and both times', (tester) async {
      await pumpStrip(tester, late: caffeine);
      expect(
          find.text(
              'Coffee after 2:30 PM may affect your 10:30 PM bedtime.'),
          findsOneWidget);
      expect(find.text('+ Glass of water'), findsNothing);
    });

    testWidgets('the alcohol note offers the glass, and the offer works',
        (tester) async {
      var added = 0;
      await pumpStrip(tester, chaser: true, onWater: () => added++);
      expect(find.text('A glass of water alongside your drink helps.'),
          findsOneWidget);

      await tester.tap(find.text('+ Glass of water'));
      expect(added, 1);
    });

    testWidgets('each note puts itself away, and says which', (tester) async {
      final away = <DrinkNoteKind>[];
      await pumpStrip(tester,
          late: caffeine, chaser: true, onDismiss: away.add);

      expect(find.byTooltip('Dismiss'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Dismiss').first);
      await tester.tap(find.byTooltip('Dismiss').last);
      expect(away, [DrinkNoteKind.caffeine, DrinkNoteKind.alcohol]);
    });
  });

  group('on the water screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // layout is the responsive suite's job
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 400));
      } finally {
        FlutterError.onError = prev;
      }
    }

    void pinned(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name,
            (tester) => withClock(Clock.fixed(now), () => body(tester)));

    const coffeeNote = 'Coffee after 2:30 PM may affect your 10:30 PM bedtime.';

    pinned('a late coffee is noted against tonight\'s bedtime', (tester) async {
      await drank('coffee', DateTime(2026, 3, 14, 15, 30));
      await open(tester);
      expect(find.text(coffeeNote), findsOneWidget);
    });

    pinned('a morning coffee is not', (tester) async {
      await drank('coffee', DateTime(2026, 3, 14, 9, 0));
      await open(tester);
      expect(find.textContaining('may affect your'), findsNothing);
    });

    pinned('putting it away keeps it away for the day', (tester) async {
      await drank('coffee', DateTime(2026, 3, 14, 15, 30));
      await open(tester);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(coffeeNote), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await open(tester);
      expect(find.text(coffeeNote), findsNothing,
          reason: 'it was put away today, so it stays away on reopening');
    });

    pinned('yesterday\'s put-away note has nothing to do with today\'s coffee',
        (tester) async {
      await CleanStorageService.setAppPreference(
          'drink_notes_dismissed', ['2026-03-13:caffeine']);
      await drank('coffee', DateTime(2026, 3, 14, 15, 30));
      await open(tester);
      expect(find.text(coffeeNote), findsOneWidget);
    });

    pinned('a drink offers a glass of water, and taking it settles the note',
        (tester) async {
      await drank('beer', DateTime(2026, 3, 14, 16, 30), ml: 330);
      await open(tester);
      expect(find.text('A glass of water alongside your drink helps.'),
          findsOneWidget);

      await tester.tap(find.text('+ Glass of water'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      final today = WaterService.getTodayData().logs;
      expect(today.where((l) => l.beverageId == 'water' && l.amountMl == 250),
          hasLength(1));
      expect(find.text('A glass of water alongside your drink helps.'),
          findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });

    pinned('someone on a fluid limit is never told to drink more',
        (tester) async {
      await WaterService.saveProfile(HydrationProfile(
        id: 'profile',
        weightKg: 70,
        activityLevel: ActivityLevel.sedentary,
        fluidCeilingMl: 1500,
        createdAt: now,
      ));
      await drank('beer', DateTime(2026, 3, 14, 16, 30), ml: 330);
      await open(tester);
      expect(find.text('+ Glass of water'), findsNothing);
      expect(find.textContaining('alongside your drink'), findsNothing);
    });
  });
}
