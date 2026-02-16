import 'package:hive/hive.dart';

part 'hydration_challenge.g.dart';

/// Challenge difficulty levels
@HiveType(typeId: 35)
enum ChallengeDifficulty {
  @HiveField(0)
  easy,
  @HiveField(1)
  medium,
  @HiveField(2)
  hard,
  @HiveField(3)
  extreme,
}

/// Challenge duration types
@HiveType(typeId: 36)
enum ChallengeDuration {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  monthly,
  @HiveField(3)
  custom,
}

/// Hydration challenge model
@HiveType(typeId: 37)
class HydrationChallenge extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String emoji;

  @HiveField(4)
  final ChallengeDifficulty difficulty;

  @HiveField(5)
  final ChallengeDuration duration;

  @HiveField(6)
  final int durationDays;

  @HiveField(7)
  final int targetValue;

  @HiveField(8)
  final String targetUnit; // 'ml', 'days', 'drinks', 'streak'

  @HiveField(9)
  final int rewardPoints;

  @HiveField(10)
  final bool isActive;

  @HiveField(11)
  final DateTime? startDate;

  @HiveField(12)
  final DateTime? endDate;

  @HiveField(13)
  final int currentProgress;

  @HiveField(14)
  final bool isCompleted;

  @HiveField(15)
  final DateTime? completedAt;

  @HiveField(16)
  final List<String>? milestones;

  @HiveField(17)
  final int milestonesCompleted;

  HydrationChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.difficulty = ChallengeDifficulty.medium,
    this.duration = ChallengeDuration.weekly,
    this.durationDays = 7,
    required this.targetValue,
    this.targetUnit = 'ml',
    this.rewardPoints = 50,
    this.isActive = false,
    this.startDate,
    this.endDate,
    this.currentProgress = 0,
    this.isCompleted = false,
    this.completedAt,
    this.milestones,
    this.milestonesCompleted = 0,
  });

  double get progressPercent => targetValue > 0 
      ? (currentProgress / targetValue).clamp(0.0, 1.0) 
      : 0.0;

  int get daysRemaining {
    if (endDate == null) return durationDays;
    final now = DateTime.now();
    if (now.isAfter(endDate!)) return 0;
    return endDate!.difference(now).inDays + 1;
  }

  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  String get difficultyLabel {
    switch (difficulty) {
      case ChallengeDifficulty.easy: return 'Easy';
      case ChallengeDifficulty.medium: return 'Medium';
      case ChallengeDifficulty.hard: return 'Hard';
      case ChallengeDifficulty.extreme: return 'Extreme';
    }
  }

  String get durationLabel {
    switch (duration) {
      case ChallengeDuration.daily: return 'Daily';
      case ChallengeDuration.weekly: return 'Weekly';
      case ChallengeDuration.monthly: return 'Monthly';
      case ChallengeDuration.custom: return '$durationDays Days';
    }
  }

  HydrationChallenge copyWith({
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    int? currentProgress,
    bool? isCompleted,
    DateTime? completedAt,
    int? milestonesCompleted,
  }) {
    return HydrationChallenge(
      id: id,
      title: title,
      description: description,
      emoji: emoji,
      difficulty: difficulty,
      duration: duration,
      durationDays: durationDays,
      targetValue: targetValue,
      targetUnit: targetUnit,
      rewardPoints: rewardPoints,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      milestones: milestones,
      milestonesCompleted: milestonesCompleted ?? this.milestonesCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'emoji': emoji,
    'difficulty': difficulty.index,
    'duration': duration.index,
    'durationDays': durationDays,
    'targetValue': targetValue,
    'targetUnit': targetUnit,
    'rewardPoints': rewardPoints,
    'isActive': isActive,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'currentProgress': currentProgress,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'milestones': milestones,
    'milestonesCompleted': milestonesCompleted,
  };

  factory HydrationChallenge.fromJson(Map<String, dynamic> json) => HydrationChallenge(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    emoji: json['emoji'] ?? '🏆',
    difficulty: ChallengeDifficulty.values[json['difficulty'] ?? 1],
    duration: ChallengeDuration.values[json['duration'] ?? 1],
    durationDays: json['durationDays'] ?? 7,
    targetValue: json['targetValue'] ?? 0,
    targetUnit: json['targetUnit'] ?? 'ml',
    rewardPoints: json['rewardPoints'] ?? 50,
    isActive: json['isActive'] ?? false,
    startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    currentProgress: json['currentProgress'] ?? 0,
    isCompleted: json['isCompleted'] ?? false,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    milestones: (json['milestones'] as List<dynamic>?)?.cast<String>(),
    milestonesCompleted: json['milestonesCompleted'] ?? 0,
  );

  /// Available challenges
  static List<HydrationChallenge> get availableChallenges => [
    // Daily Challenges
    HydrationChallenge(
      id: 'daily_goal_streak_3',
      title: '3-Day Goal Crusher',
      description: 'Meet your daily water goal for 3 consecutive days',
      emoji: '🔥',
      difficulty: ChallengeDifficulty.easy,
      duration: ChallengeDuration.custom,
      durationDays: 3,
      targetValue: 3,
      targetUnit: 'days',
      rewardPoints: 30,
      milestones: ['Day 1', 'Day 2', 'Day 3'],
    ),
    HydrationChallenge(
      id: 'weekly_goal_streak',
      title: 'Week Warrior',
      description: 'Complete your daily goal for an entire week',
      emoji: '⚔️',
      difficulty: ChallengeDifficulty.medium,
      duration: ChallengeDuration.weekly,
      durationDays: 7,
      targetValue: 7,
      targetUnit: 'days',
      rewardPoints: 75,
      milestones: ['Day 1', 'Day 3', 'Day 5', 'Day 7'],
    ),
    HydrationChallenge(
      id: 'hydration_master',
      title: 'Hydration Master',
      description: 'Drink 20 liters of water in a week',
      emoji: '🌊',
      difficulty: ChallengeDifficulty.hard,
      duration: ChallengeDuration.weekly,
      durationDays: 7,
      targetValue: 20000,
      targetUnit: 'ml',
      rewardPoints: 100,
      milestones: ['5L', '10L', '15L', '20L'],
    ),
    HydrationChallenge(
      id: 'early_bird_week',
      title: 'Early Bird',
      description: 'Drink water before 8 AM for 5 days',
      emoji: '🌅',
      difficulty: ChallengeDifficulty.medium,
      duration: ChallengeDuration.weekly,
      durationDays: 7,
      targetValue: 5,
      targetUnit: 'days',
      rewardPoints: 50,
    ),
    HydrationChallenge(
      id: 'variety_explorer',
      title: 'Beverage Explorer',
      description: 'Try 8 different beverage types this week',
      emoji: '🎨',
      difficulty: ChallengeDifficulty.medium,
      duration: ChallengeDuration.weekly,
      durationDays: 7,
      targetValue: 8,
      targetUnit: 'types',
      rewardPoints: 60,
    ),
    HydrationChallenge(
      id: 'caffeine_break',
      title: 'Caffeine Detox',
      description: 'Go 3 days without caffeinated drinks',
      emoji: '☯️',
      difficulty: ChallengeDifficulty.hard,
      duration: ChallengeDuration.custom,
      durationDays: 3,
      targetValue: 3,
      targetUnit: 'days',
      rewardPoints: 80,
    ),
    HydrationChallenge(
      id: 'monthly_champion',
      title: 'Monthly Champion',
      description: 'Meet your goal 25 days out of 30',
      emoji: '👑',
      difficulty: ChallengeDifficulty.extreme,
      duration: ChallengeDuration.monthly,
      durationDays: 30,
      targetValue: 25,
      targetUnit: 'days',
      rewardPoints: 200,
      milestones: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
    ),
    HydrationChallenge(
      id: 'overachiever_week',
      title: 'Overachiever',
      description: 'Exceed your daily goal by 20% for 5 days',
      emoji: '🚀',
      difficulty: ChallengeDifficulty.hard,
      duration: ChallengeDuration.weekly,
      durationDays: 7,
      targetValue: 5,
      targetUnit: 'days',
      rewardPoints: 90,
    ),
    HydrationChallenge(
      id: 'consistent_drinker',
      title: 'Consistent Hydrator',
      description: 'Log at least 6 drinks every day for a week',
      emoji: '📊',
      difficulty: ChallengeDifficulty.medium,
      duration: ChallengeDuration.weekly,
      durationDays: 7,
      targetValue: 7,
      targetUnit: 'days',
      rewardPoints: 70,
    ),
    HydrationChallenge(
      id: 'no_alcohol_month',
      title: 'Sober Month',
      description: 'Go an entire month without alcoholic drinks',
      emoji: '🧘',
      difficulty: ChallengeDifficulty.extreme,
      duration: ChallengeDuration.monthly,
      durationDays: 30,
      targetValue: 30,
      targetUnit: 'days',
      rewardPoints: 150,
    ),
  ];
}

