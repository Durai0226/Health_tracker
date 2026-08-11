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
    return (select(periodDays)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Every day **including tombstones** — the shape cloud sync needs.
  /// [getAllDays] hides deleted days (right for the calendar), but a sync that
  /// can't see a tombstone reads it as "missing locally" and re-downloads the
  /// day the user deleted — which then also feeds the derived cycle lengths and
  /// corrupts the predictions.
  Future<List<PeriodDayRow>> getAllDaysIncludingDeleted() {
    return (select(periodDays)..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  /// Upsert a day, clearing any tombstone.
  ///
  /// Period day ids ARE the date (`yyyy-MM-dd`), so re-logging a day the user
  /// previously deleted collides with its tombstone. `insertOnConflictUpdate`
  /// only writes the columns the companion sets, and `PeriodDay.toCompanion()`
  /// doesn't set `deletedAt` — without the explicit clear the re-logged day
  /// would stay invisible.
  Future<void> upsertDay(PeriodDaysCompanion row) => into(periodDays)
      .insertOnConflictUpdate(row.copyWith(deletedAt: const Value(null)));

  /// Soft delete: stamp a tombstone instead of dropping the row.
  ///
  /// A hard `DELETE` left nothing behind to say "the user removed this", so the
  /// next cloud sync saw the id present in Firestore and absent locally, took
  /// that for "not downloaded yet" and wrote the day straight back — silently
  /// re-introducing a flow day into the derived cycle history.
  ///
  /// `updatedAt` is bumped so the deletion wins the LWW comparison, and
  /// `synced` is cleared so the row is re-uploaded.
  Future<void> deleteDay(String id) async {
    final now = DateTime.now();
    await (update(periodDays)..where((t) => t.id.equals(id))).write(
      PeriodDaysCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

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
