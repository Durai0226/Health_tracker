import 'package:hive/hive.dart';

part 'fitness_activity.g.dart';

/// FitnessActivity - Tracks completed workout sessions
/// Inspired by Fitbit, Strava, Apple Health, Google Fit best practices
@HiveType(typeId: 25)
class FitnessActivity extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // walk, gym, yoga, run, cycling, swimming

  @HiveField(2)
  final String title;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final DateTime? endTime;

  @HiveField(5)
  final int durationMinutes;

  @HiveField(6)
  final int? caloriesBurned;

  @HiveField(7)
  final double? distanceKm;

  @HiveField(8)
  final int? steps;

  @HiveField(9)
  final int? heartRateAvg;

  @HiveField(10)
  final String? notes;

  @HiveField(11)
  final bool isCompleted;

  @HiveField(12)
  final String? reminderId; // Link to FitnessReminder if triggered by one

  FitnessActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.startTime,
    this.endTime,
    this.durationMinutes = 0,
    this.caloriesBurned,
    this.distanceKm,
    this.steps,
    this.heartRateAvg,
    this.notes,
    this.isCompleted = false,
    this.reminderId,
  });

  /// Create a copy with updated fields
  FitnessActivity copyWith({
    String? id,
    String? type,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    int? caloriesBurned,
    double? distanceKm,
    int? steps,
    int? heartRateAvg,
    String? notes,
    bool? isCompleted,
    String? reminderId,
  }) {
    return FitnessActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceKm: distanceKm ?? this.distanceKm,
      steps: steps ?? this.steps,
      heartRateAvg: heartRateAvg ?? this.heartRateAvg,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderId: reminderId ?? this.reminderId,
    );
  }

  /// Get emoji for activity type
  String get emoji {
    switch (type) {
      case 'walk':
        return '🚶';
      case 'gym':
        return '🏋️';
      case 'yoga':
        return '🧘';
      case 'run':
        return '🏃';
      case 'cycling':
        return '🚴';
      case 'swimming':
        return '🏊';
      case 'hiit':
        return '⚡';
      case 'stretching':
        return '🤸';
      default:
        return '💪';
    }
  }

  /// Get display name for activity type
  String get displayType {
    switch (type) {
      case 'walk':
        return 'Walking';
      case 'gym':
        return 'Gym Workout';
      case 'yoga':
        return 'Yoga';
      case 'run':
        return 'Running';
      case 'cycling':
        return 'Cycling';
      case 'swimming':
        return 'Swimming';
      case 'hiit':
        return 'HIIT';
      case 'stretching':
        return 'Stretching';
      default:
        return 'Workout';
    }
  }

  /// Estimate calories burned based on activity type and duration
  /// Using MET (Metabolic Equivalent of Task) values
  static int estimateCalories(String type, int durationMinutes, {double weightKg = 70}) {
    final metValues = {
      'walk': 3.5,
      'run': 9.8,
      'cycling': 7.5,
      'swimming': 8.0,
      'gym': 6.0,
      'yoga': 3.0,
      'hiit': 10.0,
      'stretching': 2.5,
    };
    
    final met = metValues[type] ?? 5.0;
    // Calories = MET × weight (kg) × duration (hours)
    return ((met * weightKg * (durationMinutes / 60))).round();
  }

  /// Format duration as string
  String get formattedDuration {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  /// Format distance as string
  String get formattedDistance {
    if (distanceKm == null) return '-';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).round()} m';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationMinutes': durationMinutes,
    'caloriesBurned': caloriesBurned,
    'distanceKm': distanceKm,
    'steps': steps,
    'heartRateAvg': heartRateAvg,
    'notes': notes,
    'isCompleted': isCompleted,
    'reminderId': reminderId,
  };

  factory FitnessActivity.fromJson(Map<String, dynamic> json) => FitnessActivity(
    id: json['id'] ?? '',
    type: json['type'] ?? 'walk',
    title: json['title'] ?? '',
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    durationMinutes: json['durationMinutes'] ?? 0,
    caloriesBurned: json['caloriesBurned'],
    distanceKm: json['distanceKm']?.toDouble(),
    steps: json['steps'],
    heartRateAvg: json['heartRateAvg'],
    notes: json['notes'],
    isCompleted: json['isCompleted'] ?? false,
    reminderId: json['reminderId'],
  );
}

/// Weekly fitness goal tracking
@HiveType(typeId: 26)
class FitnessGoal extends HiveObject {
  @HiveField(0)
  final int weeklyWorkoutTarget; // Number of workouts per week

  @HiveField(1)
  final int weeklyMinutesTarget; // Total minutes per week

  @HiveField(2)
  final int weeklyCaloriesTarget; // Total calories per week

  @HiveField(3)
  final int dailyStepsTarget; // Daily steps goal

  @HiveField(4)
  final List<String> preferredActivities; // Preferred workout types

  FitnessGoal({
    this.weeklyWorkoutTarget = 5,
    this.weeklyMinutesTarget = 150,
    this.weeklyCaloriesTarget = 2000,
    this.dailyStepsTarget = 10000,
    this.preferredActivities = const ['walk', 'run', 'gym'],
  });

  FitnessGoal copyWith({
    int? weeklyWorkoutTarget,
    int? weeklyMinutesTarget,
    int? weeklyCaloriesTarget,
    int? dailyStepsTarget,
    List<String>? preferredActivities,
  }) {
    return FitnessGoal(
      weeklyWorkoutTarget: weeklyWorkoutTarget ?? this.weeklyWorkoutTarget,
      weeklyMinutesTarget: weeklyMinutesTarget ?? this.weeklyMinutesTarget,
      weeklyCaloriesTarget: weeklyCaloriesTarget ?? this.weeklyCaloriesTarget,
      dailyStepsTarget: dailyStepsTarget ?? this.dailyStepsTarget,
      preferredActivities: preferredActivities ?? this.preferredActivities,
    );
  }

  Map<String, dynamic> toJson() => {
    'weeklyWorkoutTarget': weeklyWorkoutTarget,
    'weeklyMinutesTarget': weeklyMinutesTarget,
    'weeklyCaloriesTarget': weeklyCaloriesTarget,
    'dailyStepsTarget': dailyStepsTarget,
    'preferredActivities': preferredActivities,
  };

  factory FitnessGoal.fromJson(Map<String, dynamic> json) => FitnessGoal(
    weeklyWorkoutTarget: json['weeklyWorkoutTarget'] ?? 5,
    weeklyMinutesTarget: json['weeklyMinutesTarget'] ?? 150,
    weeklyCaloriesTarget: json['weeklyCaloriesTarget'] ?? 2000,
    dailyStepsTarget: json['dailyStepsTarget'] ?? 10000,
    preferredActivities: (json['preferredActivities'] as List<dynamic>?)?.cast<String>() ?? ['walk', 'run', 'gym'],
  );
}
