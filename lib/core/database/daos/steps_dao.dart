import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/steps_tables.dart';

part 'steps_dao.g.dart';

@DriftAccessor(tables: [StepDailyData, StepManualEntries, HealthProfiles])
class StepsDao extends DatabaseAccessor<AppDatabase> with _$StepsDaoMixin {
  StepsDao(AppDatabase db) : super(db);

  // ============ DAILY ============
  Future<List<StepDayRow>> getDayRange(DateTime from, DateTime to) {
    return (select(stepDailyData)
          ..where((t) => t.date.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  /// The date of every day whose goal was reached, however long ago.
  ///
  /// The streak is a count of consecutive days, so it has to see all of them:
  /// the in-memory window is the last ~35 days, which capped any streak at about
  /// 35 however long it really was. Only the dates are needed, not the rows.
  Future<List<DateTime>> getGoalReachedDates() async {
    final rows = await (select(stepDailyData)
          ..where((t) => t.goalReached.equals(true) & t.deletedAt.isNull()))
        .get();
    return [for (final r in rows) r.date];
  }

  Future<StepDayRow?> getDay(String id) {
    return (select(stepDailyData)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> saveDay(StepDailyDataCompanion row) =>
      into(stepDailyData).insertOnConflictUpdate(row);

  /// Every step day in [from]..[to], INCLUDING tombstoned ones.
  ///
  /// The shape cloud sync needs: `getDayRange` filters `deletedAt IS NULL`, and
  /// a syncer that cannot see a tombstone reads the row as "missing on this
  /// device" and downloads the deleted day straight back.
  Future<List<StepDayRow>> getDayRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(stepDailyData)
          ..where((t) => t.date.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  /// Soft delete, mirroring [SleepDao.deleteSession].
  ///
  /// A hard delete cannot propagate: the next sync sees the id present in
  /// Firestore and absent locally, and restores it. `updatedAt` is bumped so
  /// the deletion wins the LWW comparison and `synced` is cleared so the row
  /// is re-uploaded.
  Future<void> deleteDay(String id) async {
    final now = DateTime.now();
    await (update(stepDailyData)..where((t) => t.id.equals(id))).write(
      StepDailyDataCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ MANUAL ENTRIES ============
  /// Manual entries for MANY days in one query, bucketed by day id.
  ///
  /// Same defect as the water DAO: the per-day variant was called in a loop
  /// over a 35-day window inside `StepService.init()`, before `runApp()`.
  Future<Map<String, List<StepManualEntryRow>>> getManualEntriesForDays(
      List<String> dailyDataIds) async {
    if (dailyDataIds.isEmpty) return {};
    final rows = await (select(stepManualEntries)
          ..where((t) =>
              t.dailyDataId.isIn(dailyDataIds) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
    final out = <String, List<StepManualEntryRow>>{};
    for (final r in rows) {
      out.putIfAbsent(r.dailyDataId, () => []).add(r);
    }
    return out;
  }

  Future<List<StepManualEntryRow>> getManualEntriesForDay(String dailyDataId) {
    return (select(stepManualEntries)
          ..where((t) =>
              t.dailyDataId.equals(dailyDataId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.time)]))
        .get();
  }

  Future<void> addManualEntry(StepManualEntriesCompanion row) =>
      into(stepManualEntries).insertOnConflictUpdate(row);

  /// Soft delete — see [deleteDay].
  Future<void> deleteManualEntry(String id) async {
    final now = DateTime.now();
    await (update(stepManualEntries)..where((t) => t.id.equals(id))).write(
      StepManualEntriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ PROFILE (single row) ============
  Future<HealthProfileRow?> getProfile() {
    return (select(healthProfiles)..where((t) => t.id.equals('profile')))
        .getSingleOrNull();
  }

  Future<void> saveProfile(HealthProfilesCompanion row) =>
      into(healthProfiles).insertOnConflictUpdate(row);
}
