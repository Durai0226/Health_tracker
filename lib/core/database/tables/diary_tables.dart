import 'package:drift/drift.dart';

/// Free-form journal entries: a timestamped note, with an optional mood and
/// tags. Unlike the vitals-style trackers (BP/glucose/weight/mood) this
/// deliberately does not share their table/DAO/service apparatus with: those
/// are all built around a classifiable numeric "reading", which a diary
/// entry has no equivalent of. The mood here is the entry's own (the Mood log's
/// 0 = Great … 4 = Terrible scale), not a row in that log.
@TableIndex(name: 'idx_diary_entry_at', columns: {#entryAt})
class DiaryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get body => text()();
  DateTimeColumn get entryAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get moodIndex => integer().nullable()();
  TextColumn get tagsJson => text().nullable()(); // JSON string[]

  @override
  Set<Column> get primaryKey => {id};
}
