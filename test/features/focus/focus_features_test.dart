import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/app_allow_list.dart';
import 'package:tablet_remainder/features/focus/models/custom_tag.dart';
import 'package:tablet_remainder/features/focus/models/detailed_stats.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';

void main() {
  group('FocusCoins Model Tests', () {
    test('should calculate coins correctly for completed session', () {
      final coins = CoinsCalculator.calculateCoinsForSession(25, isCompleted: true);
      expect(coins, 50); // 25 minutes * 2 coins per minute
    });

    test('should return 0 coins for abandoned session', () {
      final coins = CoinsCalculator.calculateCoinsForSession(25, isCompleted: false);
      expect(coins, 0);
    });

    test('should calculate streak bonus correctly', () {
      expect(CoinsCalculator.calculateStreakBonus(1), 0);
      expect(CoinsCalculator.calculateStreakBonus(3), 10);
      expect(CoinsCalculator.calculateStreakBonus(7), 25);
      expect(CoinsCalculator.calculateStreakBonus(14), 50);
      expect(CoinsCalculator.calculateStreakBonus(30), 100);
    });

    test('RealTreeType should have correct coin costs', () {
      expect(RealTreeType.bamboo.coinCost, 200);
      expect(RealTreeType.oak.coinCost, 500);
      expect(RealTreeType.cherry.coinCost, 600);
    });

    test('FocusCoins serialization should work correctly', () {
      const coins = FocusCoins(
        totalCoins: 500,
        lifetimeCoins: 1000,
        coinsSpentOnTrees: 500,
      );
      
      final json = coins.toJson();
      final restored = FocusCoins.fromJson(json);
      
      expect(restored.totalCoins, 500);
      expect(restored.lifetimeCoins, 1000);
      expect(restored.coinsSpentOnTrees, 500);
    });

    test('CoinTransaction should serialize correctly', () {
      final transaction = CoinTransaction(
        id: 'test_123',
        type: CoinTransactionType.earned,
        amount: 50,
        timestamp: DateTime(2024, 1, 15),
        description: 'Test transaction',
      );
      
      final json = transaction.toJson();
      final restored = CoinTransaction.fromJson(json);
      
      expect(restored.id, 'test_123');
      expect(restored.type, CoinTransactionType.earned);
      expect(restored.amount, 50);
    });
  });

  group('AppAllowList Model Tests', () {
    // The three tests that were here exercised `isAppAllowed()` and the
    // `isStrictMode` flag — an enforcement predicate with no production caller,
    // in a feature that never had the permissions to enforce anything. Testing it
    // gave the strongest possible false signal: green assertions over a promise
    // the app could not keep. Both the predicate and these tests are gone.
    //
    // What survives is what the list actually is: a note the user writes.
    test('partitions the list the user wrote', () {
      final allowList = AppAllowList(
        apps: [
          AllowedApp(
            id: 'spotify',
            name: 'Spotify',
            packageName: 'com.spotify.music',
            category: AppCategory.music,
            addedAt: DateTime(2024, 1, 15),
            isAllowed: true,
          ),
          AllowedApp(
            id: 'socialapp',
            name: 'Social App',
            packageName: 'com.social.app',
            category: AppCategory.social,
            addedAt: DateTime(2024, 1, 15),
            isAllowed: false,
          ),
        ],
      );

      expect(allowList.allowedApps.map((a) => a.id), ['spotify']);
      expect(allowList.blockedApps.map((a) => a.id), ['socialapp']);
    });

    test('loads a list written before the enforcement flags were removed', () {
      // Old records carry isStrictMode / blockNotifications /
      // showWarningOnBlockedApp / gracePeriodSeconds. They must be ignored, not
      // choked on.
      final restored = AppAllowList.fromJson({
        'apps': [],
        'isStrictMode': true,
        'blockNotifications': false,
        'showWarningOnBlockedApp': false,
        'gracePeriodSeconds': 30,
      });
      expect(restored.apps, isEmpty);
    });

    test('PresetAllowList should return correct app counts', () {
      expect(PresetAllowList.getProductivityApps().length, 6);
      expect(PresetAllowList.getEducationApps().length, 5);
      expect(PresetAllowList.getMusicApps().length, 3);
    });

    test('AllowedApp serialization should work correctly', () {
      final app = AllowedApp(
        id: 'test_app',
        name: 'Test App',
        packageName: 'com.test.app',
        category: AppCategory.productivity,
        addedAt: DateTime(2024, 1, 15),
        isAllowed: true,
      );
      
      final json = app.toJson();
      final restored = AllowedApp.fromJson(json);
      
      expect(restored.id, 'test_app');
      expect(restored.name, 'Test App');
      expect(restored.category, AppCategory.productivity);
    });
  });

  group('CustomTag Model Tests', () {
    test('DefaultTags should return 8 default tags', () {
      final defaults = DefaultTags.getDefaultTags();
      expect(defaults.length, 8);
    });

    test('FocusTag should serialize correctly', () {
      final tag = FocusTag(
        id: 'study',
        name: 'Study',
        color: const Color(0xFF2196F3),
        emoji: '📚',
        createdAt: DateTime(2024, 1, 15),
        usageCount: 10,
        isDefault: true,
      );
      
      final json = tag.toJson();
      final restored = FocusTag.fromJson(json);
      
      expect(restored.id, 'study');
      expect(restored.name, 'Study');
      expect(restored.emoji, '📚');
      expect(restored.usageCount, 10);
    });

    test('FocusTag availableColors should have 12 options', () {
      expect(FocusTag.availableColors.length, 12);
    });

    test('FocusTag availableEmojis should have 18 options', () {
      expect(FocusTag.availableEmojis.length, 18);
    });
  });

  group('DetailedStats Model Tests', () {
    test('DailyFocusStats should calculate totals correctly', () {
      final stats = DailyFocusStats(
        date: DateTime(2024, 1, 15),
        totalMinutes: 120,
        sessionsCount: 5,
        completedSessions: 4,
        abandonedSessions: 1,
      );
      
      expect(stats.totalHours, 2);
      expect(stats.completionRate, 0.8);
      expect(stats.hasData, true);
    });

    test('DailyFocusStats with no data should return hasData false', () {
      final stats = DailyFocusStats(date: DateTime(2024, 1, 15));
      expect(stats.hasData, false);
    });

    test('ProductivityPattern should analyze sessions correctly', () {
      final sessions = [
        FocusSession(
          id: '1',
          startedAt: DateTime(2024, 1, 15, 9, 0), // 9 AM Monday
          targetMinutes: 25,
          actualMinutes: 25,
          wasCompleted: true,
          activityType: FocusActivityType.work,
          plantType: PlantType.tree,
        ),
        FocusSession(
          id: '2',
          startedAt: DateTime(2024, 1, 15, 10, 0), // 10 AM Monday
          targetMinutes: 25,
          actualMinutes: 25,
          wasCompleted: true,
          activityType: FocusActivityType.study,
          plantType: PlantType.tree,
        ),
      ];
      
      final pattern = ProductivityPattern.analyze(sessions);
      
      expect(pattern.minutesByHour.containsKey(9), true);
      expect(pattern.minutesByHour.containsKey(10), true);
      expect(pattern.minutesByDayOfWeek.containsKey(1), true); // Monday
    });
  });

  group('Integration Tests', () {
    test('Complete focus session flow should work', () {
      // Simulate a complete session
      final session = FocusSession(
        id: 'session_test',
        startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        completedAt: DateTime.now(),
        targetMinutes: 25,
        actualMinutes: 25,
        wasCompleted: true,
        wasAbandoned: false,
        activityType: FocusActivityType.work,
        plantType: PlantType.tree,
      );
      
      // Calculate coins earned
      final coinsEarned = CoinsCalculator.calculateCoinsForSession(
        session.actualMinutes,
        isCompleted: session.wasCompleted,
      );
      
      expect(coinsEarned, 50);
      expect(session.wasCompleted, true);
    });

    test('Tag statistics should aggregate correctly', () {
      final tag = FocusTag(
        id: 'work',
        name: 'Work',
        color: const Color(0xFF4CAF50),
        createdAt: DateTime.now(),
        usageCount: 20,
      );
      
      final stats = TagStatistics(
        tagId: tag.id,
        tagName: tag.name,
        tagColor: tag.color,
        totalMinutes: 500,
        sessionCount: 20,
      );
      
      expect(stats.averageSessionMinutes, 25.0);
      expect(stats.totalHours, 8);
    });
  });

  group('Model Serialization Edge Cases', () {
    test('FocusCoins with empty lists should serialize correctly', () {
      const coins = FocusCoins();
      final json = coins.toJson();
      final restored = FocusCoins.fromJson(json);
      
      expect(restored.totalCoins, 0);
      expect(restored.plantedTrees.isEmpty, true);
      expect(restored.transactions.isEmpty, true);
    });

    test('AppAllowList round-trips an empty list', () {
      const allowList = AppAllowList();
      final restored = AppAllowList.fromJson(allowList.toJson());

      expect(restored.apps, isEmpty);
      expect(restored.allowedApps, isEmpty);
      expect(restored.blockedApps, isEmpty);
    });

  });
}
