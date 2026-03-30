import 'package:drift/drift.dart';

/// Period Data Table
class PeriodData extends Table {
  TextColumn get id => text()();
  DateTimeColumn get lastPeriodStart => dateTime().nullable()();
  DateTimeColumn get lastPeriodEnd => dateTime().nullable()();
  IntColumn get averageCycleLength => integer().withDefault(const Constant(28))();
  IntColumn get averagePeriodLength => integer().withDefault(const Constant(5))();
  BoolColumn get isTrackingEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get periodHistoryJson => text().nullable()(); // JSON array
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Period Reminders Table
class PeriodRemindersTable extends Table {
  @override
  String get tableName => 'period_reminders';

  TextColumn get id => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get daysBefore => integer().withDefault(const Constant(2))();
  IntColumn get reminderHour => integer().withDefault(const Constant(9))();
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get ovulationReminder => boolean().withDefault(const Constant(true))();
  BoolColumn get fertileWindowReminder => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Symptom Logs Table
class SymptomLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get symptomsJson => text()(); // JSON array of symptom data
  IntColumn get flowIntensity => integer().nullable()(); // 1-5 scale
  IntColumn get moodRating => integer().nullable()(); // 1-5 scale
  IntColumn get energyLevel => integer().nullable()(); // 1-5 scale
  RealColumn get temperature => real().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cycle Logs Table
class CycleLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get cycleLength => integer().nullable()();
  IntColumn get periodLength => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isComplete => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
