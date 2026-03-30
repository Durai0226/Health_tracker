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
}
