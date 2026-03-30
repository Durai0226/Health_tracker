import 'dart:convert';
import 'exercise.dart';

/// User gender for personalized recommendations
enum Gender {
  male,
  female,
  other;

  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }
}

/// Equipment preference
enum EquipmentPreference {
  none,
  minimal,
  full;

  String get displayName {
    switch (this) {
      case EquipmentPreference.none:
        return 'No Equipment';
      case EquipmentPreference.minimal:
        return 'Minimal Equipment';
      case EquipmentPreference.full:
        return 'Full Gym Access';
    }
  }

  String get description {
    switch (this) {
      case EquipmentPreference.none:
        return 'Bodyweight exercises only';
      case EquipmentPreference.minimal:
        return 'Dumbbells, resistance bands';
      case EquipmentPreference.full:
        return 'Complete gym equipment';
    }
  }
}

/// User's fitness profile and preferences
class FitnessProfile {
  final String id;
  final String? name;
  final int? age;
  final Gender? gender;
  final EquipmentPreference equipmentPreference;
  final double? weightKg;
  final double? heightCm;
  final FitnessLevel fitnessLevel;
  final List<BodyPart> focusAreas;
  final FitnessGoal fitnessGoal;
  final int weeklyWorkoutTarget;
  final int dailyCalorieTarget;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool voiceGuidanceEnabled;
  final int restBetweenExercisesSeconds;
  final int countdownSeconds;
  final bool showExerciseTips;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FitnessProfile({
    required this.id,
    this.name,
    this.age,
    this.gender,
    this.equipmentPreference = EquipmentPreference.none,
    this.weightKg,
    this.heightCm,
    this.fitnessLevel = FitnessLevel.beginner,
    this.focusAreas = const [],
    this.fitnessGoal = FitnessGoal.stayFit,
    this.weeklyWorkoutTarget = 3,
    this.dailyCalorieTarget = 300,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.voiceGuidanceEnabled = true,
    this.restBetweenExercisesSeconds = 30,
    this.countdownSeconds = 3,
    this.showExerciseTips = true,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
    this.updatedAt,
  });

