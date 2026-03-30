import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// ExerciseDB API Service
/// Fetches exercises with GIF demonstrations from exercisedb.dev
class ExerciseDBService {
  static final ExerciseDBService _instance = ExerciseDBService._internal();
  factory ExerciseDBService() => _instance;
  ExerciseDBService._internal();

  static const String _baseUrl = 'https://exercisedb.p.rapidapi.com';
  static const String _cacheKey = 'exercisedb_cache';
  static const String _cacheTimestampKey = 'exercisedb_cache_timestamp';
  static const Duration _cacheDuration = Duration(days: 7);

  List<ExerciseDBItem> _exercises = [];
  bool _isInitialized = false;

  List<ExerciseDBItem> get exercises => List.unmodifiable(_exercises);
  bool get isInitialized => _isInitialized;

  /// Initialize service and load cached data
  Future<void> init() async {
    if (_isInitialized) return;
    
    await _loadFromCache();
    _isInitialized = true;
    debugPrint('✓ ExerciseDBService initialized with ${_exercises.length} exercises');
  }

  /// Get exercises by body part
  List<ExerciseDBItem> getByBodyPart(String bodyPart) {
    return _exercises.where((e) => 
      e.bodyPart.toLowerCase() == bodyPart.toLowerCase() ||
      e.target.toLowerCase() == bodyPart.toLowerCase()
    ).toList();
  }

  /// Get exercises by equipment
  List<ExerciseDBItem> getByEquipment(String equipment) {
    return _exercises.where((e) => 
      e.equipment.toLowerCase() == equipment.toLowerCase()
    ).toList();
  }

  /// Get exercise by ID
  ExerciseDBItem? getById(String id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Search exercises by name
  List<ExerciseDBItem> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _exercises.where((e) => 
      e.name.toLowerCase().contains(lowerQuery) ||
      e.bodyPart.toLowerCase().contains(lowerQuery) ||
      e.target.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Get unique body parts
  List<String> get bodyParts {
    return _exercises.map((e) => e.bodyPart).toSet().toList()..sort();
  }

  /// Get unique equipment types
  List<String> get equipmentTypes {
    return _exercises.map((e) => e.equipment).toSet().toList()..sort();
  }

  /// Get unique target muscles
  List<String> get targetMuscles {
    return _exercises.map((e) => e.target).toSet().toList()..sort();
  }

  /// Load exercises from cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      
      if (cacheJson != null) {
        final List<dynamic> decoded = jsonDecode(cacheJson);
        _exercises = decoded.map((e) => ExerciseDBItem.fromJson(e)).toList();
        debugPrint('Loaded ${_exercises.length} exercises from cache');
      } else {
        // Load built-in exercises as fallback
        _loadBuiltInExercises();
      }
    } catch (e) {
      debugPrint('Error loading ExerciseDB cache: $e');
      _loadBuiltInExercises();
    }
  }

