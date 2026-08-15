import 'package:drift/drift.dart';

/// Step-count tracking tables. Universal sync fields on every row (see
/// period_tables.dart). `HealthProfiles` is a single-row body/schedule profile
/// shared by the Steps and Sleep features (stride/weight for distance+calories,
/// bedtime/wake target for sleep).

/// One day's step total (date-keyed). `sensorSteps` from HealthKit/Health
/// Connect/pedometer; `manualSteps` from the user; `effectiveSteps` =
/// sensorSteps ?? manualSteps (computed in the model).
@DataClassName('StepDayRow')
@TableIndex(name: 'idx_steps_date', columns: {#date})
class StepDailyData extends Table {
  TextColumn get id => text()(); // yyyy-MM-dd
  DateTimeColumn get date => dateTime()();
  IntColumn get goalSteps => integer().withDefault(const Constant(8000))();
  IntColumn get sensorSteps => integer().nullable()();
  IntColumn get manualSteps => integer().withDefault(const Constant(0))();
  RealColumn get distanceMeters => real().withDefault(const Constant(0))();
  RealColumn get activeCalories => real().withDefault(const Constant(0))();
  IntColumn get sourceIndex =>
      integer().withDefault(const Constant(3))(); // StepSource.index (manual)
  TextColumn get hourlyJson => text().nullable()(); // JSON int[24]
  BoolColumn get goalReached => boolean().withDefault(const Constant(false))();
  DateTimeColumn get goalReachedAt => dateTime().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A manual step adjustment/log entry (many per day).
@DataClassName('StepManualEntryRow')
class StepManualEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dailyDataId => text()(); // → StepDailyData.id
  DateTimeColumn get time => dateTime()();
  IntColumn get steps => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row (`id = 'profile'`) body + schedule profile, shared by Steps
/// (distance/calorie/adaptive-goal math) and Sleep (target + bedtime/wake).
@DataClassName('HealthProfileRow')
class HealthProfiles extends Table {
  TextColumn get id => text()(); // 'profile'
  RealColumn get weightKg => real().nullable()();
  IntColumn get heightCm => integer().nullable()();
  IntColumn get age => integer().nullable()();
  BoolColumn get isMale => boolean().withDefault(const Constant(true))();
  RealColumn get strideLengthCm => real().nullable()();
  IntColumn get customStepGoal => integer().nullable()();
  BoolColumn get useCustomStepGoal =>
      boolean().withDefault(const Constant(false))();
  IntColumn get targetSleepMinutes =>
      integer().withDefault(const Constant(480))();
  IntColumn get bedtimeHour => integer().withDefault(const Constant(22))();
  IntColumn get bedtimeMinute => integer().withDefault(const Constant(30))();
  IntColumn get wakeHour => integer().withDefault(const Constant(7))();
  IntColumn get wakeMinute => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
