import 'package:drift/drift.dart';

/// Daily Water Data Table
@TableIndex(name: 'idx_water_day_date', columns: {#date})
class DailyWaterDataTable extends Table {
  @override
  String get tableName => 'daily_water_data';

  TextColumn get id => text()(); // date key: yyyy-MM-dd
  DateTimeColumn get date => dateTime()();
  IntColumn get dailyGoalMl => integer().withDefault(const Constant(2500))();
  IntColumn get totalIntakeMl => integer().withDefault(const Constant(0))();
  IntColumn get effectiveHydrationMl => integer().withDefault(const Constant(0))();
  IntColumn get totalCaffeineMg => integer().withDefault(const Constant(0))();
  IntColumn get alcoholicDrinksCount => integer().withDefault(const Constant(0))();
  BoolColumn get goalReached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get goalReachedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Enhanced Water Logs Table
@TableIndex(name: 'idx_water_logs_daily', columns: {#dailyDataId})
class EnhancedWaterLogs extends Table {
  TextColumn get id => text()();
  TextColumn get dailyDataId => text()(); // Foreign key to DailyWaterData
  DateTimeColumn get time => dateTime()();
  IntColumn get amountMl => integer()();
  IntColumn get effectiveHydrationMl => integer()();
  TextColumn get beverageId => text()();
  TextColumn get beverageName => text()();
  TextColumn get beverageEmoji => text().nullable()();
  IntColumn get hydrationPercent => integer().withDefault(const Constant(100))();
  TextColumn get containerId => text().nullable()();
  TextColumn get containerName => text().nullable()();
  IntColumn get caffeineAmount => integer().withDefault(const Constant(0))();
  BoolColumn get isAlcoholic => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Beverage Types Table
class BeverageTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('💧'))();
  IntColumn get hydrationPercent => integer().withDefault(const Constant(100))();
  IntColumn get colorValue => integer()();
  BoolColumn get hasCaffeine => boolean().withDefault(const Constant(false))();
  RealColumn get caffeinePerMl => real().withDefault(const Constant(0.0))();
  BoolColumn get isAlcoholic => boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Water Containers Table
class WaterContainers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get capacityMl => integer()();
  TextColumn get emoji => text().withDefault(const Constant('🥤'))();
  IntColumn get colorValue => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUsed => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Hydration Profiles Table
class HydrationProfiles extends Table {
  TextColumn get id => text()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get activityLevel => integer().withDefault(const Constant(1))(); // ActivityLevel enum
  IntColumn get climateType => integer().withDefault(const Constant(1))(); // ClimateType enum
  IntColumn get customGoalMl => integer().nullable()();
  BoolColumn get useCustomGoal => boolean().withDefault(const Constant(false))();
  BoolColumn get pregnantOrNursing => boolean().withDefault(const Constant(false))();
  TextColumn get healthConditionsJson => text().nullable()(); // JSON array
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Water Achievements Table
class WaterAchievements extends Table {
  TextColumn get id => text()();
  IntColumn get totalDrinks => integer().withDefault(const Constant(0))();
  IntColumn get totalMl => integer().withDefault(const Constant(0))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  IntColumn get daysGoalMet => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastGoalMetDate => dateTime().nullable()();
  IntColumn get earlyMorningDrinks => integer().withDefault(const Constant(0))();
  IntColumn get caffeineFreeDays => integer().withDefault(const Constant(0))();
  IntColumn get alcoholFreeDays => integer().withDefault(const Constant(0))();
  IntColumn get totalPoints => integer().withDefault(const Constant(0))();
  TextColumn get beverageTypesUsedJson => text().nullable()(); // JSON array
  TextColumn get achievementsJson => text().nullable()(); // JSON array of achievement data

  @override
  Set<Column> get primaryKey => {id};
}
