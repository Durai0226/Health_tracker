import 'package:drift/drift.dart';

/// Notes Table
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()(); // JSON delta from Quill or Markdown
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get tagIdsJson => text().nullable()(); // JSON array
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get reminderId => text().nullable()();
  TextColumn get folderId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Folders Table
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer().nullable()();
  IntColumn get iconCodePoint => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tags Table
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
