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

  /// Every row in [from]..[to] **including tombstones** — the shape cloud sync
  /// needs. `getForRange` hides deleted nights (right for the UI) but a sync
  /// that can't see a tombstone reads it as "missing locally" and re-downloads
  /// the night the user deleted.
  Future<List<SleepSessionRow>> getForRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(sleepSessions)
          ..where((t) => t.wakeTime.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.wakeTime)]))
        .get();
  }

  /// Ids of nights in [from]..[to] that have been deleted, so an importer can
  /// avoid resurrecting them.
  Future<Set<String>> deletedIdsInRange(DateTime from, DateTime to) async {
    final rows = await (select(sleepSessions)
          ..where((t) =>
              t.wakeTime.isBetweenValues(from, to) & t.deletedAt.isNotNull()))
        .get();
    return rows.map((r) => r.id).toSet();
  }

  Future<void> upsert(SleepSessionsCompanion row) =>
      into(sleepSessions).insertOnConflictUpdate(row);

  /// Soft delete: stamp a tombstone instead of dropping the row.
  ///
  /// A hard `DELETE` left nothing behind to say "the user removed this", so the
  /// next cloud sync saw the id present in Firestore and absent locally, took
  /// that for "not downloaded yet" and wrote the night straight back. The
  /// tombstone rides along as an ordinary last-write-wins row; every read path
  /// here already filters `deletedAt IS NULL`.
  ///
  /// `updatedAt` is bumped so the deletion wins the LWW comparison, and
  /// `synced` is cleared so the row is re-uploaded.
  Future<void> deleteSession(String id) async {
    final now = DateTime.now();
    await (update(sleepSessions)..where((t) => t.id.equals(id))).write(
      SleepSessionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }
}
