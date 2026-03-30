import '../models/exercise.dart';
import '../models/workout.dart';

/// Built-in workout library with pre-designed workouts
class WorkoutLibrary {
  static final WorkoutLibrary _instance = WorkoutLibrary._internal();
  factory WorkoutLibrary() => _instance;
  WorkoutLibrary._internal();

  /// Get all pre-built workouts
  List<Workout> get allWorkouts => _workouts;

  /// Get workouts by body part
  List<Workout> getByBodyPart(BodyPart bodyPart) {
    return _workouts.where((w) => w.primaryBodyPart == bodyPart).toList();
  }

  /// Get workouts by difficulty
  List<Workout> getByDifficulty(ExerciseDifficulty difficulty) {
    return _workouts.where((w) => w.difficulty == difficulty).toList();
  }

  /// Get workouts by duration range
  List<Workout> getByDuration({int? minMinutes, int? maxMinutes}) {
    return _workouts.where((w) {
      if (minMinutes != null && w.estimatedDurationMinutes < minMinutes) return false;
      if (maxMinutes != null && w.estimatedDurationMinutes > maxMinutes) return false;
      return true;
    }).toList();
  }

  /// Get workout by ID
  Workout? getById(String id) {
    try {
      return _workouts.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get quick workouts (under 10 minutes)
  List<Workout> get quickWorkouts => 
      _workouts.where((w) => w.estimatedDurationMinutes <= 10).toList();

  /// Get featured/popular workouts
  List<Workout> get featuredWorkouts => 
      _workouts.where((w) => w.tags.contains('featured')).toList();

  /// Get workouts filtered by equipment requirement
  List<Workout> getByEquipmentPreference({required bool requiresEquipment}) {
    return _workouts.where((w) => w.requiresEquipment == requiresEquipment).toList();
  }

  /// Get bodyweight-only workouts (no equipment needed)
  List<Workout> get bodyweightWorkouts => 
      _workouts.where((w) => !w.requiresEquipment).toList();

  /// Get workouts that require equipment
  List<Workout> get equipmentWorkouts => 
      _workouts.where((w) => w.requiresEquipment).toList();

  // ============================================
  // PRE-BUILT WORKOUTS
  // ============================================
  
  static final List<Workout> _workouts = [
    // ==========================================
    // FULL BODY WORKOUTS
    // ==========================================
    Workout(
      id: 'full_body_beginner',
      name: '7 Minute Full Body',
      description: 'Quick full body workout perfect for beginners. Great way to start your fitness journey.',
      primaryBodyPart: BodyPart.fullBody,
      targetedBodyParts: [BodyPart.fullBody, BodyPart.cardio],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'jumping_jacks', customDurationSeconds: 30, restAfterSeconds: 10, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'squats', customReps: 12, restAfterSeconds: 10, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 10, restAfterSeconds: 10, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 20, restAfterSeconds: 10, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'lunges', customReps: 12, restAfterSeconds: 10, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'crunches', customReps: 15, restAfterSeconds: 10, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'high_knees', customDurationSeconds: 30, restAfterSeconds: 0, orderIndex: 6),
      ],
      estimatedDurationMinutes: 7,
      estimatedCalories: 50,
      tags: ['featured', 'quick', 'beginner'],
      createdAt: DateTime(2024, 1, 1),
    ),
    
    Workout(
      id: 'full_body_blast',
      name: '20 Minute Full Body Blast',
      description: 'Comprehensive workout hitting every major muscle group. Perfect for a complete session.',
      primaryBodyPart: BodyPart.fullBody,
      targetedBodyParts: [BodyPart.fullBody, BodyPart.cardio, BodyPart.abs],
      difficulty: ExerciseDifficulty.intermediate,
      exercises: [
        const WorkoutExercise(exerciseId: 'jumping_jacks', customDurationSeconds: 45, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'squats', customReps: 15, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 12, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'mountain_climbers', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'lunges', customReps: 16, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'burpees', customReps: 8, restAfterSeconds: 15, orderIndex: 6),
        const WorkoutExercise(exerciseId: 'bicycle_crunches', customReps: 20, restAfterSeconds: 15, orderIndex: 7),
        const WorkoutExercise(exerciseId: 'squat_jumps', customReps: 10, restAfterSeconds: 15, orderIndex: 8),
        const WorkoutExercise(exerciseId: 'superman', customReps: 12, restAfterSeconds: 15, orderIndex: 9),
        const WorkoutExercise(exerciseId: 'high_knees', customDurationSeconds: 45, restAfterSeconds: 15, orderIndex: 10),
        const WorkoutExercise(exerciseId: 'tricep_dips', customReps: 12, restAfterSeconds: 0, orderIndex: 11),
      ],
      estimatedDurationMinutes: 20,
      estimatedCalories: 180,
      tags: ['featured', 'popular'],
      createdAt: DateTime(2024, 1, 1),
    ),

    Workout(
      id: 'hiit_burner',
      name: 'HIIT Fat Burner',
      description: 'High intensity interval training to maximize calorie burn in minimum time.',
      primaryBodyPart: BodyPart.fullBody,
      targetedBodyParts: [BodyPart.cardio, BodyPart.fullBody],
      difficulty: ExerciseDifficulty.advanced,
      exercises: [
        const WorkoutExercise(exerciseId: 'burpees', customReps: 10, restAfterSeconds: 20, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'mountain_climbers', customDurationSeconds: 40, restAfterSeconds: 20, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'squat_jumps', customReps: 12, restAfterSeconds: 20, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'high_knees', customDurationSeconds: 40, restAfterSeconds: 20, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'jumping_lunges', customReps: 16, restAfterSeconds: 20, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'star_jumps', customReps: 12, restAfterSeconds: 20, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'burpees', customReps: 10, restAfterSeconds: 20, orderIndex: 6),
        const WorkoutExercise(exerciseId: 'skaters', customDurationSeconds: 40, restAfterSeconds: 0, orderIndex: 7),
      ],
      estimatedDurationMinutes: 15,
      estimatedCalories: 200,
      tags: ['featured', 'hiit', 'fat-burn'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // ABS WORKOUTS
    // ==========================================
    Workout(
      id: 'abs_beginner',
      name: '10 Minute Abs',
      description: 'Beginner-friendly ab workout to build core strength.',
      primaryBodyPart: BodyPart.abs,
      targetedBodyParts: [BodyPart.abs],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'crunches', customReps: 15, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 20, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'leg_raises', customReps: 10, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'dead_bug', customReps: 12, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'bicycle_crunches', customReps: 16, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'flutter_kicks', customDurationSeconds: 20, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 30, restAfterSeconds: 0, orderIndex: 6),
      ],
      estimatedDurationMinutes: 10,
      estimatedCalories: 60,
      tags: ['abs', 'core', 'beginner'],
      createdAt: DateTime(2024, 1, 1),
    ),

    Workout(
      id: 'abs_shredder',
      name: '15 Min Abs Shredder',
      description: 'Intense core workout to sculpt your abs.',
      primaryBodyPart: BodyPart.abs,
      targetedBodyParts: [BodyPart.abs],
      difficulty: ExerciseDifficulty.intermediate,
      exercises: [
        const WorkoutExercise(exerciseId: 'mountain_climbers', customDurationSeconds: 30, restAfterSeconds: 10, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'crunches', customReps: 20, restAfterSeconds: 10, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'russian_twists', customReps: 24, restAfterSeconds: 10, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'leg_raises', customReps: 15, restAfterSeconds: 10, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 45, restAfterSeconds: 10, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'bicycle_crunches', customReps: 24, restAfterSeconds: 10, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'flutter_kicks', customDurationSeconds: 30, restAfterSeconds: 10, orderIndex: 6),
        const WorkoutExercise(exerciseId: 'side_plank', customDurationSeconds: 30, restAfterSeconds: 10, orderIndex: 7),
        const WorkoutExercise(exerciseId: 'dead_bug', customReps: 16, restAfterSeconds: 10, orderIndex: 8),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 60, restAfterSeconds: 0, orderIndex: 9),
      ],
      estimatedDurationMinutes: 15,
      estimatedCalories: 100,
      tags: ['featured', 'abs', 'intense'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // ARM WORKOUTS
    // ==========================================
    Workout(
      id: 'arms_toned',
      name: 'Toned Arms',
      description: 'Build strong, defined arms without any equipment.',
      primaryBodyPart: BodyPart.arms,
      targetedBodyParts: [BodyPart.arms, BodyPart.shoulders],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'arm_circles', customDurationSeconds: 30, restAfterSeconds: 10, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 10, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'tricep_dips', customReps: 10, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'plank_shoulder_taps', customReps: 16, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'diamond_push_ups', customReps: 8, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'arm_circles', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 12, restAfterSeconds: 0, orderIndex: 6),
      ],
      estimatedDurationMinutes: 12,
      estimatedCalories: 70,
      tags: ['arms', 'upper-body'],
      createdAt: DateTime(2024, 1, 1),
    ),