  FitnessProfile copyWith({
    String? id,
    String? name,
    int? age,
    Gender? gender,
    EquipmentPreference? equipmentPreference,
    double? weightKg,
    double? heightCm,
    FitnessLevel? fitnessLevel,
    List<BodyPart>? focusAreas,
    FitnessGoal? fitnessGoal,
    int? weeklyWorkoutTarget,
    int? dailyCalorieTarget,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? voiceGuidanceEnabled,
    int? restBetweenExercisesSeconds,
    int? countdownSeconds,
    bool? showExerciseTips,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FitnessProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      equipmentPreference: equipmentPreference ?? this.equipmentPreference,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      focusAreas: focusAreas ?? this.focusAreas,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      weeklyWorkoutTarget: weeklyWorkoutTarget ?? this.weeklyWorkoutTarget,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      restBetweenExercisesSeconds: restBetweenExercisesSeconds ?? this.restBetweenExercisesSeconds,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      showExerciseTips: showExerciseTips ?? this.showExerciseTips,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate BMI if height and weight available
  double? get bmi {
    if (weightKg == null || heightCm == null) return null;
    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  /// Get BMI category
  String? get bmiCategory {
    final calculatedBmi = bmi;
    if (calculatedBmi == null) return null;
    if (calculatedBmi < 18.5) return 'Underweight';
    if (calculatedBmi < 25) return 'Normal';
    if (calculatedBmi < 30) return 'Overweight';
    return 'Obese';
  }

  /// Get recommended workout difficulty
  ExerciseDifficulty get recommendedDifficulty {
    switch (fitnessLevel) {
      case FitnessLevel.beginner:
        return ExerciseDifficulty.beginner;
      case FitnessLevel.intermediate:
        return ExerciseDifficulty.intermediate;
      case FitnessLevel.advanced:
      case FitnessLevel.athlete:
        return ExerciseDifficulty.advanced;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'gender': gender?.index,
    'equipmentPreference': equipmentPreference.index,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'fitnessLevel': fitnessLevel.index,
    'focusAreas': focusAreas.map((b) => b.index).toList(),
    'fitnessGoal': fitnessGoal.index,
    'weeklyWorkoutTarget': weeklyWorkoutTarget,
    'dailyCalorieTarget': dailyCalorieTarget,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'voiceGuidanceEnabled': voiceGuidanceEnabled,
    'restBetweenExercisesSeconds': restBetweenExercisesSeconds,
    'countdownSeconds': countdownSeconds,
    'showExerciseTips': showExerciseTips,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory FitnessProfile.fromJson(Map<String, dynamic> json) => FitnessProfile(
    id: json['id'] ?? '',
    name: json['name'],
    age: json['age'],
    gender: json['gender'] != null ? Gender.values[json['gender']] : null,
    equipmentPreference: EquipmentPreference.values[json['equipmentPreference'] ?? 0],
    weightKg: json['weightKg']?.toDouble(),
    heightCm: json['heightCm']?.toDouble(),
    fitnessLevel: FitnessLevel.values[json['fitnessLevel'] ?? 0],
    focusAreas: (json['focusAreas'] as List<dynamic>?)
        ?.map((i) => BodyPart.values[i as int])
        .toList() ?? [],
    fitnessGoal: FitnessGoal.values[json['fitnessGoal'] ?? 0],
    weeklyWorkoutTarget: json['weeklyWorkoutTarget'] ?? 3,
    dailyCalorieTarget: json['dailyCalorieTarget'] ?? 300,
    soundEnabled: json['soundEnabled'] ?? true,
    vibrationEnabled: json['vibrationEnabled'] ?? true,
    voiceGuidanceEnabled: json['voiceGuidanceEnabled'] ?? true,
    restBetweenExercisesSeconds: json['restBetweenExercisesSeconds'] ?? 30,
    countdownSeconds: json['countdownSeconds'] ?? 3,
    showExerciseTips: json['showExerciseTips'] ?? true,
    hasCompletedOnboarding: json['hasCompletedOnboarding'] ?? false,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt']) 
        : null,
  );

  String toJsonString() => jsonEncode(toJson());

  factory FitnessProfile.fromJsonString(String jsonString) =>
      FitnessProfile.fromJson(jsonDecode(jsonString));

  /// Create default profile
  factory FitnessProfile.defaultProfile() => FitnessProfile(
    id: 'default',
    fitnessLevel: FitnessLevel.beginner,
    fitnessGoal: FitnessGoal.stayFit,
    createdAt: DateTime.now(),
  );
}

/// User's fitness level
enum FitnessLevel {
  beginner,
  intermediate,
  advanced,
  athlete;

  String get displayName {
    switch (this) {
      case FitnessLevel.beginner:
        return 'Beginner';
      case FitnessLevel.intermediate:
        return 'Intermediate';
      case FitnessLevel.advanced:
        return 'Advanced';
      case FitnessLevel.athlete:
        return 'Athlete';
    }
  }

  String get description {
    switch (this) {
      case FitnessLevel.beginner:
        return 'New to fitness or returning after a break';
      case FitnessLevel.intermediate:
        return 'Regular exercise for 6+ months';
      case FitnessLevel.advanced:
        return 'Consistent training for 2+ years';
      case FitnessLevel.athlete:
        return 'Competitive or professional level';
    }
  }
}

/// User's fitness goal
enum FitnessGoal {
  loseWeight,
  buildMuscle,
  stayFit,
  increaseEndurance,
  improveFlexibility,
  gainStrength;

  String get displayName {
    switch (this) {
      case FitnessGoal.loseWeight:
        return 'Lose Weight';
      case FitnessGoal.buildMuscle:
        return 'Build Muscle';
      case FitnessGoal.stayFit:
        return 'Stay Fit';
      case FitnessGoal.increaseEndurance:
        return 'Increase Endurance';
      case FitnessGoal.improveFlexibility:
        return 'Improve Flexibility';
      case FitnessGoal.gainStrength:
        return 'Gain Strength';
    }
  }

  String get emoji {
    switch (this) {
      case FitnessGoal.loseWeight:
        return '🏃';
      case FitnessGoal.buildMuscle:
        return '💪';
      case FitnessGoal.stayFit:
        return '❤️';
      case FitnessGoal.increaseEndurance:
        return '🚴';
      case FitnessGoal.improveFlexibility:
        return '🧘';
      case FitnessGoal.gainStrength:
        return '🏋️';
    }
  }
}

/// Fitness achievements
class FitnessAchievement {
  final String id;
  final String title;
  final String description;
  final String iconEmoji;
  final AchievementType type;
  final int targetValue;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const FitnessAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconEmoji,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  double get progress {
    if (targetValue == 0) return 0;
    return (currentValue / targetValue).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'iconEmoji': iconEmoji,
    'type': type.index,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory FitnessAchievement.fromJson(Map<String, dynamic> json) => FitnessAchievement(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    iconEmoji: json['iconEmoji'] ?? '🏆',
    type: AchievementType.values[json['type'] ?? 0],
    targetValue: json['targetValue'] ?? 0,
    currentValue: json['currentValue'] ?? 0,
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null 
        ? DateTime.parse(json['unlockedAt']) 
        : null,
  );
}

enum AchievementType {
  workoutsCompleted,
  streakDays,
  caloriesBurned,
  minutesExercised,
  bodyPartsWorked,
}
