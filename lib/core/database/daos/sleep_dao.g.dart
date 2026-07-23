// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_dao.dart';

// ignore_for_file: type=lint
mixin _$SleepDaoMixin on DatabaseAccessor<AppDatabase> {
  $SleepSessionsTable get sleepSessions => attachedDatabase.sleepSessions;
  SleepDaoManager get managers => SleepDaoManager(this);
}

class SleepDaoManager {
  final _$SleepDaoMixin _db;
  SleepDaoManager(this._db);
  $$SleepSessionsTableTableManager get sleepSessions =>
      $$SleepSessionsTableTableManager(_db.attachedDatabase, _db.sleepSessions);
}
