import 'package:hive/hive.dart';

part 'water_achievement.g.dart';

/// Achievement types for gamification
@HiveType(typeId: 25)
enum AchievementType {
  @HiveField(0)
  streak, // Consecutive days meeting goal

  @HiveField(1)
  totalVolume, // Total water consumed

  @HiveField(2)
  consistency, // Regular drinking pattern

  @HiveField(3)
  variety, // Trying different beverages

  @HiveField(4)
  earlyBird, // Drinking water early morning

  @HiveField(5)
  nightOwl, // Staying hydrated late

  @HiveField(6)
  perfectWeek, // 7 days in a row at 100%

  @HiveField(7)
  perfectMonth, // 30 days in a row at 100%

  @HiveField(8)
  overachiever, // Exceeding goal by 120%

  @HiveField(9)
  socialDrinker, // Not drinking alcohol for X days

  @HiveField(10)
  caffeineControl, // Limiting caffeine intake
}

/// User achievement with progress tracking
@HiveType(typeId: 26)
class WaterAchievement extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final AchievementType type;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final String emoji;

  @HiveField(5)
  final int targetValue;

  @HiveField(6)
  final int currentValue;

  @HiveField(7)
  final bool isUnlocked;

  @HiveField(8)
  final DateTime? unlockedAt;

  @HiveField(9)
  final int tier; // Bronze = 1, Silver = 2, Gold = 3, Platinum = 4

  @HiveField(10)
  final int points; // Points awarded for this achievement

  WaterAchievement({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.tier = 1,
    this.points = 10,
  });

  double get progress => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  String get tierName {
    switch (tier) {
      case 1:
        return 'Bronze';
      case 2:
        return 'Silver';
      case 3:
        return 'Gold';
      case 4:
        return 'Platinum';
      default:
        return 'Bronze';
    }
  }

  String get tierEmoji {
    switch (tier) {
      case 1:
        return '🥉';
      case 2:
        return '🥈';
      case 3:
        return '🥇';
      case 4:
        return '💎';
      default:
        return '🥉';
    }
  }

  WaterAchievement copyWith({
    int? currentValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return WaterAchievement(
      id: id,
      type: type,
      title: title,
      description: description,
      emoji: emoji,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      tier: tier,
      points: points,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'description': description,
    'emoji': emoji,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'tier': tier,
    'points': points,
  };

  factory WaterAchievement.fromJson(Map<String, dynamic> json) => WaterAchievement(
    id: json['id'] ?? '',
    type: AchievementType.values[json['type'] ?? 0],
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    emoji: json['emoji'] ?? '🏆',
    targetValue: json['targetValue'] ?? 1,
    currentValue: json['currentValue'] ?? 0,
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
    tier: json['tier'] ?? 1,
    points: json['points'] ?? 10,
  );

  /// All available achievements
  static List<WaterAchievement> get allAchievements => [
    // Streak achievements
    WaterAchievement(
      id: 'streak_3',
      type: AchievementType.streak,
      title: 'Getting Started',
      description: 'Meet your water goal for 3 days in a row',
      emoji: '🔥',
      targetValue: 3,
      tier: 1,
      points: 10,
    ),
    WaterAchievement(
      id: 'streak_7',
      type: AchievementType.streak,
      title: 'Week Warrior',
      description: 'Meet your water goal for 7 days in a row',
      emoji: '🔥',
      targetValue: 7,
      tier: 2,
      points: 25,
    ),
    WaterAchievement(
      id: 'streak_14',
      type: AchievementType.streak,
      title: 'Hydration Hero',
      description: 'Meet your water goal for 14 days in a row',
      emoji: '🔥',
      targetValue: 14,
      tier: 2,
      points: 50,
    ),
    WaterAchievement(
      id: 'streak_30',
      type: AchievementType.streak,
      title: 'Monthly Master',
      description: 'Meet your water goal for 30 days in a row',
      emoji: '🔥',
      targetValue: 30,
      tier: 3,
      points: 100,
    ),
    WaterAchievement(
      id: 'streak_60',
      type: AchievementType.streak,
      title: 'Hydration Legend',
      description: 'Meet your water goal for 60 days in a row',
      emoji: '🔥',
      targetValue: 60,
      tier: 3,
      points: 200,
    ),
    WaterAchievement(
      id: 'streak_100',
      type: AchievementType.streak,
      title: 'Century Champion',
      description: 'Meet your water goal for 100 days in a row',
      emoji: '🔥',
      targetValue: 100,
      tier: 4,
      points: 500,
    ),
    WaterAchievement(
      id: 'streak_365',
      type: AchievementType.streak,
      title: 'Year of Hydration',
      description: 'Meet your water goal for 365 days in a row',
      emoji: '👑',
      targetValue: 365,
      tier: 4,
      points: 1000,
    ),

    // Total volume achievements (in liters)
    WaterAchievement(
      id: 'volume_10',
      type: AchievementType.totalVolume,
      title: 'First Steps',
      description: 'Drink a total of 10 liters',
      emoji: '💧',
      targetValue: 10000,
      tier: 1,
      points: 10,
    ),
    WaterAchievement(
      id: 'volume_50',
      type: AchievementType.totalVolume,
      title: 'Hydration Novice',
      description: 'Drink a total of 50 liters',
      emoji: '💧',
      targetValue: 50000,
      tier: 1,
      points: 25,
    ),
    WaterAchievement(
      id: 'volume_100',
      type: AchievementType.totalVolume,
      title: 'Water Lover',
      description: 'Drink a total of 100 liters',
      emoji: '🌊',
      targetValue: 100000,
      tier: 2,
      points: 50,
    ),
    WaterAchievement(
      id: 'volume_500',
      type: AchievementType.totalVolume,
      title: 'Ocean Drinker',
      description: 'Drink a total of 500 liters',
      emoji: '🌊',
      targetValue: 500000,
      tier: 3,
      points: 150,
    ),
    WaterAchievement(
      id: 'volume_1000',
      type: AchievementType.totalVolume,
      title: 'Aqua Master',
      description: 'Drink a total of 1000 liters',
      emoji: '🌊',
      targetValue: 1000000,
      tier: 4,
      points: 300,
    ),

    // Early bird achievements
    WaterAchievement(
      id: 'early_bird_7',
      type: AchievementType.earlyBird,
      title: 'Early Riser',
      description: 'Drink water before 7 AM for 7 days',
      emoji: '🌅',
      targetValue: 7,
      tier: 1,
      points: 20,
    ),
    WaterAchievement(
      id: 'early_bird_30',
      type: AchievementType.earlyBird,
      title: 'Morning Champion',
      description: 'Drink water before 7 AM for 30 days',
      emoji: '🌅',
      targetValue: 30,
      tier: 2,
      points: 75,
    ),

    // Variety achievements
    WaterAchievement(
      id: 'variety_5',
      type: AchievementType.variety,
      title: 'Drink Explorer',
      description: 'Try 5 different beverage types',
      emoji: '🎨',
      targetValue: 5,
      tier: 1,
      points: 15,
    ),
    WaterAchievement(
      id: 'variety_10',
      type: AchievementType.variety,
      title: 'Beverage Connoisseur',
      description: 'Try 10 different beverage types',
      emoji: '🎨',
      targetValue: 10,
      tier: 2,
      points: 40,
    ),

    // Perfect week/month
    WaterAchievement(
      id: 'perfect_week',
      type: AchievementType.perfectWeek,
      title: 'Perfect Week',
      description: 'Achieve 100% goal every day for a week',
      emoji: '⭐',
      targetValue: 7,
      tier: 2,
      points: 50,
    ),
    WaterAchievement(
      id: 'perfect_month',
      type: AchievementType.perfectMonth,
      title: 'Perfect Month',
      description: 'Achieve 100% goal every day for a month',
      emoji: '⭐',
      targetValue: 30,
      tier: 3,
      points: 200,
    ),

    // Overachiever
    WaterAchievement(
      id: 'overachiever_7',
      type: AchievementType.overachiever,
      title: 'Overachiever',
      description: 'Exceed your goal by 120% for 7 days',
      emoji: '🚀',
      targetValue: 7,
      tier: 2,
      points: 40,
    ),

    // Caffeine control
    WaterAchievement(
      id: 'caffeine_free_7',
      type: AchievementType.caffeineControl,
      title: 'Caffeine Detox',
      description: 'Go 7 days without caffeinated drinks',
      emoji: '☯️',
      targetValue: 7,
      tier: 2,
      points: 35,
    ),

    // Alcohol-free
    WaterAchievement(
      id: 'sober_30',
      type: AchievementType.socialDrinker,
      title: 'Sober Month',
      description: 'Go 30 days without alcoholic drinks',
      emoji: '🧘',
      targetValue: 30,
      tier: 2,
      points: 75,
    ),
  ];
}

/// User's achievement progress stored together
@HiveType(typeId: 27)
class UserAchievements extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<WaterAchievement> achievements;

  @HiveField(2)
  final int totalPoints;

  @HiveField(3)
  final int currentStreak;

  @HiveField(4)
  final int longestStreak;

  @HiveField(5)
  final int totalDrinks;

  @HiveField(6)
  final int totalMl;

  @HiveField(7)
  final List<String> beverageTypesUsed;

  @HiveField(8)
  final int daysGoalMet;

  @HiveField(9)
  final DateTime? lastGoalMetDate;

  @HiveField(10)
  final int caffeineFreeDays;

  @HiveField(11)
  final int alcoholFreeDays;

  @HiveField(12)
  final int earlyMorningDrinks;

  UserAchievements({
    required this.id,
    List<WaterAchievement>? achievements,
    this.totalPoints = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDrinks = 0,
    this.totalMl = 0,
    List<String>? beverageTypesUsed,
    this.daysGoalMet = 0,
    this.lastGoalMetDate,
    this.caffeineFreeDays = 0,
    this.alcoholFreeDays = 0,
    this.earlyMorningDrinks = 0,
  })  : achievements = achievements ?? WaterAchievement.allAchievements,
        beverageTypesUsed = beverageTypesUsed ?? [];

  int get level => (totalPoints / 100).floor() + 1;
  int get pointsToNextLevel => 100 - (totalPoints % 100);

  List<WaterAchievement> get unlockedAchievements =>
      achievements.where((a) => a.isUnlocked).toList();

  List<WaterAchievement> get lockedAchievements =>
      achievements.where((a) => !a.isUnlocked).toList();

  UserAchievements copyWith({
    List<WaterAchievement>? achievements,
    int? totalPoints,
    int? currentStreak,
    int? longestStreak,
    int? totalDrinks,
    int? totalMl,
    List<String>? beverageTypesUsed,
    int? daysGoalMet,
    DateTime? lastGoalMetDate,
    int? caffeineFreeDays,
    int? alcoholFreeDays,
    int? earlyMorningDrinks,
  }) {
    return UserAchievements(
      id: id,
      achievements: achievements ?? this.achievements,
      totalPoints: totalPoints ?? this.totalPoints,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalDrinks: totalDrinks ?? this.totalDrinks,
      totalMl: totalMl ?? this.totalMl,
      beverageTypesUsed: beverageTypesUsed ?? this.beverageTypesUsed,
      daysGoalMet: daysGoalMet ?? this.daysGoalMet,
      lastGoalMetDate: lastGoalMetDate ?? this.lastGoalMetDate,
      caffeineFreeDays: caffeineFreeDays ?? this.caffeineFreeDays,
      alcoholFreeDays: alcoholFreeDays ?? this.alcoholFreeDays,
      earlyMorningDrinks: earlyMorningDrinks ?? this.earlyMorningDrinks,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'achievements': achievements.map((a) => a.toJson()).toList(),
    'totalPoints': totalPoints,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'totalDrinks': totalDrinks,
    'totalMl': totalMl,
    'beverageTypesUsed': beverageTypesUsed,
    'daysGoalMet': daysGoalMet,
    'lastGoalMetDate': lastGoalMetDate?.toIso8601String(),
    'caffeineFreeDays': caffeineFreeDays,
    'alcoholFreeDays': alcoholFreeDays,
    'earlyMorningDrinks': earlyMorningDrinks,
  };

  factory UserAchievements.fromJson(Map<String, dynamic> json) => UserAchievements(
    id: json['id'] ?? 'default',
    achievements: (json['achievements'] as List<dynamic>?)
        ?.map((a) => WaterAchievement.fromJson(a))
        .toList(),
    totalPoints: json['totalPoints'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    longestStreak: json['longestStreak'] ?? 0,
    totalDrinks: json['totalDrinks'] ?? 0,
    totalMl: json['totalMl'] ?? 0,
    beverageTypesUsed: (json['beverageTypesUsed'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList(),
    daysGoalMet: json['daysGoalMet'] ?? 0,
    lastGoalMetDate: json['lastGoalMetDate'] != null
        ? DateTime.parse(json['lastGoalMetDate'])
        : null,
    caffeineFreeDays: json['caffeineFreeDays'] ?? 0,
    alcoholFreeDays: json['alcoholFreeDays'] ?? 0,
    earlyMorningDrinks: json['earlyMorningDrinks'] ?? 0,
  );
}
