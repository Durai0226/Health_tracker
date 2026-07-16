import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/core_tables.dart';

part 'core_dao.g.dart';

@DriftAccessor(tables: [UserSettingsTable, ActionLogs, AppPreferences])
class CoreDao extends DatabaseAccessor<AppDatabase> with _$CoreDaoMixin {
  CoreDao(AppDatabase db) : super(db);

  // ============ USER SETTINGS ============
  
  Future<UserSettingsTableData?> getUserSettings() async {
    return await (select(userSettingsTable)
      ..where((t) => t.id.equals('settings')))
      .getSingleOrNull();
  }

  Future<void> saveUserSettings(UserSettingsTableCompanion settings) async {
    await into(userSettingsTable).insertOnConflictUpdate(settings);
  }

  Stream<UserSettingsTableData?> watchUserSettings() {
    return (select(userSettingsTable)
      ..where((t) => t.id.equals('settings')))
      .watchSingleOrNull();
  }

  // ============ ACTION LOGS ============

  Future<List<ActionLog>> getAllActionLogs() async {
    return await (select(actionLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }

  Future<List<ActionLog>> getActionLogsByType(int actionType) async {
    return await (select(actionLogs)
      ..where((t) => t.actionType.equals(actionType))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }

  Future<List<ActionLog>> getActionLogsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return await (select(actionLogs)
      ..where((t) => t.timestamp.isBiggerOrEqualValue(startOfDay) & 
                     t.timestamp.isSmallerThanValue(endOfDay))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }

  Future<List<ActionLog>> getActionLogsForReference(String referenceId) async {
    return await (select(actionLogs)
      ..where((t) => t.referenceId.equals(referenceId))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .get();
  }

  Future<void> addActionLog(ActionLogsCompanion log) async {
    await into(actionLogs).insert(log);
  }

  Future<void> deleteActionLog(String id) async {
    await (delete(actionLogs)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearOldActionLogs(int keepDays) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    await (delete(actionLogs)
      ..where((t) => t.timestamp.isSmallerThanValue(cutoffDate)))
      .go();
  }

  Stream<List<ActionLog>> watchActionLogs() {
    return (select(actionLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
      .watch();
  }

  // ============ APP PREFERENCES ============

  Future<String?> getPreference(String key) async {
    final result = await (select(appPreferences)
      ..where((t) => t.key.equals(key)))
      .getSingleOrNull();
    return result?.value;
  }

  Future<int?> getIntPreference(String key) async {
    final result = await (select(appPreferences)
      ..where((t) => t.key.equals(key)))
      .getSingleOrNull();
    return result?.intValue;
  }

  Future<bool?> getBoolPreference(String key) async {
    final result = await (select(appPreferences)
      ..where((t) => t.key.equals(key)))
      .getSingleOrNull();
    return result?.boolValue;
  }

  Future<void> setPreference(String key, String? value) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(
        key: key,
        value: Value(value),
      ),
    );
  }

  Future<void> setIntPreference(String key, int value) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(
        key: key,
        intValue: Value(value),
      ),
    );
  }

  Future<void> setBoolPreference(String key, bool value) async {
    await into(appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion.insert(
        key: key,
        boolValue: Value(value),
      ),
    );
  }

  Future<void> deletePreference(String key) async {
    await (delete(appPreferences)..where((t) => t.key.equals(key))).go();
  }

  Future<Map<String, dynamic>> getAllPreferences() async {
    final prefs = await select(appPreferences).get();
    final map = <String, dynamic>{};
    for (final pref in prefs) {
      if (pref.boolValue != null) {
        map[pref.key] = pref.boolValue;
      } else if (pref.intValue != null) {
        map[pref.key] = pref.intValue;
      } else {
        map[pref.key] = pref.value;
      }
    }
    return map;
  }
}
