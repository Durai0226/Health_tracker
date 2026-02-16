import 'package:hive/hive.dart';

part 'nutrition_models.g.dart';

/// Food Entry - Individual food item log
@HiveType(typeId: 40)
class FoodEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? brand;

  @HiveField(3)
  final double servingSize;

  @HiveField(4)
  final String servingUnit; // g, ml, oz, cup, etc.

  @HiveField(5)
  final double calories;

  @HiveField(6)
  final double protein; // grams

  @HiveField(7)
  final double carbs; // grams

  @HiveField(8)
  final double fat; // grams

  @HiveField(9)
  final double? fiber;

  @HiveField(10)
  final double? sugar;

  @HiveField(11)
  final double? sodium; // mg

  @HiveField(12)
  final double? saturatedFat;

  @HiveField(13)
  final double? cholesterol;

  @HiveField(14)
  final String mealType; // breakfast, lunch, dinner, snack

  @HiveField(15)
  final DateTime loggedAt;

  @HiveField(16)
  final String? barcode;

  @HiveField(17)
  final String? imageUrl;

  @HiveField(18)
  final bool isFavorite;

  @HiveField(19)
  final String? notes;

  FoodEntry({
    required this.id,
    required this.name,
    this.brand,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
    this.saturatedFat,
    this.cholesterol,
    required this.mealType,
    required this.loggedAt,
    this.barcode,
    this.imageUrl,
    this.isFavorite = false,
    this.notes,
  });

  double get netCarbs => (carbs - (fiber ?? 0)).clamp(0, double.infinity);

  int get nutrientScore {
    int score = 50;
    if (fiber != null && fiber! > 3) score += 10;
    if (protein > 10) score += 10;
    if (sugar != null && sugar! < 5) score += 10;
    if (saturatedFat != null && saturatedFat! < 3) score += 10;
    if (sodium != null && sodium! < 500) score += 10;
    return score.clamp(0, 100);
  }

  String get mealEmoji {
    switch (mealType) {
      case 'breakfast': return '🌅';
      case 'lunch': return '☀️';
      case 'dinner': return '🌙';
      case 'snack': return '🍎';
      default: return '🍽️';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
    'sodium': sodium,
    'saturatedFat': saturatedFat,
    'cholesterol': cholesterol,
    'mealType': mealType,
    'loggedAt': loggedAt.toIso8601String(),
    'barcode': barcode,
    'imageUrl': imageUrl,
    'isFavorite': isFavorite,
    'notes': notes,
  };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    brand: json['brand'],
    servingSize: (json['servingSize'] ?? 0).toDouble(),
    servingUnit: json['servingUnit'] ?? 'g',
    calories: (json['calories'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    carbs: (json['carbs'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
    fiber: json['fiber']?.toDouble(),
    sugar: json['sugar']?.toDouble(),
    sodium: json['sodium']?.toDouble(),
    saturatedFat: json['saturatedFat']?.toDouble(),
    cholesterol: json['cholesterol']?.toDouble(),
    mealType: json['mealType'] ?? 'snack',
    loggedAt: DateTime.parse(json['loggedAt'] ?? DateTime.now().toIso8601String()),
    barcode: json['barcode'],
    imageUrl: json['imageUrl'],
    isFavorite: json['isFavorite'] ?? false,
    notes: json['notes'],
  );
}

/// Nutrition Goals - Daily macro targets
@HiveType(typeId: 41)
class NutritionGoals extends HiveObject {
  @HiveField(0)
  final int dailyCalories;

  @HiveField(1)
  final double proteinGrams;

  @HiveField(2)
  final double carbsGrams;

  @HiveField(3)
  final double fatGrams;

  @HiveField(4)
  final double? fiberGrams;

  @HiveField(5)
  final double? sugarGrams;

  @HiveField(6)
  final double? sodiumMg;

  @HiveField(7)
  final bool useNetCarbs;

  @HiveField(8)
  final String macroMode; // grams, percentage

  @HiveField(9)
  final int proteinPercentage;

  @HiveField(10)
  final int carbsPercentage;

  @HiveField(11)
  final int fatPercentage;

  NutritionGoals({
    this.dailyCalories = 2000,
    this.proteinGrams = 150,
    this.carbsGrams = 200,
    this.fatGrams = 65,
    this.fiberGrams = 25,
    this.sugarGrams = 50,
    this.sodiumMg = 2300,
    this.useNetCarbs = false,
    this.macroMode = 'grams',
    this.proteinPercentage = 30,
    this.carbsPercentage = 40,
    this.fatPercentage = 30,
  });

  Map<String, dynamic> toJson() => {
    'dailyCalories': dailyCalories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'fiberGrams': fiberGrams,
    'sugarGrams': sugarGrams,
    'sodiumMg': sodiumMg,
    'useNetCarbs': useNetCarbs,
    'macroMode': macroMode,
    'proteinPercentage': proteinPercentage,
    'carbsPercentage': carbsPercentage,
    'fatPercentage': fatPercentage,
  };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
    dailyCalories: json['dailyCalories'] ?? 2000,
    proteinGrams: (json['proteinGrams'] ?? 150).toDouble(),
    carbsGrams: (json['carbsGrams'] ?? 200).toDouble(),
    fatGrams: (json['fatGrams'] ?? 65).toDouble(),
    fiberGrams: json['fiberGrams']?.toDouble(),
    sugarGrams: json['sugarGrams']?.toDouble(),
    sodiumMg: json['sodiumMg']?.toDouble(),
    useNetCarbs: json['useNetCarbs'] ?? false,
    macroMode: json['macroMode'] ?? 'grams',
    proteinPercentage: json['proteinPercentage'] ?? 30,
    carbsPercentage: json['carbsPercentage'] ?? 40,
    fatPercentage: json['fatPercentage'] ?? 30,
  );
}

/// Recipe - Saved recipes with ingredients
@HiveType(typeId: 42)
class Recipe extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final List<RecipeIngredient> ingredients;

  @HiveField(4)
  final List<String> instructions;

  @HiveField(5)
  final int servings;

  @HiveField(6)
  final int prepTimeMinutes;

  @HiveField(7)
  final int cookTimeMinutes;

  @HiveField(8)
  final String? imageUrl;

  @HiveField(9)
  final List<String> tags; // vegetarian, vegan, gluten-free, etc.

  @HiveField(10)
  final bool isBookmarked;

  @HiveField(11)
  final String? source; // URL or source

  @HiveField(12)
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    this.imageUrl,
    this.tags = const [],
    this.isBookmarked = false,
    this.source,
    required this.createdAt,
  });

  double get totalCalories => ingredients.fold(0, (sum, i) => sum + i.calories);
  double get totalProtein => ingredients.fold(0, (sum, i) => sum + i.protein);
  double get totalCarbs => ingredients.fold(0, (sum, i) => sum + i.carbs);
  double get totalFat => ingredients.fold(0, (sum, i) => sum + i.fat);

  double get caloriesPerServing => totalCalories / servings;
  double get proteinPerServing => totalProtein / servings;
  double get carbsPerServing => totalCarbs / servings;
  double get fatPerServing => totalFat / servings;

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'instructions': instructions,
    'servings': servings,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'imageUrl': imageUrl,
    'tags': tags,
    'isBookmarked': isBookmarked,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    ingredients: (json['ingredients'] as List<dynamic>?)
        ?.map((i) => RecipeIngredient.fromJson(i))
        .toList() ?? [],
    instructions: List<String>.from(json['instructions'] ?? []),
    servings: json['servings'] ?? 1,
    prepTimeMinutes: json['prepTimeMinutes'] ?? 0,
    cookTimeMinutes: json['cookTimeMinutes'] ?? 0,
    imageUrl: json['imageUrl'],
    tags: List<String>.from(json['tags'] ?? []),
    isBookmarked: json['isBookmarked'] ?? false,
    source: json['source'],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
  );
}