    Workout(
      id: 'arms_strength',
      name: 'Arm Strength Builder',
      description: 'Advanced arm workout for serious strength gains.',
      primaryBodyPart: BodyPart.arms,
      targetedBodyParts: [BodyPart.arms, BodyPart.shoulders, BodyPart.chest],
      difficulty: ExerciseDifficulty.advanced,
      exercises: [
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 15, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'diamond_push_ups', customReps: 12, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'pike_push_ups', customReps: 10, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'tricep_dips', customReps: 15, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'plank_shoulder_taps', customReps: 24, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'decline_push_ups', customReps: 10, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'wide_push_ups', customReps: 12, restAfterSeconds: 15, orderIndex: 6),
        const WorkoutExercise(exerciseId: 'diamond_push_ups', customReps: 10, restAfterSeconds: 0, orderIndex: 7),
      ],
      estimatedDurationMinutes: 18,
      estimatedCalories: 120,
      tags: ['arms', 'strength', 'advanced'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // LEG WORKOUTS
    // ==========================================
    Workout(
      id: 'legs_beginner',
      name: 'Leg Day Basics',
      description: 'Build lower body strength with this beginner leg workout.',
      primaryBodyPart: BodyPart.legs,
      targetedBodyParts: [BodyPart.legs],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'squats', customReps: 15, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'lunges', customReps: 16, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'glute_bridges', customReps: 15, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'calf_raises', customReps: 20, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'sumo_squats', customReps: 12, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'donkey_kicks', customReps: 12, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'wall_sit', customDurationSeconds: 30, restAfterSeconds: 0, orderIndex: 6),
      ],
      estimatedDurationMinutes: 12,
      estimatedCalories: 80,
      tags: ['legs', 'lower-body', 'beginner'],
      createdAt: DateTime(2024, 1, 1),
    ),

    Workout(
      id: 'legs_burn',
      name: 'Leg Burn Challenge',
      description: 'Intense leg workout that will leave your muscles burning.',
      primaryBodyPart: BodyPart.legs,
      targetedBodyParts: [BodyPart.legs, BodyPart.cardio],
      difficulty: ExerciseDifficulty.intermediate,
      exercises: [
        const WorkoutExercise(exerciseId: 'squat_jumps', customReps: 12, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'lunges', customReps: 20, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'wall_sit', customDurationSeconds: 45, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'sumo_squats', customReps: 15, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'glute_bridges', customReps: 20, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'reverse_lunges', customReps: 20, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'fire_hydrants', customReps: 16, restAfterSeconds: 15, orderIndex: 6),
        const WorkoutExercise(exerciseId: 'single_leg_deadlift', customReps: 12, restAfterSeconds: 15, orderIndex: 7),
        const WorkoutExercise(exerciseId: 'squat_jumps', customReps: 10, restAfterSeconds: 15, orderIndex: 8),
        const WorkoutExercise(exerciseId: 'wall_sit', customDurationSeconds: 60, restAfterSeconds: 0, orderIndex: 9),
      ],
      estimatedDurationMinutes: 18,
      estimatedCalories: 150,
      tags: ['featured', 'legs', 'intense'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // CHEST WORKOUTS
    // ==========================================
    Workout(
      id: 'chest_push',
      name: 'Chest Push Day',
      description: 'Build a strong chest with various push-up variations.',
      primaryBodyPart: BodyPart.chest,
      targetedBodyParts: [BodyPart.chest, BodyPart.arms],
      difficulty: ExerciseDifficulty.intermediate,
      exercises: [
        const WorkoutExercise(exerciseId: 'incline_push_ups', customReps: 15, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 12, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'wide_push_ups', customReps: 12, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'diamond_push_ups', customReps: 10, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'chest_squeeze', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'decline_push_ups', customReps: 8, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'push_ups', customReps: 15, restAfterSeconds: 0, orderIndex: 6),
      ],
      estimatedDurationMinutes: 14,
      estimatedCalories: 90,
      tags: ['chest', 'push', 'upper-body'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // BACK WORKOUTS
    // ==========================================
    Workout(
      id: 'back_strength',
      name: 'Back Strengthener',
      description: 'Strengthen your back and improve posture.',
      primaryBodyPart: BodyPart.back,
      targetedBodyParts: [BodyPart.back, BodyPart.shoulders],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'cat_cow', customReps: 10, restAfterSeconds: 10, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'superman', customReps: 12, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'bird_dog', customReps: 16, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'reverse_snow_angels', customReps: 12, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'prone_y_raises', customReps: 12, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'superman', customReps: 15, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'cat_cow', customReps: 8, restAfterSeconds: 0, orderIndex: 6),
      ],
      estimatedDurationMinutes: 12,
      estimatedCalories: 50,
      tags: ['back', 'posture', 'beginner'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // CARDIO WORKOUTS
    // ==========================================
    Workout(
      id: 'cardio_blast',
      name: 'Cardio Blast',
      description: 'Get your heart pumping with this high-energy cardio session.',
      primaryBodyPart: BodyPart.cardio,
      targetedBodyParts: [BodyPart.cardio, BodyPart.fullBody],
      difficulty: ExerciseDifficulty.intermediate,
      exercises: [
        const WorkoutExercise(exerciseId: 'jumping_jacks', customDurationSeconds: 45, restAfterSeconds: 15, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'high_knees', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'butt_kicks', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'mountain_climbers', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'skaters', customDurationSeconds: 30, restAfterSeconds: 15, orderIndex: 4),
        const WorkoutExercise(exerciseId: 'star_jumps', customReps: 12, restAfterSeconds: 15, orderIndex: 5),
        const WorkoutExercise(exerciseId: 'run_in_place', customDurationSeconds: 45, restAfterSeconds: 15, orderIndex: 6),
        const WorkoutExercise(exerciseId: 'jumping_jacks', customDurationSeconds: 45, restAfterSeconds: 0, orderIndex: 7),
      ],
      estimatedDurationMinutes: 12,
      estimatedCalories: 120,
      tags: ['featured', 'cardio', 'fat-burn'],
      createdAt: DateTime(2024, 1, 1),
    ),

    // ==========================================
    // QUICK WORKOUTS (5 MIN)
    // ==========================================
    Workout(
      id: 'quick_morning',
      name: '5 Min Morning Energizer',
      description: 'Quick workout to start your day with energy.',
      primaryBodyPart: BodyPart.fullBody,
      targetedBodyParts: [BodyPart.fullBody, BodyPart.cardio],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'jumping_jacks', customDurationSeconds: 30, restAfterSeconds: 10, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'squats', customReps: 10, restAfterSeconds: 10, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'inchworms', customReps: 5, restAfterSeconds: 10, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'high_knees', customDurationSeconds: 20, restAfterSeconds: 10, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 20, restAfterSeconds: 0, orderIndex: 4),
      ],
      estimatedDurationMinutes: 5,
      estimatedCalories: 35,
      tags: ['quick', 'morning', 'beginner'],
      createdAt: DateTime(2024, 1, 1),
    ),

    Workout(
      id: 'quick_abs',
      name: '5 Min Ab Blast',
      description: 'Quick core workout you can do anywhere.',
      primaryBodyPart: BodyPart.abs,
      targetedBodyParts: [BodyPart.abs],
      difficulty: ExerciseDifficulty.beginner,
      exercises: [
        const WorkoutExercise(exerciseId: 'crunches', customReps: 15, restAfterSeconds: 10, orderIndex: 0),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 20, restAfterSeconds: 10, orderIndex: 1),
        const WorkoutExercise(exerciseId: 'bicycle_crunches', customReps: 16, restAfterSeconds: 10, orderIndex: 2),
        const WorkoutExercise(exerciseId: 'leg_raises', customReps: 10, restAfterSeconds: 10, orderIndex: 3),
        const WorkoutExercise(exerciseId: 'plank', customDurationSeconds: 30, restAfterSeconds: 0, orderIndex: 4),
      ],
      estimatedDurationMinutes: 5,
      estimatedCalories: 30,
      tags: ['quick', 'abs', 'core'],
      createdAt: DateTime(2024, 1, 1),
    ),
  ];
}