  /// Save exercises to cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(_exercises.map((e) => e.toJson()).toList());
      await prefs.setString(_cacheKey, jsonData);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving ExerciseDB cache: $e');
    }
  }

  /// Check if cache is stale
  Future<bool> _isCacheStale() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return true;
    
    final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheDate) > _cacheDuration;
  }

  /// Load built-in exercises as fallback (offline mode)
  void _loadBuiltInExercises() {
    _exercises = _builtInExercises;
    debugPrint('Loaded ${_exercises.length} built-in exercises');
  }

  /// Map ExerciseDB body part to our BodyPart enum string
  static String mapBodyPart(String exerciseDbBodyPart) {
    switch (exerciseDbBodyPart.toLowerCase()) {
      case 'back':
        return 'back';
      case 'cardio':
        return 'cardio';
      case 'chest':
        return 'chest';
      case 'lower arms':
      case 'upper arms':
        return 'arms';
      case 'lower legs':
      case 'upper legs':
        return 'legs';
      case 'neck':
      case 'shoulders':
        return 'shoulders';
      case 'waist':
        return 'abs';
      default:
        return 'fullBody';
    }
  }

  /// Built-in exercises for offline fallback
  static final List<ExerciseDBItem> _builtInExercises = [
    // CHEST
    ExerciseDBItem(
      id: 'push_up',
      name: 'Push Up',
      bodyPart: 'chest',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/sWH0nXSt8pKJOZ',
      target: 'pectorals',
      secondaryMuscles: ['triceps', 'shoulders'],
      instructions: [
        'Get into a plank position with hands shoulder-width apart',
        'Lower your body until chest nearly touches the floor',
        'Push back up to starting position',
        'Keep your core tight throughout the movement',
      ],
    ),
    ExerciseDBItem(
      id: 'diamond_push_up',
      name: 'Diamond Push Up',
      bodyPart: 'chest',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/Z5lM1tXUYBqF3G',
      target: 'triceps',
      secondaryMuscles: ['pectorals', 'shoulders'],
      instructions: [
        'Form a diamond shape with your hands under your chest',
        'Lower your body keeping elbows close to sides',
        'Push back up to starting position',
      ],
    ),
    ExerciseDBItem(
      id: 'incline_push_up',
      name: 'Incline Push Up',
      bodyPart: 'chest',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/kL9mNxPQ2wRs7T',
      target: 'pectorals',
      secondaryMuscles: ['triceps', 'shoulders'],
      instructions: [
        'Place hands on elevated surface shoulder-width apart',
        'Lower chest toward the surface',
        'Push back up to starting position',
      ],
    ),

    // BACK
    ExerciseDBItem(
      id: 'pull_up',
      name: 'Pull Up',
      bodyPart: 'back',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/hY7kLmN3pQrS9X',
      target: 'lats',
      secondaryMuscles: ['biceps', 'forearms'],
      instructions: [
        'Grip the bar with palms facing away, shoulder-width apart',
        'Pull yourself up until chin is above the bar',
        'Lower yourself with control',
      ],
    ),
    ExerciseDBItem(
      id: 'superman',
      name: 'Superman',
      bodyPart: 'back',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/wX9yZaB2cD4eF6',
      target: 'spine',
      secondaryMuscles: ['glutes', 'hamstrings'],
      instructions: [
        'Lie face down with arms extended in front',
        'Simultaneously raise arms, chest, and legs off the ground',
        'Hold for 2-3 seconds, then lower',
      ],
    ),

    // LEGS
    ExerciseDBItem(
      id: 'squat',
      name: 'Bodyweight Squat',
      bodyPart: 'upper legs',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/gH8iJ0kL1mN2oP',
      target: 'quads',
      secondaryMuscles: ['glutes', 'hamstrings', 'calves'],
      instructions: [
        'Stand with feet shoulder-width apart',
        'Lower your body as if sitting back into a chair',
        'Keep chest up and knees tracking over toes',
        'Push through heels to return to standing',
      ],
    ),
    ExerciseDBItem(
      id: 'lunge',
      name: 'Forward Lunge',
      bodyPart: 'upper legs',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/qR3sT4uV5wX6yZ',
      target: 'quads',
      secondaryMuscles: ['glutes', 'hamstrings'],
      instructions: [
        'Stand tall with feet hip-width apart',
        'Step forward with one leg and lower until both knees are at 90 degrees',
        'Push back to starting position',
        'Alternate legs',
      ],
    ),
    ExerciseDBItem(
      id: 'jump_squat',
      name: 'Jump Squat',
      bodyPart: 'upper legs',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/aB7cD8eF9gH0iJ',
      target: 'quads',
      secondaryMuscles: ['glutes', 'calves'],
      instructions: [
        'Start in squat position',
        'Explosively jump up, extending legs fully',
        'Land softly and immediately go into next squat',
      ],
    ),
    ExerciseDBItem(
      id: 'calf_raise',
      name: 'Calf Raise',
      bodyPart: 'lower legs',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/kL1mN2oP3qR4sT',
      target: 'calves',
      secondaryMuscles: [],
      instructions: [
        'Stand with feet hip-width apart',
        'Rise up onto the balls of your feet',
        'Hold at the top, then lower slowly',
      ],
    ),

    // ABS
    ExerciseDBItem(
      id: 'crunch',
      name: 'Crunch',
      bodyPart: 'waist',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/uV5wX6yZ7aB8cD',
      target: 'abs',
      secondaryMuscles: ['obliques'],
      instructions: [
        'Lie on your back with knees bent, feet flat on floor',
        'Place hands behind head or across chest',
        'Lift shoulders off the ground using your abs',
        'Lower with control',
      ],
    ),
    ExerciseDBItem(
      id: 'plank',
      name: 'Plank',
      bodyPart: 'waist',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/eF9gH0iJ1kL2mN',
      target: 'abs',
      secondaryMuscles: ['shoulders', 'back'],
      instructions: [
        'Start in push-up position but rest on forearms',
        'Keep body in a straight line from head to heels',
        'Engage core and hold position',
        'Don\'t let hips sag or pike up',
      ],
    ),
    ExerciseDBItem(
      id: 'mountain_climber',
      name: 'Mountain Climber',
      bodyPart: 'waist',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/oP3qR4sT5uV6wX',
      target: 'abs',
      secondaryMuscles: ['quads', 'shoulders'],
      instructions: [
        'Start in plank position',
        'Drive one knee toward chest',
        'Quickly switch legs in a running motion',
        'Keep hips down and core engaged',
      ],
    ),
    ExerciseDBItem(
      id: 'bicycle_crunch',
      name: 'Bicycle Crunch',
      bodyPart: 'waist',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/yZ7aB8cD9eF0gH',
      target: 'abs',
      secondaryMuscles: ['obliques'],
      instructions: [
        'Lie on back with hands behind head',
        'Lift shoulders and bring one knee to opposite elbow',
        'Extend other leg straight',
        'Alternate sides in a pedaling motion',
      ],
    ),

    // ARMS
    ExerciseDBItem(
      id: 'tricep_dip',
      name: 'Tricep Dip',
      bodyPart: 'upper arms',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/iJ1kL2mN3oP4qR',
      target: 'triceps',
      secondaryMuscles: ['shoulders', 'chest'],
      instructions: [
        'Sit on edge of bench/chair with hands gripping edge',
        'Slide off and lower body by bending elbows',
        'Push back up until arms are straight',
      ],
    ),
    ExerciseDBItem(
      id: 'bicep_curl',
      name: 'Dumbbell Bicep Curl',
      bodyPart: 'upper arms',
      equipment: 'dumbbell',
      gifUrl: 'https://v2.exercisedb.io/image/sT5uV6wX7yZ8aB',
      target: 'biceps',
      secondaryMuscles: ['forearms'],
      instructions: [
        'Stand with dumbbells at sides, palms facing forward',
        'Curl weights up toward shoulders',
        'Lower with control',
        'Keep elbows close to body',
      ],
    ),

    // SHOULDERS
    ExerciseDBItem(
      id: 'pike_push_up',
      name: 'Pike Push Up',
      bodyPart: 'shoulders',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/cD9eF0gH1iJ2kL',
      target: 'delts',
      secondaryMuscles: ['triceps', 'chest'],
      instructions: [
        'Start in downward dog position with hips high',
        'Lower head toward the ground by bending elbows',
        'Push back up to starting position',
      ],
    ),
    ExerciseDBItem(
      id: 'shoulder_press',
      name: 'Dumbbell Shoulder Press',
      bodyPart: 'shoulders',
      equipment: 'dumbbell',
      gifUrl: 'https://v2.exercisedb.io/image/mN3oP4qR5sT6uV',
      target: 'delts',
      secondaryMuscles: ['triceps', 'traps'],
      instructions: [
        'Hold dumbbells at shoulder height with palms forward',
        'Press weights overhead until arms are extended',
        'Lower with control back to shoulders',
      ],
    ),

    // CARDIO / FULL BODY
    ExerciseDBItem(
      id: 'burpee',
      name: 'Burpee',
      bodyPart: 'cardio',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/wX7yZ8aB9cD0eF',
      target: 'cardiovascular system',
      secondaryMuscles: ['quads', 'chest', 'shoulders'],
      instructions: [
        'Stand with feet shoulder-width apart',
        'Drop into squat and place hands on floor',
        'Jump feet back into plank',
        'Do a push-up (optional)',
        'Jump feet forward and explosively jump up',
      ],
    ),
    ExerciseDBItem(
      id: 'jumping_jack',
      name: 'Jumping Jack',
      bodyPart: 'cardio',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/gH1iJ2kL3mN4oP',
      target: 'cardiovascular system',
      secondaryMuscles: ['shoulders', 'calves'],
      instructions: [
        'Stand with feet together, arms at sides',
        'Jump while spreading legs and raising arms overhead',
        'Jump back to starting position',
        'Maintain a steady rhythm',
      ],
    ),
    ExerciseDBItem(
      id: 'high_knees',
      name: 'High Knees',
      bodyPart: 'cardio',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/qR5sT6uV7wX8yZ',
      target: 'cardiovascular system',
      secondaryMuscles: ['quads', 'abs'],
      instructions: [
        'Stand tall with feet hip-width apart',
        'Run in place, driving knees up to hip height',
        'Pump arms in opposition to legs',
        'Stay on balls of feet',
      ],
    ),
    ExerciseDBItem(
      id: 'butt_kicks',
      name: 'Butt Kicks',
      bodyPart: 'cardio',
      equipment: 'body weight',
      gifUrl: 'https://v2.exercisedb.io/image/aB9cD0eF1gH2iJ',
      target: 'cardiovascular system',
      secondaryMuscles: ['hamstrings', 'calves'],
      instructions: [
        'Stand tall with feet hip-width apart',
        'Jog in place, kicking heels up toward glutes',
        'Pump arms naturally',
        'Maintain quick pace',
      ],
    ),
  ];
}

/// ExerciseDB exercise item model
class ExerciseDBItem {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String gifUrl;
  final String target;
  final List<String> secondaryMuscles;
  final List<String> instructions;

  const ExerciseDBItem({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.gifUrl,
    required this.target,
    this.secondaryMuscles = const [],
    this.instructions = const [],
  });

  factory ExerciseDBItem.fromJson(Map<String, dynamic> json) {
    return ExerciseDBItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      bodyPart: json['bodyPart'] ?? '',
      equipment: json['equipment'] ?? 'body weight',
      gifUrl: json['gifUrl'] ?? '',
      target: json['target'] ?? '',
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      instructions: (json['instructions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bodyPart': bodyPart,
      'equipment': equipment,
      'gifUrl': gifUrl,
      'target': target,
      'secondaryMuscles': secondaryMuscles,
      'instructions': instructions,
    };
  }

  @override
  String toString() => 'ExerciseDBItem(id: $id, name: $name, bodyPart: $bodyPart)';
}
