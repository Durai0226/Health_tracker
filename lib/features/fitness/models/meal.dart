import 'dart:convert';

/// Meal types for nutrition tracking
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '☀️';
      case MealType.dinner:
        return '🌙';
      case MealType.snack:
        return '🍎';
    }
  }

  String get timeRange {
    switch (this) {
      case MealType.breakfast:
        return '6:00 - 10:00';
      case MealType.lunch:
        return '11:00 - 14:00';
      case MealType.dinner:
        return '17:00 - 21:00';
      case MealType.snack:
        return 'Anytime';
    }
  }
}

/// Individual food item with nutritional info
class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSize;
  final String servingUnit;
  final String? imageUrl;
  final String? category;

  const FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.servingSize = 100,
    this.servingUnit = 'g',
    this.imageUrl,
    this.category,
  });

  double get totalMacros => protein + carbs + fat;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'imageUrl': imageUrl,
    'category': category,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    calories: (json['calories'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    carbs: (json['carbs'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
    servingSize: (json['servingSize'] ?? 100).toDouble(),
    servingUnit: json['servingUnit'] ?? 'g',
    imageUrl: json['imageUrl'],
    category: json['category'],
  );
}

/// Logged meal entry
class MealEntry {
  final String id;
  final MealType type;
  final List<MealFoodItem> foods;
  final DateTime loggedAt;
  final String? notes;

  const MealEntry({
    required this.id,
    required this.type,
    required this.foods,
    required this.loggedAt,
    this.notes,
  });

  double get totalCalories => foods.fold(0, (sum, f) => sum + f.totalCalories);
  double get totalProtein => foods.fold(0, (sum, f) => sum + f.totalProtein);
  double get totalCarbs => foods.fold(0, (sum, f) => sum + f.totalCarbs);
  double get totalFat => foods.fold(0, (sum, f) => sum + f.totalFat);

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'foods': foods.map((f) => f.toJson()).toList(),
    'loggedAt': loggedAt.toIso8601String(),
    'notes': notes,
  };

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: json['id'] ?? '',
    type: MealType.values[json['type'] ?? 0],
    foods: (json['foods'] as List<dynamic>?)
        ?.map((f) => MealFoodItem.fromJson(f))
        .toList() ?? [],
    loggedAt: json['loggedAt'] != null
        ? DateTime.parse(json['loggedAt'])
        : DateTime.now(),
    notes: json['notes'],
  );
}

/// Food item with quantity in a meal
class MealFoodItem {
  final FoodItem food;
  final double quantity;

  const MealFoodItem({
    required this.food,
    this.quantity = 1,
  });

  double get totalCalories => food.calories * quantity;
  double get totalProtein => food.protein * quantity;
  double get totalCarbs => food.carbs * quantity;
  double get totalFat => food.fat * quantity;

  Map<String, dynamic> toJson() => {
    'food': food.toJson(),
    'quantity': quantity,
  };

  factory MealFoodItem.fromJson(Map<String, dynamic> json) => MealFoodItem(
    food: FoodItem.fromJson(json['food'] ?? {}),
    quantity: (json['quantity'] ?? 1).toDouble(),
  );
}

/// Daily nutrition summary
class DailyNutrition {
  final DateTime date;
  final List<MealEntry> meals;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFat;
  final double waterLiters;

  const DailyNutrition({
    required this.date,
    this.meals = const [],
    this.targetCalories = 2000,
    this.targetProtein = 150,
    this.targetCarbs = 250,
    this.targetFat = 65,
    this.waterLiters = 0,
  });

  double get consumedCalories => meals.fold(0, (sum, m) => sum + m.totalCalories);
  double get consumedProtein => meals.fold(0, (sum, m) => sum + m.totalProtein);
  double get consumedCarbs => meals.fold(0, (sum, m) => sum + m.totalCarbs);
  double get consumedFat => meals.fold(0, (sum, m) => sum + m.totalFat);

  double get caloriesProgress => (consumedCalories / targetCalories).clamp(0, 1.5);
  double get proteinProgress => (consumedProtein / targetProtein).clamp(0, 1.5);
  double get carbsProgress => (consumedCarbs / targetCarbs).clamp(0, 1.5);
  double get fatProgress => (consumedFat / targetFat).clamp(0, 1.5);

  int get remainingCalories => (targetCalories - consumedCalories).round();

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'meals': meals.map((m) => m.toJson()).toList(),
    'targetCalories': targetCalories,
    'targetProtein': targetProtein,
    'targetCarbs': targetCarbs,
    'targetFat': targetFat,
    'waterLiters': waterLiters,
  };

  factory DailyNutrition.fromJson(Map<String, dynamic> json) => DailyNutrition(
    date: json['date'] != null
        ? DateTime.parse(json['date'])
        : DateTime.now(),
    meals: (json['meals'] as List<dynamic>?)
        ?.map((m) => MealEntry.fromJson(m))
        .toList() ?? [],
    targetCalories: json['targetCalories'] ?? 2000,
    targetProtein: json['targetProtein'] ?? 150,
    targetCarbs: json['targetCarbs'] ?? 250,
    targetFat: json['targetFat'] ?? 65,
    waterLiters: (json['waterLiters'] ?? 0).toDouble(),
  );

  String toJsonString() => jsonEncode(toJson());

  factory DailyNutrition.fromJsonString(String jsonString) =>
      DailyNutrition.fromJson(jsonDecode(jsonString));
}
