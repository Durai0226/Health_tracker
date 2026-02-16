import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/models/water_achievement.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/models/hydration_challenge.dart';

void main() {
  group('BeverageType Tests', () {
    test('default beverages list is not empty', () {
      expect(BeverageType.defaultBeverages, isNotEmpty);
    });

    test('water has 100% hydration', () {
      final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');
      expect(water.hydrationPercent, 100);
      expect(water.hasCaffeine, false);
      expect(water.isAlcoholic, false);
    });

    test('coffee has caffeine', () {
      final coffee = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'coffee');
      expect(coffee.hasCaffeine, true);
      expect(coffee.caffeinePerMl, greaterThan(0));
    });

    test('beer is alcoholic with reduced hydration', () {
      final beer = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'beer');
      expect(beer.isAlcoholic, true);
      expect(beer.hydrationPercent, lessThan(100));
    });

    test('getEffectiveHydration calculates correctly', () {
      final water = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'water');
      expect(water.getEffectiveHydration(250), 250);

      final coffee = BeverageType.defaultBeverages.firstWhere((b) => b.id == 'coffee');
      final effectiveCoffee = coffee.getEffectiveHydration(250);
      expect(effectiveCoffee, lessThan(250));
      expect(effectiveCoffee, (250 * coffee.hydrationPercent / 100).round());
    });

    test('beverage copyWith works correctly', () {
      final water = BeverageType.defaultBeverages.first;
      final modified = water.copyWith(name: 'Test Water', hydrationPercent: 95);
      
      expect(modified.name, 'Test Water');
      expect(modified.hydrationPercent, 95);
      expect(modified.id, water.id);
    });
  });

  group('WaterContainer Tests', () {
    test('default containers list is not empty', () {
      expect(WaterContainer.defaultContainers, isNotEmpty);
    });

    test('containers have valid capacities', () {
      for (final container in WaterContainer.defaultContainers) {
        expect(container.capacityMl, greaterThan(0));
        expect(container.name, isNotEmpty);
        expect(container.emoji, isNotEmpty);
      }
    });

    test('container copyWith works correctly', () {
      final container = WaterContainer.defaultContainers.first;
      final modified = container.copyWith(
        name: 'Custom Cup',
        capacityMl: 500,
      );
      
      expect(modified.name, 'Custom Cup');
      expect(modified.capacityMl, 500);
      expect(modified.id, container.id);
    });
  });

  group('EnhancedWaterLog Tests', () {
    test('creates log with correct values', () {
      final log = EnhancedWaterLog(
        id: 'test-log',
        time: DateTime.now(),
        amountMl: 250,
        effectiveHydrationMl: 200,
        beverageId: 'coffee',
        beverageName: 'Coffee',
        beverageEmoji: '☕',
        hydrationPercent: 80,
        caffeineAmount: 95,
        isAlcoholic: false,
      );

      expect(log.amountMl, 250);
      expect(log.effectiveHydrationMl, 200);
      expect(log.caffeineAmount, 95);
      expect(log.isAlcoholic, false);
    });

    test('log with note stores note correctly', () {
      final log = EnhancedWaterLog(
        id: 'test-log',
        time: DateTime.now(),
        amountMl: 250,
        effectiveHydrationMl: 250,
        beverageId: 'water',
        beverageName: 'Water',
        beverageEmoji: '💧',
        hydrationPercent: 100,
        note: 'After workout',
      );

      expect(log.note, 'After workout');
    });
  });

  group('DailyWaterData Tests', () {
    test('creates daily data with correct defaults', () {
      final data = DailyWaterData(
        id: 'test-day',
        date: DateTime.now(),
        dailyGoalMl: 2500,
      );

      expect(data.totalIntakeMl, 0);
      expect(data.effectiveHydrationMl, 0);
      expect(data.logs, isEmpty);
      expect(data.goalReached, false);
    });

    test('progress calculation is correct', () {
      final data = DailyWaterData(
        id: 'test-day',
        date: DateTime.now(),
        dailyGoalMl: 2500,
        effectiveHydrationMl: 1250,
      );

      expect(data.progress, 0.5);
    });

    test('drinksCount returns correct count', () {
      final logs = [
        EnhancedWaterLog(
          id: '1',
          time: DateTime.now(),
          amountMl: 250,
          effectiveHydrationMl: 250,
          beverageId: 'water',
          beverageName: 'Water',
          beverageEmoji: '💧',
          hydrationPercent: 100,
        ),
        EnhancedWaterLog(
          id: '2',
          time: DateTime.now(),
          amountMl: 200,
          effectiveHydrationMl: 160,
          beverageId: 'coffee',
          beverageName: 'Coffee',
          beverageEmoji: '☕',
          hydrationPercent: 80,
          caffeineAmount: 76,
        ),
      ];

      final data = DailyWaterData(
        id: 'test-day',
        date: DateTime.now(),
        dailyGoalMl: 2500,
        logs: logs,
      );

      expect(data.drinksCount, 2);
    });
  });

  group('HydrationProfile Tests', () {
    test('calculated goal is reasonable', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 70,
        heightCm: 175,
        age: 30,
        activityLevel: ActivityLevel.moderate,
        climate: ClimateType.moderate,
      );

      // Should be at least 2000ml for a healthy adult
      expect(profile.calculatedGoalMl, greaterThanOrEqualTo(2000));
      // Should not exceed 5000ml
      expect(profile.calculatedGoalMl, lessThanOrEqualTo(5000));
    });

    test('high activity increases water goal', () {
      final sedentary = HydrationProfile(
        id: 'test1',
        weightKg: 70,
        activityLevel: ActivityLevel.sedentary,
      );

      final active = HydrationProfile(
        id: 'test2',
        weightKg: 70,
        activityLevel: ActivityLevel.veryActive,
      );

      expect(active.calculatedGoalMl, greaterThan(sedentary.calculatedGoalMl));
    });

    test('hot climate increases water goal', () {
      final temperate = HydrationProfile(
        id: 'test1',
        weightKg: 70,
        climate: ClimateType.moderate,
      );

      final hot = HydrationProfile(
        id: 'test2',
        weightKg: 70,
        climate: ClimateType.hot,
      );

      expect(hot.calculatedGoalMl, greaterThan(temperate.calculatedGoalMl));
    });

    test('custom goal overrides calculated when useCustomGoal is true', () {
      final profile = HydrationProfile(
        id: 'test',
        weightKg: 70,
        customGoalMl: 3000,
        useCustomGoal: true,
      );

      // When useCustomGoal is true, customGoalMl should be used
      expect(profile.customGoalMl, 3000);
    });
  });

  group('WaterAchievement Tests', () {
    test('all achievements list is not empty', () {
      expect(WaterAchievement.allAchievements, isNotEmpty);
    });

    test('achievement progress calculation is correct', () {
      final achievement = WaterAchievement(
        id: 'test',
        title: 'Test Achievement',
        description: 'Test description',
        emoji: '🏆',
        type: AchievementType.streak,
        targetValue: 10,
        currentValue: 5,
        points: 50,
      );

      expect(achievement.progress, 0.5);
      expect(achievement.isUnlocked, false);
    });

    test('unlocked achievement has progress 1.0', () {
      final achievement = WaterAchievement(
        id: 'test',
        title: 'Test Achievement',
        description: 'Test description',
        emoji: '🏆',
        type: AchievementType.streak,
        targetValue: 10,
        currentValue: 10,
        isUnlocked: true,
        points: 50,
      );

      expect(achievement.progress, 1.0);
      expect(achievement.isUnlocked, true);
    });

    test('tier integer values map correctly', () {
      final bronzeAchievement = WaterAchievement(
        id: 'test',
        title: 'Test',
        description: 'Test',
        emoji: '🏆',
        type: AchievementType.streak,
        targetValue: 3,
        tier: 1, // Bronze
        points: 10,
      );

      expect(bronzeAchievement.tier, 1);
      expect(bronzeAchievement.tierName, 'Bronze');
    });
  });

  group('UserAchievements Tests', () {
    test('new user has zero points', () {
      final userAchievements = UserAchievements(id: 'user');
      expect(userAchievements.totalPoints, 0);
    });

    test('level calculation is correct', () {
      final achievements = [
        WaterAchievement(
          id: 'a1',
          title: 'Test 1',
          description: 'Test',
          emoji: '🏆',
          type: AchievementType.streak,
          targetValue: 3,
          currentValue: 3,
          isUnlocked: true,
          points: 50,
        ),
        WaterAchievement(
          id: 'a2',
          title: 'Test 2',
          description: 'Test',
          emoji: '🏆',
          type: AchievementType.totalVolume,
          targetValue: 1000,
          currentValue: 1000,
          isUnlocked: true,
          points: 50,
        ),
      ];

      final userAchievements = UserAchievements(
        id: 'user',
        achievements: achievements,
      );

      expect(userAchievements.totalPoints, 100);
      expect(userAchievements.level, 2); // 100 points / 100 per level = level 2
    });
  });

  group('HydrationChallenge Tests', () {
    test('available challenges list is not empty', () {
      expect(HydrationChallenge.availableChallenges, isNotEmpty);
    });

    test('challenge progress calculation is correct', () {
      final challenge = HydrationChallenge(
        id: 'test',
        title: 'Test Challenge',
        description: 'Test description',
        emoji: '🏆',
        targetValue: 10,
        currentProgress: 5,
      );

      expect(challenge.progressPercent, 0.5);
      expect(challenge.isCompleted, false);
    });

    test('days remaining calculation is correct', () {
      final now = DateTime.now();
      final challenge = HydrationChallenge(
        id: 'test',
        title: 'Test Challenge',
        description: 'Test description',
        emoji: '🏆',
        targetValue: 7,
        durationDays: 7,
        startDate: now,
        endDate: now.add(const Duration(days: 3)),
      );

      expect(challenge.daysRemaining, 4); // 3 days + 1
    });

    test('expired challenge is detected', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final challenge = HydrationChallenge(
        id: 'test',
        title: 'Test Challenge',
        description: 'Test description',
        emoji: '🏆',
        targetValue: 7,
        endDate: past,
      );

      expect(challenge.isExpired, true);
    });

    test('difficulty labels are correct', () {
      final easyChallenge = HydrationChallenge(
        id: 'test',
        title: 'Easy Challenge',
        description: 'Test',
        emoji: '🏆',
        difficulty: ChallengeDifficulty.easy,
        targetValue: 3,
      );

      expect(easyChallenge.difficultyLabel, 'Easy');
    });

    test('challenge copyWith works correctly', () {
      final challenge = HydrationChallenge.availableChallenges.first;
      final started = challenge.copyWith(
        isActive: true,
        startDate: DateTime.now(),
        currentProgress: 1,
      );

      expect(started.isActive, true);
      expect(started.currentProgress, 1);
      expect(started.id, challenge.id);
      expect(started.title, challenge.title);
    });
  });

  group('MonthlyWaterStats Tests', () {
    test('creates monthly stats with correct values', () {
      final stats = MonthlyWaterStats(
        year: 2024,
        month: 1,
        totalIntakeMl: 75000,
        daysTracked: 30,
        daysGoalMet: 25,
        averageDailyMl: 2500,
        currentStreak: 10,
        longestStreak: 15,
      );

      expect(stats.totalIntakeMl, 75000);
      expect(stats.daysTracked, 30);
      expect(stats.completionRate, 25 / 30);
    });
  });

  group('HydrationInsight Tests', () {
    test('creates insight with required fields', () {
      final insight = HydrationInsight(
        id: 'test',
        title: 'Great job!',
        description: 'You are staying hydrated',
        emoji: '💧',
        type: InsightType.tip,
      );

      expect(insight.title, 'Great job!');
      expect(insight.emoji, '💧');
      expect(insight.type, InsightType.tip);
    });

    test('different insight types are available', () {
      expect(InsightType.values, contains(InsightType.tip));
      expect(InsightType.values, contains(InsightType.warning));
      expect(InsightType.values, contains(InsightType.achievement));
      expect(InsightType.values, contains(InsightType.reminder));
      expect(InsightType.values, contains(InsightType.suggestion));
    });
  });
}
