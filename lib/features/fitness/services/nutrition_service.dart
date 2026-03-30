import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal.dart';

/// Nutrition Service for meal tracking and nutrition data persistence
/// Uses SharedPreferences for local storage with optional Firestore sync
class NutritionService {
  static final NutritionService _instance = NutritionService._internal();
  factory NutritionService() => _instance;
  NutritionService._internal();

  static const String _mealEntriesKey = 'nutrition_meal_entries';
  static const String _dailyNutritionKey = 'nutrition_daily';
  static const String _customFoodsKey = 'nutrition_custom_foods';
  static const String _goalsKey = 'nutrition_goals';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Cached data
  List<MealEntry> _mealEntries = [];
  Map<String, DailyNutrition> _dailyNutrition = {};
  List<FoodItem> _customFoods = [];
  NutritionGoals _goals = NutritionGoals.defaultGoals();

  bool get isInitialized => _isInitialized;
  List<MealEntry> get mealEntries => List.unmodifiable(_mealEntries);
  List<FoodItem> get customFoods => List.unmodifiable(_customFoods);
  NutritionGoals get goals => _goals;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Initialize the service and load cached data
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _loadMealEntries();
      await _loadDailyNutrition();
      await _loadCustomFoods();
      await _loadGoals();
      _isInitialized = true;
      debugPrint('✓ NutritionService initialized');
    } catch (e) {
      debugPrint('Error initializing NutritionService: $e');
    }
  }

  // ============================================
  // MEAL ENTRY MANAGEMENT
  // ============================================

  /// Get meal entries for a specific date
  List<MealEntry> getMealEntriesForDate(DateTime date) {
    final dateStr = _dateToString(date);
    return _mealEntries.where((entry) => 
      _dateToString(entry.loggedAt) == dateStr
    ).toList();
  }

  /// Get meal entries by type for a date
  List<MealEntry> getMealEntriesByType(DateTime date, MealType type) {
    return getMealEntriesForDate(date).where((e) => e.type == type).toList();
  }

  /// Add a new meal entry
  Future<MealEntry> addMealEntry({
    required MealType type,
    required List<MealFoodItem> foods,
    String? notes,
    DateTime? loggedAt,
  }) async {
    final entry = MealEntry(
      id: _generateId(),
      type: type,
      foods: foods,
      loggedAt: loggedAt ?? DateTime.now(),
      notes: notes,
    );

    _mealEntries.add(entry);
    await _saveMealEntries();
    await _updateDailyNutrition(entry.loggedAt);
    
    return entry;
  }

  /// Update an existing meal entry
  Future<bool> updateMealEntry(MealEntry updated) async {
    final index = _mealEntries.indexWhere((e) => e.id == updated.id);
    if (index == -1) return false;

    final oldDate = _mealEntries[index].loggedAt;
    _mealEntries[index] = updated;
    await _saveMealEntries();
    
    // Update daily nutrition for both old and new dates
    await _updateDailyNutrition(oldDate);
    if (_dateToString(oldDate) != _dateToString(updated.loggedAt)) {
      await _updateDailyNutrition(updated.loggedAt);
    }
    
    return true;
  }

  /// Delete a meal entry
  Future<bool> deleteMealEntry(String id) async {
    final index = _mealEntries.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    final entry = _mealEntries[index];
    _mealEntries.removeAt(index);
    await _saveMealEntries();
    await _updateDailyNutrition(entry.loggedAt);
    
    return true;
  }

  /// Quick add calories without detailed food tracking
  Future<MealEntry> quickAddCalories({
    required MealType type,
    required double calories,
    String? name,
  }) async {
    final food = MealFoodItem(
      food: FoodItem(
        id: _generateId(),
        name: name ?? 'Quick Add',
        calories: calories,
        protein: 0,
        carbs: 0,
        fat: 0,
      ),
      quantity: 1,
    );

    return addMealEntry(type: type, foods: [food]);
  }

  // ============================================
  // DAILY NUTRITION
  // ============================================

  /// Get daily nutrition for a specific date
  DailyNutrition getDailyNutrition(DateTime date) {
    final dateStr = _dateToString(date);
    if (_dailyNutrition.containsKey(dateStr)) {
      return _dailyNutrition[dateStr]!;
    }
    // Create default nutrition with meals from that date
    final meals = getMealEntriesForDate(date);
    return DailyNutrition(
      date: date,
      meals: meals,
      targetCalories: _goals.dailyCalories.round(),
      targetProtein: _goals.dailyProtein.round(),
      targetCarbs: _goals.dailyCarbs.round(),
      targetFat: _goals.dailyFat.round(),
    );
  }

  /// Get daily nutrition for date range
  List<DailyNutrition> getDailyNutritionRange(DateTime start, DateTime end) {
    final results = <DailyNutrition>[];
    var current = start;
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      results.add(getDailyNutrition(current));
      current = current.add(const Duration(days: 1));
    }
    
    return results;
  }

  /// Get this week's nutrition summary
  List<DailyNutrition> getWeeklyNutrition() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return getDailyNutritionRange(weekStart, now);
  }

  /// Calculate and update daily nutrition for a date
  Future<void> _updateDailyNutrition(DateTime date) async {
    final dateStr = _dateToString(date);
    final meals = getMealEntriesForDate(date);

    _dailyNutrition[dateStr] = DailyNutrition(
      date: date,
      meals: meals,
      targetCalories: _goals.dailyCalories.round(),
      targetProtein: _goals.dailyProtein.round(),
      targetCarbs: _goals.dailyCarbs.round(),
      targetFat: _goals.dailyFat.round(),
    );

    await _saveDailyNutrition();
  }

  // ============================================
  // CUSTOM FOODS
  // ============================================

  /// Add a custom food item
  Future<FoodItem> addCustomFood(FoodItem food) async {
    final newFood = FoodItem(
      id: food.id.isEmpty ? _generateId() : food.id,
      name: food.name,
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      servingSize: food.servingSize,
      servingUnit: food.servingUnit,
      imageUrl: food.imageUrl,
      category: food.category,
    );

    _customFoods.add(newFood);
    await _saveCustomFoods();
    return newFood;
  }

  /// Delete a custom food
  Future<bool> deleteCustomFood(String id) async {
    final index = _customFoods.indexWhere((f) => f.id == id);
    if (index == -1) return false;
    _customFoods.removeAt(index);
    await _saveCustomFoods();
    return true;
  }

  /// Search custom foods
  List<FoodItem> searchCustomFoods(String query) {
    final lowerQuery = query.toLowerCase();
    return _customFoods.where((f) => 
      f.name.toLowerCase().contains(lowerQuery) ||
      (f.category?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  // ============================================
  // NUTRITION GOALS
  // ============================================

  /// Update nutrition goals
  Future<void> updateGoals(NutritionGoals newGoals) async {
    _goals = newGoals;
    await _saveGoals();
    
    // Recalculate daily nutrition with new goals
    for (final dateStr in _dailyNutrition.keys) {
      final date = DateTime.parse(dateStr);
      await _updateDailyNutrition(date);
    }
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// Get average daily calories for last N days
  double getAverageCalories(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final nutrition = getDailyNutritionRange(start, now);
    
    if (nutrition.isEmpty) return 0;
    
    final total = nutrition.fold<double>(0, (sum, n) => sum + n.consumedCalories);
    return total / nutrition.length;
  }

  /// Get calorie trend (positive = increasing, negative = decreasing)
  double getCalorieTrend() {
    final thisWeek = getWeeklyNutrition();
    if (thisWeek.length < 2) return 0;

    final now = DateTime.now();
    final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
    final lastWeekEnd = now.subtract(Duration(days: now.weekday));
    final lastWeek = getDailyNutritionRange(lastWeekStart, lastWeekEnd);

    final thisWeekAvg = thisWeek.fold<double>(0, (sum, n) => sum + n.consumedCalories) / thisWeek.length;
    final lastWeekAvg = lastWeek.isEmpty ? thisWeekAvg : 
        lastWeek.fold<double>(0, (sum, n) => sum + n.consumedCalories) / lastWeek.length;

    if (lastWeekAvg == 0) return 0;
    return ((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100;
  }

  /// Get macro distribution for a date
  Map<String, double> getMacroDistribution(DateTime date) {
    final nutrition = getDailyNutrition(date);
    final total = nutrition.consumedProtein + nutrition.consumedCarbs + nutrition.consumedFat;
    
    if (total == 0) {
      return {'protein': 0.33, 'carbs': 0.33, 'fat': 0.33};
    }

    return {
      'protein': nutrition.consumedProtein / total,
      'carbs': nutrition.consumedCarbs / total,
      'fat': nutrition.consumedFat / total,
    };
  }

  // ============================================
  // PERSISTENCE
  // ============================================

  Future<void> _loadMealEntries() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_mealEntriesKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _mealEntries = decoded.map((e) => MealEntry.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading meal entries: $e');
    }
  }

  Future<void> _saveMealEntries() async {
    try {
      final prefs = await _preferences;
      final json = jsonEncode(_mealEntries.map((e) => e.toJson()).toList());
      await prefs.setString(_mealEntriesKey, json);
    } catch (e) {
      debugPrint('Error saving meal entries: $e');
    }
  }

  Future<void> _loadDailyNutrition() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_dailyNutritionKey);
      if (json != null) {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _dailyNutrition = decoded.map((key, value) => 
          MapEntry(key, DailyNutrition.fromJson(value))
        );
      }
    } catch (e) {
      debugPrint('Error loading daily nutrition: $e');
    }
  }

  Future<void> _saveDailyNutrition() async {
    try {
      final prefs = await _preferences;
      final json = jsonEncode(_dailyNutrition.map((key, value) => 
        MapEntry(key, value.toJson())
      ));
      await prefs.setString(_dailyNutritionKey, json);
    } catch (e) {
      debugPrint('Error saving daily nutrition: $e');
    }
  }

  Future<void> _loadCustomFoods() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_customFoodsKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _customFoods = decoded.map((e) => FoodItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading custom foods: $e');
    }
  }

  Future<void> _saveCustomFoods() async {
    try {
      final prefs = await _preferences;
      final json = jsonEncode(_customFoods.map((e) => e.toJson()).toList());
      await prefs.setString(_customFoodsKey, json);
    } catch (e) {
      debugPrint('Error saving custom foods: $e');
    }
  }

  Future<void> _loadGoals() async {
    try {
      final prefs = await _preferences;
      final json = prefs.getString(_goalsKey);
      if (json != null) {
        _goals = NutritionGoals.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  Future<void> _saveGoals() async {
    try {
      final prefs = await _preferences;
      final json = jsonEncode(_goals.toJson());
      await prefs.setString(_goalsKey, json);
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           (1000 + (DateTime.now().microsecond % 9000)).toString();
  }

  /// Clear all nutrition data (for testing/reset)
  Future<void> clearAllData() async {
    _mealEntries.clear();
    _dailyNutrition.clear();
    _customFoods.clear();
    _goals = NutritionGoals.defaultGoals();

    final prefs = await _preferences;
    await prefs.remove(_mealEntriesKey);
    await prefs.remove(_dailyNutritionKey);
    await prefs.remove(_customFoodsKey);
    await prefs.remove(_goalsKey);
  }
}

/// Nutrition goals model
class NutritionGoals {
  final double dailyCalories;
  final double dailyProtein;
  final double dailyCarbs;
  final double dailyFat;
  final double dailyWater; // in ml

  const NutritionGoals({
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyCarbs,
    required this.dailyFat,
    this.dailyWater = 2000,
  });

  factory NutritionGoals.defaultGoals() => const NutritionGoals(
    dailyCalories: 2000,
    dailyProtein: 50,
    dailyCarbs: 250,
    dailyFat: 65,
    dailyWater: 2000,
  );

  Map<String, dynamic> toJson() => {
    'dailyCalories': dailyCalories,
    'dailyProtein': dailyProtein,
    'dailyCarbs': dailyCarbs,
    'dailyFat': dailyFat,
    'dailyWater': dailyWater,
  };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
    dailyCalories: (json['dailyCalories'] ?? 2000).toDouble(),
    dailyProtein: (json['dailyProtein'] ?? 50).toDouble(),
    dailyCarbs: (json['dailyCarbs'] ?? 250).toDouble(),
    dailyFat: (json['dailyFat'] ?? 65).toDouble(),
    dailyWater: (json['dailyWater'] ?? 2000).toDouble(),
  );

  NutritionGoals copyWith({
    double? dailyCalories,
    double? dailyProtein,
    double? dailyCarbs,
    double? dailyFat,
    double? dailyWater,
  }) => NutritionGoals(
    dailyCalories: dailyCalories ?? this.dailyCalories,
    dailyProtein: dailyProtein ?? this.dailyProtein,
    dailyCarbs: dailyCarbs ?? this.dailyCarbs,
    dailyFat: dailyFat ?? this.dailyFat,
    dailyWater: dailyWater ?? this.dailyWater,
  );
}
