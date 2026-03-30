/// A multi-day workout challenge/program
class WorkoutChallenge {
  final String id;
  final String name;
  final String description;
  final int durationDays;
  final ChallengeDifficulty difficulty;
  final ChallengeCategory category;
  final List<ChallengeDay> days;
  final String? imageUrl;
  final int estimatedCaloriesTotal;
  final List<String> benefits;
  final bool isPremium;
  final DateTime createdAt;

  const WorkoutChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.durationDays,
    required this.difficulty,
    required this.category,
    required this.days,
    this.imageUrl,
    this.estimatedCaloriesTotal = 0,
    this.benefits = const [],
    this.isPremium = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'durationDays': durationDays,
    'difficulty': difficulty.index,
    'category': category.index,
    'days': days.map((d) => d.toJson()).toList(),
    'imageUrl': imageUrl,
    'estimatedCaloriesTotal': estimatedCaloriesTotal,
    'benefits': benefits,
    'isPremium': isPremium,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkoutChallenge.fromJson(Map<String, dynamic> json) => WorkoutChallenge(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    durationDays: json['durationDays'],
    difficulty: ChallengeDifficulty.values[json['difficulty']],
    category: ChallengeCategory.values[json['category']],
    days: (json['days'] as List).map((d) => ChallengeDay.fromJson(d)).toList(),
    imageUrl: json['imageUrl'],
    estimatedCaloriesTotal: json['estimatedCaloriesTotal'] ?? 0,
    benefits: List<String>.from(json['benefits'] ?? []),
    isPremium: json['isPremium'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );
}

/// A single day in a challenge
class ChallengeDay {
  final int dayNumber;
  final String title;
  final String? description;
  final String? workoutId;
  final bool isRestDay;
  final List<String> exercises;
  final int estimatedMinutes;
  final int estimatedCalories;

  const ChallengeDay({
    required this.dayNumber,
    required this.title,
    this.description,
    this.workoutId,
    this.isRestDay = false,
    this.exercises = const [],
    this.estimatedMinutes = 0,
    this.estimatedCalories = 0,
  });

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'title': title,
    'description': description,
    'workoutId': workoutId,
    'isRestDay': isRestDay,
    'exercises': exercises,
    'estimatedMinutes': estimatedMinutes,
    'estimatedCalories': estimatedCalories,
  };

  factory ChallengeDay.fromJson(Map<String, dynamic> json) => ChallengeDay(
    dayNumber: json['dayNumber'],
    title: json['title'],
    description: json['description'],
    workoutId: json['workoutId'],
    isRestDay: json['isRestDay'] ?? false,
    exercises: List<String>.from(json['exercises'] ?? []),
    estimatedMinutes: json['estimatedMinutes'] ?? 0,
    estimatedCalories: json['estimatedCalories'] ?? 0,
  );
}

/// User's progress in a challenge
class ChallengeProgress {
  final String id;
  final String challengeId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int currentDay;
  final List<int> completedDays;
  final int totalCaloriesBurned;
  final int totalMinutes;
  final bool isActive;

  const ChallengeProgress({
    required this.id,
    required this.challengeId,
    required this.startedAt,
    this.completedAt,
    this.currentDay = 1,
    this.completedDays = const [],
    this.totalCaloriesBurned = 0,
    this.totalMinutes = 0,
    this.isActive = true,
  });

  double get progressPercent {
    if (completedDays.isEmpty) return 0;
    return completedDays.length / 30; // Assuming 30-day challenges
  }

  bool isDayCompleted(int day) => completedDays.contains(day);

  ChallengeProgress copyWith({
    String? id,
    String? challengeId,
    DateTime? startedAt,
    DateTime? completedAt,
    int? currentDay,
    List<int>? completedDays,
    int? totalCaloriesBurned,
    int? totalMinutes,
    bool? isActive,
  }) => ChallengeProgress(
    id: id ?? this.id,
    challengeId: challengeId ?? this.challengeId,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    currentDay: currentDay ?? this.currentDay,
    completedDays: completedDays ?? this.completedDays,
    totalCaloriesBurned: totalCaloriesBurned ?? this.totalCaloriesBurned,
    totalMinutes: totalMinutes ?? this.totalMinutes,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'challengeId': challengeId,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'currentDay': currentDay,
    'completedDays': completedDays,
    'totalCaloriesBurned': totalCaloriesBurned,
    'totalMinutes': totalMinutes,
    'isActive': isActive,
  };

  factory ChallengeProgress.fromJson(Map<String, dynamic> json) => ChallengeProgress(
    id: json['id'],
    challengeId: json['challengeId'],
    startedAt: DateTime.parse(json['startedAt']),
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    currentDay: json['currentDay'] ?? 1,
    completedDays: List<int>.from(json['completedDays'] ?? []),
    totalCaloriesBurned: json['totalCaloriesBurned'] ?? 0,
    totalMinutes: json['totalMinutes'] ?? 0,
    isActive: json['isActive'] ?? true,
  );
}

enum ChallengeDifficulty {
  beginner,
  intermediate,
  advanced;

  String get displayName {
    switch (this) {
      case ChallengeDifficulty.beginner:
        return 'Beginner';
      case ChallengeDifficulty.intermediate:
        return 'Intermediate';
      case ChallengeDifficulty.advanced:
        return 'Advanced';
    }
  }
}

enum ChallengeCategory {
  weightLoss,
  muscleBuilding,
  flexibility,
  endurance,
  fullBody,
  abs,
  legs,
  arms;

  String get displayName {
    switch (this) {
      case ChallengeCategory.weightLoss:
        return 'Weight Loss';
      case ChallengeCategory.muscleBuilding:
        return 'Muscle Building';
      case ChallengeCategory.flexibility:
        return 'Flexibility';
      case ChallengeCategory.endurance:
        return 'Endurance';
      case ChallengeCategory.fullBody:
        return 'Full Body';
      case ChallengeCategory.abs:
        return 'Abs';
      case ChallengeCategory.legs:
        return 'Legs';
      case ChallengeCategory.arms:
        return 'Arms';
    }
  }

  String get emoji {
    switch (this) {
      case ChallengeCategory.weightLoss:
        return '🔥';
      case ChallengeCategory.muscleBuilding:
        return '💪';
      case ChallengeCategory.flexibility:
        return '🧘';
      case ChallengeCategory.endurance:
        return '🏃';
      case ChallengeCategory.fullBody:
        return '⚡';
      case ChallengeCategory.abs:
        return '🎯';
      case ChallengeCategory.legs:
        return '🦵';
      case ChallengeCategory.arms:
        return '💪';
    }
  }
}
