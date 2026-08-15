import 'package:drift/drift.dart';

/// Free-form journal entries. No rating/severity/tags — just a timestamped
/// note, unlike the vitals-style trackers (BP/glucose/weight/mood) this
/// deliberately does not share their table/DAO/service apparatus with: those
/// are all built around a classifiable numeric "reading", which a diary
/// entry has no equivalent of.
@TableIndex(name: 'idx_diary_entry_at', columns: {#entryAt})
class DiaryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text()();
  DateTimeColumn get entryAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
