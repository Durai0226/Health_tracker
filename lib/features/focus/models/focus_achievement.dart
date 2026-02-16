import 'package:flutter/material.dart';

enum AchievementType {
  firstSession,
  tenMinutes,
  thirtyMinutes,
  oneHour,
  threeHours,
  fiveHours,
  tenHours,
  twentyFiveHours,
  fiftyHours,
  hundredHours,
  firstPlant,
  tenPlants,
  fiftyPlants,
  hundredPlants,
  firstStreak,
  weekStreak,
  monthStreak,
  earlyBird,
  nightOwl,
  weekendWarrior,
  perfectWeek,
  allPlants,
  breathingMaster,
  soundExplorer,
}

extension AchievementTypeExtension on AchievementType {
  String get name {
    switch (this) {
      case AchievementType.firstSession:
        return 'First Focus';
      case AchievementType.tenMinutes:
        return '10 Minutes';
      case AchievementType.thirtyMinutes:
        return 'Half Hour Hero';
      case AchievementType.oneHour:
        return 'Hour of Power';
      case AchievementType.threeHours:
        return 'Three Hour Marathon';
      case AchievementType.fiveHours:
        return 'Focus Champion';
      case AchievementType.tenHours:
        return 'Deep Worker';
      case AchievementType.twentyFiveHours:
        return 'Focus Master';
      case AchievementType.fiftyHours:
        return 'Concentration King';
      case AchievementType.hundredHours:
        return 'Focus Legend';
      case AchievementType.firstPlant:
        return 'First Plant';
      case AchievementType.tenPlants:
        return 'Small Garden';
      case AchievementType.fiftyPlants:
        return 'Garden Keeper';
      case AchievementType.hundredPlants:
        return 'Forest Guardian';
      case AchievementType.firstStreak:
        return 'Getting Started';
      case AchievementType.weekStreak:
        return 'Week Warrior';
      case AchievementType.monthStreak:
        return 'Monthly Champion';
      case AchievementType.earlyBird:
        return 'Early Bird';
      case AchievementType.nightOwl:
        return 'Night Owl';
      case AchievementType.weekendWarrior:
        return 'Weekend Warrior';
      case AchievementType.perfectWeek:
        return 'Perfect Week';
      case AchievementType.allPlants:
        return 'Plant Collector';
      case AchievementType.breathingMaster:
        return 'Breathing Master';
      case AchievementType.soundExplorer:
        return 'Sound Explorer';
    }
  }

  String get description {
    switch (this) {
      case AchievementType.firstSession:
        return 'Complete your first focus session';
      case AchievementType.tenMinutes:
        return 'Focus for 10 minutes total';
      case AchievementType.thirtyMinutes:
        return 'Focus for 30 minutes total';
      case AchievementType.oneHour:
        return 'Focus for 1 hour total';
      case AchievementType.threeHours:
        return 'Focus for 3 hours total';
      case AchievementType.fiveHours:
        return 'Focus for 5 hours total';
      case AchievementType.tenHours:
        return 'Focus for 10 hours total';
      case AchievementType.twentyFiveHours:
        return 'Focus for 25 hours total';
      case AchievementType.fiftyHours:
        return 'Focus for 50 hours total';
      case AchievementType.hundredHours:
        return 'Focus for 100 hours total';
      case AchievementType.firstPlant:
        return 'Grow your first plant';
      case AchievementType.tenPlants:
        return 'Grow 10 plants';
      case AchievementType.fiftyPlants:
        return 'Grow 50 plants';
      case AchievementType.hundredPlants:
        return 'Grow 100 plants';
      case AchievementType.firstStreak:
        return 'Focus 3 days in a row';
      case AchievementType.weekStreak:
        return 'Focus 7 days in a row';
      case AchievementType.monthStreak:
        return 'Focus 30 days in a row';
      case AchievementType.earlyBird:
        return 'Complete a session before 7 AM';
      case AchievementType.nightOwl:
        return 'Complete a session after 10 PM';
      case AchievementType.weekendWarrior:
        return 'Complete 5 sessions on weekends';
      case AchievementType.perfectWeek:
        return 'Focus every day for a week';
      case AchievementType.allPlants:
        return 'Unlock all plant types';
      case AchievementType.breathingMaster:
        return 'Complete 50 breathing exercises';
      case AchievementType.soundExplorer:
        return 'Try all ambient sounds';
    }
  }

