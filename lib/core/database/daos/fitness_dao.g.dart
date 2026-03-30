// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_dao.dart';

// ignore_for_file: type=lint
mixin _$FitnessDaoMixin on DatabaseAccessor<AppDatabase> {
  $FitnessRemindersTable get fitnessReminders =>
      attachedDatabase.fitnessReminders;
  $FitnessActivitiesTable get fitnessActivities =>
      attachedDatabase.fitnessActivities;
  FitnessDaoManager get managers => FitnessDaoManager(this);
}

class FitnessDaoManager {
  final _$FitnessDaoMixin _db;
  FitnessDaoManager(this._db);
  $$FitnessRemindersTableTableManager get fitnessReminders =>
      $$FitnessRemindersTableTableManager(
        _db.attachedDatabase,
        _db.fitnessReminders,
      );
  $$FitnessActivitiesTableTableManager get fitnessActivities =>
      $$FitnessActivitiesTableTableManager(
        _db.attachedDatabase,
        _db.fitnessActivities,
      );
}
