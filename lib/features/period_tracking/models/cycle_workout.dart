import '../theme/flo_theme.dart';

/// Workout model tailored to cycle phases
class CycleWorkout {
  final String id;
  final String name;
  final String description;
  final WorkoutCategory category;
  final int durationMinutes;
  final int caloriesBurned;
  final WorkoutIntensity intensity;
  final List<CyclePhaseType> recommendedPhases;
  final String? imageUrl;
  final String? videoUrl;
  final List<WorkoutStep> steps;
  final bool isPremium;

  const CycleWorkout({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.intensity,
    required this.recommendedPhases,
    this.imageUrl,
    this.videoUrl,
    this.steps = const [],
    this.isPremium = false,
  });

  /// Check if workout is recommended for given phase
  bool isRecommendedFor(CyclePhaseType phase) {
    return recommendedPhases.contains(phase);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category.index,
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'intensity': intensity.index,
        'recommendedPhases': recommendedPhases.map((p) => p.index).toList(),
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'steps': steps.map((s) => s.toJson()).toList(),
        'isPremium': isPremium,
      };

  factory CycleWorkout.fromJson(Map<String, dynamic> json) => CycleWorkout(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        category: WorkoutCategory.values[json['category']],
        durationMinutes: json['durationMinutes'],
        caloriesBurned: json['caloriesBurned'],
        intensity: WorkoutIntensity.values[json['intensity']],
        recommendedPhases: (json['recommendedPhases'] as List)
            .map((p) => CyclePhaseType.values[p])
            .toList(),
        imageUrl: json['imageUrl'],
        videoUrl: json['videoUrl'],
        steps: (json['steps'] as List?)
                ?.map((s) => WorkoutStep.fromJson(s))
                .toList() ??
            [],
        isPremium: json['isPremium'] ?? false,
      );
}

/// Workout categories matching the Flo design
enum WorkoutCategory {
  meditation,
  yoga,
  workouts,
  dietPlan,
  stretching,
  breathing,
  cardio,
  strength,
}

extension WorkoutCategoryExtension on WorkoutCategory {
  String get displayName {
    switch (this) {
      case WorkoutCategory.meditation:
        return 'Meditation';
      case WorkoutCategory.yoga:
        return 'Yoga';
      case WorkoutCategory.workouts:
        return 'Workouts';
      case WorkoutCategory.dietPlan:
        return 'Diet Plan';
      case WorkoutCategory.stretching:
        return 'Stretching';
      case WorkoutCategory.breathing:
        return 'Breathing';
      case WorkoutCategory.cardio:
        return 'Cardio';
      case WorkoutCategory.strength:
        return 'Strength';
    }
  }

  String get icon {
    switch (this) {
      case WorkoutCategory.meditation:
        return '🧘';
      case WorkoutCategory.yoga:
        return '🧘‍♀️';
      case WorkoutCategory.workouts:
        return '💪';
      case WorkoutCategory.dietPlan:
        return '🥗';
      case WorkoutCategory.stretching:
        return '🤸';
      case WorkoutCategory.breathing:
        return '🌬️';
      case WorkoutCategory.cardio:
        return '🏃‍♀️';
      case WorkoutCategory.strength:
        return '🏋️';
    }
  }
}

/// Workout intensity levels
enum WorkoutIntensity {
  low,
  medium,
  high,
}

extension WorkoutIntensityExtension on WorkoutIntensity {
  String get displayName {
    switch (this) {
      case WorkoutIntensity.low:
        return 'Low';
      case WorkoutIntensity.medium:
        return 'Medium';
      case WorkoutIntensity.high:
        return 'High';
    }
  }

  /// Best intensities for each phase
  static List<WorkoutIntensity> forPhase(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return [WorkoutIntensity.low];
      case CyclePhaseType.follicular:
        return [WorkoutIntensity.medium, WorkoutIntensity.high];
      case CyclePhaseType.ovulation:
        return [WorkoutIntensity.high];
      case CyclePhaseType.luteal:
        return [WorkoutIntensity.low, WorkoutIntensity.medium];
      case CyclePhaseType.pms:
        return [WorkoutIntensity.low];
    }
  }
}

/// Individual workout step
class WorkoutStep {
  final String name;
  final String? description;
  final int durationSeconds;
  final int? reps;
  final String? imageUrl;

  const WorkoutStep({
    required this.name,
    this.description,
    required this.durationSeconds,
    this.reps,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'durationSeconds': durationSeconds,
        'reps': reps,
        'imageUrl': imageUrl,
      };

  factory WorkoutStep.fromJson(Map<String, dynamic> json) => WorkoutStep(
        name: json['name'],
        description: json['description'],
        durationSeconds: json['durationSeconds'],
        reps: json['reps'],
        imageUrl: json['imageUrl'],
      );
}

/// User's workout log
class WorkoutLog {
  final String id;
  final String workoutId;
  final DateTime completedAt;
  final int durationMinutes;
  final int caloriesBurned;
  final CyclePhaseType? phaseWhenCompleted;
  final String? notes;
  final int? rating; // 1-5

