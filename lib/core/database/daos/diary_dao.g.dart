// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_dao.dart';

// ignore_for_file: type=lint
mixin _$DiaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $DiaryEntriesTable get diaryEntries => attachedDatabase.diaryEntries;
  DiaryDaoManager get managers => DiaryDaoManager(this);
}

class DiaryDaoManager {
  final _$DiaryDaoMixin _db;
  DiaryDaoManager(this._db);
  $$DiaryEntriesTableTableManager get diaryEntries =>
      $$DiaryEntriesTableTableManager(_db.attachedDatabase, _db.diaryEntries);
}
