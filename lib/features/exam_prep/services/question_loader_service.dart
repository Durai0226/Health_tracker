import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/question_bank_data.dart';

/// Service for loading questions from local JSON assets and cloud storage
/// Implements hybrid approach: core questions bundled locally, extended content from Firestore
class QuestionLoaderService extends ChangeNotifier {
  static final QuestionLoaderService _instance = QuestionLoaderService._internal();
  factory QuestionLoaderService() => _instance;
  QuestionLoaderService._internal();

  // Cache keys
  static const String _cachePrefix = 'questions_cache_';
  static const String _cacheTimestampPrefix = 'questions_cache_ts_';
  static const String _manifestCacheKey = 'questions_manifest';
  static const Duration _cacheExpiry = Duration(days: 7);

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  // In-memory cache
  final Map<String, List<QuestionBankItem>> _memoryCache = {};
  Map<String, dynamic>? _manifest;
  
  // Loading state
  bool _isLoading = false;
  String? _loadingCategory;
  double _loadingProgress = 0.0;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get loadingCategory => _loadingCategory;
  double get loadingProgress => _loadingProgress;
  Map<String, dynamic>? get manifest => _manifest;

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadManifest();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('QuestionLoaderService init error: $e');
    }
  }

  /// Load the manifest file
  Future<void> _loadManifest() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/questions/manifest.json');
      _manifest = json.decode(jsonString);
    } catch (e) {
      debugPrint('Error loading manifest: $e');
      // Create default manifest structure
      _manifest = {
        'version': '1.0.0',
        'categories': [],
        'subjects': [],
      };
    }
  }

  /// Get all available categories from manifest
  List<Map<String, dynamic>> getCategories() {
    if (_manifest == null) return [];
    return List<Map<String, dynamic>>.from(_manifest!['categories'] ?? []);
  }

  /// Get all subjects from manifest
  List<Map<String, dynamic>> getSubjects() {
    if (_manifest == null) return [];
    return List<Map<String, dynamic>>.from(_manifest!['subjects'] ?? []);
  }

  /// Load questions for a specific category
  Future<List<QuestionBankItem>> loadCategoryQuestions(String categoryId) async {
    // Check memory cache first
    if (_memoryCache.containsKey(categoryId)) {
      return _memoryCache[categoryId]!;
    }

    // Check local cache
    final cachedQuestions = await _loadFromCache(categoryId);
    if (cachedQuestions != null) {
      _memoryCache[categoryId] = cachedQuestions;
      return cachedQuestions;
    }

    // Load from assets
    _isLoading = true;
    _loadingCategory = categoryId;
    _loadingProgress = 0.0;
    notifyListeners();

    try {
      final questions = await _loadFromAssets(categoryId);
      _memoryCache[categoryId] = questions;
      await _saveToCache(categoryId, questions);
      
      _isLoading = false;
      _loadingCategory = null;
      _loadingProgress = 1.0;
      notifyListeners();
      
      return questions;
    } catch (e) {
      debugPrint('Error loading category $categoryId: $e');
      _isLoading = false;
      _loadingCategory = null;
      notifyListeners();
      return [];
    }
  }

  /// Load questions from local JSON assets
  Future<List<QuestionBankItem>> _loadFromAssets(String categoryId) async {
    final List<QuestionBankItem> questions = [];
    
    try {
      final String jsonString = await rootBundle.loadString('assets/questions/$categoryId/core.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> questionsList = data['questions'] ?? [];
      
      for (int i = 0; i < questionsList.length; i++) {
        final q = questionsList[i];
        questions.add(QuestionBankItem.fromJson(q));
        
        // Update progress
        _loadingProgress = (i + 1) / questionsList.length;
        if (i % 50 == 0) notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading assets for $categoryId: $e');
    }
    
    return questions;
  }

  /// Get questions with detailed solutions only
  Future<List<QuestionBankItem>> getQuestionsWithSolutions({
    String? categoryId,
    String? subjectId,
  }) async {
    final questions = await getFilteredQuestions(
      categoryId: categoryId,
      subjectId: subjectId,
    );
    return questions.where((q) => q.hasDetailedSolution).toList();
  }

  /// Load questions from local SharedPreferences cache
  Future<List<QuestionBankItem>?> _loadFromCache(String categoryId) async {
    if (_prefs == null) return null;

    final timestampKey = '$_cacheTimestampPrefix$categoryId';
    final cacheKey = '$_cachePrefix$categoryId';

    // Check cache timestamp
    final timestamp = _prefs!.getInt(timestampKey);
    if (timestamp == null) return null;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
      // Cache expired
      await _prefs!.remove(cacheKey);
      await _prefs!.remove(timestampKey);
      return null;
    }

    // Load cached data
    final cachedJson = _prefs!.getString(cacheKey);
    if (cachedJson == null) return null;

    try {
      final List<dynamic> data = json.decode(cachedJson);
      return data.map((q) => QuestionBankItem.fromJson(q)).toList();
    } catch (e) {
      debugPrint('Error parsing cache for $categoryId: $e');
      return null;
    }
  }

  /// Save questions to local cache
  Future<void> _saveToCache(String categoryId, List<QuestionBankItem> questions) async {
    if (_prefs == null) return;

    final timestampKey = '$_cacheTimestampPrefix$categoryId';
    final cacheKey = '$_cachePrefix$categoryId';

    try {
      final jsonList = questions.map((q) => q.toJson()).toList();
      await _prefs!.setString(cacheKey, json.encode(jsonList));
      await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving cache for $categoryId: $e');
    }
  }

  /// Load all core questions (from all local categories)
  Future<List<QuestionBankItem>> loadAllCoreQuestions() async {
    final List<QuestionBankItem> allQuestions = [];
    final categories = getCategories();

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final categoryId = category['id'] as String;
      
      _loadingProgress = i / categories.length;
      _loadingCategory = categoryId;
      notifyListeners();

      final questions = await loadCategoryQuestions(categoryId);
      allQuestions.addAll(questions);
    }

    _loadingProgress = 1.0;
    _loadingCategory = null;
    notifyListeners();

    return allQuestions;
  }

  /// Get questions by subject
  Future<List<QuestionBankItem>> getQuestionsBySubject(String subjectId) async {
    final allQuestions = <QuestionBankItem>[];
    
    // Load from all cached categories
    for (final entry in _memoryCache.entries) {
      allQuestions.addAll(
        entry.value.where((q) => q.subjectId == subjectId)
      );
    }
    
    return allQuestions;
  }

  /// Get questions by topic
  Future<List<QuestionBankItem>> getQuestionsByTopic(String topicId) async {
    final allQuestions = <QuestionBankItem>[];
    
    for (final entry in _memoryCache.entries) {
      allQuestions.addAll(
        entry.value.where((q) => q.topicId == topicId)
      );
    }
    
    return allQuestions;
  }

  /// Get questions by difficulty
  Future<List<QuestionBankItem>> getQuestionsByDifficulty(String difficulty) async {
    final allQuestions = <QuestionBankItem>[];
    
    for (final entry in _memoryCache.entries) {
      allQuestions.addAll(
        entry.value.where((q) => q.difficulty == difficulty)
      );
    }
    
    return allQuestions;
  }

  /// Get questions by exam category and filters
  Future<List<QuestionBankItem>> getFilteredQuestions({
    String? categoryId,
    String? subjectId,
    String? topicId,
    String? difficulty,
    int? year,
    List<String>? tags,
    int? limit,
  }) async {
    List<QuestionBankItem> questions;
    
    if (categoryId != null) {
      questions = await loadCategoryQuestions(categoryId);
    } else {
      questions = [];
      for (final entry in _memoryCache.entries) {
        questions.addAll(entry.value);
      }
    }

    // Apply filters
    if (subjectId != null) {
      questions = questions.where((q) => q.subjectId == subjectId).toList();
    }
    if (topicId != null) {
      questions = questions.where((q) => q.topicId == topicId).toList();
    }
    if (difficulty != null) {
      questions = questions.where((q) => q.difficulty == difficulty).toList();
    }
    if (year != null) {
      questions = questions.where((q) => q.year == year).toList();
    }
    if (tags != null && tags.isNotEmpty) {
      questions = questions.where((q) => 
        tags.any((tag) => q.tags.contains(tag))
      ).toList();
    }

    // Apply limit
    if (limit != null && questions.length > limit) {
      questions = questions.take(limit).toList();
    }

    return questions;
  }

  /// Get random questions for practice
  Future<List<QuestionBankItem>> getRandomQuestions({
    String? categoryId,
    String? subjectId,
    String? difficulty,
    required int count,
  }) async {
    final filtered = await getFilteredQuestions(
      categoryId: categoryId,
      subjectId: subjectId,
      difficulty: difficulty,
    );

    if (filtered.length <= count) return filtered;

    // Shuffle and take
    final shuffled = List<QuestionBankItem>.from(filtered)..shuffle();
    return shuffled.take(count).toList();
  }

  /// Get total question count
  int getTotalQuestionCount() {
    int total = 0;
    for (final entry in _memoryCache.entries) {
      total += entry.value.length;
    }
    return total;
  }

  /// Get question count by category
  int getCategoryQuestionCount(String categoryId) {
    return _memoryCache[categoryId]?.length ?? 0;
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _memoryCache.clear();
    
    if (_prefs != null) {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_cacheTimestampPrefix)) {
          await _prefs!.remove(key);
        }
      }
    }
    
    notifyListeners();
  }

  /// Clear cache for specific category
  Future<void> clearCategoryCache(String categoryId) async {
    _memoryCache.remove(categoryId);
    
    if (_prefs != null) {
      await _prefs!.remove('$_cachePrefix$categoryId');
      await _prefs!.remove('$_cacheTimestampPrefix$categoryId');
    }
    
    notifyListeners();
  }

  /// Preload questions for offline use
  Future<void> preloadForOffline(List<String> categoryIds) async {
    _isLoading = true;
    notifyListeners();

    for (int i = 0; i < categoryIds.length; i++) {
      _loadingProgress = i / categoryIds.length;
      _loadingCategory = categoryIds[i];
      notifyListeners();

      await loadCategoryQuestions(categoryIds[i]);
    }

    _isLoading = false;
    _loadingCategory = null;
    _loadingProgress = 1.0;
    notifyListeners();
  }
}