@HiveType(typeId: 43)
class RecipeIngredient extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final double calories;

  @HiveField(4)
  final double protein;

  @HiveField(5)
  final double carbs;

  @HiveField(6)
  final double fat;

  RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'unit': unit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
    name: json['name'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    unit: json['unit'] ?? '',
    calories: (json['calories'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    carbs: (json['carbs'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
  );
}

/// Meal Plan - Weekly/daily meal planning
@HiveType(typeId: 44)
class MealPlan extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime startDate;

  @HiveField(3)
  final DateTime endDate;

  @HiveField(4)
  final List<PlannedMeal> meals;

  @HiveField(5)
  final int targetCalories;

  @HiveField(6)
  final List<String> dietaryRestrictions;

  @HiveField(7)
  final bool isActive;

  MealPlan({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.meals,
    required this.targetCalories,
    this.dietaryRestrictions = const [],
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'meals': meals.map((m) => m.toJson()).toList(),
    'targetCalories': targetCalories,
    'dietaryRestrictions': dietaryRestrictions,
    'isActive': isActive,
  };

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
    endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
    meals: (json['meals'] as List<dynamic>?)
        ?.map((m) => PlannedMeal.fromJson(m))
        .toList() ?? [],
    targetCalories: json['targetCalories'] ?? 2000,
    dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
    isActive: json['isActive'] ?? true,
  );
}

@HiveType(typeId: 45)
class PlannedMeal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final String mealType; // breakfast, lunch, dinner, snack

  @HiveField(3)
  final String? recipeId;

  @HiveField(4)
  final String name;

  @HiveField(5)
  final double calories;

  @HiveField(6)
  final double protein;

  @HiveField(7)
  final double carbs;

  @HiveField(8)
  final double fat;

  @HiveField(9)
  final bool isLogged;

  PlannedMeal({
    required this.id,
    required this.date,
    required this.mealType,
    this.recipeId,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.isLogged = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'mealType': mealType,
    'recipeId': recipeId,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'isLogged': isLogged,
  };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
    id: json['id'] ?? '',
    date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    mealType: json['mealType'] ?? 'snack',
    recipeId: json['recipeId'],
    name: json['name'] ?? '',
    calories: (json['calories'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    carbs: (json['carbs'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
    isLogged: json['isLogged'] ?? false,
  );
}

/// Intermittent Fasting - Fasting tracker
@HiveType(typeId: 46)
class FastingSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime? endTime;

  @HiveField(3)
  final int targetHours; // 16, 18, 20, etc.

  @HiveField(4)
  final String fastingType; // 16:8, 18:6, 20:4, OMAD, custom

  @HiveField(5)
  final bool isCompleted;

  @HiveField(6)
  final String? notes;

  FastingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.targetHours,
    required this.fastingType,
    this.isCompleted = false,
    this.notes,
  });

  Duration get elapsedDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double get progressPercentage {
    final elapsed = elapsedDuration.inMinutes;
    final target = targetHours * 60;
    return (elapsed / target * 100).clamp(0, 100);
  }

  Duration get remainingDuration {
    final target = Duration(hours: targetHours);
    final remaining = target - elapsedDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isTargetReached => elapsedDuration.inHours >= targetHours;

  String get fastingEmoji {
    if (progressPercentage < 25) return '🌙';
    if (progressPercentage < 50) return '⏳';
    if (progressPercentage < 75) return '🔥';
    if (progressPercentage < 100) return '💪';
    return '🏆';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'targetHours': targetHours,
    'fastingType': fastingType,
    'isCompleted': isCompleted,
    'notes': notes,
  };

  factory FastingSession.fromJson(Map<String, dynamic> json) => FastingSession(
    id: json['id'] ?? '',
    startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    targetHours: json['targetHours'] ?? 16,
    fastingType: json['fastingType'] ?? '16:8',
    isCompleted: json['isCompleted'] ?? false,
    notes: json['notes'],
  );
}

/// Grocery List - Shopping list from meal plans
@HiveType(typeId: 47)
class GroceryList extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<GroceryItem> items;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? mealPlanId;

  @HiveField(5)
  final double? estimatedCost;

  GroceryList({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    this.mealPlanId,
    this.estimatedCost,
  });

  int get completedCount => items.where((i) => i.isPurchased).length;
  double get completionPercentage => items.isEmpty ? 0 : completedCount / items.length * 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'mealPlanId': mealPlanId,
    'estimatedCost': estimatedCost,
  };

  factory GroceryList.fromJson(Map<String, dynamic> json) => GroceryList(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    items: (json['items'] as List<dynamic>?)
        ?.map((i) => GroceryItem.fromJson(i))
        .toList() ?? [],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    mealPlanId: json['mealPlanId'],
    estimatedCost: json['estimatedCost']?.toDouble(),
  );
}

@HiveType(typeId: 48)
class GroceryItem extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double quantity;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final String category; // produce, dairy, meat, etc.

  @HiveField(4)
  bool isPurchased;

  @HiveField(5)
  final double? estimatedPrice;

  GroceryItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.isPurchased = false,
    this.estimatedPrice,
  });

  String get categoryEmoji {
    switch (category.toLowerCase()) {
      case 'produce': return '🥬';
      case 'dairy': return '🧀';
      case 'meat': return '🥩';
      case 'seafood': return '🐟';
      case 'grains': return '🌾';
      case 'frozen': return '🧊';
      case 'beverages': return '🥤';
      case 'snacks': return '🍿';
      default: return '🛒';
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'category': category,
    'isPurchased': isPurchased,
    'estimatedPrice': estimatedPrice,
  };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
    name: json['name'] ?? '',
    quantity: (json['quantity'] ?? 0).toDouble(),
    unit: json['unit'] ?? '',
    category: json['category'] ?? 'other',
    isPurchased: json['isPurchased'] ?? false,
    estimatedPrice: json['estimatedPrice']?.toDouble(),
  );
}