  WorkoutLog({
    required this.id,
    required this.workoutId,
    required this.completedAt,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.phaseWhenCompleted,
    this.notes,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'completedAt': completedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'phaseWhenCompleted': phaseWhenCompleted?.index,
        'notes': notes,
        'rating': rating,
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'],
        workoutId: json['workoutId'],
        completedAt: DateTime.parse(json['completedAt']),
        durationMinutes: json['durationMinutes'],
        caloriesBurned: json['caloriesBurned'],
        phaseWhenCompleted: json['phaseWhenCompleted'] != null
            ? CyclePhaseType.values[json['phaseWhenCompleted']]
            : null,
        notes: json['notes'],
        rating: json['rating'],
      );
}

/// Workout progress tracking
class WorkoutProgress {
  final int totalWorkoutsCompleted;
  final int totalMinutes;
  final int totalCaloriesBurned;
  final int currentStreak;
  final int longestStreak;
  final Map<WorkoutCategory, int> categoryCount;
  final double weeklyGoalPercent;

  WorkoutProgress({
    this.totalWorkoutsCompleted = 0,
    this.totalMinutes = 0,
    this.totalCaloriesBurned = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.categoryCount = const {},
    this.weeklyGoalPercent = 0,
  });

  Map<String, dynamic> toJson() => {
        'totalWorkoutsCompleted': totalWorkoutsCompleted,
        'totalMinutes': totalMinutes,
        'totalCaloriesBurned': totalCaloriesBurned,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'categoryCount':
            categoryCount.map((k, v) => MapEntry(k.index.toString(), v)),
        'weeklyGoalPercent': weeklyGoalPercent,
      };

  factory WorkoutProgress.fromJson(Map<String, dynamic> json) =>
      WorkoutProgress(
        totalWorkoutsCompleted: json['totalWorkoutsCompleted'] ?? 0,
        totalMinutes: json['totalMinutes'] ?? 0,
        totalCaloriesBurned: json['totalCaloriesBurned'] ?? 0,
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        categoryCount: (json['categoryCount'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(WorkoutCategory.values[int.parse(k)], v)) ??
            {},
        weeklyGoalPercent: (json['weeklyGoalPercent'] ?? 0).toDouble(),
      );
}

/// Predefined workouts for each phase
class PhaseWorkouts {
  static List<CycleWorkout> getForPhase(CyclePhaseType phase) {
    switch (phase) {
      case CyclePhaseType.menstrual:
        return _menstrualWorkouts;
      case CyclePhaseType.follicular:
        return _follicularWorkouts;
      case CyclePhaseType.ovulation:
        return _ovulationWorkouts;
      case CyclePhaseType.luteal:
        return _lutealWorkouts;
      case CyclePhaseType.pms:
        return _pmsWorkouts;
    }
  }

