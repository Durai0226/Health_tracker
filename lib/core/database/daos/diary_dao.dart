import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/diary_tables.dart';

part 'diary_dao.g.dart';

@DriftAccessor(tables: [DiaryEntries])
class DiaryDao extends DatabaseAccessor<AppDatabase> with _$DiaryDaoMixin {
  DiaryDao(AppDatabase db) : super(db);

  Future<List<DiaryEntry>> getAll() async {
    return await (select(diaryEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.entryAt)]))
        .get();
  }

  Future<List<DiaryEntry>> getForRange(DateTime from, DateTime to) async {
    return await (select(diaryEntries)
          ..where((t) => t.entryAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.entryAt)]))
        .get();
  }

  Stream<List<DiaryEntry>> watchAll() {
    return (select(diaryEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.entryAt)]))
        .watch();
  }

  Future<void> upsert(DiaryEntriesCompanion row) async {
    await into(diaryEntries).insertOnConflictUpdate(row);
  }

  Future<void> deleteEntry(String id) async {
    await (delete(diaryEntries)..where((t) => t.id.equals(id))).go();
  }
}
