/// On a prescribed fluid limit the gauge counts DOWN to it.
///
/// The ceiling was treated as a goal: the ring filled toward it, read "of 1500
/// ml", and called reaching it "Goal reached" with a tick. For someone on a
/// limit, what is left is the number that matters, and getting there is the line
/// not to cross, not a prize. And it measured hydration-adjusted intake, where a
/// limit is about the volume of liquid swallowed.
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
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/widgets/water_hero_gauge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('the gauge', () {
    Future<void> pump(
      WidgetTester tester, {
      required int current,
      int goal = 2500,
      int? limit,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 600);
      addTearDown(tester.view.reset);
      final progress = limit != null ? current / limit : current / goal;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: WaterHeroGauge(
                progress: progress,
                currentMl: current,
                goalMl: goal,
                limitMl: limit),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('with no limit it counts up to the goal, as ever',
        (tester) async {
      await pump(tester, current: 900);
      expect(find.text('900'), findsOneWidget);
      expect(find.text('of 2500 ml'), findsOneWidget);
      expect(find.text('36%'), findsOneWidget);
    });

    testWidgets('with no limit, reaching the goal still says so', (tester) async {
      await pump(tester, current: 2500);
      expect(find.text('Goal reached'), findsOneWidget);
    });

    testWidgets('on a limit it shows what is LEFT', (tester) async {
      await pump(tester, current: 600, limit: 1500);
      expect(find.text('900'), findsOneWidget);
      expect(find.text('ml left of 1500'), findsOneWidget);
      expect(find.text('40% of limit'), findsOneWidget);
      expect(find.text('Goal reached'), findsNothing);
    });

    testWidgets('right at the limit it is a limit, not a goal', (tester) async {
      // The goal IS the ceiling for someone on a limit (that is how the profile
      // reports it), which is exactly when "current >= goal" would read as won.
      await pump(tester, current: 1500, goal: 1500, limit: 1500);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Limit reached'), findsOneWidget);
      expect(find.text('Goal reached'), findsNothing,
          reason: 'reaching a ceiling is not an achievement');
    });

    testWidgets('past it, says by how much, and never goes negative',
        (tester) async {
      await pump(tester, current: 1720, limit: 1500);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Over by 220 ml'), findsOneWidget);
      expect(find.text('-220'), findsNothing);
    });

    testWidgets('a limit of zero is not a limit', (tester) async {
      await pump(tester, current: 900, limit: 0);
      expect(find.text('of 2500 ml'), findsOneWidget);
    });
  });

  group('on the water screen', () {
    late db.AppDatabase database;
    final now = DateTime(2026, 3, 14, 15, 0);

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

    Future<void> restrict(int? ceiling) => WaterService.saveProfile(
        HydrationProfile(
          id: 'profile',
          weightKg: 70,
          activityLevel: ActivityLevel.sedentary,
          fluidCeilingMl: ceiling,
          createdAt: now,
        ));

    Future<void> drank(String id, int ml) => WaterService.addWaterLogForDate(
        date: now, amountMl: ml, beverage: beverage(id), time: now);

    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2000);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const AquaWaterDashboard()));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 1500));
      } finally {
        FlutterError.onError = prev;
      }
    }

    void pinned(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name,
            (tester) => withClock(Clock.fixed(now), () => body(tester)));

    pinned('someone on a limit sees what is left, from what they swallowed',
        (tester) async {
      await restrict(1500);
      await drank('water', 600);
      await open(tester);

      expect(find.text('900'), findsOneWidget);
      expect(find.text('ml left of 1500'), findsOneWidget);
    });

    pinned('it counts the volume of a drink that hydrates less than it fills',
        (tester) async {
      await restrict(1500);
      // 500 ml of beer is credited as less than 500 ml of hydration, but it is
      // 500 ml of liquid, and the limit is about liquid.
      await drank('beer', 500);
      await open(tester);

      expect(find.text('1000'), findsOneWidget,
          reason: 'raw 500 ml swallowed against a 1500 ml limit');
    });

    pinned('past the limit it says so', (tester) async {
      await restrict(1500);
      await drank('water', 1700);
      await open(tester);

      expect(find.text('Over by 200 ml'), findsOneWidget);
    });

    pinned('someone with no limit is unchanged', (tester) async {
      await restrict(null);
      await drank('water', 600);
      await open(tester);

      expect(find.textContaining('ml left of'), findsNothing);
      expect(find.text('600'), findsWidgets);
    });
  });
}
