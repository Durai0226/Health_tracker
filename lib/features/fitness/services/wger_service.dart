import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Wger.de API Service - Free and Open Source Exercise Database
/// Provides exercise images, videos, and detailed information
/// API Documentation: https://wger.de/api/v2/
class WgerService {
  static final WgerService _instance = WgerService._internal();
  factory WgerService() => _instance;
  WgerService._internal();

  static const String _baseUrl = 'https://wger.de/api/v2';
  static const String _mediaBaseUrl = 'https://wger.de/media';
  static const String _cacheKey = 'wger_exercises_cache';
  static const String _imageCacheKey = 'wger_images_cache';
  static const String _cacheTimestampKey = 'wger_cache_timestamp';
  static const Duration _cacheDuration = Duration(days: 7);

  List<WgerExercise> _exercises = [];
  Map<int, List<WgerImage>> _exerciseImages = {};
  bool _isInitialized = false;

  List<WgerExercise> get exercises => List.unmodifiable(_exercises);
  bool get isInitialized => _isInitialized;

  /// Initialize service and load cached data
  Future<void> init() async {
    if (_isInitialized) return;
    
    await _loadFromCache();
    _isInitialized = true;
    debugPrint('✓ WgerService initialized with ${_exercises.length} exercises');
  }

  /// Fetch exercises from wger.de API (English language = 2)
  Future<void> fetchExercises({bool forceRefresh = false}) async {
    if (!forceRefresh && !await _isCacheStale()) {
      debugPrint('Using cached wger exercises');
      return;
    }

    try {
      debugPrint('Fetching exercises from wger.de...');
      final exercises = <WgerExercise>[];
      String? nextUrl = '$_baseUrl/exerciseinfo/?language=2&limit=100';

      while (nextUrl != null) {
        final response = await http.get(Uri.parse(nextUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List;
          
          for (final item in results) {
            exercises.add(WgerExercise.fromJson(item));
          }
          
          nextUrl = data['next'];
        } else {
          throw Exception('Failed to fetch: ${response.statusCode}');
        }
      }

      _exercises = exercises;
      await _saveToCache();
      debugPrint('Fetched ${_exercises.length} exercises from wger.de');
    } catch (e) {
      debugPrint('Error fetching wger exercises: $e');
      // Use built-in fallback data
      _loadBuiltInData();
    }
  }

  /// Fetch images for exercises
  Future<void> fetchImages({bool forceRefresh = false}) async {
    try {
      debugPrint('Fetching exercise images from wger.de...');
      final images = <int, List<WgerImage>>{};
      String? nextUrl = '$_baseUrl/exerciseimage/?limit=100';

      while (nextUrl != null) {
        final response = await http.get(Uri.parse(nextUrl));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List;
          
          for (final item in results) {
            final image = WgerImage.fromJson(item);
            if (!images.containsKey(image.exerciseId)) {
              images[image.exerciseId] = [];
            }
            images[image.exerciseId]!.add(image);
          }
          
          nextUrl = data['next'];
        } else {
          break;
        }
      }

      _exerciseImages = images;
      await _saveImagesToCache();
      debugPrint('Fetched images for ${_exerciseImages.length} exercises');
    } catch (e) {
      debugPrint('Error fetching wger images: $e');
    }
  }

  /// Get exercise by ID
  WgerExercise? getExerciseById(int id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get exercises by category
  List<WgerExercise> getByCategory(String category) {
    return _exercises.where((e) => 
      e.category.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  /// Get exercises by equipment
  List<WgerExercise> getByEquipment(String equipment) {
    return _exercises.where((e) => 
      e.equipment.any((eq) => eq.toLowerCase().contains(equipment.toLowerCase()))
    ).toList();
  }

  /// Get bodyweight exercises (no equipment)
  List<WgerExercise> get bodyweightExercises {
    return _exercises.where((e) => 
      e.equipment.isEmpty || 
      e.equipment.any((eq) => eq.toLowerCase().contains('bodyweight') || eq.toLowerCase().contains('none'))
    ).toList();
  }

  /// Search exercises by name
  List<WgerExercise> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _exercises.where((e) => 
      e.name.toLowerCase().contains(lowerQuery) ||
      e.category.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Get images for an exercise
  List<WgerImage> getImagesForExercise(int exerciseId) {
    return _exerciseImages[exerciseId] ?? [];
  }

  /// Get main image URL for an exercise
  String? getMainImageUrl(int exerciseId) {
    final images = getImagesForExercise(exerciseId);
    if (images.isEmpty) return null;
    
    // Prefer main image
    final mainImage = images.firstWhere(
      (img) => img.isMain,
      orElse: () => images.first,
    );
    return mainImage.imageUrl;
  }

  /// Load from cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      
      if (cacheJson != null) {
        final List<dynamic> decoded = jsonDecode(cacheJson);
        _exercises = decoded.map((e) => WgerExercise.fromJson(e)).toList();
        debugPrint('Loaded ${_exercises.length} exercises from cache');
      } else {
        _loadBuiltInData();
      }

      // Load images cache
      final imagesCacheJson = prefs.getString(_imageCacheKey);
      if (imagesCacheJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(imagesCacheJson);
        _exerciseImages = decoded.map((key, value) => MapEntry(
          int.parse(key),
          (value as List).map((e) => WgerImage.fromJson(e)).toList(),
        ));
      }
    } catch (e) {
      debugPrint('Error loading wger cache: $e');
      _loadBuiltInData();
    }
  }

  /// Save to cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(_exercises.map((e) => e.toJson()).toList());
      await prefs.setString(_cacheKey, jsonData);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving wger cache: $e');
    }
  }

