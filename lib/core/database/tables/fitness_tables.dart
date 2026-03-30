import 'package:drift/drift.dart';

/// Fitness Reminders Table
class FitnessReminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();
  TextColumn get fitnessType => text().withDefault(const Constant('general'))();
  DateTimeColumn get scheduledTime => dateTime()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get repeatDaysJson => text().nullable()(); // JSON array of weekdays
  IntColumn get reminderMinutesBefore => integer().withDefault(const Constant(15))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fitness Activities Table
class FitnessActivities extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get activityType => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationMinutes => integer()();
  RealColumn get caloriesBurned => real().nullable()();
  RealColumn get distanceKm => real().nullable()();
  IntColumn get steps => integer().nullable()();
  IntColumn get heartRateAvg => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get goalType => integer().nullable()(); // FitnessGoal enum
  IntColumn get goalValue => integer().nullable()();
  IntColumn get goalProgress => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
