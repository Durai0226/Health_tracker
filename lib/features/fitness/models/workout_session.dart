import 'dart:convert';
import 'exercise.dart';

/// Completed workout session
class WorkoutSession {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final int caloriesBurned;
  final int exercisesCompleted;
  final int totalExercises;
  final bool wasCompleted;
  final bool wasAbandoned;
  final List<ExerciseLog> exerciseLogs;
  final int? moodBefore;
  final int? moodAfter;
  final String? notes;
  final double? averageHeartRate;
  final BodyPart? primaryBodyPart;

  const WorkoutSession({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.startedAt,
    this.completedAt,
    required this.durationSeconds,
    this.caloriesBurned = 0,
    required this.exercisesCompleted,
    required this.totalExercises,
    this.wasCompleted = false,
    this.wasAbandoned = false,
    this.exerciseLogs = const [],
    this.moodBefore,
    this.moodAfter,
    this.notes,
    this.averageHeartRate,
    this.primaryBodyPart,
  });

  WorkoutSession copyWith({
    String? id,
    String? workoutId,
    String? workoutName,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationSeconds,
    int? caloriesBurned,
    int? exercisesCompleted,
    int? totalExercises,
    bool? wasCompleted,
    bool? wasAbandoned,
    List<ExerciseLog>? exerciseLogs,
    int? moodBefore,
    int? moodAfter,
    String? notes,
    double? averageHeartRate,
    BodyPart? primaryBodyPart,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      exercisesCompleted: exercisesCompleted ?? this.exercisesCompleted,
      totalExercises: totalExercises ?? this.totalExercises,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
      exerciseLogs: exerciseLogs ?? this.exerciseLogs,
      moodBefore: moodBefore ?? this.moodBefore,
      moodAfter: moodAfter ?? this.moodAfter,
      notes: notes ?? this.notes,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      primaryBodyPart: primaryBodyPart ?? this.primaryBodyPart,
    );
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Get completion percentage
  double get completionPercentage {
    if (totalExercises == 0) return 0;
    return exercisesCompleted / totalExercises;
  }

  /// Check if session is from today
  bool get isFromToday {
    final now = DateTime.now();
    return startedAt.year == now.year &&
        startedAt.month == now.month &&
        startedAt.day == now.day;
  }

  /// Check if session is from this week
  bool get isFromThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return startedAt.isAfter(startOfDay);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'workoutName': workoutName,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'caloriesBurned': caloriesBurned,
    'exercisesCompleted': exercisesCompleted,
    'totalExercises': totalExercises,
    'wasCompleted': wasCompleted,
    'wasAbandoned': wasAbandoned,
    'exerciseLogs': exerciseLogs.map((e) => e.toJson()).toList(),
    'moodBefore': moodBefore,
    'moodAfter': moodAfter,
    'notes': notes,
    'averageHeartRate': averageHeartRate,
    'primaryBodyPart': primaryBodyPart?.index,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] ?? '',
    workoutId: json['workoutId'] ?? '',
    workoutName: json['workoutName'] ?? '',
    startedAt: json['startedAt'] != null 
        ? DateTime.parse(json['startedAt']) 
        : DateTime.now(),
    completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt']) 
        : null,
    durationSeconds: json['durationSeconds'] ?? 0,
    caloriesBurned: json['caloriesBurned'] ?? 0,
    exercisesCompleted: json['exercisesCompleted'] ?? 0,
    totalExercises: json['totalExercises'] ?? 0,
    wasCompleted: json['wasCompleted'] ?? false,
    wasAbandoned: json['wasAbandoned'] ?? false,
    exerciseLogs: (json['exerciseLogs'] as List<dynamic>?)
        ?.map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    moodBefore: json['moodBefore'],
    moodAfter: json['moodAfter'],
    notes: json['notes'],
    averageHeartRate: json['averageHeartRate']?.toDouble(),
    primaryBodyPart: json['primaryBodyPart'] != null 
        ? BodyPart.values[json['primaryBodyPart']] 
        : null,
  );

  String toJsonString() => jsonEncode(toJson());

  factory WorkoutSession.fromJsonString(String jsonString) =>
      WorkoutSession.fromJson(jsonDecode(jsonString));
}

