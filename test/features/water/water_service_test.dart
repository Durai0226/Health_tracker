import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';

import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/models/water_achievement.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

import 'dart:io';

void main() {
  group('WaterService Tests', () {
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for Hive
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);
      
      // Register Adapters
      // Register Adapters
      if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(BeverageTypeAdapter());
      if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(WaterContainerAdapter());
      if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(ActivityLevelAdapter());
      if (!Hive.isAdapterRegistered(23)) Hive.registerAdapter(ClimateTypeAdapter());
      if (!Hive.isAdapterRegistered(24)) Hive.registerAdapter(HydrationProfileAdapter());
      if (!Hive.isAdapterRegistered(25)) Hive.registerAdapter(AchievementTypeAdapter());
      if (!Hive.isAdapterRegistered(26)) Hive.registerAdapter(WaterAchievementAdapter());
      if (!Hive.isAdapterRegistered(27)) Hive.registerAdapter(UserAchievementsAdapter());
      if (!Hive.isAdapterRegistered(28)) Hive.registerAdapter(EnhancedWaterLogAdapter());
      if (!Hive.isAdapterRegistered(29)) Hive.registerAdapter(DailyWaterDataAdapter());

      await WaterService.init();
    });

    tearDown(() async {
      await WaterService.resetForTesting();
      await Hive.deleteFromDisk();
      await tempDir.delete(recursive: true);
    });

    test('getDailyGoal returns correct default or calculated goal', () {
      final goal = WaterService.getDailyGoal();
      expect(goal, greaterThan(0));
    });

    test('addWaterLog adds a log and updates daily totals', () async {
      final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');
      
      final dayData = await WaterService.addWaterLog(
        amountMl: 250,
        beverage: water,
      );

      expect(dayData.logs.length, 1);
      expect(dayData.totalIntakeMl, 250);
      expect(dayData.effectiveHydrationMl, 250); // Water is 100% hydration

      // Verify persistence
      final todayData = WaterService.getTodayData();
      expect(todayData.logs.length, 1);
      expect(todayData.totalIntakeMl, 250);
    });

    test('addWaterLog with coffee updates caffeine and hydration correctly', () async {
      final coffee = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'coffee');
      // Coffee might have different hydration factor, e.g., 85% or 100% depending on implementation
      // And caffeine content
      
      final dayData = await WaterService.addWaterLog(
        amountMl: 200,
        beverage: coffee,
      );

      expect(dayData.logs.length, 1);
      expect(dayData.totalIntakeMl, 200);
      expect(dayData.totalCaffeineMg, greaterThan(0));
      
      // Check effective hydration
      final expectedHydration = (200 * coffee.hydrationPercent / 100).round();
      expect(dayData.effectiveHydrationMl, expectedHydration);
    });

    test('removeWaterLog correctly updates totals', () async {
      final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');
      
      // Add log
      final dayData = await WaterService.addWaterLog(
        amountMl: 500,
        beverage: water,
      );
      final logId = dayData.logs.first.id;

      // Remove log
      await WaterService.removeWaterLog(logId);

      final updatedData = WaterService.getTodayData();
      expect(updatedData.logs, isEmpty);
      expect(updatedData.totalIntakeMl, 0);
      expect(updatedData.effectiveHydrationMl, 0);
    });
  });
}
