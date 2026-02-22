import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/core/services/storage_service.dart';

void main() {
  group('Water Feature Integration Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await StorageService.init();
      await WaterService.init();
    });

    tearDown(() async {
      await WaterService.resetForTesting();
    });

    test('Water Service Initialization', () async {
      await WaterService.init();
      
      final beverages = WaterService.getAllBeverages();
      expect(beverages.isNotEmpty, true);
      
      final containers = WaterService.getAllContainers();
      expect(containers.isNotEmpty, true);
      
      final profile = WaterService.getProfile();
      expect(profile, isNotNull);
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
      final newGoal = 3000;
      
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

    test('Monthly Statistics', () async {
      await WaterService.init();
      
      final now = DateTime.now();
      final monthlyStats = WaterService.getMonthlyStats(now.year, now.month);
      
      expect(monthlyStats, isNotNull);
      expect(monthlyStats.year, now.year);
      expect(monthlyStats.month, now.month);
    });

    test('Achievements System', () async {
      await WaterService.init();
      
      final achievements = WaterService.getAchievements();
      
      expect(achievements, isNotNull);
      expect(achievements.achievements.isNotEmpty, true);
      expect(achievements.totalDrinks, greaterThanOrEqualTo(0));
    });

    test('Hydration Insights Generation', () async {
      await WaterService.init();
      
      final insights = WaterService.getInsights();
      
      expect(insights, isNotNull);
      expect(insights, isList);
    });

    test('CSV Export Functionality', () async {
      await WaterService.init();
      
      final waterBeverage = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(
        amountMl: 500,
        beverage: waterBeverage,
      );
      
      final csv = WaterService.exportToCsv();
      
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
      
      final csv = WaterService.exportDetailedCsv();
      
      expect(csv.isNotEmpty, true);
      expect(csv.contains('Beverage'), true);
      expect(csv.contains('Amount'), true);
    });

    test('Container Usage Count Update', () async {
      await WaterService.init();
      
      final container = WaterService.getContainer('glass_250ml');
      expect(container, isNotNull);
      
      final initialUsage = container!.usageCount;
      
      final waterBeverage = WaterService.getBeverage('water')!;
      await WaterService.addWaterLog(
        amountMl: 250,
        beverage: waterBeverage,
        container: container,
      );
      
      final updatedContainer = WaterService.getContainer('glass_250ml');
      expect(updatedContainer!.usageCount, initialUsage + 1);
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
      
      final coffeeBeverage = WaterService.getBeverage('coffee')!;
      final coffeeEffective = coffeeBeverage.getEffectiveHydration(200);
      expect(coffeeEffective, lessThan(200));
      
      final alcoholBeverage = WaterService.getBeverage('beer');
      if (alcoholBeverage != null) {
        final alcoholEffective = alcoholBeverage.getEffectiveHydration(330);
        expect(alcoholEffective, lessThanOrEqualTo(0));
      }
    });
  });
}