  static const List<CycleWorkout> _menstrualWorkouts = [
    CycleWorkout(
      id: 'menstrual_1',
      name: 'Gentle Stretching',
      description: 'Soothing stretches to ease cramps and tension',
      category: WorkoutCategory.stretching,
      durationMinutes: 15,
      caloriesBurned: 50,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.menstrual, CyclePhaseType.pms],
    ),
    CycleWorkout(
      id: 'menstrual_2',
      name: 'Restorative Yoga',
      description: 'Calming poses for relaxation and comfort',
      category: WorkoutCategory.yoga,
      durationMinutes: 20,
      caloriesBurned: 60,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.menstrual],
    ),
    CycleWorkout(
      id: 'menstrual_3',
      name: 'Deep Breathing',
      description: 'Breathing exercises to reduce stress and pain',
      category: WorkoutCategory.breathing,
      durationMinutes: 10,
      caloriesBurned: 20,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.menstrual, CyclePhaseType.pms],
    ),
    CycleWorkout(
      id: 'menstrual_4',
      name: 'Sleep Meditation',
      description: 'Guided meditation for better rest',
      category: WorkoutCategory.meditation,
      durationMinutes: 15,
      caloriesBurned: 15,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.menstrual],
    ),
  ];

  static const List<CycleWorkout> _follicularWorkouts = [
    CycleWorkout(
      id: 'follicular_1',
      name: 'Power Yoga',
      description: 'Energizing flow to match your rising energy',
      category: WorkoutCategory.yoga,
      durationMinutes: 30,
      caloriesBurned: 200,
      intensity: WorkoutIntensity.medium,
      recommendedPhases: [CyclePhaseType.follicular],
    ),
    CycleWorkout(
      id: 'follicular_2',
      name: 'HIIT Cardio',
      description: 'High-intensity intervals for peak performance',
      category: WorkoutCategory.cardio,
      durationMinutes: 25,
      caloriesBurned: 300,
      intensity: WorkoutIntensity.high,
      recommendedPhases: [CyclePhaseType.follicular, CyclePhaseType.ovulation],
    ),
    CycleWorkout(
      id: 'follicular_3',
      name: 'Strength Training',
      description: 'Build muscle during your strongest phase',
      category: WorkoutCategory.strength,
      durationMinutes: 40,
      caloriesBurned: 250,
      intensity: WorkoutIntensity.high,
      recommendedPhases: [CyclePhaseType.follicular],
    ),
    CycleWorkout(
      id: 'follicular_4',
      name: 'Dance Workout',
      description: 'Fun cardio dance session',
      category: WorkoutCategory.cardio,
      durationMinutes: 30,
      caloriesBurned: 280,
      intensity: WorkoutIntensity.medium,
      recommendedPhases: [CyclePhaseType.follicular],
    ),
  ];

  static const List<CycleWorkout> _ovulationWorkouts = [
    CycleWorkout(
      id: 'ovulation_1',
      name: 'Peak Performance HIIT',
      description: 'Maximum intensity during your peak',
      category: WorkoutCategory.cardio,
      durationMinutes: 30,
      caloriesBurned: 350,
      intensity: WorkoutIntensity.high,
      recommendedPhases: [CyclePhaseType.ovulation],
    ),
    CycleWorkout(
      id: 'ovulation_2',
      name: 'Advanced Yoga Flow',
      description: 'Challenging poses for peak flexibility',
      category: WorkoutCategory.yoga,
      durationMinutes: 45,
      caloriesBurned: 250,
      intensity: WorkoutIntensity.high,
      recommendedPhases: [CyclePhaseType.ovulation],
    ),
    CycleWorkout(
      id: 'ovulation_3',
      name: 'Running Workout',
      description: 'Outdoor or treadmill run',
      category: WorkoutCategory.cardio,
      durationMinutes: 35,
      caloriesBurned: 400,
      intensity: WorkoutIntensity.high,
      recommendedPhases: [CyclePhaseType.ovulation, CyclePhaseType.follicular],
    ),
  ];

  static const List<CycleWorkout> _lutealWorkouts = [
    CycleWorkout(
      id: 'luteal_1',
      name: 'Moderate Yoga',
      description: 'Balanced practice for winding down',
      category: WorkoutCategory.yoga,
      durationMinutes: 30,
      caloriesBurned: 120,
      intensity: WorkoutIntensity.medium,
      recommendedPhases: [CyclePhaseType.luteal],
    ),
    CycleWorkout(
      id: 'luteal_2',
      name: 'Light Cardio Walk',
      description: 'Gentle walking workout',
      category: WorkoutCategory.cardio,
      durationMinutes: 30,
      caloriesBurned: 150,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.luteal, CyclePhaseType.pms],
    ),
    CycleWorkout(
      id: 'luteal_3',
      name: 'Pilates',
      description: 'Core strengthening without strain',
      category: WorkoutCategory.workouts,
      durationMinutes: 25,
      caloriesBurned: 140,
      intensity: WorkoutIntensity.medium,
      recommendedPhases: [CyclePhaseType.luteal],
    ),
    CycleWorkout(
      id: 'luteal_4',
      name: 'Stress Relief Meditation',
      description: 'Calm your mind and reduce anxiety',
      category: WorkoutCategory.meditation,
      durationMinutes: 15,
      caloriesBurned: 20,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.luteal, CyclePhaseType.pms],
    ),
  ];

  static const List<CycleWorkout> _pmsWorkouts = [
    CycleWorkout(
      id: 'pms_1',
      name: 'Gentle Flow Yoga',
      description: 'Soothing movements for comfort',
      category: WorkoutCategory.yoga,
      durationMinutes: 20,
      caloriesBurned: 70,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.pms],
    ),
    CycleWorkout(
      id: 'pms_2',
      name: 'Mood Boost Walk',
      description: 'Light walking to lift spirits',
      category: WorkoutCategory.cardio,
      durationMinutes: 20,
      caloriesBurned: 100,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.pms],
    ),
    CycleWorkout(
      id: 'pms_3',
      name: 'PMS Relief Stretches',
      description: 'Target bloating and tension',
      category: WorkoutCategory.stretching,
      durationMinutes: 15,
      caloriesBurned: 40,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.pms, CyclePhaseType.menstrual],
    ),
    CycleWorkout(
      id: 'pms_4',
      name: 'Calming Meditation',
      description: 'Reduce irritability and stress',
      category: WorkoutCategory.meditation,
      durationMinutes: 10,
      caloriesBurned: 15,
      intensity: WorkoutIntensity.low,
      recommendedPhases: [CyclePhaseType.pms],
    ),
  ];

  static List<CycleWorkout> get allWorkouts => [
        ..._menstrualWorkouts,
        ..._follicularWorkouts,
        ..._ovulationWorkouts,
        ..._lutealWorkouts,
        ..._pmsWorkouts,
      ];
}
