// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_dao.dart';

// ignore_for_file: type=lint
mixin _$PeriodDaoMixin on DatabaseAccessor<AppDatabase> {
  $PeriodDataTable get periodData => attachedDatabase.periodData;
  $PeriodRemindersTableTable get periodRemindersTable =>
      attachedDatabase.periodRemindersTable;
  $SymptomLogsTable get symptomLogs => attachedDatabase.symptomLogs;
  $CycleLogsTable get cycleLogs => attachedDatabase.cycleLogs;
  PeriodDaoManager get managers => PeriodDaoManager(this);
}

class PeriodDaoManager {
  final _$PeriodDaoMixin _db;
  PeriodDaoManager(this._db);
  $$PeriodDataTableTableManager get periodData =>
      $$PeriodDataTableTableManager(_db.attachedDatabase, _db.periodData);
  $$PeriodRemindersTableTableTableManager get periodRemindersTable =>
      $$PeriodRemindersTableTableTableManager(
        _db.attachedDatabase,
        _db.periodRemindersTable,
      );
  $$SymptomLogsTableTableManager get symptomLogs =>
      $$SymptomLogsTableTableManager(_db.attachedDatabase, _db.symptomLogs);
  $$CycleLogsTableTableManager get cycleLogs =>
      $$CycleLogsTableTableManager(_db.attachedDatabase, _db.cycleLogs);
}
