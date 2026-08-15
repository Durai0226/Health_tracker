import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_alarm_service.dart' show kShowOnLockScreenPref;
import '../database/app_database.dart';
import '../database/daos/core_dao.dart';
import '../database/daos/medication_dao.dart';
import '../database/daos/water_dao.dart';
import '../database/daos/reminders_dao.dart';
import '../models/user_settings.dart';
import '../config/env_config.dart';
import '../../features/reminders/models/reminder_model.dart' as ReminderModel;
import '../../features/reminders/models/reminder_category_model.dart' as ReminderCategoryModel;
import 'package:uuid/uuid.dart';
import '../../features/medication/models/medicine.dart';
import '../../features/medication/services/medicine_storage_service.dart';
import '../../features/medication/services/vitals_storage_service.dart';
import '../../features/diary/services/diary_storage_service.dart';
import '../../features/focus/services/focus_service.dart';
import '../../features/water/services/water_service.dart';
import '../../features/period/services/period_service.dart';
import '../../features/steps/services/step_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/water/models/enhanced_water_log.dart';
import '../../features/water/models/water_reminder_config.dart';

/// Clean Drift-based storage service - unified storage using Drift DAOs
class CleanStorageService {
  static bool _isInitialized = false;
  static AppDatabase? _database;
  
  // DAO accessors
  static AppDatabase get database {
    _database ??= AppDatabase.instance;
    return _database!;
  }
  
  static CoreDao get _coreDao => database.coreDao;
  static MedicationDao get _medicationDao => database.medicationDao;
  static WaterDao get _waterDao => database.waterDao;
  static RemindersDao get _remindersDao => database.remindersDao;

