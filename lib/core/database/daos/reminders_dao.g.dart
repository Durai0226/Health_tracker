// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_dao.dart';

// ignore_for_file: type=lint
mixin _$RemindersDaoMixin on DatabaseAccessor<AppDatabase> {
  $RemindersTable get reminders => attachedDatabase.reminders;
  $ReminderCategoriesTable get reminderCategories =>
      attachedDatabase.reminderCategories;
  RemindersDaoManager get managers => RemindersDaoManager(this);
}

class RemindersDaoManager {
  final _$RemindersDaoMixin _db;
  RemindersDaoManager(this._db);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db.attachedDatabase, _db.reminders);
  $$ReminderCategoriesTableTableManager get reminderCategories =>
      $$ReminderCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.reminderCategories,
      );
}
