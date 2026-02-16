import 'package:hive/hive.dart';

part 'hydration_profile.g.dart';

/// Activity level for goal calculation
@HiveType(typeId: 22)
enum ActivityLevel {
  @HiveField(0)
  sedentary, // Little to no exercise

  @HiveField(1)
  light, // Light exercise 1-3 days/week

  @HiveField(2)
  moderate, // Moderate exercise 3-5 days/week

  @HiveField(3)
  active, // Hard exercise 6-7 days/week

  @HiveField(4)
  veryActive, // Very hard exercise, physical job
}

/// Climate type for goal adjustment
@HiveType(typeId: 23)
enum ClimateType {
  @HiveField(0)
  cold, // < 10°C

  @HiveField(1)
  moderate, // 10-25°C

  @HiveField(2)
  warm, // 25-30°C

  @HiveField(3)
  hot, // 30-35°C

  @HiveField(4)
  veryHot, // > 35°C
}

/// User's hydration profile for personalized goal calculation
@HiveType(typeId: 24)
class HydrationProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double? weightKg;

  @HiveField(2)
  final int? heightCm;

  @HiveField(3)
  final int? age;

  @HiveField(4)
  final bool isMale;

  @HiveField(5)
  final ActivityLevel activityLevel;

  @HiveField(6)
  final ClimateType climate;

  @HiveField(7)
  final bool isPregnant;

  @HiveField(8)
  final bool isBreastfeeding;

  @HiveField(9)
  final int customGoalMl; // User can override calculated goal

  @HiveField(10)
  final bool useCustomGoal;

  @HiveField(11)
  final DateTime? createdAt;

  @HiveField(12)
  final DateTime? updatedAt;

  @HiveField(13)
  final bool wakeUpReminderEnabled;

  @HiveField(14)
  final int? wakeUpHour;

  @HiveField(15)
  final int? bedtimeHour;

  HydrationProfile({
    required this.id,
    this.weightKg,
    this.heightCm,
    this.age,
    this.isMale = true,
    this.activityLevel = ActivityLevel.moderate,
    this.climate = ClimateType.moderate,
    this.isPregnant = false,
    this.isBreastfeeding = false,
    this.customGoalMl = 2500,
    this.useCustomGoal = false,
    this.createdAt,
    this.updatedAt,
    this.wakeUpReminderEnabled = true,
    this.wakeUpHour = 7,
    this.bedtimeHour = 22,
  });

  /// Calculate recommended daily water intake based on profile
  int get calculatedGoalMl {
    if (weightKg == null) return 2500; // Default

    // Base calculation: 30-35ml per kg of body weight
    double baseMl = weightKg! * 33;

    // Activity level adjustment
    switch (activityLevel) {
      case ActivityLevel.sedentary:
        baseMl *= 0.9;
        break;
      case ActivityLevel.light:
        baseMl *= 1.0;
        break;
      case ActivityLevel.moderate:
        baseMl *= 1.1;
        break;
      case ActivityLevel.active:
        baseMl *= 1.2;
        break;
      case ActivityLevel.veryActive:
        baseMl *= 1.35;
        break;
    }

    // Climate adjustment
    switch (climate) {
      case ClimateType.cold:
        baseMl *= 0.9;
        break;
      case ClimateType.moderate:
        baseMl *= 1.0;
        break;
      case ClimateType.warm:
        baseMl *= 1.1;
        break;
      case ClimateType.hot:
        baseMl *= 1.2;
        break;
      case ClimateType.veryHot:
        baseMl *= 1.35;
        break;
    }

    // Gender adjustment (women typically need slightly less)
    if (!isMale) {
      baseMl *= 0.9;
    }

    // Pregnancy/breastfeeding adjustment
    if (isPregnant) {
      baseMl += 300;
    }
    if (isBreastfeeding) {
      baseMl += 700;
    }

    // Age adjustment (older adults may need reminders but similar amounts)
    if (age != null && age! > 65) {
      baseMl *= 0.95;
    }

    return baseMl.round().clamp(1500, 5000);
  }

  /// Get the effective daily goal (custom or calculated)
  int get effectiveGoalMl => useCustomGoal ? customGoalMl : calculatedGoalMl;

  /// Get activity level as display string
  String get activityLevelString {
    switch (activityLevel) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Lightly Active';
      case ActivityLevel.moderate:
        return 'Moderately Active';
      case ActivityLevel.active:
        return 'Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
    }
  }

  /// Get climate as display string
  String get climateString {
    switch (climate) {
      case ClimateType.cold:
        return 'Cold';
      case ClimateType.moderate:
        return 'Moderate';
      case ClimateType.warm:
        return 'Warm';
      case ClimateType.hot:
        return 'Hot';
      case ClimateType.veryHot:
        return 'Very Hot';
    }
  }

  HydrationProfile copyWith({
    double? weightKg,
    int? heightCm,
    int? age,
    bool? isMale,
    ActivityLevel? activityLevel,
    ClimateType? climate,
    bool? isPregnant,
    bool? isBreastfeeding,
    int? customGoalMl,
    bool? useCustomGoal,
    DateTime? updatedAt,
    bool? wakeUpReminderEnabled,
    int? wakeUpHour,
    int? bedtimeHour,
  }) {
    return HydrationProfile(
      id: id,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      isMale: isMale ?? this.isMale,
      activityLevel: activityLevel ?? this.activityLevel,
      climate: climate ?? this.climate,
      isPregnant: isPregnant ?? this.isPregnant,
      isBreastfeeding: isBreastfeeding ?? this.isBreastfeeding,
      customGoalMl: customGoalMl ?? this.customGoalMl,
      useCustomGoal: useCustomGoal ?? this.useCustomGoal,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      wakeUpReminderEnabled: wakeUpReminderEnabled ?? this.wakeUpReminderEnabled,
      wakeUpHour: wakeUpHour ?? this.wakeUpHour,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'age': age,
    'isMale': isMale,
    'activityLevel': activityLevel.index,
    'climate': climate.index,
    'isPregnant': isPregnant,
    'isBreastfeeding': isBreastfeeding,
    'customGoalMl': customGoalMl,
    'useCustomGoal': useCustomGoal,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'wakeUpReminderEnabled': wakeUpReminderEnabled,
    'wakeUpHour': wakeUpHour,
    'bedtimeHour': bedtimeHour,
  };

  factory HydrationProfile.fromJson(Map<String, dynamic> json) => HydrationProfile(
    id: json['id'] ?? 'default',
    weightKg: json['weightKg']?.toDouble(),
    heightCm: json['heightCm'],
    age: json['age'],
    isMale: json['isMale'] ?? true,
    activityLevel: ActivityLevel.values[json['activityLevel'] ?? 2],
    climate: ClimateType.values[json['climate'] ?? 1],
    isPregnant: json['isPregnant'] ?? false,
    isBreastfeeding: json['isBreastfeeding'] ?? false,
    customGoalMl: json['customGoalMl'] ?? 2500,
    useCustomGoal: json['useCustomGoal'] ?? false,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    wakeUpReminderEnabled: json['wakeUpReminderEnabled'] ?? true,
    wakeUpHour: json['wakeUpHour'] ?? 7,
    bedtimeHour: json['bedtimeHour'] ?? 22,
  );
}