/// Log of a single exercise within a session
class ExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final int? repsCompleted;
  final bool wasCompleted;
  final bool wasSkipped;
  final int caloriesBurned;

  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.startedAt,
    this.completedAt,
    required this.durationSeconds,
    this.repsCompleted,
    this.wasCompleted = true,
    this.wasSkipped = false,
    this.caloriesBurned = 0,
  });

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'durationSeconds': durationSeconds,
    'repsCompleted': repsCompleted,
    'wasCompleted': wasCompleted,
    'wasSkipped': wasSkipped,
    'caloriesBurned': caloriesBurned,
  };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    exerciseId: json['exerciseId'] ?? '',
    exerciseName: json['exerciseName'] ?? '',
    startedAt: json['startedAt'] != null 
        ? DateTime.parse(json['startedAt']) 
        : DateTime.now(),
    completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt']) 
        : null,
    durationSeconds: json['durationSeconds'] ?? 0,
    repsCompleted: json['repsCompleted'],
    wasCompleted: json['wasCompleted'] ?? true,
    wasSkipped: json['wasSkipped'] ?? false,
    caloriesBurned: json['caloriesBurned'] ?? 0,
  );
}

/// Daily workout stats
class DailyWorkoutStats {
  final DateTime date;
  final int workoutsCompleted;
  final int totalDurationMinutes;
  final int totalCaloriesBurned;
  final List<String> bodyPartsWorked;
  final bool goalMet;

  const DailyWorkoutStats({
    required this.date,
    this.workoutsCompleted = 0,
    this.totalDurationMinutes = 0,
    this.totalCaloriesBurned = 0,
    this.bodyPartsWorked = const [],
    this.goalMet = false,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'workoutsCompleted': workoutsCompleted,
    'totalDurationMinutes': totalDurationMinutes,
    'totalCaloriesBurned': totalCaloriesBurned,
    'bodyPartsWorked': bodyPartsWorked,
    'goalMet': goalMet,
  };

  factory DailyWorkoutStats.fromJson(Map<String, dynamic> json) => DailyWorkoutStats(
    date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    workoutsCompleted: json['workoutsCompleted'] ?? 0,
    totalDurationMinutes: json['totalDurationMinutes'] ?? 0,
    totalCaloriesBurned: json['totalCaloriesBurned'] ?? 0,
    bodyPartsWorked: (json['bodyPartsWorked'] as List<dynamic>?)?.cast<String>() ?? [],
    goalMet: json['goalMet'] ?? false,
  );
}

/// Weekly workout summary
class WeeklyWorkoutSummary {
  final DateTime weekStartDate;
  final int totalWorkouts;
  final int totalMinutes;
  final int totalCalories;
  final int currentStreak;
  final Map<String, int> bodyPartFrequency;
  final List<DailyWorkoutStats> dailyStats;

  const WeeklyWorkoutSummary({
    required this.weekStartDate,
    this.totalWorkouts = 0,
    this.totalMinutes = 0,
    this.totalCalories = 0,
    this.currentStreak = 0,
    this.bodyPartFrequency = const {},
    this.dailyStats = const [],
  });

  /// Get average workout duration
  int get averageWorkoutMinutes {
    if (totalWorkouts == 0) return 0;
    return totalMinutes ~/ totalWorkouts;
  }

  /// Get most worked body part
  String? get mostWorkedBodyPart {
    if (bodyPartFrequency.isEmpty) return null;
    return bodyPartFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Map<String, dynamic> toJson() => {
    'weekStartDate': weekStartDate.toIso8601String(),
    'totalWorkouts': totalWorkouts,
    'totalMinutes': totalMinutes,
    'totalCalories': totalCalories,
    'currentStreak': currentStreak,
    'bodyPartFrequency': bodyPartFrequency,
    'dailyStats': dailyStats.map((d) => d.toJson()).toList(),
  };

  factory WeeklyWorkoutSummary.fromJson(Map<String, dynamic> json) => WeeklyWorkoutSummary(
    weekStartDate: json['weekStartDate'] != null 
        ? DateTime.parse(json['weekStartDate']) 
        : DateTime.now(),
    totalWorkouts: json['totalWorkouts'] ?? 0,
    totalMinutes: json['totalMinutes'] ?? 0,
    totalCalories: json['totalCalories'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    bodyPartFrequency: (json['bodyPartFrequency'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as int)) ?? {},
    dailyStats: (json['dailyStats'] as List<dynamic>?)
        ?.map((d) => DailyWorkoutStats.fromJson(d as Map<String, dynamic>))
        .toList() ?? [],
  );
}