/// Daily Nutrition Summary
class DailyNutritionSummary {
  final DateTime date;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final double totalSugar;
  final double totalSodium;
  final List<FoodEntry> entries;
  final NutritionGoals goals;

  DailyNutritionSummary({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    required this.totalSugar,
    required this.totalSodium,
    required this.entries,
    required this.goals,
  });

  double get caloriesProgress => (totalCalories / goals.dailyCalories * 100).clamp(0, 150);
  double get proteinProgress => (totalProtein / goals.proteinGrams * 100).clamp(0, 150);
  double get carbsProgress => (totalCarbs / goals.carbsGrams * 100).clamp(0, 150);
  double get fatProgress => (totalFat / goals.fatGrams * 100).clamp(0, 150);

  int get remainingCalories => (goals.dailyCalories - totalCalories).round();

  Map<String, List<FoodEntry>> get entriesByMeal {
    final result = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      result.putIfAbsent(entry.mealType, () => []).add(entry);
    }
    return result;
  }
}

/// Weekly Nutrition Digest
class WeeklyNutritionDigest {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final int daysLogged;
  final int goalsMet;
  final List<String> bestFoods;
  final List<String> worstFoods;
  final String trend; // improving, maintaining, declining

  WeeklyNutritionDigest({
    required this.weekStart,
    required this.weekEnd,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    required this.daysLogged,
    required this.goalsMet,
    required this.bestFoods,
    required this.worstFoods,
    required this.trend,
  });
}