/// User's active and completed challenges
@HiveType(typeId: 38)
class UserChallenges extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final List<HydrationChallenge> activeChallenges;

  @HiveField(2)
  final List<HydrationChallenge> completedChallenges;

  @HiveField(3)
  final int totalChallengesCompleted;

  @HiveField(4)
  final int totalPointsEarned;

  UserChallenges({
    required this.id,
    List<HydrationChallenge>? activeChallenges,
    List<HydrationChallenge>? completedChallenges,
    this.totalChallengesCompleted = 0,
    this.totalPointsEarned = 0,
  })  : activeChallenges = activeChallenges ?? [],
        completedChallenges = completedChallenges ?? [];

  UserChallenges copyWith({
    List<HydrationChallenge>? activeChallenges,
    List<HydrationChallenge>? completedChallenges,
    int? totalChallengesCompleted,
    int? totalPointsEarned,
  }) {
    return UserChallenges(
      id: id,
      activeChallenges: activeChallenges ?? this.activeChallenges,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      totalChallengesCompleted: totalChallengesCompleted ?? this.totalChallengesCompleted,
      totalPointsEarned: totalPointsEarned ?? this.totalPointsEarned,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activeChallenges': activeChallenges.map((c) => c.toJson()).toList(),
    'completedChallenges': completedChallenges.map((c) => c.toJson()).toList(),
    'totalChallengesCompleted': totalChallengesCompleted,
    'totalPointsEarned': totalPointsEarned,
  };

  factory UserChallenges.fromJson(Map<String, dynamic> json) => UserChallenges(
    id: json['id'] ?? 'user',
    activeChallenges: (json['activeChallenges'] as List<dynamic>?)
        ?.map((c) => HydrationChallenge.fromJson(c))
        .toList(),
    completedChallenges: (json['completedChallenges'] as List<dynamic>?)
        ?.map((c) => HydrationChallenge.fromJson(c))
        .toList(),
    totalChallengesCompleted: json['totalChallengesCompleted'] ?? 0,
    totalPointsEarned: json['totalPointsEarned'] ?? 0,
  );
}
