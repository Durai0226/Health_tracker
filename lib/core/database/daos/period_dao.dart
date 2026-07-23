import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/period_tables.dart';

part 'period_dao.g.dart';

@DriftAccessor(tables: [MenstrualCycles, PeriodDays, PeriodSettingsTable])
class PeriodDao extends DatabaseAccessor<AppDatabase> with _$PeriodDaoMixin {
  PeriodDao(AppDatabase db) : super(db);

  // ============ DAYS ============
  Future<List<PeriodDayRow>> getDaysForRange(DateTime from, DateTime to) {
    return (select(periodDays)
          ..where((t) => t.date.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Future<List<PeriodDayRow>> getAllDays() {
    return (select(periodDays)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  Future<PeriodDayRow?> getDay(String id) {
    return (select(periodDays)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertDay(PeriodDaysCompanion row) =>
      into(periodDays).insertOnConflictUpdate(row);

  Future<void> deleteDay(String id) =>
      (delete(periodDays)..where((t) => t.id.equals(id))).go();

  // ============ CYCLES (derived) ============
  Future<List<MenstrualCycleRow>> getAllCycles() {
    return (select(menstrualCycles)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.startDate)]))
        .get();
  }

  Future<void> upsertCycle(MenstrualCyclesCompanion row) =>
      into(menstrualCycles).insertOnConflictUpdate(row);

  Future<void> deleteCycle(String id) =>
      (delete(menstrualCycles)..where((t) => t.id.equals(id))).go();

  /// Replace the full derived-cycle set atomically (used by _recomputeCycles).
  Future<void> replaceCycles(List<MenstrualCyclesCompanion> rows) async {
    await batch((b) {
      b.deleteWhere(menstrualCycles, (t) => const Constant(true));
      b.insertAll(menstrualCycles, rows);
    });
  }

  // ============ SETTINGS (single row) ============
  Future<PeriodSettingsRow?> getSettings() {
    return (select(periodSettingsTable)..where((t) => t.id.equals('settings')))
        .getSingleOrNull();
  }

  Future<void> saveSettings(PeriodSettingsTableCompanion row) =>
      into(periodSettingsTable).insertOnConflictUpdate(row);
}
