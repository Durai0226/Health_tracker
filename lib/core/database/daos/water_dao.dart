import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/water_tables.dart';

part 'water_dao.g.dart';

@DriftAccessor(tables: [
  DailyWaterDataTable,
  EnhancedWaterLogs,
  BeverageTypes,
  WaterContainers,
  HydrationProfiles,
  WaterAchievements,
])
class WaterDao extends DatabaseAccessor<AppDatabase> with _$WaterDaoMixin {
  WaterDao(AppDatabase db) : super(db);

  // ============ DAILY WATER DATA ============

  Future<DailyWaterDataTableData?> getDailyData(String dateKey) async {
    return await (select(dailyWaterDataTable)
      ..where((t) => t.id.equals(dateKey)))
      .getSingleOrNull();
  }

  Future<List<DailyWaterDataTableData>> getDataForRange(DateTime start, DateTime end) async {
    return await (select(dailyWaterDataTable)
      ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.asc(t.date)]))
      .get();
  }

  Future<void> saveDailyData(DailyWaterDataTableCompanion data) async {
    await into(dailyWaterDataTable).insertOnConflictUpdate(data);
  }

  Stream<DailyWaterDataTableData?> watchDailyData(String dateKey) {
    return (select(dailyWaterDataTable)
      ..where((t) => t.id.equals(dateKey)))
      .watchSingleOrNull();
  }

  // ============ WATER LOGS ============

  Future<List<EnhancedWaterLog>> getLogsForDay(String dailyDataId) async {
    return await (select(enhancedWaterLogs)
      ..where((t) => t.dailyDataId.equals(dailyDataId))
      ..orderBy([(t) => OrderingTerm.asc(t.time)]))
      .get();
  }

  /// Logs for MANY days in one query, bucketed by day id.
  ///
  /// [getLogsForDay] was called in a loop over the warm-cache window — 90 days
  /// — during `WaterService.init()`, which runs BEFORE `runApp()`. That is up
  /// to 91 serialized round trips standing between app launch and the first
  /// frame, and it grows with how long someone has used the app.
  Future<Map<String, List<EnhancedWaterLog>>> getLogsForDays(
      List<String> dailyDataIds) async {
    if (dailyDataIds.isEmpty) return {};
    final rows = await (select(enhancedWaterLogs)
          ..where((t) => t.dailyDataId.isIn(dailyDataIds))
          ..orderBy([(t) => OrderingTerm.asc(t.time)]))
        .get();
    final out = <String, List<EnhancedWaterLog>>{};
    for (final r in rows) {
      out.putIfAbsent(r.dailyDataId, () => []).add(r);
    }
    return out;
  }

  Future<void> addWaterLog(EnhancedWaterLogsCompanion log) async {
    await into(enhancedWaterLogs).insert(log);
  }

  Future<void> updateWaterLog(EnhancedWaterLogsCompanion log) async {
    await (update(enhancedWaterLogs)
      ..where((t) => t.id.equals(log.id.value)))
      .write(log);
  }

  Future<void> deleteWaterLog(String id) async {
    await (delete(enhancedWaterLogs)..where((t) => t.id.equals(id))).go();
  }

  /// Which day a log belongs to (`dailyDataId`, i.e. the `yyyy-MM-dd` key), or
  /// null if there is no such row.
  ///
  /// Lets an Undo remove a drink without knowing its date. Assuming "today"
  /// there is wrong for anything added for a past day — the history editor, or
  /// a quick-add drained from a tap made before midnight.
  Future<String?> dayKeyForLog(String id) async {
    final row = await (select(enhancedWaterLogs)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row?.dailyDataId;
  }

  /// Every stored day, oldest first — for backup export, which must not be
  /// limited to whatever the service happens to have warmed into memory.
  Future<List<DailyWaterDataTableData>> getAllDailyData() async {
    return await (select(dailyWaterDataTable)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
  }

  /// Insert-or-replace a log. [addWaterLog] is a plain INSERT, which throws on
  /// a duplicate id — restoring the same backup twice used to abort the import
  /// part-way through.
  Future<void> upsertWaterLog(EnhancedWaterLogsCompanion log) async {
    await into(enhancedWaterLogs).insertOnConflictUpdate(log);
  }

  /// Drop every log belonging to [dailyDataId]. Needed so a restore can replace
  /// a day's entries rather than merge into whatever was there.
  Future<void> deleteLogsForDay(String dailyDataId) async {
    await (delete(enhancedWaterLogs)
          ..where((t) => t.dailyDataId.equals(dailyDataId)))
        .go();
  }

  // ============ BEVERAGES ============

  Future<List<BeverageType>> getAllBeverages() async {
    return await (select(beverageTypes)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .get();
  }

  Future<BeverageType?> getBeverage(String id) async {
    return await (select(beverageTypes)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> addBeverage(BeverageTypesCompanion beverage) async {
    await into(beverageTypes).insert(beverage);
  }

  Future<void> updateBeverage(BeverageTypesCompanion beverage) async {
    await (update(beverageTypes)..where((t) => t.id.equals(beverage.id.value))).write(beverage);
  }

  Future<void> deleteBeverage(String id) async {
    await (delete(beverageTypes)..where((t) => t.id.equals(id))).go();
  }

  // ============ CONTAINERS ============

  Future<List<WaterContainer>> getAllContainers() async {
    return await select(waterContainers).get();
  }

  Future<void> addContainer(WaterContainersCompanion container) async {
    await into(waterContainers).insert(container);
  }

  Future<void> updateContainer(WaterContainersCompanion container) async {
    await (update(waterContainers)..where((t) => t.id.equals(container.id.value))).write(container);
  }

  Future<void> deleteContainer(String id) async {
    await (delete(waterContainers)..where((t) => t.id.equals(id))).go();
  }

  // ============ HYDRATION PROFILE ============

  Future<HydrationProfile?> getProfile() async {
    return await (select(hydrationProfiles)..where((t) => t.id.equals('profile'))).getSingleOrNull();
  }

  Future<void> saveProfile(HydrationProfilesCompanion profile) async {
    await into(hydrationProfiles).insertOnConflictUpdate(profile);
  }

  // ============ ACHIEVEMENTS ============

  Future<WaterAchievement?> getAchievements() async {
    return await (select(waterAchievements)..where((t) => t.id.equals('user'))).getSingleOrNull();
  }

  Future<void> saveAchievements(WaterAchievementsCompanion achievements) async {
    await into(waterAchievements).insertOnConflictUpdate(achievements);
  }

  Stream<WaterAchievement?> watchAchievements() {
    return (select(waterAchievements)..where((t) => t.id.equals('user'))).watchSingleOrNull();
  }

  // ============ LIFETIME AGGREGATES ============

  /// One row per persisted day, over the WHOLE history — not the 90-day warm
  /// cache the service keeps in memory.
  ///
  /// Achievements and streaks used to be computed by folding
  /// `_dailyWaterNotifier.value.values`, so lifetime totals *shrank* as old
  /// days aged out of the cache — and the shrunken numbers were then persisted
  /// over the good ones. This query is the fix: it reads the table.
  ///
  /// The two correlated sub-selects keep it to a single round trip and return
  /// one row per day (~1,825 rows for five years of use), not one per log.
  ///
  /// The early-drink hour is evaluated in SQLite with `'unixepoch', 'localtime'`
  /// so it matches Dart's `DateTime.hour` on the same device — drift stores
  /// DateTime as unix *seconds*, and the achievement it feeds ("distinct days
  /// with a pre-07:00 drink") is defined in local time. The two are pinned
  /// against each other in `test/features/water/water_lifetime_aggregates_test.dart`.
  Future<List<WaterDayAggregate>> lifetimeDayAggregates({
    int earlyDrinkBeforeHour = 7,
  }) async {
    final rows = await customSelect(
      r"""
      SELECT d.date                    AS d_date,
             d.total_intake_ml         AS total_intake_ml,
             d.effective_hydration_ml  AS effective_hydration_ml,
             d.daily_goal_ml           AS daily_goal_ml,
             d.goal_reached            AS goal_reached,
             d.total_caffeine_mg       AS total_caffeine_mg,
             d.alcoholic_drinks_count  AS alcoholic_drinks_count,
             (SELECT COUNT(*) FROM enhanced_water_logs l
                WHERE l.daily_data_id = d.id) AS log_count,
             (SELECT COUNT(*) FROM enhanced_water_logs l
                WHERE l.daily_data_id = d.id
                  AND CAST(strftime('%H', l.time, 'unixepoch', 'localtime')
                           AS INTEGER) < ?1) AS early_log_count
      FROM daily_water_data d
      ORDER BY d.date ASC
      """,
      variables: [Variable.withInt(earlyDrinkBeforeHour)],
      readsFrom: {dailyWaterDataTable, enhancedWaterLogs},
    ).get();

    return rows
        .map((r) => WaterDayAggregate(
              date: DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('d_date') * 1000),
              totalIntakeMl: r.read<int>('total_intake_ml'),
              effectiveHydrationMl: r.read<int>('effective_hydration_ml'),
              dailyGoalMl: r.read<int>('daily_goal_ml'),
              goalReached: r.read<int>('goal_reached') != 0,
              totalCaffeineMg: r.read<int>('total_caffeine_mg'),
              alcoholicDrinksCount: r.read<int>('alcoholic_drinks_count'),
              logCount: r.read<int>('log_count'),
              earlyLogCount: r.read<int>('early_log_count'),
            ))
        .toList();
  }


  // ============ USAGE COUNTS ============

  /// How often each beverage and each container has been logged, and when each
  /// was last logged — in ONE round trip.
  ///
  /// Derived from the logs rather than kept in counter columns. `BeverageTypes`
  /// has a `sortOrder` column and `WaterContainers` has `usageCount`/`lastUsed`,
  /// but nothing ever wrote any of them — `_trackBeverageUsage` was an empty
  /// method body — so "favourites" and "frequent cups" were just
  /// `defaults.take(n)`. Deriving means no counter can drift out of sync with
  /// the logs, and existing users get accurate favourites from history they
  /// already have instead of starting from zero.
  ///
  /// One query, not two, because this runs inside `WaterService.init()` — i.e.
  /// before the first frame. `startup_cost_test.dart` holds that budget.
  /// The beverage keys double as "every beverage ever logged", which is what the
  /// variety achievements need, so there is no separate DISTINCT query either.
  Future<({Map<String, WaterUsage> beverages, Map<String, WaterUsage> containers})>
      usageCounts() async {
    final rows = await customSelect(
      "SELECT 'b' AS kind, beverage_id AS k, COUNT(*) AS c, MAX(time) AS last "
      '  FROM enhanced_water_logs GROUP BY beverage_id '
      'UNION ALL '
      "SELECT 'c' AS kind, container_id AS k, COUNT(*) AS c, MAX(time) AS last "
      '  FROM enhanced_water_logs WHERE container_id IS NOT NULL '
      '  GROUP BY container_id',
      readsFrom: {enhancedWaterLogs},
    ).get();

    final beverages = <String, WaterUsage>{};
    final containers = <String, WaterUsage>{};
    for (final r in rows) {
      final last = r.read<int?>('last');
      final usage = WaterUsage(
        count: r.read<int>('c'),
        lastUsed: last == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(last * 1000),
      );
      final key = r.read<String>('k');
      if (r.read<String>('kind') == 'b') {
        beverages[key] = usage;
      } else {
        containers[key] = usage;
      }
    }
    return (beverages: beverages, containers: containers);
  }
}

/// How many times something was logged, and when it was last logged.
class WaterUsage {
  final int count;
  final DateTime? lastUsed;
  const WaterUsage({required this.count, this.lastUsed});
}

/// One persisted day reduced to the fields the achievement and streak engines
/// need. Deliberately *not* the generated Drift row class: it carries two
/// log-derived counts that live in a different table.
class WaterDayAggregate {
  final DateTime date;
  final int totalIntakeMl;
  final int effectiveHydrationMl;
  final int dailyGoalMl;
  final bool goalReached;
  final int totalCaffeineMg;
  final int alcoholicDrinksCount;

  /// Number of drink logs on this day.
  final int logCount;

  /// How many of those logs fell before the early-drink hour, in local time.
  final int earlyLogCount;

  const WaterDayAggregate({
    required this.date,
    required this.totalIntakeMl,
    required this.effectiveHydrationMl,
    required this.dailyGoalMl,
    required this.goalReached,
    required this.totalCaffeineMg,
    required this.alcoholicDrinksCount,
    required this.logCount,
    required this.earlyLogCount,
  });

  /// Mirrors the old cache-based `d.logs.isNotEmpty` predicate.
  bool get hasLogs => logCount > 0;

  bool get hasEarlyLog => earlyLogCount > 0;
}
