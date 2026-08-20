// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_dao.dart';

// ignore_for_file: type=lint
mixin _$FocusDaoMixin on DatabaseAccessor<AppDatabase> {
  $FocusSessionsTable get focusSessions => attachedDatabase.focusSessions;
  FocusDaoManager get managers => FocusDaoManager(this);
}

class FocusDaoManager {
  final _$FocusDaoMixin _db;
  FocusDaoManager(this._db);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db.attachedDatabase, _db.focusSessions);
}