  /// Test-only: drop the cached DB handle + in-memory caches so the service
  /// re-reads `AppDatabase.instance` (which a test may have pointed at an
  /// in-memory database). Does NOT close the old handle — the test owns it.
  @visibleForTesting
  static void resetForTesting() {
    _database = null;
    _isInitialized = false;
    _appPreferencesCache.clear();
    _medicinesCache.clear();
    _remindersCache.clear();
    _categoriesCache.clear();
  }

  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('CleanStorageService already initialized');
      return;
    }
    
    try {
      _database = AppDatabase.instance;
      debugPrint('✓ Drift database initialized');
      await _initDefaultCategories();
      
      // Load all caches for synchronous access
      await loadAppPreferences();
      await getAllCategoriesAsync();
      await getAllMedicinesAsync();
      await getAllReminders();

      _isInitialized = true;
      debugPrint('✓ CleanStorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing CleanStorageService: $e');
    }
  }

  static Future<void> _initDefaultCategories() async {
    try {
      final db = database;
      // Check if categories already exist
      final existingCategories = await db.select(db.reminderCategories).get();
      
      if (existingCategories.isEmpty) {
        // Insert default categories
        await db.into(db.reminderCategories).insert(ReminderCategoriesCompanion.insert(
          id: 'personal',
          name: 'Personal',
          colorValue: 0xFF4CAF50,
          iconCodePoint: 0xe7fd, // Symbols.person_rounded
        ));
        
        await db.into(db.reminderCategories).insert(ReminderCategoriesCompanion.insert(
          id: 'work', 
          name: 'Work',
          colorValue: 0xFF2196F3,
          iconCodePoint: 0xe89c, // Symbols.work_rounded
        ));
        
        await db.into(db.reminderCategories).insert(ReminderCategoriesCompanion.insert(
          id: 'health',
          name: 'Health',
          colorValue: 0xFFFF5722,
          iconCodePoint: 0xe3f4, // Symbols.health_and_safety_rounded
        ));
        
        debugPrint('✓ Default categories created');
      }
    } catch (e) {
      debugPrint('Error creating default categories: $e');
    }
  }
  
  /// Check if this is first launch
  static bool get isFirstLaunch => getAppPreference('isFirstLaunch', true) == true;
  
  static Future<void> setFirstLaunchComplete() async {
    await setAppPreference('isFirstLaunch', false);
  }

  /// Explicit consent for uploading health data to Firestore.
  ///
  /// Defaults to FALSE and is the single gate on every cloud upload. The app
  /// tells users their data stays on the device; previously an anonymous
  /// Firebase account was created on first launch and `main.dart` synced
  /// medicines, water, and 60 days of steps/sleep for every user — including
  /// people who chose "Continue as guest". Nothing may leave the device unless
  /// the user turns this on.
  static bool get cloudSyncEnabled =>
      getAppPreference('cloudSyncEnabled', false) == true;

  static Future<void> setCloudSyncEnabled(bool value) async {
    await setAppPreference('cloudSyncEnabled', value);
  }

  // ============ REMINDERS (cached for sync access) ============
  static final List<ReminderModel.Reminder> _remindersCache = [];
  
  static List<ReminderModel.Reminder> getReminders() {
    return List.unmodifiable(_remindersCache);
  }

  /// Save reminder using Drift
  static Future<void> saveReminder(ReminderModel.Reminder reminder) async {
    try {
      final db = database;
      final companion = RemindersCompanion.insert(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        categoryId: Value(reminder.categoryId),
        scheduledTime: reminder.scheduledTime,
        repeatType: Value(reminder.repeatType.index),
        customDaysJson: Value(reminder.customDays != null
            ? jsonEncode(reminder.customDays)
            : null),
        snoozeDuration: Value(reminder.snoozeDuration),
        sound: Value(reminder.sound ?? 'default'),
        priority: Value(reminder.priority.index),
        isCompleted: Value(reminder.isCompleted),
        isSynced: Value(reminder.isSynced),
        note: Value(reminder.note),
        imagePath: Value(reminder.imagePath),
        noteId: Value(reminder.noteId),
        createdAt: reminder.createdAt,
        updatedAt: reminder.updatedAt,
      );

      // Upsert so editing an existing reminder updates instead of throwing.
      await db.into(db.reminders).insertOnConflictUpdate(companion);
      await getAllReminders(); // refresh sync cache
      debugPrint('✓ Reminder saved: ${reminder.title}');
    } catch (e) {
      debugPrint('Error saving reminder: $e');
    }
  }

  /// Get all active reminders using Drift (async version that updates cache)
  static Future<List<ReminderModel.Reminder>> getAllReminders() async {
    try {
      final db = database;
      final reminderRows = await db.select(db.reminders).get();
      
      // Convert Drift rows to model objects (all fields).
      final reminders = reminderRows.map((row) {
        List<int>? customDays;
        final cdj = row.customDaysJson;
        if (cdj != null && cdj.isNotEmpty) {
          try {
            customDays = List<int>.from(jsonDecode(cdj) as List);
          } catch (_) {/* ignore malformed */}
        }
        return ReminderModel.Reminder(
          id: row.id,
          title: row.title,
          body: row.body,
          categoryId: row.categoryId,
          scheduledTime: row.scheduledTime,
          repeatType: ReminderModel.RepeatType.values[row.repeatType],
          customDays: customDays,
          snoozeDuration: row.snoozeDuration,
          sound: row.sound,
          priority: ReminderModel.ReminderPriority.values[row.priority],
          isCompleted: row.isCompleted,
          isSynced: row.isSynced,
          note: row.note,
          imagePath: row.imagePath,
          noteId: row.noteId,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }).toList();
      
      _remindersCache.clear();
      _remindersCache.addAll(reminders);
      return reminders;
    } catch (e) {
      debugPrint('Error getting reminders: $e');
      return [];
    }
  }

  /// Delete reminder using Drift
  static Future<void> deleteReminder(String reminderId) async {
    try {
      final db = database;
      await (db.delete(db.reminders)..where((tbl) => tbl.id.equals(reminderId))).go();
      await getAllReminders(); // refresh sync cache
      debugPrint('✓ Reminder deleted: $reminderId');
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  /// Get all reminder categories using Drift (cached for sync access)
  static final List<ReminderCategoryModel.ReminderCategory> _categoriesCache = [];
  
  static List<ReminderCategoryModel.ReminderCategory> getAllCategories() {
    return List.unmodifiable(_categoriesCache);
  }
  
  static Future<List<ReminderCategoryModel.ReminderCategory>> getAllCategoriesAsync() async {
    try {
      final db = database;
      final categoryRows = await db.select(db.reminderCategories).get();
      
      // Convert Drift rows to model objects
      final categories = categoryRows.map((row) {
        return ReminderCategoryModel.ReminderCategory(
          id: row.id,
          name: row.name,
          color: row.colorValue,
          icon: row.iconCodePoint,
          isDefault: row.isDefault,
        );
      }).toList();

      _categoriesCache.clear();
      _categoriesCache.addAll(categories);
      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  /// Create or update a reminder category (upsert) and refresh the cache.
  static Future<void> saveCategory(
      ReminderCategoryModel.ReminderCategory category) async {
    try {
      await _remindersDao.saveCategory(ReminderCategoriesCompanion.insert(
        id: category.id,
        name: category.name,
        colorValue: category.color,
        iconCodePoint: category.icon,
        isDefault: Value(category.isDefault),
      ));
      await getAllCategoriesAsync(); // refresh sync cache
      debugPrint('✓ Category saved: ${category.name}');
    } catch (e) {
      debugPrint('Error saving category: $e');
    }
  }

  /// Delete a reminder category and refresh the cache.
  static Future<void> deleteCategory(String id) async {
    try {
      await _remindersDao.deleteCategory(id);
      await getAllCategoriesAsync(); // refresh sync cache
      debugPrint('✓ Category deleted: $id');
    } catch (e) {
      debugPrint('Error deleting category: $e');
    }
  }


  /// Toggle reminder completion
  static Future<void> toggleReminderCompletion(ReminderModel.Reminder reminder) async {
    try {
      final db = database;
      await (db.update(db.reminders)..where((tbl) => tbl.id.equals(reminder.id)))
          .write(RemindersCompanion(
        isCompleted: Value(!reminder.isCompleted),
        updatedAt: Value(DateTime.now()),
      ));
      await getAllReminders(); // refresh sync cache
      debugPrint('✓ Reminder completion toggled: ${reminder.id}');
    } catch (e) {
      debugPrint('Error toggling reminder completion: $e');
    }
  }

  // ============ APP PREFERENCES (using CoreDao) ============
  static final Map<String, dynamic> _appPreferencesCache = {};
  
  static Map<String, dynamic> getAppPreferences() {
    return Map<String, dynamic>.from(_appPreferencesCache);
  }
  
  static Future<void> setAppPreference(String key, dynamic value) async {
    _appPreferencesCache[key] = value;
    try {
      if (value is bool) {
        await _coreDao.setBoolPreference(key, value);
      } else if (value is int) {
        await _coreDao.setIntPreference(key, value);
      } else if (value is Map || value is List) {
        // Persist complex values as JSON so they survive a restart.
        await _coreDao.setPreference(key, jsonEncode(value));
      } else {
        await _coreDao.setPreference(key, value?.toString());
      }
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }

  static dynamic getAppPreference(String key, [dynamic defaultValue]) {
    return _appPreferencesCache[key] ?? defaultValue;
  }

  /// Forget a preference entirely, rather than writing a falsy value over it.
  /// Used by one-time migrations that retire a setting (see [AiLegacyCleanup]) —
  /// leaving a stale row behind would make `getAppPreference` keep returning it.
  static Future<void> removeAppPreference(String key) async {
    _appPreferencesCache.remove(key);
    try {
      await _coreDao.deletePreference(key);
    } catch (e) {
      debugPrint('Error removing preference $key: $e');
    }
  }

  static Future<void> loadAppPreferences() async {
    try {
      final prefs = await _coreDao.getAllPreferences();
      for (final entry in prefs.entries) {
        var v = entry.value;
        // Decode JSON-encoded Map/List values back into real objects.
        if (v is String && v.length > 1 &&
            (v.startsWith('{') || v.startsWith('['))) {
          try {
            v = jsonDecode(v);
          } catch (_) {/* leave as string */}
        }
        _appPreferencesCache[entry.key] = v;
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }
  
  // ============ MEDICINES (using MedicationDao) ============
  static final List<EnhancedMedicine> _medicinesCache = [];
  
  static List<EnhancedMedicine> getAllMedicines() {
    return List.unmodifiable(_medicinesCache);
  }
  
  static Future<List<EnhancedMedicine>> getAllMedicinesAsync() async {
    try {
      final medicines = await _medicationDao.getAllMedicines();
      _medicinesCache.clear();
      _medicinesCache.addAll(medicines);
      return medicines;
    } catch (e) {
      debugPrint('Error getting medicines: $e');
      return [];
    }
  }
  
  static Future<EnhancedMedicine?> getMedicineAsync(String id) async {
    return await _medicationDao.getMedicine(id);
  }
  
  static EnhancedMedicine? getMedicine(String id) {
    try {
      return _medicinesCache.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> addMedicine(EnhancedMedicinesCompanion medicine) async {
    try {
      await _medicationDao.addMedicine(medicine);
      await getAllMedicinesAsync();
    } catch (e) {
      debugPrint('Error adding medicine: $e');
    }
  }
  
  static Future<void> updateMedicine(EnhancedMedicinesCompanion medicine) async {
    try {
      await _medicationDao.updateMedicine(medicine);
      await getAllMedicinesAsync();
    } catch (e) {
      debugPrint('Error updating medicine: $e');
    }
  }
  
  static Future<void> deleteMedicine(String id) async {
    try {
      await _medicationDao.deleteMedicine(id);
      await getAllMedicinesAsync();
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
    }
  }
  
  /// Add medicine from model object (for cloud sync compatibility)
  static Future<void> addMedicineFromModel(Medicine medicine) async {
    // Store in cache for now - full Drift integration would convert to Companion
    debugPrint('Adding medicine from model: ${medicine.name}');
  }
  
  // ============ REMINDERS (using RemindersDao) ============
  static Future<void> updateReminder(RemindersCompanion reminder) async {
    try {
      await _remindersDao.updateReminder(reminder);
    } catch (e) {
      debugPrint('Error updating reminder: $e');
    }
  }
  
  static Future<void> saveSyncedReminder(RemindersCompanion reminder) async {
    try {
      await _remindersDao.saveReminder(reminder);
    } catch (e) {
      debugPrint('Error saving synced reminder: $e');
    }
  }
  
  /// Save synced reminder from model object (for cloud sync)
  static Future<void> saveSyncedReminderFromModel(ReminderModel.Reminder reminder) async {
    try {
      final companion = RemindersCompanion.insert(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        categoryId: Value(reminder.categoryId),
        scheduledTime: reminder.scheduledTime,
        repeatType: Value(reminder.repeatType.index),
        priority: Value(reminder.priority.index),
        isCompleted: Value(reminder.isCompleted),
        createdAt: reminder.createdAt,
        updatedAt: reminder.updatedAt,
      );
      await _remindersDao.saveReminder(companion);
      await getAllReminders(); // Refresh cache
    } catch (e) {
      debugPrint('Error saving synced reminder from model: $e');
    }
  }
  
  static Future<void> deleteSyncedReminder(String id) async {
    try {
      await _remindersDao.deleteReminder(id);
    } catch (e) {
      debugPrint('Error deleting synced reminder: $e');
    }
  }
  
  // ============ WATER (using WaterDao) ============
  static Future<void> saveWaterReminder(dynamic reminder) async {
    debugPrint('Save water reminder: ${reminder.toString()}');
  }
  
  static Future<DailyWaterDataTableData?> getWaterReminder() async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return await _waterDao.getDailyData(dateKey);
  }

  /// Water reminder interval config — persisted as JSON in app preferences
  /// (key `waterReminderConfig`). No Drift table / schema change.
  static const String waterReminderConfigKey = 'waterReminderConfig';

  static Future<void> saveWaterReminderConfig(WaterReminderConfig config) async {
    await setAppPreference(waterReminderConfigKey, config.toJson());
  }

  static WaterReminderConfig? getWaterReminderConfig() {
    final raw = getAppPreference(waterReminderConfigKey);
    if (raw is Map) {
      try {
        return WaterReminderConfig.fromJson(Map<String, dynamic>.from(raw));
      } catch (e) {
        debugPrint('Error parsing water reminder config: $e');
      }
    }
    return null;
  }

  // ============ UTILITY METHODS ============
  static bool get isInitialized => _isInitialized;
  static int get defaultReminderDays => 3;
  static int get defaultReminderHour => 9;
  static int get defaultReminderMinute => 0;
  
  static UserSettings getUserSettings() {
    return UserSettings(
      darkModeEnabled: getAppPreference('darkMode', false) == true,
      soundEnabled: getAppPreference('soundEnabled', true) == true,
      vibrationEnabled: getAppPreference('vibrationEnabled', true) == true,
      snoozeIntervalMinutes: getAppPreference('snoozeInterval', 5) as int? ?? 5,
      snoozeEnabled: getAppPreference('snoozeEnabled', true) == true,
      // Migrate legacy darkMode flag → 3-way theme preference when unset.
      themeModePreference: getAppPreference(
              'themeMode',
              getAppPreference('darkMode', false) == true ? 'dark' : 'system')
          as String? ??
          'system',
      // Notification 'Display' + alarm settings (were saved but never read back,
      // so the toggles always reset to their defaults on reopen).
      showOnLockScreen: getAppPreference('showOnLockScreen', true) == true,
      persistentNotification:
          getAppPreference('persistentNotification', true) == true,
      fullScreenNotification:
          getAppPreference('fullScreenNotification', true) == true,
      alarmRingDurationSeconds:
          getAppPreference('alarmRingDuration', 30) as int? ?? 30,
      notificationSound:
          getAppPreference('notificationSound', 'default') as String? ??
              'default',
    );
  }

  static Future<void> saveUserSettings(UserSettings settings) async {
    await setAppPreference('darkMode', settings.darkModeEnabled);
    await setAppPreference('soundEnabled', settings.soundEnabled);
    await setAppPreference('vibrationEnabled', settings.vibrationEnabled);
    await setAppPreference('snoozeInterval', settings.snoozeIntervalMinutes);
    await setAppPreference('snoozeEnabled', settings.snoozeEnabled);
    await setAppPreference('themeMode', settings.themeModePreference);
    // Persist the notification 'Display' + alarm settings so they survive reopen.
    await setAppPreference('showOnLockScreen', settings.showOnLockScreen);
    // Mirror into SharedPreferences as well: the alarm fires in a background
    // isolate with no Drift connection, so that is the only place it can read
    // this from. Without the mirror the toggle silently did nothing on
    // Android, which is where every medicine reminder actually goes.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kShowOnLockScreenPref, settings.showOnLockScreen);
    } catch (_) {}
    await setAppPreference('persistentNotification', settings.persistentNotification);
    await setAppPreference('fullScreenNotification', settings.fullScreenNotification);
    await setAppPreference('alarmRingDuration', settings.alarmRingDurationSeconds);
    await setAppPreference('notificationSound', settings.notificationSound);
  }
  
  /// Full backup snapshot: medicines, focus sessions, reminders, water,
  /// settings & preferences. Medicines and focus are delegated to their own
  /// services so this service never names the generated Drift `EnhancedMedicine`
  /// (which it imports unprefixed) and avoids the naming clash.
  static Future<Map<String, dynamic>> exportAllData() async {
    final water = WaterService.listenToDailyData()?.value.values.toList() ??
        const <DailyWaterData>[];
    return {
      // v4: adds a 'vitals' section (BP + glucose, later weight). v5 adds
      // 'diary'. Older backups simply omit sections and are restored
      // non-destructively by importData.
      'version': 5,
      'timestamp': DateTime.now().toIso8601String(),
      'settings': getUserSettings().toJson(),
      'medicines': await MedicineCleanStorageService.exportMedicinesJson(),
      'focus': {
        'sessions': FocusService().exportSessionsJson(),
      },
      'reminders': getReminders().map((r) => r.toJson()).toList(),
      'water': water.map((d) => d.toJson()).toList(),
      'vitals': await VitalsStorageService.exportJson(),
      'diary': await DiaryStorageService.exportJson(),
      'preferences': Map<String, dynamic>.fromEntries(
        _appPreferencesCache.entries
            .where((e) => !kNeverLeaveTheDevice.contains(e.key)),
      ),
    };
  }

  /// Preference keys that must never enter a backup, in either direction.
  ///
  /// **Export.** `AppLockService` stores the app-lock PIN as
  /// `securityPinSalt` + `securityPinHash` via [setAppPreference], so they sat
  /// in `_appPreferencesCache` and were serialized straight into
  /// `exportAllData()`. That JSON goes two places — a ZIP handed to the OS
  /// share sheet, and a Firestore upload — so every backup a user emailed or
  /// put in Drive carried their PIN. A 4-digit PIN with a known salt is ~10,000
  /// SHA-256 operations to recover, i.e. instant, and people reuse it as their
  /// device PIN.
  ///
  /// **Import.** The restore path looped over `data['preferences']` and wrote
  /// every key back unfiltered, so a crafted `dlyminder_data.json` could set
  /// `securityLockEnabled: false` to switch off the app lock, overwrite the
  /// PIN with the attacker's own, or flip `cloudSyncEnabled: true` to turn on
  /// the upload the user had explicitly opted out of. Security state and
  /// consent state are device decisions; they are never restored from a file.
  static const Set<String> kNeverLeaveTheDevice = {
    'securityPinSalt',
    'securityPinHash',
    'securityLockEnabled',
    'securityBiometricPreferred',
    'cloudSyncEnabled',
  };

  static Future<void> clearAllData() async {
    _medicinesCache.clear();
    _appPreferencesCache.clear();
    debugPrint('✓ All cached data cleared');
  }

  /// Permanently deletes the user's data for the four core features.
  ///
  /// Unlike [clearAllData] (which only clears the in-memory caches), this
  /// deletes the actual rows from the kept Drift tables — medicines & their
  /// logs, water consumption data/logs/achievements, and reminders — and
  /// removes the focus state that is persisted as `focus*` app preferences.
  /// It then drops the in-memory caches and refreshes the reactive notifiers so
  /// the UI falls back to a clean state without an app restart.
  ///
  /// KNOWN LIMITATION: the [FocusService] singleton keeps its sessions, garden
  /// and stats in memory for the current process and re-persists them on its
  /// next save, so a complete focus reset only takes full effect after an app
  /// restart. Everything backed purely by Drift/preferences is cleared here.
  /// Clears ONLY the tables that [importData] is able to put back.
  ///
  /// A destructive restore used to call [clearAllPersistentData], which wipes
  /// 18 tables — but the backup format covers far fewer. Everything in the gap
  /// was deleted with nothing to restore it, while the UI reported "Backup
  /// restored successfully":
  ///
  ///   * medicineLogs        — ALL dose/adherence history (exportMedicinesJson
  ///                           serialises medicines only; the logs-carrying
  ///                           exportAllMedicineData has no callers)
  ///   * periodDays / menstrualCycles / periodSettingsTable
  ///   * stepDailyData / stepManualEntries  — incl. hand-typed entries
  ///   * sleepSessions / healthProfiles
  ///   * enhancedWaterLogs / waterAchievements — per-drink history; the day
  ///                           totals restore, the individual logs do not
  ///
  /// The rollback snapshot uses the same lossy export, so the failure path
  /// could not recover them either. Restoring a backup must never destroy data
  /// the backup does not contain.
  ///
  /// If [exportAllData]/[importData] are ever extended to cover more tables,
  /// add them here in the same change — the two lists must stay in sync.
  static Future<void> clearRestorableData() async {
    final db = database;
    try {
      await db.delete(db.reminders).go();
      await db.delete(db.enhancedMedicines).go();
      await db.delete(db.dailyWaterDataTable).go();
      await db.delete(db.bloodPressureReadings).go();
      await db.delete(db.glucoseReadings).go();
      await db.delete(db.weightReadings).go();
      await db.delete(db.moodEntries).go();
      await db.delete(db.diaryEntries).go();
      debugPrint('✓ Restorable data cleared (backup-covered tables only)');
    } catch (e) {
      debugPrint('Error clearing restorable data: $e');
      rethrow;
    }
  }

  static Future<void> clearAllPersistentData() async {
    final db = database;
    try {
      // Reminders
      await db.delete(db.reminders).go();
      // Medicines + their logs
      await db.delete(db.medicineLogs).go();
      await db.delete(db.enhancedMedicines).go();
      // Water consumption data + logs + achievements
      await db.delete(db.enhancedWaterLogs).go();
      await db.delete(db.dailyWaterDataTable).go();
      await db.delete(db.waterAchievements).go();
      // Period / steps / sleep trackers
      await db.delete(db.periodDays).go();
      await db.delete(db.menstrualCycles).go();
      await db.delete(db.periodSettingsTable).go();
      await db.delete(db.stepDailyData).go();
      await db.delete(db.stepManualEntries).go();
      await db.delete(db.sleepSessions).go();
      await db.delete(db.healthProfiles).go();
      // Vitals — these were previously left behind entirely, so "Delete all
      // data" silently kept every blood-pressure and blood-sugar reading.
      await db.delete(db.bloodPressureReadings).go();
      await db.delete(db.glucoseReadings).go();
      // Same gap, caught before shipping this time: weight/mood/diary.
      await db.delete(db.weightReadings).go();
      await db.delete(db.moodEntries).go();
      await db.delete(db.diaryEntries).go();

      // Residue from the removed AI feature: its Drift tables went in schema v8,
      // but the chat transcript and engine settings live in `app_preferences`,
      // which survives. Without this the deleted assistant's conversation is
      // still loaded every launch and still uploaded inside every cloud backup.
      for (final k in const [
        'aiChatThread',
        'aiProvider',
        'aiHost',
        'aiModel',
        'aiOffDeviceConsent',
        'aiDailyCallCount',
        'aiDailyCallDate',
        'aiMemoryEnabled',
        'aiAssistantTone',
      ]) {
        await removeAppPreference(k);
      }

      // Focus state persisted as app-preference JSON (focus* keys). App config
      // (theme, haptics, onboarding flags) is intentionally left untouched.
      final focusKeys = _appPreferencesCache.keys
          .where((k) => k.startsWith('focus'))
          .toList();
      for (final k in focusKeys) {
        await _coreDao.deletePreference(k);
        _appPreferencesCache.remove(k);
      }

      // Drop in-memory caches and refresh reactive state so the UI updates now.
      _medicinesCache.clear();
      _remindersCache.clear();
      WaterService.clearInMemory();
      PeriodService.clearInMemory();
      StepService.clearInMemory();
      SleepService.clearInMemory();

      debugPrint('✓ All persistent data cleared');
    } catch (e) {
      debugPrint('Error clearing persistent data: $e');
      rethrow;
    }
  }

  /// Safely restore an [exportAllData] snapshot with rollback protection.
  ///
  /// Before touching anything it snapshots the current data so a failed import
  /// can be undone. When [clearExisting] is true the kept tables are wiped
  /// first (an "overwrite" restore); otherwise the backup is MERGED
  /// non-destructively by [importData]. On any failure the pre-restore snapshot
  /// is put back and the error is rethrown for the caller to surface.
  static Future<void> restoreBackup(
    Map<String, dynamic> data, {
    bool clearExisting = false,
  }) async {
    Map<String, dynamic>? snapshot;
    try {
      snapshot = await exportAllData();
    } catch (e) {
      debugPrint('Pre-restore snapshot failed (continuing without rollback): $e');
    }
    try {
      if (clearExisting) {
        // Only the backup-covered tables. Using clearAllPersistentData() here
        // deleted dose history, period history, sleep/step entries and
        // per-drink water logs that the backup cannot restore — permanently,
        // while the UI said "Backup restored successfully".
        await clearRestorableData();
      }
      await importData(data);
    } catch (e) {
      debugPrint('Restore failed: $e — attempting rollback');
      // Roll back ONLY when we were the ones who cleared. A non-destructive
      // restore (clearExisting == false) is a pure merge that deleted nothing,
      // so wiping here would destroy strictly more than the failure did.
      if (snapshot != null && clearExisting) {
        try {
          await clearRestorableData();
          await importData(snapshot);
          debugPrint('✓ Rolled back to pre-restore snapshot');
        } catch (rollbackError) {
          debugPrint('⚠️ Rollback failed: $rollbackError');
        }
      }
      rethrow;
    }
  }

  /// Restore a backup snapshot produced by [exportAllData].
  ///
  /// NON-DESTRUCTIVE by design: every section is MERGED into existing data, and
  /// a section that is ABSENT from the backup is left completely untouched (an
  /// old/partial backup can never erase, e.g., medicines that it doesn't carry).
  /// Medicines and focus are delegated to their own services so this method
  /// never names the generated Drift `EnhancedMedicine` (avoids the clash).
  static Future<void> importData(Map<String, dynamic> data) async {
    try {
      if (data['settings'] is Map) {
        await saveUserSettings(
            UserSettings.fromJson(Map<String, dynamic>.from(data['settings'])));
      }
      // Medicines (v3+). Missing key → leave existing medicines intact.
      if (data['medicines'] is List) {
        try {
          await MedicineCleanStorageService.importMedicinesJson(
              data['medicines'] as List);
        } catch (e) {
          debugPrint('Import medicines failed: $e');
        }
      }
      // Focus sessions (v3+). Missing key → leave existing sessions intact.
      if (data['focus'] is Map) {
        try {
          final focus = Map<String, dynamic>.from(data['focus'] as Map);
          if (focus['sessions'] is List) {
            await FocusService().importSessionsJson(focus['sessions'] as List);
          }
        } catch (e) {
          debugPrint('Import focus failed: $e');
        }
      }
      for (final r in (data['reminders'] as List? ?? const [])) {
        try {
          await saveReminder(
              ReminderModel.Reminder.fromJson(Map<String, dynamic>.from(r)));
        } catch (e) {
          debugPrint('Import reminder failed: $e');
        }
      }
      for (final w in (data['water'] as List? ?? const [])) {
        try {
          await WaterService.saveDailyData(
              DailyWaterData.fromJson(Map<String, dynamic>.from(w)));
        } catch (e) {
          debugPrint('Import water failed: $e');
        }
      }
      // Vitals (v4+). Missing key → leave existing readings intact.
      if (data['vitals'] is Map) {
        try {
          await VitalsStorageService.importJson(
              Map<String, dynamic>.from(data['vitals'] as Map));
        } catch (e) {
          debugPrint('Import vitals failed: $e');
        }
      }
      // Diary (v5+). Missing key → leave existing entries intact.
      if (data['diary'] is List) {
        try {
          await DiaryStorageService.importJson(data['diary'] as List);
        } catch (e) {
          debugPrint('Import diary failed: $e');
        }
      }
      if (data['preferences'] is Map) {
        for (final e in (data['preferences'] as Map).entries) {
          final key = e.key.toString();
          // Never let a restore file decide security or consent state — see
          // [kNeverLeaveTheDevice]. A crafted backup could otherwise disable
          // the app lock, replace the PIN, or enable cloud upload.
          if (kNeverLeaveTheDevice.contains(key)) {
            debugPrint('↩︎ Skipped restoring protected preference: $key');
            continue;
          }
          await setAppPreference(key, e.value);
        }
      }
      // Refresh sync caches so the UI reflects the restore immediately.
      await getAllMedicinesAsync();
      await getAllReminders();
      debugPrint('✓ Backup restored');
    } catch (e) {
      debugPrint('Import data failed: $e');
      rethrow;
    }
  }
  

  /// Close the database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
      debugPrint('✓ CleanStorageService closed');
    }
  }
}
