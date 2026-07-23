// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_dao.dart';

// ignore_for_file: type=lint
mixin _$PeriodDaoMixin on DatabaseAccessor<AppDatabase> {
  $MenstrualCyclesTable get menstrualCycles => attachedDatabase.menstrualCycles;
  $PeriodDaysTable get periodDays => attachedDatabase.periodDays;
  $PeriodSettingsTableTable get periodSettingsTable =>
      attachedDatabase.periodSettingsTable;
  PeriodDaoManager get managers => PeriodDaoManager(this);
}

class PeriodDaoManager {
  final _$PeriodDaoMixin _db;
  PeriodDaoManager(this._db);
  $$MenstrualCyclesTableTableManager get menstrualCycles =>
      $$MenstrualCyclesTableTableManager(
        _db.attachedDatabase,
        _db.menstrualCycles,
      );
  $$PeriodDaysTableTableManager get periodDays =>
      $$PeriodDaysTableTableManager(_db.attachedDatabase, _db.periodDays);
  $$PeriodSettingsTableTableTableManager get periodSettingsTable =>
      $$PeriodSettingsTableTableTableManager(
        _db.attachedDatabase,
        _db.periodSettingsTable,
      );
}
