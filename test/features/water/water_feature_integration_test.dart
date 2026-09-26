import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/models/water_achievement.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';

/// Insight titles are stable; their ids carry a `_${DateTime.now().day}` suffix
/// from the real wall clock, so matching on the id would be flaky.
List<String> _titles(List<HydrationInsight> insights) =>
    insights.map((i) => i.title).toList();

/// These 19 tests were skipped at group level with the reason "Integration test
/// requires a device or emulator: it initializes the Drift DB". That was not
/// true — `AppDatabase.forTesting(NativeDatabase.memory())` runs Drift headless,
/// which is how `test/features/water/water_history_window_test.dart` has always
/// worked. The suite only needed that harness (and per-test isolation) instead
/// of `StorageService.init()`, which does need path_provider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  group('Water Feature Integration Tests', () {
    setUp(() async {
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      db.AppDatabase.setInstanceForTesting(database);
      WaterService.clearInMemory();
      await WaterService.resetForTesting();
      await WaterService.init();
    });

    tearDown(() async {
      await WaterService.resetForTesting();
      await database.close();
    });

    // Was: call init() a second time and assert the three default lists are
    // non-empty and the (non-nullable) profile is non-null. Those are
    // properties of the `const` default tables, not of init() — init()'s second
    // call is a no-op (`if (_isInitialized) return`), so the test passed with
    // every line of the Drift-loading body deleted. What init() actually exists
    // to do is rehydrate a RESTART from Drift, which is what this drives.
    test('init() reloads days, profile, custom drinks and cups from Drift',
        () async {
      final water = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(amountMl: 400, beverage: water);
      await WaterService.addCustomContainer(WaterContainer(
        id: 'flask',
        name: 'Steel flask',
        capacityMl: 900,
        emoji: '🥤',
        isDefault: false,
      ));
      await WaterService.addCustomBeverage(BeverageType(
        id: 'kombucha',
        name: 'Kombucha',
        emoji: '🫙',
      ));
      await WaterService.saveProfile(WaterService.getProfile()
          .copyWith(customGoalMl: 2800, useCustomGoal: true));

      // Cold start against the SAME database: drop every scrap of static state
      // (which is what a process restart does) and run the real init().
      await WaterService.resetForTesting();
      expect(WaterService.getBeverage('kombucha'), isNull,
          reason: 'sanity check on the test itself — the in-memory state really '
              'was dropped, so what comes back below came back from Drift');

      await WaterService.init();

      expect(WaterService.getTodayData().totalIntakeMl, 400);
      expect(WaterService.getTodayData().logs.single.amountMl, 400,
          reason: 'the day row and its logs are two separate reads; loading '
              'only the row would still show the right total');
      expect(WaterService.getContainer('flask')?.capacityMl, 900);
      expect(WaterService.getBeverage('kombucha')?.name, 'Kombucha');
      expect(WaterService.getProfile().effectiveGoalMl, 2800);

      // init() persists nothing here — it MERGES what Drift holds with the
      // built-in defaults, filtering by id. Drop that filter and every default
      // appears twice after the first sync writes them back.
      final containerIds = WaterService.getAllContainers().map((c) => c.id);
      expect(containerIds.toSet().length, containerIds.length,
          reason: 'a default must not be re-added as a "custom" container');
      expect(containerIds, contains('glass'));
      final beverageIds = WaterService.getAllBeverages().map((b) => b.id);
      expect(beverageIds.toSet().length, beverageIds.length,
          reason: 'a default must not be re-added as a "custom" beverage');
      expect(beverageIds, contains('water'));
    });

    test('Add Water Log - Basic Water', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water');
      expect(waterBeverage, isNotNull);
      
      final beforeData = WaterService.getTodayData();
      final beforeTotal = beforeData.totalIntakeMl;
      
      final newData = await WaterService.addWaterLog(
        amountMl: 250,
        beverage: waterBeverage!,
      );
      
      expect(newData.totalIntakeMl, beforeTotal + 250);
      expect(newData.effectiveHydrationMl, beforeTotal + 250);
      expect(newData.logs.length, beforeData.logs.length + 1);
    });

    test('Add Water Log - Coffee with Caffeine', () async {
      await WaterService.init();
      
      final coffeeBeverage = WaterService.getBeverage('coffee');
      expect(coffeeBeverage, isNotNull);
      
      final beforeData = WaterService.getTodayData();
      final beforeCaffeine = beforeData.totalCaffeineMg;
      
      final newData = await WaterService.addWaterLog(
        amountMl: 200,
        beverage: coffeeBeverage!,
      );
      
      expect(newData.totalIntakeMl, beforeData.totalIntakeMl + 200);
      expect(newData.totalCaffeineMg, greaterThan(beforeCaffeine));
      expect(newData.logs.last.caffeineAmount, greaterThan(0));
    });

    test('Add Water Log - Alcoholic Beverage', () async {
      await WaterService.init();
      
      final beerBeverage = WaterService.getBeverage('beer');
      expect(beerBeverage, isNotNull);
      expect(beerBeverage!.isAlcoholic, true);
      
      final beforeData = WaterService.getTodayData();
      final beforeAlcohol = beforeData.alcoholicDrinksCount;
      
      final newData = await WaterService.addWaterLog(
        amountMl: 330,
        beverage: beerBeverage,
      );
      
      expect(newData.alcoholicDrinksCount, beforeAlcohol + 1);
      expect(newData.logs.last.isAlcoholic, true);
    });

    test('Remove Water Log', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      
      final addedData = await WaterService.addWaterLog(
        amountMl: 250,
        beverage: waterBeverage,
      );
      
      final logId = addedData.logs.last.id;
      final beforeTotal = addedData.totalIntakeMl;
      
      await WaterService.removeWaterLog(logId);
      
      final afterData = WaterService.getTodayData();
      expect(afterData.totalIntakeMl, beforeTotal - 250);
    });

    test('Daily Goal Management', () async {
      await WaterService.init();
      
      final profile = WaterService.getProfile();
      const newGoal = 3000;
      
      final updatedProfile = profile.copyWith(
        customGoalMl: newGoal,
        useCustomGoal: true,
      );
      
      await WaterService.saveProfile(updatedProfile);
      
      final savedProfile = WaterService.getProfile();
      expect(savedProfile.customGoalMl, newGoal);
      expect(savedProfile.effectiveGoalMl, newGoal);
    });

    test('Goal Reached Detection', () async {
      await WaterService.init();
      
      final profile = WaterService.getProfile();
      final updatedProfile = profile.copyWith(
        customGoalMl: 500,
        useCustomGoal: true,
      );
      await WaterService.saveProfile(updatedProfile);
      
      final waterBeverage = WaterService.getBeverage('water')!;
      
      final newData = await WaterService.addWaterLog(
        amountMl: 500,
        beverage: waterBeverage,
      );
      
      expect(newData.goalReached, true);
      expect(newData.progress, greaterThanOrEqualTo(1.0));
      expect(newData.goalReachedAt, isNotNull);
    });

    test('Custom Container Creation', () async {
      await WaterService.init();
      
      final customContainer = WaterContainer(
        id: 'test_bottle',
        name: 'Test Bottle',
        capacityMl: 750,
        emoji: '🧴',
        isDefault: false,
      );
      
      await WaterService.addCustomContainer(customContainer);
      
      final retrieved = WaterService.getContainer('test_bottle');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test Bottle');
      expect(retrieved.capacityMl, 750);
    });

    test('Beverage Usage Tracking', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      
      await WaterService.addWaterLog(
        amountMl: 250,
        beverage: waterBeverage,
      );
      
      await WaterService.addWaterLog(
        amountMl: 250,
        beverage: waterBeverage,
      );
      
      final favorites = WaterService.getFavoriteBeverages(limit: 3);
      expect(favorites.any((b) => b.id == 'water'), true);
    });

    test('Weekly Statistics', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(
        amountMl: 1000,
        beverage: waterBeverage,
      );
      
      final weeklyStats = WaterService.getWeeklyStats();
      
      expect(weeklyStats['totalMl'], greaterThan(0));
      expect(weeklyStats['daysTracked'], greaterThan(0));
      expect(weeklyStats['averageMl'], greaterThan(0));
    });

    // Was: seed nothing, then assert the year and month that were just passed
    // in come back out, plus `isNotNull` on a non-nullable return. Every
    // aggregate the screen actually renders — days tracked, totals, best/worst
    // day, the beverage breakdown — went unasserted, so the whole accumulation
    // loop could be deleted and this still passed.
    test('Monthly Statistics aggregate only the month that was logged',
        () async {
      final water = WaterService.getBeverage('water')!;
      final coffee = WaterService.getBeverage('coffee')!;

      // A fixed "today" inside May: getMonthlyStats reads the warm day cache,
      // and a wall-clock run near a month boundary would otherwise decide
      // which days are in range.
      await withClock(Clock.fixed(DateTime(2026, 5, 20, 12)), () async {
        await WaterService.addWaterLogForDate(
            date: DateTime(2026, 5, 3), amountMl: 1000, beverage: water);
        await WaterService.addWaterLogForDate(
            date: DateTime(2026, 5, 4), amountMl: 500, beverage: water);
        await WaterService.addWaterLogForDate(
            date: DateTime(2026, 5, 4), amountMl: 200, beverage: coffee);
        // One drink in the NEXT month, which must not leak into May's numbers.
        await WaterService.addWaterLogForDate(
            date: DateTime(2026, 6, 1), amountMl: 3000, beverage: water);

        final may = WaterService.getMonthlyStats(2026, 5);
        expect(may.year, 2026);
        expect(may.month, 5);
        expect(may.daysTracked, 2,
            reason: 'two days were logged; 1 June is a different month');
        // Both drinks count at 100% hydration (coffee included — see the
        // Killer 2014 note on BeverageType), so 3 May is 1000 and 4 May is 700.
        expect(may.totalIntakeMl, 1700);
        expect(may.averageDailyMl, 850);
        expect(may.bestDayMl, 1000);
        expect(may.worstDayMl, 700);
        expect(may.daysGoalMet, 0,
            reason: 'neither day reaches the default 3152 ml goal');
        // 40 mg per 100 ml of coffee, one 200 ml cup.
        expect(may.totalCaffeineMg, 80);
        expect(may.alcoholicDrinksTotal, 0);
        expect(may.beverageBreakdown, {'water': 1500, 'coffee': 200},
            reason: 'the breakdown is by drink VOLUME, summed per beverage id');

        // A month with nothing in it must report nothing — not a plausible
        // zero-filled shape that reads as "you drank nothing in February".
        final february = WaterService.getMonthlyStats(2026, 2);
        expect(february.month, 2);
        expect(february.daysTracked, 0);
        expect(february.totalIntakeMl, 0);
        expect(february.beverageBreakdown, isEmpty);
      });
    });

    // Was: `isNotNull` on a non-nullable return, `isNotEmpty` on the const
    // definition table, and `totalDrinks >= 0` on an unsigned count. Nothing was
    // logged, so the evaluation pass was never exercised at all.
    test('Achievements are recomputed from the logged history', () async {
      final water = WaterService.getBeverage('water')!;

      WaterAchievement badge(String id) => WaterService.getAchievements()
          .achievements
          .firstWhere((a) => a.id == id);

      expect(WaterService.getAchievements().totalDrinks, 0);
      expect(WaterService.getAchievements().totalMl, 0);
      expect(badge('volume_10').isUnlocked, isFalse);

      // 9 litres — one litre short of the 10 L 'First Steps' threshold.
      for (var i = 0; i < 9; i++) {
        await WaterService.addWaterLog(amountMl: 1000, beverage: water);
      }
      expect(WaterService.getAchievements().totalDrinks, 9);
      expect(WaterService.getAchievements().totalMl, 9000);
      expect(badge('volume_10').currentValue, 9000,
          reason: 'progress must track before the unlock, or the ring on the '
              'badge is stuck at zero until the moment it fills');
      expect(badge('volume_10').isUnlocked, isFalse,
          reason: '9 L must not unlock a badge that says 10 L');

      await WaterService.addWaterLog(amountMl: 1000, beverage: water);
      expect(WaterService.getAchievements().totalMl, 10000);
      expect(badge('volume_10').isUnlocked, isTrue);
      expect(badge('volume_10').unlockedAt, isNotNull);
      expect(badge('volume_50').isUnlocked, isFalse,
          reason: 'the next tier is 50 L and must not come along for the ride');
      expect(badge('volume_50').currentValue, 10000);

      // The evaluation pass persists what it computed, and its own doc warns
      // that a failed read must never overwrite good stored values with zeros.
      // A restart is where that would show.
      await WaterService.resetForTesting();
      await WaterService.init();
      expect(WaterService.getAchievements().totalMl, 10000);
      expect(WaterService.getAchievements().totalDrinks, 10);
      expect(badge('volume_10').isUnlocked, isTrue,
          reason: 'an unlocked badge must survive a restart');
    });

    // Was: `isNotNull` and `isList` on a `List<HydrationInsight>` return type —
    // both true of the empty list the un-seeded call returns, and true however
    // wrong the generator is.
    test('Insights are generated from the day that was actually logged',
        () async {
      // Midday: outside the morning (6–9), afternoon (14–16) and evening (18+)
      // windows, so only the data-driven branches can fire.
      await withClock(Clock.fixed(DateTime(2026, 5, 20, 12)), () async {
        expect(WaterService.getInsights(), isEmpty,
            reason: 'nothing logged and no time window open — an insight here '
                'would be a claim about data that does not exist');

        // 40 mg caffeine per 100 ml, and the warning threshold is *above*
        // 400 mg. One litre is exactly 400 mg, i.e. still under it.
        final coffee = WaterService.getBeverage('coffee')!;
        await WaterService.addWaterLog(amountMl: 1000, beverage: coffee);
        expect(WaterService.getTodayData().totalCaffeineMg, 400);
        expect(_titles(WaterService.getInsights()),
            isNot(contains('High Caffeine Intake')),
            reason: 'the threshold is > 400 mg, so 400 mg must not trip it');

        await WaterService.addWaterLog(amountMl: 100, beverage: coffee);
        final caffeineWarning = WaterService.getInsights()
            .firstWhere((i) => i.title == 'High Caffeine Intake');
        expect(caffeineWarning.description, contains('440mg'),
            reason: 'the number in the copy must be the number in the day');
        expect(caffeineWarning.type, InsightType.warning);

        expect(_titles(WaterService.getInsights()),
            isNot(contains('Stay Hydrated')));
        final beer = WaterService.getBeverage('beer')!;
        await WaterService.addWaterLog(amountMl: 330, beverage: beer);
        expect(_titles(WaterService.getInsights()), contains('Stay Hydrated'),
            reason: 'the alcohol tip is driven by the day\'s alcoholic count');
      });
    });

    test('a prescribed fluid ceiling suppresses the encouraging insights',
        () async {
      // 19:00 with the goal met is the "Goal Achieved!" branch. Under a fluid
      // RESTRICTION that sentence congratulates someone for breaching a
      // clinical limit, which is the whole reason isRestricted exists.
      await withClock(Clock.fixed(DateTime(2026, 5, 20, 19)), () async {
        final water = WaterService.getBeverage('water')!;
        await WaterService.saveProfile(WaterService.getProfile()
            .copyWith(customGoalMl: 1000, useCustomGoal: true));
        await WaterService.addWaterLog(amountMl: 1000, beverage: water);
        final coffee = WaterService.getBeverage('coffee')!;
        await WaterService.addWaterLog(amountMl: 1100, beverage: coffee);

        // Positive control: without a ceiling the celebration DOES fire, so the
        // absence asserted below is the guard working rather than the whole
        // generator being dead.
        expect(_titles(WaterService.getInsights()), contains('Goal Achieved!'));

        await WaterService.saveProfile(
            WaterService.getProfile().copyWith(fluidCeilingMl: 1000));
        expect(WaterService.getProfile().isRestricted, isTrue);

        final restricted = _titles(WaterService.getInsights());
        expect(restricted, isNot(contains('Goal Achieved!')),
            reason: 'under a ceiling, hitting the number is a breach, not an '
                'achievement');
        expect(restricted, contains('High Caffeine Intake'),
            reason: 'a safety warning is not encouragement — suppressing the '
                'celebration must not silence the whole feed');
      });
    });

    test('CSV Export Functionality', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(
        amountMl: 500,
        beverage: waterBeverage,
      );
      
      final csv = await WaterService.exportToCsv();
      
      expect(csv.isNotEmpty, true);
      expect(csv.contains('Date'), true);
      expect(csv.contains('Total Intake'), true);
    });

    test('Detailed CSV Export', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(
        amountMl: 500,
        beverage: waterBeverage,
      );
      
      final csv = await WaterService.exportDetailedCsv();
      
      expect(csv.isNotEmpty, true);
      expect(csv.contains('Beverage'), true);
      expect(csv.contains('Amount'), true);
    });

    // The id here was 'glass_250ml', which has never existed —
    // WaterContainer.defaultContainers calls it 'glass'. Nobody noticed because
    // the whole group was skipped. Usage counts are now derived from the logs,
    // so this asserts real behaviour rather than a column nothing wrote.
    test('Container Usage Count Update', () async {
      final container = WaterService.getContainer('glass');
      expect(container, isNotNull);

      final initialUsage = container!.usageCount;

      final waterBeverage = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(
        amountMl: 250,
        beverage: waterBeverage,
        container: container,
      );

      final updatedContainer = WaterService.getContainer('glass');
      expect(updatedContainer!.usageCount, initialUsage + 1);
      expect(updatedContainer.lastUsed, isNotNull,
          reason: 'lastUsed must come from the log time');
    });

    test('frequent containers are ranked by real use, not declared order',
        () async {
      final water = WaterService.getBeverage('water')!;
      // 'jug' is last in the declared list, so it can only lead by usage.
      final jug = WaterService.getContainer('jug')!;
      for (var i = 0; i < 3; i++) {
        await WaterService.addWaterLog(
            amountMl: 500, beverage: water, container: jug);
      }

      expect(WaterService.getFrequentContainers().first.id, 'jug');
      expect(WaterService.containerUseCount('jug'), 3);
    });

    test('favourite beverages are ranked by real use, not declared order',
        () async {
      // 'herbal_tea' sits well down the declared list.
      final tea = WaterService.getBeverage('herbal_tea')!;
      for (var i = 0; i < 4; i++) {
        await WaterService.addWaterLog(amountMl: 200, beverage: tea);
      }

      expect(WaterService.getFavoriteBeverages().first.id, 'herbal_tea');
      expect(WaterService.beverageUseCount('herbal_tea'), 4);
    });

    test('Hydration Profile - Weight Based Goal', () async {
      await WaterService.init();
      
      final profile = WaterService.getProfile();
      final updatedProfile = profile.copyWith(
        weightKg: 70,
        activityLevel: ActivityLevel.moderate,
        useCustomGoal: false,
      );
      
      await WaterService.saveProfile(updatedProfile);
      
      final savedProfile = WaterService.getProfile();
      expect(savedProfile.effectiveGoalMl, greaterThan(0));
      expect(savedProfile.effectiveGoalMl, greaterThan(2000));
    });

    test('Multiple Logs Same Day', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      
      await WaterService.addWaterLog(amountMl: 250, beverage: waterBeverage);
      await WaterService.addWaterLog(amountMl: 300, beverage: waterBeverage);
      await WaterService.addWaterLog(amountMl: 200, beverage: waterBeverage);
      
      final todayData = WaterService.getTodayData();
      expect(todayData.logs.length, greaterThanOrEqualTo(3));
      expect(todayData.totalIntakeMl, greaterThanOrEqualTo(750));
    });

    test('Effective Hydration Calculation', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      expect(waterBeverage.getEffectiveHydration(250), 250);
      
      // Coffee counts in full — see the Killer 2014 / BHI note on
      // BeverageType. This used to assert `< 200`.
      final coffeeBeverage = WaterService.getBeverage('coffee')!;
      expect(coffeeBeverage.getEffectiveHydration(200), 200);

      // And beer is net hydrating, not net negative: the deduction is derived
      // from ethanol dose, and 5% ABV does not cost more fluid than a 330 ml
      // drink supplies. Only spirits go below zero.
      final beer = WaterService.getBeverage('beer')!;
      expect(beer.getEffectiveHydration(330), greaterThan(0));

      final spirits = WaterService.getBeverage('spirits')!;
      expect(spirits.getEffectiveHydration(50), lessThan(0));
    });
  });
}
