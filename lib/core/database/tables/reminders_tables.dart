import 'package:drift/drift.dart';

/// Reminders Table
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  IntColumn get repeatType => integer().withDefault(const Constant(0))(); // RepeatType enum
  TextColumn get customDaysJson => text().nullable()(); // JSON array of int
  IntColumn get snoozeDuration => integer().nullable()();
  TextColumn get sound => text().withDefault(const Constant('default'))();
  IntColumn get priority => integer().withDefault(const Constant(2))(); // ReminderPriority enum
  TextColumn get categoryId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get noteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reminder Categories Table
class ReminderCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
