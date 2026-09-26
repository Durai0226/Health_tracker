import 'package:clock/clock.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/reminders/models/reminder_kind.dart'
    show reminderResolvedKey;
import 'background_alarm_service.dart'
    show
        defaultMaxSnoozeCount,
        kShowOnLockScreenPref,
        maxSnoozeCountKey,
        snoozeEnabledKey,
        snoozeIntervalMinutesKey;
import '../database/app_database.dart';
import '../database/daos/core_dao.dart';
import '../database/daos/medication_dao.dart';
import '../database/daos/water_dao.dart';
import '../database/daos/reminders_dao.dart';
import '../models/user_settings.dart';
import '../../features/reminders/models/reminder_model.dart' as ReminderModel;
import '../../features/reminders/models/reminder_category_model.dart' as ReminderCategoryModel;
import '../../features/medication/services/medicine_storage_service.dart';
import '../../features/medication/services/vitals_storage_service.dart';
import '../../features/diary/services/diary_storage_service.dart';
import '../../features/backup/services/health_backup_serializer.dart';
import '../../features/backup/services/medication_backup_serializer.dart';
import '../../features/focus/services/focus_service.dart';
import '../../features/water/services/water_service.dart';
import '../../features/period/services/period_service.dart';
import '../../features/steps/services/step_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/biometrics/services/biometrics_service.dart';
import '../../features/water/models/enhanced_water_log.dart';
import '../../features/water/models/water_reminder_config.dart';
import '../../features/reminders/models/reminder_recurrence.dart';

/// Clean Drift-based storage service - unified storage using Drift DAOs
class CleanStorageService {
  static bool _isInitialized = false;

  // DAO accessors
  /// Always the CURRENT singleton — deliberately not cached here.
  ///
  /// This used to hold its own `AppDatabase?` and `??=` it on first use, which
  /// bought nothing (`AppDatabase.instance` is itself a singleton) and cost a
  /// real hazard: the handle survived `setInstanceForTesting`, so any test that
  /// closed its in-memory database without also calling `resetForTesting()`
  /// left this service pointing at the closed one. Every later read threw
  /// "Can't re-open a database after closing it" — swallowed by the callers'
  /// try/catch, so the test still passed while the service silently returned
  /// nothing. That noise is visible in the suite's output today.
  static AppDatabase get database => AppDatabase.instance;
  
  static CoreDao get _coreDao => database.coreDao;
  static MedicationDao get _medicationDao => database.medicationDao;
  static WaterDao get _waterDao => database.waterDao;
  static RemindersDao get _remindersDao => database.remindersDao;

