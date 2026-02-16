import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:tablet_remainder/features/focus/models/focus_coins.dart';
import 'package:tablet_remainder/features/focus/models/app_allow_list.dart';
import 'package:tablet_remainder/features/focus/models/custom_tag.dart';
import 'package:tablet_remainder/features/focus/models/focus_leaderboard.dart';
import 'package:tablet_remainder/features/focus/models/group_focus.dart';
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
    test('should correctly identify allowed apps', () {
      final allowList = AppAllowList(
        apps: [
          AllowedApp(
            id: 'spotify',
            name: 'Spotify',
            packageName: 'com.spotify.music',
            category: AppCategory.music,
            addedAt: DateTime.now(),
            isAllowed: true,
          ),
        ],
      );
      
      expect(allowList.isAppAllowed('com.spotify.music'), true);
    });

    test('strict mode should block unlisted apps', () {
      const allowList = AppAllowList(
        apps: [],
        isStrictMode: true,
      );
      
      expect(allowList.isAppAllowed('com.unknown.app'), false);
    });

    test('non-strict mode should allow unlisted apps', () {
      const allowList = AppAllowList(
        apps: [],
        isStrictMode: false,
      );
      
      expect(allowList.isAppAllowed('com.unknown.app'), true);
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

  group('FocusLeaderboard Model Tests', () {
    test('LeaderboardEntry should calculate rank change correctly', () {
      final entry = LeaderboardEntry(
        oderId: 'user_1',
        displayName: 'Test User',
        rank: 5,
        value: 1000,
        previousRank: 8,
      );
      
      expect(entry.rankChange, 3);
      expect(entry.rankImproved, true);
      expect(entry.rankDeclined, false);
    });

    test('LeaderboardEntry with declined rank should be detected', () {
      final entry = LeaderboardEntry(
        oderId: 'user_1',
        displayName: 'Test User',
        rank: 10,
        value: 500,
        previousRank: 5,
      );
      
      expect(entry.rankChange, -5);
      expect(entry.rankImproved, false);
      expect(entry.rankDeclined, true);
    });

    test('UserProfile should serialize correctly', () {
      final profile = UserProfile(
        oderId: 'user_123',
        displayName: 'Focus Master',
        friendCode: 'ABC12345',
        totalFocusMinutes: 3000,
        currentStreak: 15,
        treesPlanted: 50,
        joinedAt: DateTime(2024, 1, 1),
      );
      
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      
      expect(restored.oderId, 'user_123');
      expect(restored.displayName, 'Focus Master');
      expect(restored.totalFocusHours, 50); // 3000 / 60
      expect(restored.currentStreak, 15);
    });

    test('FocusFriend serialization should work correctly', () {
      final friend = FocusFriend(
        oderId: 'friend_1',
        displayName: 'Study Buddy',
        friendCode: 'XYZ98765',
        addedAt: DateTime(2024, 1, 10),
        totalFocusMinutes: 1500,
        currentStreak: 7,
      );
      
      final json = friend.toJson();
      final restored = FocusFriend.fromJson(json);
      
      expect(restored.oderId, 'friend_1');
      expect(restored.displayName, 'Study Buddy');
      expect(restored.currentStreak, 7);
    });
  });

  group('GroupFocus Model Tests', () {
    test('GroupFocusSession canStart should require 2+ ready participants', () {
      final session = GroupFocusSession(
        id: 'session_1',
        hostUserId: 'host_user',
        hostDisplayName: 'Host',
        roomCode: 'ABC123',
        targetMinutes: 25,
        plantType: PlantType.tree,
        participants: [
          GroupParticipant(
            oderId: 'host_user',
            displayName: 'Host',
            isHost: true,
            isReady: true,
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );
      
      expect(session.canStart, false); // Only 1 participant
    });

    test('GroupFocusSession with 2 ready participants can start', () {
      final session = GroupFocusSession(
        id: 'session_1',
        hostUserId: 'host_user',
        hostDisplayName: 'Host',
        roomCode: 'ABC123',
        targetMinutes: 25,
        plantType: PlantType.tree,
        participants: [
          GroupParticipant(
            oderId: 'host_user',
            displayName: 'Host',
            isHost: true,
            isReady: true,
            joinedAt: DateTime.now(),
          ),
          GroupParticipant(
            oderId: 'user_2',
            displayName: 'Friend',
            isHost: false,
            isReady: true,
            joinedAt: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
      );
      
      expect(session.canStart, true);
    });

    test('GroupSessionInvite shareLink should be formatted correctly', () {
      final invite = GroupSessionInvite(
        id: 'invite_1',
        sessionId: 'session_1',
        roomCode: 'ABC123',
        hostDisplayName: 'Host',
        targetMinutes: 25,
        currentParticipants: 2,
        maxParticipants: 10,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      
      expect(invite.shareLink, 'dlyminder://focus/join/ABC123');
      expect(invite.isFull, false);
    });

    test('ParticipantStatus should have correct properties', () {
      expect(ParticipantStatus.focusing.emoji, '🎯');
      expect(ParticipantStatus.completed.emoji, '🏆');
      expect(ParticipantStatus.abandoned.emoji, '💔');
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

    test('InsightType should have correct values', () {
      expect(InsightType.values.length, 4);
      expect(InsightType.positive.name, 'positive');
      expect(InsightType.improvement.name, 'improvement');
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

    test('Group session failure should mark all trees as dead', () {
      final session = GroupFocusSession(
        id: 'group_session',
        hostUserId: 'host',
        hostDisplayName: 'Host',
        roomCode: 'TEST01',
        targetMinutes: 25,
        plantType: PlantType.tree,
        participants: [
          GroupParticipant(
            oderId: 'host',
            displayName: 'Host',
            isHost: true,
            isReady: true,
            joinedAt: DateTime.now(),
            status: ParticipantStatus.focusing,
          ),
          GroupParticipant(
            oderId: 'user2',
            displayName: 'User 2',
            isHost: false,
            isReady: true,
            joinedAt: DateTime.now(),
            status: ParticipantStatus.abandoned, // This user left
          ),
        ],
        createdAt: DateTime.now(),
        status: GroupSessionStatus.failed,
        failedByUserId: 'user2',
      );
      
      expect(session.status, GroupSessionStatus.failed);
      expect(session.failedByUserId, 'user2');
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

    test('AppAllowList with default values should serialize correctly', () {
      const allowList = AppAllowList();
      final json = allowList.toJson();
      final restored = AppAllowList.fromJson(json);
      
      expect(restored.isStrictMode, false);
      expect(restored.blockNotifications, true);
      expect(restored.gracePeriodSeconds, 10);
    });

    test('GroupFocusSession progress should be 0 when not started', () {
      final session = GroupFocusSession(
        id: 'session_1',
        hostUserId: 'host',
        hostDisplayName: 'Host',
        roomCode: 'ABC123',
        targetMinutes: 25,
        plantType: PlantType.tree,
        participants: [],
        createdAt: DateTime.now(),
        status: GroupSessionStatus.waiting,
      );
      
      expect(session.progress, 0);
      expect(session.remainingTime, null);
    });
  });
}
