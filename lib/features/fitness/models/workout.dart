import 'dart:convert';
import 'exercise.dart';

/// Workout model containing a collection of exercises
class Workout {
  final String id;
  final String name;
  final String description;
  final BodyPart primaryBodyPart;
  final List<BodyPart> targetedBodyParts;
  final ExerciseDifficulty difficulty;
  final List<WorkoutExercise> exercises;
  final int estimatedDurationMinutes;
  final int estimatedCalories;
  final String? imageUrl;
  final String? thumbnailUrl;
  final bool isCustom;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? lastCompletedAt;
  final int completedCount;
  final List<String> tags;

  /// Returns true if any exercise in the workout requires equipment
  /// This is a computed property based on the workout's tags or exercise requirements
  bool get requiresEquipment => tags.contains('equipment') || tags.contains('with_equipment');

  const Workout({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryBodyPart,
    this.targetedBodyParts = const [],
    required this.difficulty,
    required this.exercises,
    required this.estimatedDurationMinutes,
    this.estimatedCalories = 0,
    this.imageUrl,
    this.thumbnailUrl,
    this.isCustom = false,
    this.isFavorite = false,
    required this.createdAt,
    this.lastCompletedAt,
    this.completedCount = 0,
    this.tags = const [],
  });

  Workout copyWith({
    String? id,
    String? name,
    String? description,
    BodyPart? primaryBodyPart,
    List<BodyPart>? targetedBodyParts,
    ExerciseDifficulty? difficulty,
    List<WorkoutExercise>? exercises,
    int? estimatedDurationMinutes,
    int? estimatedCalories,
    String? imageUrl,
    String? thumbnailUrl,
    bool? isCustom,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? lastCompletedAt,
    int? completedCount,
    List<String>? tags,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      primaryBodyPart: primaryBodyPart ?? this.primaryBodyPart,
      targetedBodyParts: targetedBodyParts ?? this.targetedBodyParts,
      difficulty: difficulty ?? this.difficulty,
      exercises: exercises ?? this.exercises,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      completedCount: completedCount ?? this.completedCount,
      tags: tags ?? this.tags,
    );
  }

  /// Calculate total workout duration including rest periods
  int get totalDurationSeconds {
    int total = 0;
    for (final exercise in exercises) {
      total += exercise.effectiveDurationSeconds;
      total += exercise.restAfterSeconds;
    }
    return total;
  }

  /// Get formatted duration string
  String get formattedDuration {
    final mins = estimatedDurationMinutes;
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
  }

  /// Get exercise count
  int get exerciseCount => exercises.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'primaryBodyPart': primaryBodyPart.index,
    'targetedBodyParts': targetedBodyParts.map((b) => b.index).toList(),
    'difficulty': difficulty.index,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'estimatedCalories': estimatedCalories,
    'imageUrl': imageUrl,
    'thumbnailUrl': thumbnailUrl,
    'isCustom': isCustom,
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
    'lastCompletedAt': lastCompletedAt?.toIso8601String(),
    'completedCount': completedCount,
    'tags': tags,
  };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    primaryBodyPart: BodyPart.values[json['primaryBodyPart'] ?? 0],
    targetedBodyParts: (json['targetedBodyParts'] as List<dynamic>?)
        ?.map((i) => BodyPart.values[i as int])
        .toList() ?? [],
    difficulty: ExerciseDifficulty.values[json['difficulty'] ?? 0],
    exercises: (json['exercises'] as List<dynamic>?)
        ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    estimatedDurationMinutes: json['estimatedDurationMinutes'] ?? 0,
    estimatedCalories: json['estimatedCalories'] ?? 0,
    imageUrl: json['imageUrl'],
    thumbnailUrl: json['thumbnailUrl'],
    isCustom: json['isCustom'] ?? false,
    isFavorite: json['isFavorite'] ?? false,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
    lastCompletedAt: json['lastCompletedAt'] != null 
        ? DateTime.parse(json['lastCompletedAt']) 
        : null,
    completedCount: json['completedCount'] ?? 0,
    tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
  );

  String toJsonString() => jsonEncode(toJson());

  factory Workout.fromJsonString(String jsonString) =>
      Workout.fromJson(jsonDecode(jsonString));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workout && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Workout plan - multi-day program
