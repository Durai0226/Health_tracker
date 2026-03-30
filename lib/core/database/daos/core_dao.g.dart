// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_dao.dart';

// ignore_for_file: type=lint
mixin _$CoreDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserSettingsTableTable get userSettingsTable =>
      attachedDatabase.userSettingsTable;
  $ActionLogsTable get actionLogs => attachedDatabase.actionLogs;
  $AppPreferencesTable get appPreferences => attachedDatabase.appPreferences;
  CoreDaoManager get managers => CoreDaoManager(this);
}

class CoreDaoManager {
  final _$CoreDaoMixin _db;
  CoreDaoManager(this._db);
  $$UserSettingsTableTableTableManager get userSettingsTable =>
      $$UserSettingsTableTableTableManager(
        _db.attachedDatabase,
        _db.userSettingsTable,
      );
  $$ActionLogsTableTableManager get actionLogs =>
      $$ActionLogsTableTableManager(_db.attachedDatabase, _db.actionLogs);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(
        _db.attachedDatabase,
        _db.appPreferences,
      );
}
