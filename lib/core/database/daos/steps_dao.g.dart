// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steps_dao.dart';

// ignore_for_file: type=lint
mixin _$StepsDaoMixin on DatabaseAccessor<AppDatabase> {
  $StepDailyDataTable get stepDailyData => attachedDatabase.stepDailyData;
  $StepManualEntriesTable get stepManualEntries =>
      attachedDatabase.stepManualEntries;
  $HealthProfilesTable get healthProfiles => attachedDatabase.healthProfiles;
  StepsDaoManager get managers => StepsDaoManager(this);
}

class StepsDaoManager {
  final _$StepsDaoMixin _db;
  StepsDaoManager(this._db);
  $$StepDailyDataTableTableManager get stepDailyData =>
      $$StepDailyDataTableTableManager(_db.attachedDatabase, _db.stepDailyData);
  $$StepManualEntriesTableTableManager get stepManualEntries =>
      $$StepManualEntriesTableTableManager(
        _db.attachedDatabase,
        _db.stepManualEntries,
      );
  $$HealthProfilesTableTableManager get healthProfiles =>
      $$HealthProfilesTableTableManager(
        _db.attachedDatabase,
        _db.healthProfiles,
      );
}