  /// Save images to cache
  Future<void> _saveImagesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(_exerciseImages.map((key, value) => MapEntry(
        key.toString(),
        value.map((e) => e.toJson()).toList(),
      )));
      await prefs.setString(_imageCacheKey, jsonData);
    } catch (e) {
      debugPrint('Error saving wger images cache: $e');
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

  /// Load built-in exercise data
  void _loadBuiltInData() {
    _exercises = _builtInExercises;
    debugPrint('Loaded ${_exercises.length} built-in exercises');
  }

  /// Built-in exercises for offline fallback
  static final List<WgerExercise> _builtInExercises = [
    // Full Body / Cardio
    WgerExercise(
      id: 1001,
      name: 'Burpees',
      category: 'Cardio',
      description: 'Full body cardio exercise combining squat, plank, and jump',
      muscles: ['Pectorals', 'Quadriceps', 'Deltoids'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: ['https://wger.de/media/exercise-images/burpees.png'],
    ),
    WgerExercise(
      id: 1002,
      name: 'Jumping Jacks',
      category: 'Cardio',
      description: 'Classic cardio exercise to warm up the entire body',
      muscles: ['Deltoids', 'Calves'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1003,
      name: 'Mountain Climbers',
      category: 'Cardio',
      description: 'Dynamic plank exercise that works core and cardio',
      muscles: ['Rectus abdominis', 'Quadriceps'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1004,
      name: 'High Knees',
      category: 'Cardio',
      description: 'Running in place while lifting knees high',
      muscles: ['Quadriceps', 'Hip Flexors'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),

    // Chest
    WgerExercise(
      id: 1010,
      name: 'Push-Ups',
      category: 'Chest',
      description: 'Classic upper body exercise for chest, shoulders, and triceps',
      muscles: ['Pectorals', 'Triceps', 'Deltoids'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1011,
      name: 'Diamond Push-Ups',
      category: 'Chest',
      description: 'Tricep-focused push-up variation with hands forming diamond shape',
      muscles: ['Triceps', 'Pectorals'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),

    // Abs
    WgerExercise(
      id: 1020,
      name: 'Crunches',
      category: 'Abs',
      description: 'Classic ab exercise targeting the upper abs',
      muscles: ['Rectus abdominis'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: ['https://wger.de/media/exercise-images/91/Crunches-1.png'],
    ),
    WgerExercise(
      id: 1021,
      name: 'Plank',
      category: 'Abs',
      description: 'Isometric core exercise for stability and strength',
      muscles: ['Rectus abdominis', 'Obliques'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1022,
      name: 'Russian Twists',
      category: 'Abs',
      description: 'Rotational exercise for obliques',
      muscles: ['Obliques', 'Rectus abdominis'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1023,
      name: 'Leg Raises',
      category: 'Abs',
      description: 'Lower ab exercise lying on back',
      muscles: ['Rectus abdominis', 'Hip Flexors'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),

    // Legs
    WgerExercise(
      id: 1030,
      name: 'Squats',
      category: 'Legs',
      description: 'Fundamental lower body exercise',
      muscles: ['Quadriceps', 'Gluteus maximus', 'Hamstrings'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1031,
      name: 'Lunges',
      category: 'Legs',
      description: 'Unilateral leg exercise for strength and balance',
      muscles: ['Quadriceps', 'Gluteus maximus'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1032,
      name: 'Glute Bridges',
      category: 'Legs',
      description: 'Glute and hamstring strengthening exercise',
      muscles: ['Gluteus maximus', 'Hamstrings'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1033,
      name: 'Calf Raises',
      category: 'Legs',
      description: 'Calf strengthening exercise',
      muscles: ['Gastrocnemius', 'Soleus'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: [],
    ),

    // Back
    WgerExercise(
      id: 1040,
      name: 'Superman',
      category: 'Back',
      description: 'Back extension exercise lying face down',
      muscles: ['Erector spinae', 'Gluteus maximus'],
      equipment: ['none (bodyweight exercise)'],
      imageUrls: ['https://wger.de/media/exercise-images/128/Hyperextensions-1.png'],
    ),

    // Arms
    WgerExercise(
      id: 1050,
      name: 'Tricep Dips',
      category: 'Arms',
      description: 'Bodyweight exercise targeting triceps using a chair or bench',
      muscles: ['Triceps', 'Deltoids'],
      equipment: ['Bench'],
      imageUrls: [],
    ),
    WgerExercise(
      id: 1051,
      name: 'Bicep Curls',
      category: 'Arms',
      description: 'Dumbbell exercise for biceps',
      muscles: ['Biceps'],
      equipment: ['Dumbbell'],
      imageUrls: ['https://wger.de/media/exercise-images/129/Standing-biceps-curl-1.png'],
    ),
  ];
}

/// Wger Exercise model
class WgerExercise {
  final int id;
  final String name;
  final String category;
  final String description;
  final List<String> muscles;
  final List<String> musclesSecondary;
  final List<String> equipment;
  final List<String> imageUrls;
  final List<String> videoUrls;

  const WgerExercise({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    this.muscles = const [],
    this.musclesSecondary = const [],
    this.equipment = const [],
    this.imageUrls = const [],
    this.videoUrls = const [],
  });

  factory WgerExercise.fromJson(Map<String, dynamic> json) {
    // Extract English translation
    String name = '';
    String description = '';
    final translations = json['translations'] as List<dynamic>? ?? [];
    for (final t in translations) {
      if (t['language'] == 2) { // English
        name = t['name'] ?? '';
        description = _stripHtml(t['description'] ?? '');
        break;
      }
    }
    if (name.isEmpty && translations.isNotEmpty) {
      name = translations.first['name'] ?? '';
      description = _stripHtml(translations.first['description'] ?? '');
    }

    // Extract muscles
    final muscles = (json['muscles'] as List<dynamic>?)
        ?.map((m) => m['name_en']?.toString() ?? m['name']?.toString() ?? '')
        .where((m) => m.isNotEmpty)
        .toList() ?? [];

    final musclesSecondary = (json['muscles_secondary'] as List<dynamic>?)
        ?.map((m) => m['name_en']?.toString() ?? m['name']?.toString() ?? '')
        .where((m) => m.isNotEmpty)
        .toList() ?? [];

    // Extract equipment
    final equipment = (json['equipment'] as List<dynamic>?)
        ?.map((e) => e['name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList() ?? [];

    // Extract images
    final images = (json['images'] as List<dynamic>?)
        ?.map((img) => img['image']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList() ?? [];

    // Extract videos
    final videos = (json['videos'] as List<dynamic>?)
        ?.map((vid) => vid['video']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList() ?? [];

    return WgerExercise(
      id: json['id'] ?? 0,
      name: name,
      category: json['category']?['name'] ?? 'General',
      description: description,
      muscles: muscles,
      musclesSecondary: musclesSecondary,
      equipment: equipment,
      imageUrls: images,
      videoUrls: videos,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': {'name': category},
    'translations': [
      {'language': 2, 'name': name, 'description': description}
    ],
    'muscles': muscles.map((m) => {'name': m}).toList(),
    'muscles_secondary': musclesSecondary.map((m) => {'name': m}).toList(),
    'equipment': equipment.map((e) => {'name': e}).toList(),
    'images': imageUrls.map((url) => {'image': url}).toList(),
    'videos': videoUrls.map((url) => {'video': url}).toList(),
  };

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  String toString() => 'WgerExercise(id: $id, name: $name, category: $category)';
}

/// Wger Image model
class WgerImage {
  final int id;
  final int exerciseId;
  final String imageUrl;
  final bool isMain;

  const WgerImage({
    required this.id,
    required this.exerciseId,
    required this.imageUrl,
    this.isMain = false,
  });

  factory WgerImage.fromJson(Map<String, dynamic> json) {
    return WgerImage(
      id: json['id'] ?? 0,
      exerciseId: json['exercise'] ?? 0,
      imageUrl: json['image'] ?? '',
      isMain: json['is_main'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercise': exerciseId,
    'image': imageUrl,
    'is_main': isMain,
  };
}
