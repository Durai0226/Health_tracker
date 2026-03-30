// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_dao.dart';

// ignore_for_file: type=lint
mixin _$WaterDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyWaterDataTableTable get dailyWaterDataTable =>
      attachedDatabase.dailyWaterDataTable;
  $EnhancedWaterLogsTable get enhancedWaterLogs =>
      attachedDatabase.enhancedWaterLogs;
  $BeverageTypesTable get beverageTypes => attachedDatabase.beverageTypes;
  $WaterContainersTable get waterContainers => attachedDatabase.waterContainers;
  $HydrationProfilesTable get hydrationProfiles =>
      attachedDatabase.hydrationProfiles;
  $WaterAchievementsTable get waterAchievements =>
      attachedDatabase.waterAchievements;
  WaterDaoManager get managers => WaterDaoManager(this);
}

class WaterDaoManager {
  final _$WaterDaoMixin _db;
  WaterDaoManager(this._db);
  $$DailyWaterDataTableTableTableManager get dailyWaterDataTable =>
      $$DailyWaterDataTableTableTableManager(
        _db.attachedDatabase,
        _db.dailyWaterDataTable,
      );
  $$EnhancedWaterLogsTableTableManager get enhancedWaterLogs =>
      $$EnhancedWaterLogsTableTableManager(
        _db.attachedDatabase,
        _db.enhancedWaterLogs,
      );
  $$BeverageTypesTableTableManager get beverageTypes =>
      $$BeverageTypesTableTableManager(_db.attachedDatabase, _db.beverageTypes);
  $$WaterContainersTableTableManager get waterContainers =>
      $$WaterContainersTableTableManager(
        _db.attachedDatabase,
        _db.waterContainers,
      );
  $$HydrationProfilesTableTableManager get hydrationProfiles =>
      $$HydrationProfilesTableTableManager(
        _db.attachedDatabase,
        _db.hydrationProfiles,
      );
  $$WaterAchievementsTableTableManager get waterAchievements =>
      $$WaterAchievementsTableTableManager(
        _db.attachedDatabase,
        _db.waterAchievements,
      );
}
