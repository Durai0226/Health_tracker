import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sleep_tables.dart';

part 'sleep_dao.g.dart';

@DriftAccessor(tables: [SleepSessions])
class SleepDao extends DatabaseAccessor<AppDatabase> with _$SleepDaoMixin {
  SleepDao(AppDatabase db) : super(db);

  Future<List<SleepSessionRow>> getAll() {
    return (select(sleepSessions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.wakeTime)]))
        .get();
  }

  Future<List<SleepSessionRow>> getForRange(DateTime from, DateTime to) {
    return (select(sleepSessions)
          ..where((t) =>
              t.wakeTime.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.wakeTime)]))
        .get();
  }

  Future<SleepSessionRow?> getForDateKey(String dateKey) {
    return (select(sleepSessions)
          ..where((t) => t.dateKey.equals(dateKey) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.wakeTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsert(SleepSessionsCompanion row) =>
      into(sleepSessions).insertOnConflictUpdate(row);

  Future<void> deleteSession(String id) =>
      (delete(sleepSessions)..where((t) => t.id.equals(id))).go();
}