  /// Test-only: drop the in-memory caches so the service re-reads from
  /// whatever `AppDatabase.instance` currently points at. The handle itself is
  /// no longer cached (see [database]); this clears the DATA caches, which do
  /// still need resetting between tests.
  @visibleForTesting
  static void resetForTesting() {
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
      // Touch the singleton so a connection failure surfaces here rather than
      // at the first read. Nothing is cached — see [database].
      AppDatabase.instance;
      debugPrint('✓ Drift database initialized');

      // Load all caches for synchronous access.
      //
      // Four disjoint tables, four independent results — nothing here reads
      // what another one wrote — so they go out together instead of one after
      // another. That matters specifically because this runs BEFORE the first
      // frame (main.dart) and production opens Drift over a background isolate
      // (`driftDatabase(name: 'dlyminder')`): the client side of that
      // connection has no statement lock, so four awaited-in-turn reads are
      // four sequential port round trips, while one `Future.wait` puts all
      // four requests in flight at once.
      //
      // No try/catch around the group: `Future.wait` rejects on the FIRST
      // error and leaves the other three running unobserved, so one failing
      // table would cost the whole startup cache. Each load owns its own
      // error boundary instead (see each method's catch) and always
      // completes — which is what makes waiting on all four safe here.
      await Future.wait([
        loadAppPreferences(),
        _loadCategoriesSeedingDefaults(),
        getAllMedicinesAsync(),
        getAllReminders(),
      ]);

      _isInitialized = true;
      debugPrint('✓ CleanStorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing CleanStorageService: $e');
    }
  }

  /// Fill the category cache, seeding the three defaults on a first launch.
  ///
  /// This used to be two full passes over `reminder_categories` on every cold
  /// start: a now-deleted `_initDefaultCategories` read the whole table to
  /// decide whether to seed, then [getAllCategoriesAsync] read it again to
  /// build the cache. The seeding check only needs to know whether the table
  /// came back empty, which the cache load already answers — so the steady
  /// state is one select, not two, and the second read survives only on the
  /// launch that actually seeds.
  ///
  /// The read is deliberately NOT the swallowing [getAllCategoriesAsync]: that
  /// returns `[]` on a failure, which would look identical to "empty table"
  /// and seed defaults into a database that is merely unreachable.
  static Future<void> _loadCategoriesSeedingDefaults() async {
    try {
      var categories = await _readCategories();
      if (categories.isEmpty) {
        await _insertDefaultCategories();
        categories = await _readCategories();
      }
      _categoriesCache
        ..clear()
        ..addAll(categories);
    } catch (e) {
      debugPrint('Error getting categories: $e');
    }
  }

  /// Seed the three built-in categories. Only reached when a successful read
  /// found the table empty, i.e. on a genuine first launch.
  static Future<void> _insertDefaultCategories() async {
    try {
      final db = database;
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

  /// Persist a reminder, allocating its reserved notification id on first save.
  ///
  /// Rows written before schema v16 arrive with `notificationId == null`.
  /// Allocating here means the legacy `id.hashCode` fallback drains naturally as
  /// reminders are touched, instead of needing Dart work inside a Drift
  /// migration — the trap the v13 `alterTable` step recorded the hard way.
  ///
  /// Returns the reminder AS STORED, so the caller arms the notification under
  /// the id that was actually written rather than the one it passed in.
  static Future<ReminderModel.Reminder> saveReminderAllocatingId(
      ReminderModel.Reminder reminder) async {
    var toSave = reminder;
    if (toSave.notificationId == null) {
      try {
        final slot = await _remindersDao.allocateNotificationId();
        if (slot != null) {
          toSave = toSave.copyWith(notificationId: slot);
        } else {
          // Block full. Keep the legacy derivation rather than refuse to save:
          // an unreserved id risks a collision, no reminder at all is a
          // guaranteed miss.
          debugPrint(
              '⚠️ Generic reminder id block full — falling back to the legacy id');
        }
      } catch (e) {
        debugPrint('⚠️ Allocating a reminder notification id failed: $e');
      }
    }
    await saveReminder(toSave);
    return toSave;
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
        notificationId: Value(reminder.notificationId),
        recurrenceRule: Value(reminder.recurrenceRule),
        endsAt: Value(reminder.endsAt),
        occurrenceLimit: Value(reminder.occurrenceLimit),
        isPaused: Value(reminder.isPaused),
        escalation: Value(reminder.escalation.name),
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

  // ============ REMINDER OCCURRENCES ============

  /// Record what happened to one occurrence of a reminder.
  ///
  /// This is the write that `isCompleted` could never be. That field is a single
  /// mutable boolean: completing a repeating reminder overwrote it and rolled
  /// `scheduledTime` forward, so the app destroyed its own history and no
  /// adherence rate, streak, digest or adaptive timing could be computed. An
  /// occurrence row is append-only history keyed on the instant it was due.
  ///
  /// Idempotent — the id is derived from (reminderId, scheduledFor), so a double
  /// tap or a background action drained twice updates one row rather than
  /// inventing a second.
  static Future<void> recordReminderOutcome({
    required String reminderId,
    required DateTime scheduledFor,
    required ReminderModel.ReminderOutcome outcome,
    DateTime? actedAt,
    DateTime? firedAt,
    int? snoozeCount,
    String? source,
  }) async {
    try {
      await _remindersDao.recordOccurrence(
        ReminderOccurrencesCompanion.insert(
          id: RemindersDao.occurrenceId(reminderId, scheduledFor),
          reminderId: reminderId,
          scheduledFor: scheduledFor,
          outcome: Value(outcome.name),
          // `clock.now()` for a resolution with no explicit time — the project
          // convention, and it makes these rows testable with `withClock`.
          actedAt: Value(
              outcome.isResolved ? (actedAt ?? clock.now()) : actedAt),
          firedAt: Value(firedAt),
          snoozeCount: snoozeCount == null ? const Value.absent() : Value(snoozeCount),
          source: Value(source),
        ),
      );
      // Mirror to SharedPreferences so the ALARM ISOLATE can see it. That
      // isolate has no Drift connection, so without this a follow-up would fire
      // for a reminder the user ticked off twenty minutes ago. Same contract as
      // `nudgeResolvedKey` on the medication side.
      if (outcome.isResolved) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(
              reminderResolvedKey(reminderId, scheduledFor), true);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error recording reminder outcome: $e');
    }
  }

  /// Every recorded occurrence of one reminder, oldest first.
  static Future<List<ReminderOccurrence>> getReminderOccurrences(
      String reminderId) async {
    try {
      return await _remindersDao.occurrencesFor(reminderId);
    } catch (e) {
      debugPrint('Error reading reminder occurrences: $e');
      return const [];
    }
  }

  /// Drop a reminder's occurrence history, when the reminder itself is deleted.
  ///
  /// Only for a real delete. These rows ARE the adherence record, so nothing
  /// else may clear them.
  static Future<void> deleteReminderOccurrences(String reminderId) async {
    try {
      await _remindersDao.deleteOccurrencesFor(reminderId);
    } catch (e) {
      debugPrint('Error deleting reminder occurrences: $e');
    }
  }

  /// Close out occurrences that were never resolved and whose time has passed.
  ///
  /// The denominator. Without it a user who never opens the app has no `missed`
  /// rows at all and therefore shows perfect adherence forever — the same reason
  /// `reconcileMissedDoses` exists on the medication side.
  ///
  /// [grace] is how long after the due time an occurrence may still be resolved
  /// normally; only rows older than that are written off.
  /// Create a `pending` row for every occurrence that has come DUE and has no
  /// row yet — the missing half of the adherence denominator.
  ///
  /// `reconcileMissedReminders` only rewrites rows returned by `pendingBefore`,
  /// and NOTHING ever wrote a `pending` row: `recordReminderOutcome` had exactly
  /// one production caller, the in-app tick, which writes `done`. The alarm
  /// isolate has no Drift connection and the scheduler never touched the table.
  /// So the sweep always found zero rows, `ReminderAdherence.byDay` only ever
  /// saw `done`, and the card printed "100% of days fully covered" for a user
  /// who had ignored a daily reminder for a month and ticked it once.
  ///
  /// Runs from the app-start / resume re-arm pass, which is the same
  /// queue-and-drain shape the dose actions use: the occurrences are derived
  /// from the recurrence, so a device that was off still gets its history.
  ///
  /// [lookback] bounds the walk. A year-old daily reminder must not mint 365
  /// rows on first run — adherence is a recent-behaviour signal, and the
  /// reconcile window is measured in minutes.
  static Future<int> recordDueReminderOccurrences({
    Duration lookback = const Duration(days: 30),
  }) async {
    try {
      final now = clock.now();
      final windowStart = now.subtract(lookback);
      final reminders = await getAllReminders();
      var created = 0;

      for (final reminder in reminders) {
        if (reminder.isPaused) continue;

        // Which instants have come due inside the window?
        final due = <DateTime>[];
        final recurrence = ReminderRecurrence.parse(
          reminder.recurrenceRule,
          fallback: reminder.repeatType,
          fallbackDays: reminder.customDays,
        );
        if (!recurrence.repeats) {
          // A one-off: its single occurrence, if it is in the past.
          if (!reminder.scheduledTime.isAfter(now) &&
              reminder.scheduledTime.isAfter(windowStart)) {
            due.add(reminder.scheduledTime);
          }
        } else {
          // Walk forward from the later of the reminder's own start and the
          // window, stopping at now. `nextAfter` steps by CALENDAR day, so an
          // 08:00 reminder stays 08:00 across a DST transition.
          var cursor = reminder.scheduledTime.isAfter(windowStart)
              ? reminder.scheduledTime.subtract(const Duration(microseconds: 1))
              : windowStart;
          // Hard cap as well as the time bound: a malformed rule must not spin.
          for (var i = 0; i < 400; i++) {
            final next = recurrence.nextAfter(
                start: reminder.scheduledTime, after: cursor);
            if (next == null || next.isAfter(now)) break;
            if (reminder.endsAt != null && next.isAfter(reminder.endsAt!)) break;
            due.add(next);
            cursor = next;
          }
        }

        for (final at in due) {
          // insertOrIgnore, NEVER an upsert: a `done` row the user created must
          // not be overwritten with a fresh `pending` one.
          final wrote = await _remindersDao.recordOccurrenceIfAbsent(
            ReminderOccurrencesCompanion.insert(
              id: RemindersDao.occurrenceId(reminder.id, at),
              reminderId: reminder.id,
              scheduledFor: at,
              outcome: const Value('pending'),
              // The occurrence became due; whether the OS actually delivered
              // the notification is not something this pass can know, so
              // `firedAt` is the due instant.
              firedAt: Value(at),
              source: const Value('derived'),
            ),
          );
          if (wrote) created++;
        }
      }

      if (created > 0) {
        debugPrint('✓ Recorded $created due reminder occurrences');
      }
      return created;
    } catch (e) {
      debugPrint('⚠️ Recording due reminder occurrences failed: $e');
      return 0;
    }
  }

  static Future<int> reconcileMissedReminders({Duration? grace}) async {
    try {
      final settings = getUserSettings();
      // Honour the user's own threshold. `autoMarkMissed` off means they do not
      // want unanswered occurrences written off at all — an adherence figure
      // they did not ask for is worse than none.
      if (!settings.autoMarkMissed) return 0;
      final window =
          grace ?? Duration(minutes: settings.missedThresholdMinutes);
      final cutoff = clock.now().subtract(window);
      final stale = await _remindersDao.pendingBefore(cutoff);
      for (final row in stale) {
        await _remindersDao.recordOccurrence(
          ReminderOccurrencesCompanion.insert(
            id: row.id,
            reminderId: row.reminderId,
            scheduledFor: row.scheduledFor,
            outcome: const Value('missed'),
            firedAt: Value(row.firedAt),
            snoozeCount: Value(row.snoozeCount),
            source: Value(row.source),
            // Deliberately no actedAt: nobody acted. Writing `now` here would
            // make a miss look like a very late completion.
          ),
        );
      }
      if (stale.isNotEmpty) {
        debugPrint('✓ Marked ${stale.length} reminder occurrences missed');
      }
      return stale.length;
    } catch (e) {
      debugPrint('Error reconciling missed reminders: $e');
      return 0;
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
          notificationId: row.notificationId,
          recurrenceRule: row.recurrenceRule,
          endsAt: row.endsAt,
          occurrenceLimit: row.occurrenceLimit,
          isPaused: row.isPaused,
          escalation: ReminderModel.ReminderEscalation.fromName(row.escalation),
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
      final categories = await _readCategories();
      _categoriesCache.clear();
      _categoriesCache.addAll(categories);
      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  /// The raw read behind both category paths. Throws on failure — the callers
  /// decide what an error means (see [_loadCategoriesSeedingDefaults]).
  static Future<List<ReminderCategoryModel.ReminderCategory>>
      _readCategories() async {
    final db = database;
    final categoryRows = await db.select(db.reminderCategories).get();

    // Convert Drift rows to model objects
    return categoryRows.map((row) {
      return ReminderCategoryModel.ReminderCategory(
        id: row.id,
        name: row.name,
        color: row.colorValue,
        icon: row.iconCodePoint,
        isDefault: row.isDefault,
      );
    }).toList();
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

  /// Write many preferences in ONE transaction.
  ///
  /// `setAppPreference` is a separate Drift write per key, and each one is its
  /// own transaction with its own WAL fsync. `FocusService._saveData` writes 19
  /// keys and is called unconditionally from `_checkAndUpdateStreak`, which
  /// runs from `init()` — awaited in main's pre-runApp `Future.wait`. So a user
  /// who has never opened Focus paid 19 sequential SQLite write transactions
  /// before the first frame, every cold start, to persist values that had not
  /// changed.
  ///
  /// The cache is updated for every key even if the write fails, matching
  /// `setAppPreference`'s existing behaviour (it writes the cache first, then
  /// persists, and swallows a failure).
  static Future<void> setAppPreferences(Map<String, dynamic> values) async {
    if (values.isEmpty) return;
    _appPreferencesCache.addAll(values);
    try {
      await AppDatabase.instance.transaction(() async {
        for (final e in values.entries) {
          final value = e.value;
          if (value is bool) {
            await _coreDao.setBoolPreference(e.key, value);
          } else if (value is int) {
            await _coreDao.setIntPreference(e.key, value);
          } else if (value is Map || value is List) {
            await _coreDao.setPreference(e.key, jsonEncode(value));
          } else {
            await _coreDao.setPreference(e.key, value?.toString());
          }
        }
      });
    } catch (e) {
      debugPrint('Error saving preferences: $e');
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
  /// Persist a reminder that arrived from the cloud.
  ///
  /// **Every column, not a subset.** This used to write ten of seventeen,
  /// silently dropping `customDaysJson`, `snoozeDuration`, `sound`, `note`,
  /// `imagePath` and `noteId`. The consequence was worse than lost detail: a
  /// cloud-arrived reminder kept its `repeatType` but lost the day list the
  /// `custom` branch of `scheduleGenericReminder` loops over, so it armed
  /// **zero** notifications while appearing perfectly normal in the list.
  ///
  /// Dormant, not live: nothing writes `users/{uid}/reminders`
  /// (`RemindersCloudService` was deleted in `0dd3c72`) and nothing reads it —
  /// the download-only listener in `sync_service.dart` was deleted with it.
  /// This applier stays, covered by
  /// `test/reminders/cloud_inbound_reminder_test.dart`, because whether
  /// reminders sync across devices is a product decision and leaving a
  /// *broken* inbound path for the next person to inherit is strictly worse
  /// than leaving a correct one.
  static Future<void> saveSyncedReminderFromModel(
      ReminderModel.Reminder reminder) async {
    try {
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
        isSynced: const Value(true),
        note: Value(reminder.note),
        imagePath: Value(reminder.imagePath),
        noteId: Value(reminder.noteId),
        recurrenceRule: Value(reminder.recurrenceRule),
        endsAt: Value(reminder.endsAt),
        occurrenceLimit: Value(reminder.occurrenceLimit),
        isPaused: Value(reminder.isPaused),
        escalation: Value(reminder.escalation.name),
        // Not carried from the cloud: notification ids are per-device, allocated
        // from this device's reserved block. Taking another device's id would
        // collide with whatever local reminder already holds it.
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
      // Was saved nowhere and read nowhere, so `maxSnoozeCount` was permanently
      // the model's default however the user set it — and the alarm isolate's
      // cap, which reads the mirrored key, was permanently 3.
      maxSnoozeCount: getAppPreference('maxSnoozeCount', defaultMaxSnoozeCount)
              as int? ??
          defaultMaxSnoozeCount,
      // Four more that existed in UserSettingsTable and were written and read
      // nowhere, so they were permanently their model defaults however the user
      // set them. `autoMarkMissed` + `missedThresholdMinutes` are what turn an
      // unanswered occurrence into a `missed` row — the denominator every
      // adherence figure needs.
      autoMarkMissed: getAppPreference('autoMarkMissed', true) == true,
      missedThresholdMinutes:
          getAppPreference('missedThresholdMinutes', 60) as int? ?? 60,
      reminderSnoozeMinutes:
          getAppPreference('reminderSnoozeMinutes', 10) as int? ?? 10,
      preferredRingtone: getAppPreference('preferredRingtone') as String?,
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
    await setAppPreference('maxSnoozeCount', settings.maxSnoozeCount);
    await setAppPreference('autoMarkMissed', settings.autoMarkMissed);
    await setAppPreference(
        'missedThresholdMinutes', settings.missedThresholdMinutes);
    await setAppPreference(
        'reminderSnoozeMinutes', settings.reminderSnoozeMinutes);
    if (settings.preferredRingtone != null) {
      await setAppPreference('preferredRingtone', settings.preferredRingtone);
    }
    await setAppPreference('themeMode', settings.themeModePreference);
    // Persist the notification 'Display' + alarm settings so they survive reopen.
    await setAppPreference('showOnLockScreen', settings.showOnLockScreen);
    await mirrorSettingsForAlarmIsolate(settings);
    await setAppPreference('persistentNotification', settings.persistentNotification);
    await setAppPreference('fullScreenNotification', settings.fullScreenNotification);
    await setAppPreference('alarmRingDuration', settings.alarmRingDurationSeconds);
    await setAppPreference('notificationSound', settings.notificationSound);
  }

  /// Copy every setting the ALARM ISOLATE needs into SharedPreferences.
  ///
  /// That isolate has no Drift connection, so SharedPreferences is the only
  /// place it can read these from. Without the mirror the toggles silently did
  /// nothing on Android — which is where every medicine reminder actually goes.
  ///
  /// Called from [saveUserSettings] and from startup. It used to be only
  /// startup, and only two of these keys: changing the snooze interval in
  /// Settings therefore had no effect until the next cold start, and
  /// `maxSnoozeCount` was never mirrored at all, so the cap was stuck at
  /// [defaultMaxSnoozeCount] no matter what the user chose.
  static Future<void> mirrorSettingsForAlarmIsolate(
      UserSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kShowOnLockScreenPref, settings.showOnLockScreen);
      await prefs.setInt(
          snoozeIntervalMinutesKey, settings.snoozeIntervalMinutes);
      await prefs.setBool(snoozeEnabledKey, settings.snoozeEnabled);
      await prefs.setInt(maxSnoozeCountKey, settings.maxSnoozeCount);
    } catch (e) {
      debugPrint('⚠️ Mirroring settings for the alarm isolate failed: $e');
    }
  }
  
  /// Full backup snapshot: medicines (with dose history), doctors,
  /// appointments, household profiles, focus sessions, reminders, water,
  /// vitals, diary, sleep, period, steps, the shared health profile, settings
  /// & preferences. Medicines and focus are delegated to their own services so
  /// this service never names the generated Drift `EnhancedMedicine` (which it
  /// imports unprefixed) and avoids the naming clash; sleep/period/steps/
  /// profile go through [HealthBackupSerializer] and doctors/appointments/
  /// dependents through [MedicationBackupSerializer] for the same reason —
  /// `StepDailyData`, `HealthProfile`, `Doctor`, `Appointment` and
  /// `DependentProfile` are all domain names here and generated table names
  /// there.
  static Future<Map<String, dynamic>> exportAllData() async {
    // Read the whole persisted history, NOT `listenToDailyData()?.value` — that
    // is WaterService's 90-day warm cache, so backups silently contained only
    // the last three months of drinking for any longer-running user.
    final water = await WaterService.exportAllDaysForBackup();
    return {
      // v4: adds a 'vitals' section (BP + glucose, later weight). v5 adds
      // 'diary'. v6 adds 'sleep', 'period', 'steps' and 'healthProfile' — the
      // four features that had never been in a backup at all. v7 adds
      // 'doctors', 'appointments' and 'dependents', which had never been in
      // one either and, being hand-typed, exist nowhere else. Older backups
      // simply omit sections and are restored non-destructively by importData.
      'version': 7,
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
      ...await HealthBackupSerializer.exportJson(),
      ...await MedicationBackupSerializer.exportJson(),
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
  /// 18 tables — but the backup format covered far fewer. Everything in the gap
  /// was deleted with nothing to restore it, while the UI reported "Backup
  /// restored successfully".
  ///
  /// The gap was closed from both ends. `enhancedWaterLogs` went first: the
  /// format has always *carried* per-drink logs (DailyWaterData.toJson embeds
  /// them) and the restore path simply dropped them by writing through
  /// `saveDailyData`, which persists the day row only; it now uses
  /// `WaterService.restoreDayWithLogs`. Sleep, period days, step days and
  /// hand-typed step entries followed — they are exported and re-imported by
  /// [HealthBackupSerializer], whose [HealthBackupSerializer.clearRestorableRows]
  /// is the matching clear called below. Doctors and appointments came last,
  /// through [MedicationBackupSerializer] in the same shape.
  ///
  /// What is STILL outside the backup, and therefore still must not be cleared
  /// here:
  ///
  ///   * medicineLogs        — dose history IS exported (nested under each
  ///                           medicine, see `doseLogsBackupKey`), but a log
  ///                           whose medicine no longer exists is not, so
  ///                           clearing the table could destroy a row the
  ///                           restore cannot put back
  ///   * menstrualCycles     — derived from periodDays and recomputed by
  ///                           PeriodService, so never exported
  ///   * waterAchievements   — unlocked badges and points (recomputed from the
  ///                           restored history by refreshAfterRestore, so this
  ///                           one is derived rather than lost)
  ///   * dependentProfiles   — exported and re-imported, but not cleared: the
  ///                           "self" row is app scaffolding created once by
  ///                           ActiveProfileService.init(). See
  ///                           [MedicationBackupSerializer.clearRestorableRows]
  ///   * pharmacies /        — tables with DAO methods and no writer anywhere
  ///     treatmentCourses      in the app, so they hold no user data at all
  ///
  /// The rollback snapshot uses the same export, so a failure path can only
  /// recover what the export covers. Restoring a backup must never destroy
  /// data the backup does not contain.
  ///
  /// [forBackup] is the file about to be imported, and narrows the wipe to the
  /// sections that file actually carries. "What [importData] can put back" is a
  /// property of the FILE, not of the format: an overwrite restore of an older
  /// backup — a v5 one, written before `sleep`/`period`/`steps` existed, or a
  /// v6 one written before `doctors`/`appointments` did — would otherwise clear
  /// tables whose section is simply absent, and the import would put nothing
  /// back. That is the same silent destruction this method was extracted to
  /// stop, one version late: every backup already in someone's Firestore or
  /// Drive predates the newest sections. Passing null clears every covered
  /// table, which is right only for a map known to be a current
  /// [exportAllData]; both call sites below pass theirs explicitly, so the
  /// null default is reached only from tests that clear without restoring.
  ///
  /// The test is `containsKey`, never "is non-empty": a file that carries
  /// `'diary': []` is a file whose author has no diary entries, and an
  /// overwrite restore of it must genuinely empty the table.
  ///
  /// If [exportAllData]/[importData] are ever extended to cover more tables,
  /// add them here in the same change — the two lists must stay in sync.
  /// `test/core/restore_does_not_destroy_test.dart` pins that invariant.
  static Future<void> clearRestorableData({
    Map<String, dynamic>? forBackup,
  }) async {
    final db = database;
    bool carries(String section) =>
        forBackup == null || forBackup.containsKey(section);
    try {
      if (carries('reminders')) await db.delete(db.reminders).go();
      if (carries('medicines')) await db.delete(db.enhancedMedicines).go();
      if (carries('water')) {
        // Logs before day totals: the logs reference the day id.
        await db.delete(db.enhancedWaterLogs).go();
        await db.delete(db.dailyWaterDataTable).go();
      }
      if (carries('vitals')) {
        // One section, four tables — VitalsStorageService exports and imports
        // blood pressure, glucose, weight and mood together.
        await db.delete(db.bloodPressureReadings).go();
        await db.delete(db.glucoseReadings).go();
        await db.delete(db.weightReadings).go();
        await db.delete(db.moodEntries).go();
      }
      if (carries('diary')) await db.delete(db.diaryEntries).go();
      await HealthBackupSerializer.clearRestorableRows(forBackup: forBackup);
      await MedicationBackupSerializer.clearRestorableRows(
          forBackup: forBackup);
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
      // The medication side tables, which "Delete all data" left behind
      // entirely: a consultant's name and phone number, the date and place of
      // every appointment, and a household member's date of birth, blood type,
      // allergies and insurance details all survived a wipe that told the user
      // "All data deleted." Appointments first — they reference the other two.
      // `pharmacies` and `treatmentCourses` are not here because nothing in
      // the app has ever written a row to either. The well-known "self"
      // profile goes with them and is recreated by ActiveProfileService.init()
      // on the next launch — the same restart-shaped limitation FocusService
      // has below, and the right trade against leaving a dependent's medical
      // details on a device the user was told is now clean.
      await db.delete(db.appointments).go();
      await db.delete(db.doctors).go();
      await db.delete(db.dependentProfiles).go();
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
      await db.delete(db.biometricDailyData).go();
      await db.delete(db.workoutSessions).go();
      await db.delete(db.healthSources).go();
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

      // Focus session history is a real table since v15, so wiping the `focus*`
      // preference keys is no longer enough — that would leave the entire session
      // history behind while telling the user their data was deleted. Removing
      // `focusSessionsMigratedToDrift` above also means the next launch would look
      // for a legacy blob, find none, and simply record itself as migrated again.
      try {
        await AppDatabase.instance.focusDao.deleteEverything();
      } catch (e) {
        debugPrint('Error clearing focus sessions: $e');
      }

      // Drop in-memory caches and refresh reactive state so the UI updates now.
      _medicinesCache.clear();
      _remindersCache.clear();
      WaterService.clearInMemory();
      PeriodService.clearInMemory();
      StepService.clearInMemory();
      SleepService.clearInMemory();
      BiometricsService.clearInMemory();

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
        // Only the backup-covered tables, and only the sections THIS file
        // carries. Using clearAllPersistentData() here deleted dose history,
        // period history and sleep/step entries that the backup cannot restore
        // — permanently, while the UI said "Backup restored successfully".
        // Passing `data` closes the same hole one version further out: an
        // older file omits whole sections, and clearing those would destroy
        // them just as permanently.
        await clearRestorableData(forBackup: data);
      }
      await importData(data);
    } catch (e) {
      debugPrint('Restore failed: $e — attempting rollback');
      // Roll back ONLY when we were the ones who cleared. A non-destructive
      // restore (clearExisting == false) is a pure merge that deleted nothing,
      // so wiping here would destroy strictly more than the failure did.
      if (snapshot != null && clearExisting) {
        try {
          // The snapshot is a current export, so it carries every section —
          // but say so explicitly rather than relying on the null default.
          await clearRestorableData(forBackup: snapshot);
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
      // `saveDailyData` persists only the day row, so restoring through it left
      // every restored day's totals with no per-drink entries behind them.
      // `restoreDayWithLogs` writes both.
      final waterRows = (data['water'] as List? ?? const []);
      for (final w in waterRows) {
        try {
          await WaterService.restoreDayWithLogs(
              DailyWaterData.fromJson(Map<String, dynamic>.from(w)));
        } catch (e) {
          debugPrint('Import water failed: $e');
        }
      }
      if (waterRows.isNotEmpty) {
        // Favourites and achievements are derived; recompute once at the end
        // rather than per day.
        try {
          await WaterService.refreshAfterRestore();
        } catch (e) {
          debugPrint('Water post-restore refresh failed: $e');
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
      // Sleep / period / steps / health profile (v6+). Each section is
      // independently optional, so a pre-v6 backup restores exactly as before.
      //
      // These write Drift rows directly. The SleepService / PeriodService /
      // StepService singletons hold their own in-memory copy and reload it in
      // `init()`, so the restored nights, cycles and step days appear after the
      // app restart the restore screens already ask for — the same known
      // limitation FocusService has above.
      try {
        await HealthBackupSerializer.importJson(data);
      } catch (e) {
        debugPrint('Import sleep/period/steps failed: $e');
      }
      // Doctors / appointments / household profiles (v7+), same shape: each
      // section independently optional, so a pre-v7 backup restores exactly as
      // before. The screens that show these read on build rather than from a
      // cached singleton, so nothing needs reloading here.
      try {
        await MedicationBackupSerializer.importJson(data);
      } catch (e) {
        debugPrint('Import doctors/appointments/dependents failed: $e');
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
  

  /// Close the database connection.
  ///
  /// Closes the singleton itself: this service no longer owns a separate handle
  /// to close, and leaving `AppDatabase.instance` open while marking ourselves
  /// closed would be the same staleness bug from the other direction.
  static Future<void> close() async {
    if (!_isInitialized) return;
    await AppDatabase.instance.close();
    _isInitialized = false;
    debugPrint('✓ CleanStorageService closed');
  }
}