  String get emoji {
    switch (this) {
      case AchievementType.firstSession:
        return '🎯';
      case AchievementType.tenMinutes:
        return '⏱️';
      case AchievementType.thirtyMinutes:
        return '⏰';
      case AchievementType.oneHour:
        return '🕐';
      case AchievementType.threeHours:
        return '🏃';
      case AchievementType.fiveHours:
        return '🏆';
      case AchievementType.tenHours:
        return '💪';
      case AchievementType.twentyFiveHours:
        return '🧠';
      case AchievementType.fiftyHours:
        return '👑';
      case AchievementType.hundredHours:
        return '🌟';
      case AchievementType.firstPlant:
        return '🌱';
      case AchievementType.tenPlants:
        return '🌿';
      case AchievementType.fiftyPlants:
        return '🌳';
      case AchievementType.hundredPlants:
        return '🌲';
      case AchievementType.firstStreak:
        return '🔥';
      case AchievementType.weekStreak:
        return '🔥';
      case AchievementType.monthStreak:
        return '💎';
      case AchievementType.earlyBird:
        return '🐦';
      case AchievementType.nightOwl:
        return '🦉';
      case AchievementType.weekendWarrior:
        return '⚔️';
      case AchievementType.perfectWeek:
        return '✨';
      case AchievementType.allPlants:
        return '🎨';
      case AchievementType.breathingMaster:
        return '🧘';
      case AchievementType.soundExplorer:
        return '🎵';
    }
  }

  Color get color {
    switch (this) {
      case AchievementType.firstSession:
      case AchievementType.tenMinutes:
      case AchievementType.thirtyMinutes:
        return const Color(0xFFCD7F32); // Bronze
      case AchievementType.oneHour:
      case AchievementType.threeHours:
      case AchievementType.fiveHours:
      case AchievementType.firstPlant:
      case AchievementType.tenPlants:
      case AchievementType.firstStreak:
        return const Color(0xFFC0C0C0); // Silver
      case AchievementType.tenHours:
      case AchievementType.twentyFiveHours:
      case AchievementType.fiftyPlants:
      case AchievementType.weekStreak:
      case AchievementType.earlyBird:
      case AchievementType.nightOwl:
      case AchievementType.weekendWarrior:
        return const Color(0xFFFFD700); // Gold
      case AchievementType.fiftyHours:
      case AchievementType.hundredHours:
      case AchievementType.hundredPlants:
      case AchievementType.monthStreak:
      case AchievementType.perfectWeek:
      case AchievementType.allPlants:
      case AchievementType.breathingMaster:
      case AchievementType.soundExplorer:
        return const Color(0xFFE5E4E2); // Platinum
    }
  }

  int get requiredValue {
    switch (this) {
      case AchievementType.firstSession:
        return 1;
      case AchievementType.tenMinutes:
        return 10;
      case AchievementType.thirtyMinutes:
        return 30;
      case AchievementType.oneHour:
        return 60;
      case AchievementType.threeHours:
        return 180;
      case AchievementType.fiveHours:
        return 300;
      case AchievementType.tenHours:
        return 600;
      case AchievementType.twentyFiveHours:
        return 1500;
      case AchievementType.fiftyHours:
        return 3000;
      case AchievementType.hundredHours:
        return 6000;
      case AchievementType.firstPlant:
        return 1;
      case AchievementType.tenPlants:
        return 10;
      case AchievementType.fiftyPlants:
        return 50;
      case AchievementType.hundredPlants:
        return 100;
      case AchievementType.firstStreak:
        return 3;
      case AchievementType.weekStreak:
        return 7;
      case AchievementType.monthStreak:
        return 30;
      case AchievementType.earlyBird:
        return 1;
      case AchievementType.nightOwl:
        return 1;
      case AchievementType.weekendWarrior:
        return 5;
      case AchievementType.perfectWeek:
        return 7;
      case AchievementType.allPlants:
        return 12;
      case AchievementType.breathingMaster:
        return 50;
      case AchievementType.soundExplorer:
        return 15;
    }
  }
}

class FocusAchievement {
  final AchievementType type;
  final DateTime? unlockedAt;
  final int currentProgress;
  final bool isUnlocked;

  const FocusAchievement({
    required this.type,
    this.unlockedAt,
    this.currentProgress = 0,
    this.isUnlocked = false,
  });

  double get progressPercent {
    if (isUnlocked) return 1.0;
    return (currentProgress / type.requiredValue).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'currentProgress': currentProgress,
        'isUnlocked': isUnlocked,
      };

  factory FocusAchievement.fromJson(Map<String, dynamic> json) => FocusAchievement(
        type: AchievementType.values[json['type'] ?? 0],
        unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
        currentProgress: json['currentProgress'] ?? 0,
        isUnlocked: json['isUnlocked'] ?? false,
      );

  FocusAchievement copyWith({
    AchievementType? type,
    DateTime? unlockedAt,
    int? currentProgress,
    bool? isUnlocked,
  }) {
    return FocusAchievement(
      type: type ?? this.type,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentProgress: currentProgress ?? this.currentProgress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}
