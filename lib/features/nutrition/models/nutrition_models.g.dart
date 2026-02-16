// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodEntryAdapter extends TypeAdapter<FoodEntry> {
  @override
  final int typeId = 40;

  @override
  FoodEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodEntry(
      id: fields[0] as String,
      name: fields[1] as String,
      brand: fields[2] as String?,
      servingSize: fields[3] as double,
      servingUnit: fields[4] as String,
      calories: fields[5] as double,
      protein: fields[6] as double,
      carbs: fields[7] as double,
      fat: fields[8] as double,
      fiber: fields[9] as double?,
      sugar: fields[10] as double?,
      sodium: fields[11] as double?,
      saturatedFat: fields[12] as double?,
      cholesterol: fields[13] as double?,
      mealType: fields[14] as String,
      loggedAt: fields[15] as DateTime,
      barcode: fields[16] as String?,
      imageUrl: fields[17] as String?,
      isFavorite: fields[18] as bool,
      notes: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FoodEntry obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.brand)
      ..writeByte(3)
      ..write(obj.servingSize)
      ..writeByte(4)
      ..write(obj.servingUnit)
      ..writeByte(5)
      ..write(obj.calories)
      ..writeByte(6)
      ..write(obj.protein)
      ..writeByte(7)
      ..write(obj.carbs)
      ..writeByte(8)
      ..write(obj.fat)
      ..writeByte(9)
      ..write(obj.fiber)
      ..writeByte(10)
      ..write(obj.sugar)
      ..writeByte(11)
      ..write(obj.sodium)
      ..writeByte(12)
      ..write(obj.saturatedFat)
      ..writeByte(13)
      ..write(obj.cholesterol)
      ..writeByte(14)
      ..write(obj.mealType)
      ..writeByte(15)
      ..write(obj.loggedAt)
      ..writeByte(16)
      ..write(obj.barcode)
      ..writeByte(17)
      ..write(obj.imageUrl)
      ..writeByte(18)
      ..write(obj.isFavorite)
      ..writeByte(19)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NutritionGoalsAdapter extends TypeAdapter<NutritionGoals> {
  @override
  final int typeId = 41;

  @override
  NutritionGoals read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionGoals(
      dailyCalories: fields[0] as int,
      proteinGrams: fields[1] as double,
      carbsGrams: fields[2] as double,
      fatGrams: fields[3] as double,
      fiberGrams: fields[4] as double?,
      sugarGrams: fields[5] as double?,
      sodiumMg: fields[6] as double?,
      useNetCarbs: fields[7] as bool,
      macroMode: fields[8] as String,
      proteinPercentage: fields[9] as int,
      carbsPercentage: fields[10] as int,
      fatPercentage: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionGoals obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.dailyCalories)
      ..writeByte(1)
      ..write(obj.proteinGrams)
      ..writeByte(2)
      ..write(obj.carbsGrams)
      ..writeByte(3)
      ..write(obj.fatGrams)
      ..writeByte(4)
      ..write(obj.fiberGrams)
      ..writeByte(5)
      ..write(obj.sugarGrams)
      ..writeByte(6)
      ..write(obj.sodiumMg)
      ..writeByte(7)
      ..write(obj.useNetCarbs)
      ..writeByte(8)
      ..write(obj.macroMode)
      ..writeByte(9)
      ..write(obj.proteinPercentage)
      ..writeByte(10)
      ..write(obj.carbsPercentage)
      ..writeByte(11)
      ..write(obj.fatPercentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionGoalsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 42;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      ingredients: (fields[3] as List).cast<RecipeIngredient>(),
      instructions: (fields[4] as List).cast<String>(),
      servings: fields[5] as int,
      prepTimeMinutes: fields[6] as int,
      cookTimeMinutes: fields[7] as int,
      imageUrl: fields[8] as String?,
      tags: (fields[9] as List).cast<String>(),
      isBookmarked: fields[10] as bool,
      source: fields[11] as String?,
      createdAt: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.ingredients)
      ..writeByte(4)
      ..write(obj.instructions)
      ..writeByte(5)
      ..write(obj.servings)
      ..writeByte(6)
      ..write(obj.prepTimeMinutes)
      ..writeByte(7)
      ..write(obj.cookTimeMinutes)
      ..writeByte(8)
      ..write(obj.imageUrl)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.isBookmarked)
      ..writeByte(11)
      ..write(obj.source)
      ..writeByte(12)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecipeIngredientAdapter extends TypeAdapter<RecipeIngredient> {
  @override
  final int typeId = 43;

  @override
  RecipeIngredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeIngredient(
      name: fields[0] as String,
      amount: fields[1] as double,
      unit: fields[2] as String,
      calories: fields[3] as double,
      protein: fields[4] as double,
      carbs: fields[5] as double,
      fat: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeIngredient obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.calories)
      ..writeByte(4)
      ..write(obj.protein)
      ..writeByte(5)
      ..write(obj.carbs)
      ..writeByte(6)
      ..write(obj.fat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MealPlanAdapter extends TypeAdapter<MealPlan> {
  @override
  final int typeId = 44;

  @override
  MealPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      meals: (fields[4] as List).cast<PlannedMeal>(),
      targetCalories: fields[5] as int,
      dietaryRestrictions: (fields[6] as List).cast<String>(),
      isActive: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlan obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.meals)
      ..writeByte(5)
      ..write(obj.targetCalories)
      ..writeByte(6)
      ..write(obj.dietaryRestrictions)
      ..writeByte(7)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlannedMealAdapter extends TypeAdapter<PlannedMeal> {
  @override
  final int typeId = 45;

  @override
  PlannedMeal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedMeal(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      mealType: fields[2] as String,
      recipeId: fields[3] as String?,
      name: fields[4] as String,
      calories: fields[5] as double,
      protein: fields[6] as double,
      carbs: fields[7] as double,
      fat: fields[8] as double,
      isLogged: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedMeal obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.mealType)
      ..writeByte(3)
      ..write(obj.recipeId)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.calories)
      ..writeByte(6)
      ..write(obj.protein)
      ..writeByte(7)
      ..write(obj.carbs)
      ..writeByte(8)
      ..write(obj.fat)
      ..writeByte(9)
      ..write(obj.isLogged);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedMealAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FastingSessionAdapter extends TypeAdapter<FastingSession> {
  @override
  final int typeId = 46;

  @override
  FastingSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FastingSession(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      targetHours: fields[3] as int,
      fastingType: fields[4] as String,
      isCompleted: fields[5] as bool,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FastingSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.targetHours)
      ..writeByte(4)
      ..write(obj.fastingType)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FastingSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GroceryListAdapter extends TypeAdapter<GroceryList> {
  @override
  final int typeId = 47;

  @override
  GroceryList read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroceryList(
      id: fields[0] as String,
      name: fields[1] as String,
      items: (fields[2] as List).cast<GroceryItem>(),
      createdAt: fields[3] as DateTime,
      mealPlanId: fields[4] as String?,
      estimatedCost: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, GroceryList obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.mealPlanId)
      ..writeByte(5)
      ..write(obj.estimatedCost);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryListAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GroceryItemAdapter extends TypeAdapter<GroceryItem> {
  @override
  final int typeId = 48;

  @override
  GroceryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroceryItem(
      name: fields[0] as String,
      quantity: fields[1] as double,
      unit: fields[2] as String,
      category: fields[3] as String,
      isPurchased: fields[4] as bool,
      estimatedPrice: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, GroceryItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.isPurchased)
      ..writeByte(5)
      ..write(obj.estimatedPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
