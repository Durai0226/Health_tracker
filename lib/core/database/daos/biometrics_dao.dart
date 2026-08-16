import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/biometrics_tables.dart';

part 'biometrics_dao.g.dart';

/// Daily biometric aggregates, workout sessions, and the contributing-source
/// registry.
///
/// Same contract as the other health DAOs: `insertOnConflictUpdate` everywhere
/// (never insert-then-update), soft deletes, and every ordinary read filters
/// `deletedAt.isNull()`. The `*IncludingDeleted` variants exist only for cloud
/// sync, which has to see tombstones to propagate a deletion.
@DriftAccessor(tables: [BiometricDailyData, WorkoutSessions, HealthSources])
class BiometricsDao extends DatabaseAccessor<AppDatabase>
    with _$BiometricsDaoMixin {
  BiometricsDao(AppDatabase db) : super(db);

  // ============ DAILY BIOMETRICS ============

  Future<List<BiometricDayRow>> getDayRange(DateTime from, DateTime to) {
    return (select(biometricDailyData)
          ..where((t) => t.date.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<BiometricDayRow?> getDay(String id) {
    return (select(biometricDailyData)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Cloud-sync only — tombstones included.
  Future<List<BiometricDayRow>> getDayRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(biometricDailyData)
          ..where((t) => t.date.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  /// Date keys in range whose row the user deleted, so an importer can avoid
  /// resurrecting them. Without this the next sync re-creates the day and the
  /// deleted data comes straight back — the bug `SleepDao.deletedIdsInRange`
  /// was added to fix.
  Future<Set<String>> deletedDateKeysInRange(DateTime from, DateTime to) async {
    final rows = await (select(biometricDailyData)
          ..where(
              (t) => t.date.isBetweenValues(from, to) & t.deletedAt.isNotNull()))
        .get();
    return rows.map((r) => r.id).toSet();
  }

  Future<void> upsertDay(BiometricDailyDataCompanion row) =>
      into(biometricDailyData).insertOnConflictUpdate(row);

  Future<void> deleteDay(String id) async {
    final now = DateTime.now();
    await (update(biometricDailyData)..where((t) => t.id.equals(id))).write(
      BiometricDailyDataCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ WORKOUTS ============

  Future<List<WorkoutSessionRow>> getWorkoutsForRange(
      DateTime from, DateTime to) {
    return (select(workoutSessions)
          ..where((t) =>
              t.startedAt.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<List<WorkoutSessionRow>> getWorkoutsForDateKey(String dateKey) {
    return (select(workoutSessions)
          ..where((t) => t.dateKey.equals(dateKey) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  Future<List<WorkoutSessionRow>> getWorkoutsForRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(workoutSessions)
          ..where((t) => t.startedAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<Set<String>> deletedWorkoutIdsInRange(
      DateTime from, DateTime to) async {
    final rows = await (select(workoutSessions)
          ..where((t) =>
              t.startedAt.isBetweenValues(from, to) & t.deletedAt.isNotNull()))
        .get();
    return rows.map((r) => r.id).toSet();
  }

  Future<void> upsertWorkout(WorkoutSessionsCompanion row) =>
      into(workoutSessions).insertOnConflictUpdate(row);

  Future<void> deleteWorkout(String id) async {
    final now = DateTime.now();
    await (update(workoutSessions)..where((t) => t.id.equals(id))).write(
      WorkoutSessionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ SOURCE REGISTRY ============

  /// Every contributing source, most recently seen first. Disabled sources are
  /// included — the Connected-devices screen has to render the off switch.
  Future<List<HealthSourceRow>> getSources() {
    return (select(healthSources)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.lastSeenAt)]))
        .get();
  }

  /// Only the sources aggregation is allowed to draw from.
  Future<List<HealthSourceRow>> getEnabledSources() {
    return (select(healthSources)
          ..where((t) => t.deletedAt.isNull() & t.enabled.equals(true)))
        .get();
  }

  Future<HealthSourceRow?> getSource(String id) {
    return (select(healthSources)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertSource(HealthSourcesCompanion row) =>
      into(healthSources).insertOnConflictUpdate(row);

  /// User toggles from the Connected-devices screen. Kept separate from
  /// [upsertSource] so a sync pass refreshing `lastSeenAt` can never clobber a
  /// preference the user set.
  Future<void> setSourceEnabled(String id, bool enabled) async {
    await (update(healthSources)..where((t) => t.id.equals(id))).write(
      HealthSourcesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }

  Future<void> setSourcePriority(String id, int priority) async {
    await (update(healthSources)..where((t) => t.id.equals(id))).write(
      HealthSourcesCompanion(
        priority: Value(priority),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      ),
    );
  }
}
