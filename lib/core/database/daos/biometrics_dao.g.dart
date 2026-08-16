// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometrics_dao.dart';

// ignore_for_file: type=lint
mixin _$BiometricsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BiometricDailyDataTable get biometricDailyData =>
      attachedDatabase.biometricDailyData;
  $WorkoutSessionsTable get workoutSessions => attachedDatabase.workoutSessions;
  $HealthSourcesTable get healthSources => attachedDatabase.healthSources;
  BiometricsDaoManager get managers => BiometricsDaoManager(this);
}

class BiometricsDaoManager {
  final _$BiometricsDaoMixin _db;
  BiometricsDaoManager(this._db);
  $$BiometricDailyDataTableTableManager get biometricDailyData =>
      $$BiometricDailyDataTableTableManager(
        _db.attachedDatabase,
        _db.biometricDailyData,
      );
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(
        _db.attachedDatabase,
        _db.workoutSessions,
      );
  $$HealthSourcesTableTableManager get healthSources =>
      $$HealthSourcesTableTableManager(_db.attachedDatabase, _db.healthSources);
}