class WorkoutPlan {
  final String id;
  final String name;
  final String description;
  final int durationWeeks;
  final ExerciseDifficulty difficulty;
  final List<WorkoutPlanDay> days;
  final String? imageUrl;
  final bool isCustom;
  final DateTime createdAt;
  final int currentDay;
  final bool isActive;

  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.durationWeeks,
    required this.difficulty,
    required this.days,
    this.imageUrl,
    this.isCustom = false,
    required this.createdAt,
    this.currentDay = 0,
    this.isActive = false,
  });

  WorkoutPlan copyWith({
    String? id,
    String? name,
    String? description,
    int? durationWeeks,
    ExerciseDifficulty? difficulty,
    List<WorkoutPlanDay>? days,
    String? imageUrl,
    bool? isCustom,
    DateTime? createdAt,
    int? currentDay,
    bool? isActive,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      difficulty: difficulty ?? this.difficulty,
      days: days ?? this.days,
      imageUrl: imageUrl ?? this.imageUrl,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      currentDay: currentDay ?? this.currentDay,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get progress percentage
  double get progressPercentage {
    if (days.isEmpty) return 0;
    return currentDay / days.length;
  }

  /// Get total workouts in plan
  int get totalWorkouts => days.where((d) => !d.isRestDay).length;

  /// Get completed workouts
  int get completedWorkouts => currentDay;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'durationWeeks': durationWeeks,
    'difficulty': difficulty.index,
    'days': days.map((d) => d.toJson()).toList(),
    'imageUrl': imageUrl,
    'isCustom': isCustom,
    'createdAt': createdAt.toIso8601String(),
    'currentDay': currentDay,
    'isActive': isActive,
  };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    durationWeeks: json['durationWeeks'] ?? 1,
    difficulty: ExerciseDifficulty.values[json['difficulty'] ?? 0],
    days: (json['days'] as List<dynamic>?)
        ?.map((d) => WorkoutPlanDay.fromJson(d as Map<String, dynamic>))
        .toList() ?? [],
    imageUrl: json['imageUrl'],
    isCustom: json['isCustom'] ?? false,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
    currentDay: json['currentDay'] ?? 0,
    isActive: json['isActive'] ?? false,
  );
}

/// Single day in a workout plan
class WorkoutPlanDay {
  final int dayNumber;
  final String? workoutId;
  final bool isRestDay;
  final String? note;
  final bool isCompleted;
  final DateTime? completedAt;

  const WorkoutPlanDay({
    required this.dayNumber,
    this.workoutId,
    this.isRestDay = false,
    this.note,
    this.isCompleted = false,
    this.completedAt,
  });

  WorkoutPlanDay copyWith({
    int? dayNumber,
    String? workoutId,
    bool? isRestDay,
    String? note,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return WorkoutPlanDay(
      dayNumber: dayNumber ?? this.dayNumber,
      workoutId: workoutId ?? this.workoutId,
      isRestDay: isRestDay ?? this.isRestDay,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'workoutId': workoutId,
    'isRestDay': isRestDay,
    'note': note,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory WorkoutPlanDay.fromJson(Map<String, dynamic> json) => WorkoutPlanDay(
    dayNumber: json['dayNumber'] ?? 0,
    workoutId: json['workoutId'],
    isRestDay: json['isRestDay'] ?? false,
    note: json['note'],
    isCompleted: json['isCompleted'] ?? false,
    completedAt: json['completedAt'] != null 
        ? DateTime.parse(json['completedAt']) 
        : null,
  );
}
