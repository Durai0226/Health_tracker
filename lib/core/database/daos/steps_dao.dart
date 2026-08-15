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

  Future<StepDayRow?> getDay(String id) {
    return (select(stepDailyData)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> saveDay(StepDailyDataCompanion row) =>
      into(stepDailyData).insertOnConflictUpdate(row);

  Future<void> deleteDay(String id) =>
      (delete(stepDailyData)..where((t) => t.id.equals(id))).go();

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

  Future<void> deleteManualEntry(String id) =>
      (delete(stepManualEntries)..where((t) => t.id.equals(id))).go();

  // ============ PROFILE (single row) ============
  Future<HealthProfileRow?> getProfile() {
    return (select(healthProfiles)..where((t) => t.id.equals('profile')))
        .getSingleOrNull();
  }

  Future<void> saveProfile(HealthProfilesCompanion row) =>
      into(healthProfiles).insertOnConflictUpdate(row);
}
