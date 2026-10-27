import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/water_dao.dart';
import '../../../core/health/hydration_goal.dart';
import '../../sleep/services/sleep_service.dart';
import '../../../core/health/streak_engine.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../models/hydration_profile.dart';
import '../models/water_achievement.dart';
import '../models/enhanced_water_log.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/services/water_action_queue.dart';
import 'hydration_health_sync.dart';
import 'hydration_weather_service.dart';
import '../../../core/utils/calendar_day.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/services/vacation_mode.dart';

/// One queued drink after it became a real log: the row's id, the moment it was
/// filed under (which is when the button was tapped, not when the app resumed)
/// and the volume as tapped.
///
/// The date travels with the id because an Undo has to delete from the day the
/// drink actually landed on. See [WaterService.drainPendingWaterActions].
typedef AppliedWaterAction = ({String id, DateTime at, int amountMl});

/// Comprehensive water tracking service
/// Handles beverages, containers, achievements, statistics, and insights
/// Uses in-memory storage with ValueNotifier for reactivity
class WaterService {
  static bool _isInitialized = false;
  static const _uuid = Uuid();

  // In-memory storage with ValueNotifier for reactivity
  static final ValueNotifier<Map<String, DailyWaterData>> _dailyWaterNotifier = 
      ValueNotifier<Map<String, DailyWaterData>>({});
  static final List<BeverageType> _customBeverages = [];
  static final List<WaterContainer> _customContainers = [];
  static HydrationProfile _profile = HydrationProfile(id: 'profile', createdAt: clock.now());
  static UserAchievements _achievements = UserAchievements(id: 'user');

  /// Drinks the user deleted, by day key — the tombstones that stop a stale
  /// copy of a day putting them back. See [mergeCloudDay].
  ///
  /// Persisted as one JSON row in the shared key-value table rather than as a
  /// column on `daily_water_data`: this is sync bookkeeping, not part of a
  /// day's record, and it is read once per session — lazily, on the first path
  /// that needs it, never on the start-up path. See [_ensureTombstonesLoaded].
  static Map<String, Set<String>> _deletedLogIds = {};
  static bool _tombstonesLoaded = false;
  static const _deletedLogIdsPrefKey = 'water.deletedLogIds';

  /// Expose value listenable for daily water data
  static ValueListenable<Map<String, DailyWaterData>>? listenToDailyData() {
    return _dailyWaterNotifier;
  }

  static WaterDao get _dao => db.AppDatabase.instance.waterDao;

  /// How much history [init] pre-loads into the in-memory cache at start-up.
  ///
  /// This is a *warm cache*, not the extent of the stored history: any older
  /// day is pulled in on demand by [_ensureDayLoaded] / [loadDataForDate] /
  /// [ensureRangeLoaded]. Nothing may read or write a day without going through
  /// one of those — a day that is merely absent from this window must never be
  /// mistaken for a day with no data.
  static const Duration warmCacheWindow = Duration(days: 90);

  /// Initialize the water service — loads persisted data from Drift.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final now = clock.now();
      final rows = await _dao.getDataForRange(
        now.subtract(warmCacheWindow),
        DateTime(now.year, now.month, now.day + 1),
      );
      // ONE query for every day's logs, not one per day. This runs before
      // runApp(), and warmCacheWindow is 90 days — the old loop meant up to 91
      // serialized round trips between launching the app and seeing a frame,
      // growing with how long the person has used it.
      final byDay = await _dao.getLogsForDays(rows.map((r) => r.id).toList());
      final map = <String, DailyWaterData>{};
      for (final row in rows) {
        final logRows = byDay[row.id] ?? const [];
        map[row.id] = _dailyFromRow(row, logRows.map(_logFromRow).toList());
      }
      _dailyWaterNotifier.value = map;
      debugPrint('✓ WaterService loaded ${map.length} days from Drift');
    } catch (e) {
      debugPrint('⚠️ WaterService load failed (using empty): $e');
    }

    // Load persisted hydration profile.
    try {
      final row = await _dao.getProfile();
      if (row != null) {
        _profile = _profileFromRow(row);
        debugPrint('✓ WaterService loaded hydration profile from Drift');
      }
    } catch (e) {
      debugPrint('⚠️ WaterService profile load failed: $e');
    }

    // Load persisted custom beverages (merged with defaults, no default dupes).
    try {
      final rows = await _dao.getAllBeverages();
      final defaultIds =
          BeverageType.defaultBeverages.map((b) => b.id).toSet();
      _customBeverages
        ..clear()
        ..addAll(rows
            .where((r) => !defaultIds.contains(r.id))
            .map(_beverageFromRow));
      debugPrint('✓ WaterService loaded ${_customBeverages.length} custom beverages');
    } catch (e) {
      debugPrint('⚠️ WaterService beverages load failed: $e');
    }

    // Load persisted custom containers (merged with defaults, no default dupes).
    try {
      final rows = await _dao.getAllContainers();
      final defaultIds =
          WaterContainer.defaultContainers.map((c) => c.id).toSet();
      _customContainers
        ..clear()
        ..addAll(rows
            .where((r) => !defaultIds.contains(r.id))
            .map(_containerFromRow));
      debugPrint('✓ WaterService loaded ${_customContainers.length} custom containers');
    } catch (e) {
      debugPrint('⚠️ WaterService containers load failed: $e');
    }

    // Load persisted achievements, then re-evaluate against the loaded daily
    // data so streaks/points/unlock states are fresh and survive restart.
    try {
      final row = await _dao.getAchievements();
      if (row != null) {
        _achievements = _achievementsFromRow(row);
        debugPrint('✓ WaterService loaded achievements from Drift');
      }
    } catch (e) {
      debugPrint('⚠️ WaterService achievements load failed: $e');
    }
    // Log-derived favourites / frequent cups. Before achievements so a failure
    // here cannot skip the achievement pass.
    await _refreshUsage();
    try {
      await _evaluateAchievements();
    } catch (e) {
      debugPrint('⚠️ WaterService achievements evaluation failed: $e');
    }

    _isInitialized = true;
  }

  // ---- Drift <-> model mapping / persistence -----------------------------
  static EnhancedWaterLog _logFromRow(db.EnhancedWaterLog r) => EnhancedWaterLog(
        id: r.id,
        time: r.time,
        amountMl: r.amountMl,
        effectiveHydrationMl: r.effectiveHydrationMl,
        beverageId: r.beverageId,
        beverageName: r.beverageName,
        beverageEmoji: r.beverageEmoji ?? '💧',
        hydrationPercent: r.hydrationPercent,
        containerId: r.containerId,
        containerName: r.containerName,
        caffeineAmount: r.caffeineAmount,
        isAlcoholic: r.isAlcoholic,
        note: r.note,
      );

  static DailyWaterData _dailyFromRow(
      db.DailyWaterDataTableData r, List<EnhancedWaterLog> logs) {
    return DailyWaterData(
      id: r.id,
      date: r.date,
      dailyGoalMl: r.dailyGoalMl,
      totalIntakeMl: r.totalIntakeMl,
      effectiveHydrationMl: r.effectiveHydrationMl,
      totalCaffeineMg: r.totalCaffeineMg,
      alcoholicDrinksCount: r.alcoholicDrinksCount,
      goalReached: r.goalReached,
      goalReachedAt: r.goalReachedAt,
      logs: logs,
      deletedLogIds: _tombstonesFor(r.id),
    );
  }

  /// Read the tombstone map, once per session, on first use.
  ///
  /// Deliberately NOT part of [init]: that runs before `runApp()`, and one more
  /// read there is one more thing between tapping the icon and the first frame
  /// — `test/performance/startup_cost_test.dart` holds that budget. Nothing on
  /// the startup path needs these; the paths that do (a delete, a merge, a
  /// restore, a backup export, a sync upload) all await this first, and all of
  /// them are already asynchronous.
  static Future<void> _ensureTombstonesLoaded() async {
    if (_tombstonesLoaded) return;
    // Set before the read, not after: a failure means an unreadable row, and
    // retrying it on every delete would not make it readable.
    _tombstonesLoaded = true;
    try {
      final raw = await db.AppDatabase.instance.coreDao
          .getPreference(_deletedLogIdsPrefKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in decoded.entries) {
        _deletedLogIds
            .putIfAbsent(e.key, () => <String>{})
            .addAll((e.value as List).map((id) => id.toString()));
      }
    } catch (e) {
      debugPrint('⚠️ WaterService tombstone load failed: $e');
    }
  }

  /// The drinks recorded as deleted on [dayKey] — a snapshot, not the live set,
  /// so a day object cannot be mutated from under its holder.
  ///
  /// Empty until [_ensureTombstonesLoaded] has run, so every caller that needs
  /// a real answer awaits that first.
  static Set<String> _tombstonesFor(String dayKey) {
    final ids = _deletedLogIds[dayKey];
    return (ids == null || ids.isEmpty)
        ? const <String>{}
        : Set.unmodifiable(ids);
  }

  /// Record [ids] as deleted drinks on [dayKey] and persist the set.
  ///
  /// A no-op when nothing is new, so restoring a backup of hundreds of days
  /// rewrites the row only for the days that actually add one, not once per day.
  static Future<void> _recordDeletedLogs(
      String dayKey, Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await _ensureTombstonesLoaded();
    final set = _deletedLogIds.putIfAbsent(dayKey, () => <String>{});
    final before = set.length;
    set.addAll(ids);
    if (set.length == before) return;
    await _persistDeletedLogIds();
  }

  /// Write the tombstone map, pruned to [warmCacheWindow].
  ///
  /// A tombstone only has to outlive the window in which a stale cloud copy or
  /// a backup can still be carrying the drink; keeping every one of them would
  /// grow this row for the life of the install. Day keys are `yyyy-MM-dd`, so
  /// comparing them as strings compares them chronologically.
  static Future<void> _persistDeletedLogIds() async {
    try {
      final cutoff = _getDateKey(clock.now().subtract(warmCacheWindow));
      _deletedLogIds.removeWhere(
          (key, ids) => ids.isEmpty || key.compareTo(cutoff) < 0);
      await db.AppDatabase.instance.coreDao.setPreference(
        _deletedLogIdsPrefKey,
        jsonEncode({
          for (final e in _deletedLogIds.entries) e.key: e.value.toList(),
        }),
      );
    } catch (e) {
      debugPrint('⚠️ persist water tombstones failed: $e');
    }
  }

  /// The day row as Drift wants it. Shared by every writer so no path can
  /// quietly persist a different subset of the columns.
  static db.DailyWaterDataTableCompanion _dayCompanion(DailyWaterData d) =>
      db.DailyWaterDataTableCompanion(
        id: Value(d.id),
        date: Value(d.date),
        dailyGoalMl: Value(d.dailyGoalMl),
        totalIntakeMl: Value(d.totalIntakeMl),
        effectiveHydrationMl: Value(d.effectiveHydrationMl),
        totalCaffeineMg: Value(d.totalCaffeineMg),
        alcoholicDrinksCount: Value(d.alcoholicDrinksCount),
        goalReached: Value(d.goalReached),
        goalReachedAt: Value(d.goalReachedAt),
      );

  /// One drink row, belonging to [dayId]. Shared for the same reason.
  static db.EnhancedWaterLogsCompanion _logCompanion(
          String dayId, EnhancedWaterLog l) =>
      db.EnhancedWaterLogsCompanion(
        id: Value(l.id),
        dailyDataId: Value(dayId),
        time: Value(l.time),
        amountMl: Value(l.amountMl),
        effectiveHydrationMl: Value(l.effectiveHydrationMl),
        beverageId: Value(l.beverageId),
        beverageName: Value(l.beverageName),
        beverageEmoji: Value(l.beverageEmoji),
        hydrationPercent: Value(l.hydrationPercent),
        containerId: Value(l.containerId),
        containerName: Value(l.containerName),
        caffeineAmount: Value(l.caffeineAmount),
        isAlcoholic: Value(l.isAlcoholic),
        note: Value(l.note),
      );

  static Future<void> _persistDay(DailyWaterData d) async {
    try {
      await _dao.saveDailyData(_dayCompanion(d));
      // [d] is what the table now holds for this day, so the lifetime snapshot
      // can be folded forward rather than re-read. Only after the write
      // succeeds: this method swallows its own failures, and a failed write
      // must not leave the snapshot claiming something the table does not hold.
      _patchAggregate(d);
    } catch (e) {
      debugPrint('⚠️ persist day failed: $e');
    }
  }

  static Future<void> _persistLog(String dayId, EnhancedWaterLog l) async {
    try {
      await _dao.addWaterLog(_logCompanion(dayId, l));
    } catch (e) {
      debugPrint('⚠️ persist log failed: $e');
    }
  }

  // ---- Color <-> int helpers (colorValue column stores 0xAARRGGBB) --------
  static int _hexToColorValue(String? hex) {
    if (hex == null || hex.isEmpty) return 0xFF2196F3;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16) ?? 0xFF2196F3;
  }

  static String _colorValueToHex(int value) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }

  // ---- Profile <-> Drift mapping / persistence ---------------------------
  static HydrationProfile _profileFromRow(db.HydrationProfile r) {
    Map<String, dynamic> extra = const {};
    final raw = r.healthConditionsJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) extra = decoded;
      } catch (_) {}
    }
    final activityIdx =
        r.activityLevel.clamp(0, ActivityLevel.values.length - 1);
    final climateIdx = r.climateType.clamp(0, ClimateType.values.length - 1);
    return HydrationProfile(
      id: r.id,
      weightKg: r.weightKg,
      heightCm: extra['heightCm'] as int?,
      age: extra['age'] as int?,
      isMale: extra['isMale'] as bool? ?? true,
      activityLevel: ActivityLevel.values[activityIdx],
      climate: ClimateType.values[climateIdx],
      isPregnant: extra['isPregnant'] as bool? ?? r.pregnantOrNursing,
      isBreastfeeding: extra['isBreastfeeding'] as bool? ?? false,
      customGoalMl: r.customGoalMl ?? 2500,
      useCustomGoal: r.useCustomGoal,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      wakeUpReminderEnabled: extra['wakeUpReminderEnabled'] as bool? ?? true,
      wakeUpHour: extra['wakeUpHour'] as int? ?? 7,
      bedtimeHour: extra['bedtimeHour'] as int? ?? 22,
      fluidCeilingMl: extra['fluidCeilingMl'] as int?,
      conditions: parseHydrationConditions(extra['conditions']),
    );
  }

  static Future<void> _persistProfile(HydrationProfile p) async {
    try {
      // Fields with no dedicated column overflow into healthConditionsJson.
      final extra = <String, dynamic>{
        'heightCm': p.heightCm,
        'age': p.age,
        'isMale': p.isMale,
        'isPregnant': p.isPregnant,
        'isBreastfeeding': p.isBreastfeeding,
        'wakeUpReminderEnabled': p.wakeUpReminderEnabled,
        'wakeUpHour': p.wakeUpHour,
        'bedtimeHour': p.bedtimeHour,
        'fluidCeilingMl': p.fluidCeilingMl,
        'conditions': p.conditions.map((c) => c.name).toList(),
      };
      await _dao.saveProfile(db.HydrationProfilesCompanion(
        id: const Value('profile'),
        weightKg: Value(p.weightKg),
        activityLevel: Value(p.activityLevel.index),
        climateType: Value(p.climate.index),
        customGoalMl: Value(p.customGoalMl),
        useCustomGoal: Value(p.useCustomGoal),
        pregnantOrNursing: Value(p.isPregnant || p.isBreastfeeding),
        healthConditionsJson: Value(jsonEncode(extra)),
        createdAt: Value(p.createdAt ?? clock.now()),
        updatedAt: Value(p.updatedAt ?? clock.now()),
      ));
    } catch (e) {
      debugPrint('⚠️ persist profile failed: $e');
    }
  }

  // ---- Beverage <-> Drift mapping / persistence --------------------------
  static BeverageType _beverageFromRow(db.BeverageType r) => BeverageType(
        id: r.id,
        name: r.name,
        emoji: r.emoji,
        hydrationPercent: r.hydrationPercent,
        colorHex: _colorValueToHex(r.colorValue),
        isDefault: r.isDefault,
        hasCaffeine: r.hasCaffeine,
        caffeinePerMl: r.caffeinePerMl.round(),
        isAlcoholic: r.isAlcoholic,
      );

  static Future<void> _persistBeverage(BeverageType b) async {
    try {
      await _dao.addBeverage(db.BeverageTypesCompanion(
        id: Value(b.id),
        name: Value(b.name),
        emoji: Value(b.emoji),
        hydrationPercent: Value(b.hydrationPercent),
        colorValue: Value(_hexToColorValue(b.colorHex)),
        hasCaffeine: Value(b.hasCaffeine),
        caffeinePerMl: Value(b.caffeinePerMl.toDouble()),
        isAlcoholic: Value(b.isAlcoholic),
        isDefault: Value(b.isDefault),
      ));
    } catch (e) {
      debugPrint('⚠️ persist beverage failed: $e');
    }
  }

  // ---- Container <-> Drift mapping / persistence -------------------------
  static WaterContainer _containerFromRow(db.WaterContainer r) =>
      WaterContainer(
        id: r.id,
        name: r.name,
        emoji: r.emoji,
        capacityMl: r.capacityMl,
        isDefault: r.isDefault,
        colorHex: _colorValueToHex(r.colorValue),
        usageCount: r.usageCount,
        lastUsed: r.lastUsed,
      );

  static db.WaterContainersCompanion _containerCompanion(WaterContainer c) =>
      db.WaterContainersCompanion(
        id: Value(c.id),
        name: Value(c.name),
        capacityMl: Value(c.capacityMl),
        emoji: Value(c.emoji),
        colorValue: Value(_hexToColorValue(c.colorHex)),
        isDefault: Value(c.isDefault),
        usageCount: Value(c.usageCount),
        lastUsed: Value(c.lastUsed),
      );

  // ============ BEVERAGES ============

  /// Get all beverages (default + custom)
  static List<BeverageType> getAllBeverages() {
    return [...BeverageType.defaultBeverages, ..._customBeverages];
  }

  /// Get beverage by ID
  static BeverageType? getBeverage(String id) {
    final allBeverages = getAllBeverages();
    return allBeverages.where((b) => b.id == id).firstOrNull;
  }

  /// Add custom beverage
  static Future<void> addCustomBeverage(BeverageType beverage) async {
    _customBeverages.add(beverage);
    _notifyListeners();
    await _persistBeverage(beverage);
  }

  /// Delete custom beverage (only non-default)
  static Future<void> deleteBeverage(String id) async {
    _customBeverages.removeWhere((b) => b.id == id);
    _notifyListeners();
    try {
      await _dao.deleteBeverage(id);
    } catch (e) {
      debugPrint('⚠️ delete beverage failed: $e');
    }
  }

  /// Get favorite beverages (most used)
  /// Log-derived usage, refreshed on init and after every write. Empty until
  /// the first refresh, in which case the getters below fall back to declared
  /// order — which is exactly the old behaviour, so a failed refresh degrades
  /// rather than breaks.
  static Map<String, WaterUsage> _beverageUsage = const {};
  static Map<String, WaterUsage> _containerUsage = const {};

  /// Recompute the usage maps from the logs. One grouped query.
  ///
  /// The exact answer, and the one the incremental [_bumpUsage] / [_dropUsage]
  /// patches are kept in agreement with. Run on `init()` and after a restore;
  /// the per-drink paths patch instead, because this scans every log row ever
  /// written.
  static Future<void> _refreshUsage() async {
    try {
      final u = await _dao.usageCounts();
      _beverageUsage = u.beverages;
      _containerUsage = u.containers;
    } catch (e) {
      debugPrint('⚠️ WaterService usage refresh failed: $e');
    }
  }

  /// Fold one newly-added [log] into the usage maps.
  ///
  /// The maps are replaced rather than mutated: [_beverageUsage] starts as a
  /// `const {}`, which cannot be written to.
  static void _bumpUsage(EnhancedWaterLog log) {
    _beverageUsage = {
      ..._beverageUsage,
      log.beverageId: _incremented(_beverageUsage[log.beverageId], log.time),
    };
    final containerId = log.containerId;
    if (containerId != null) {
      _containerUsage = {
        ..._containerUsage,
        containerId: _incremented(_containerUsage[containerId], log.time),
      };
    }
  }

  /// Take one removed [log] back out again, so a delete cannot leave the counts
  /// permanently inflated.
  ///
  /// The key is dropped at zero rather than left at 0, because
  /// `_beverageUsage.keys` is what [_evaluateAchievements] reads as "every
  /// beverage ever logged" — a stale key there would keep a "tried N drinks"
  /// badge unlocked on a drink the user has removed.
  ///
  /// `lastUsed` is deliberately NOT rolled back: recovering the previous
  /// maximum needs the log table, and this is the Undo path. It can therefore
  /// name a moment slightly later than the newest surviving drink until the
  /// next [_refreshUsage]; nothing but the cup list's "last used" reads it.
  static void _dropUsage(EnhancedWaterLog log) {
    _beverageUsage =
        _decremented(_beverageUsage, log.beverageId);
    final containerId = log.containerId;
    if (containerId != null) {
      _containerUsage = _decremented(_containerUsage, containerId);
    }
  }

  /// [prev] with one more use at [at]. `lastUsed` takes the LATER of the two
  /// because [WaterDao.usageCounts] reports `MAX(time)` and this path also
  /// serves back-dated adds from the history editor.
  static WaterUsage _incremented(WaterUsage? prev, DateTime at) {
    final last = prev?.lastUsed;
    return WaterUsage(
      count: (prev?.count ?? 0) + 1,
      lastUsed: last == null || at.isAfter(last) ? at : last,
    );
  }

  static Map<String, WaterUsage> _decremented(
      Map<String, WaterUsage> usage, String key) {
    final prev = usage[key];
    if (prev == null) return usage;
    final next = {...usage};
    if (prev.count <= 1) {
      next.remove(key);
    } else {
      next[key] = WaterUsage(count: prev.count - 1, lastUsed: prev.lastUsed);
    }
    return next;
  }

  /// Most-logged beverages first, ties broken by declared order so the list is
  /// stable. Previously `getAllBeverages().take(limit)` — i.e. never actually
  /// the user's favourites, just the first six built-ins.
  static List<BeverageType> getFavoriteBeverages({int limit = 6}) {
    final all = getAllBeverages();
    final ranked = [...all];
    final order = {for (var i = 0; i < all.length; i++) all[i].id: i};
    ranked.sort((a, b) {
      final ca = _beverageUsage[a.id]?.count ?? 0;
      final cb = _beverageUsage[b.id]?.count ?? 0;
      if (ca != cb) return cb.compareTo(ca);
      return (order[a.id] ?? 0).compareTo(order[b.id] ?? 0);
    });
    return ranked.take(limit).toList();
  }

  /// How many times [beverageId] has been logged.
  static int beverageUseCount(String beverageId) =>
      _beverageUsage[beverageId]?.count ?? 0;

  // ============ CONTAINERS ============

  /// Get all containers
  /// All containers, with [WaterContainer.usageCount] / [WaterContainer.lastUsed]
  /// filled in from the logs. The columns of the same name exist on the table
  /// but nothing ever wrote them, so both fields were permanently 0/null on
  /// every container the UI showed.
  static List<WaterContainer> getAllContainers() {
    return [
      for (final c in [...WaterContainer.defaultContainers, ..._customContainers])
        _withUsage(c),
    ];
  }

  static WaterContainer _withUsage(WaterContainer c) {
    final u = _containerUsage[c.id];
    if (u == null) return c;
    return c.copyWith(usageCount: u.count, lastUsed: u.lastUsed);
  }

  /// Get container by ID
  static WaterContainer? getContainer(String id) {
    final allContainers = getAllContainers();
    return allContainers.where((c) => c.id == id).firstOrNull;
  }

  /// Add custom container
  static Future<void> addCustomContainer(WaterContainer container) async {
    _customContainers.add(container);
    _notifyListeners();
    try {
      await _dao.addContainer(_containerCompanion(container));
    } catch (e) {
      debugPrint('⚠️ persist container failed: $e');
    }
  }

  /// Update container
  static Future<void> updateContainer(WaterContainer container) async {
    final index = _customContainers.indexWhere((c) => c.id == container.id);
    if (index >= 0) {
      _customContainers[index] = container;
      _notifyListeners();
      try {
        await _dao.updateContainer(_containerCompanion(container));
      } catch (e) {
        debugPrint('⚠️ update container failed: $e');
      }
    }
  }

  /// Delete custom container
  static Future<void> deleteContainer(String id) async {
    _customContainers.removeWhere((c) => c.id == id);
    _notifyListeners();
    try {
      await _dao.deleteContainer(id);
    } catch (e) {
      debugPrint('⚠️ delete container failed: $e');
    }
  }

  /// Get frequently used containers
  /// Most-used cups first, ties broken by declared order. Previously
  /// `getAllContainers().take(limit)` — the first four built-ins, regardless of
  /// what the user actually drinks from.
  static List<WaterContainer> getFrequentContainers({int limit = 4}) {
    final all = getAllContainers();
    final order = {for (var i = 0; i < all.length; i++) all[i].id: i};
    final ranked = [...all];
    ranked.sort((a, b) {
      final ca = _containerUsage[a.id]?.count ?? 0;
      final cb = _containerUsage[b.id]?.count ?? 0;
      if (ca != cb) return cb.compareTo(ca);
      return (order[a.id] ?? 0).compareTo(order[b.id] ?? 0);
    });
    return ranked.take(limit).toList();
  }

  /// How many times [containerId] has been logged, and when it was last used.
  /// The `usage_count`/`last_used` columns exist but were never written; these
  /// come from the logs instead, so they are correct for history too.
  static int containerUseCount(String containerId) =>
      _containerUsage[containerId]?.count ?? 0;

  static DateTime? containerLastUsed(String containerId) =>
      _containerUsage[containerId]?.lastUsed;

  // ============ HYDRATION PROFILE ============

  /// Get or create hydration profile
  static HydrationProfile getProfile() {
    return _profile;
  }

  /// Save hydration profile
  static Future<void> saveProfile(HydrationProfile profile) async {
    _profile = profile;
    _notifyListeners();

    // Persist the profile itself.
    await _persistProfile(profile);

    // Recompute today's daily goal from the profile's effective goal and
    // persist the day so progress/goal-reached stay consistent.
    final key = _getDateKey(clock.now());
    final newGoal = await _goalNowFor(profile);
    final today = _dailyWaterNotifier.value[key];
    if (today != null) {
      if (today.dailyGoalMl != newGoal) {
        final updated = _recalculateDailyData(
          today.copyWith(dailyGoalMl: newGoal),
          today.logs,
        );
        await saveDailyData(updated);
      }
    } else {
      await saveDailyData(
        DailyWaterData(id: key, date: clock.now(), dailyGoalMl: newGoal),
      );
    }
  }

  /// Today's goal for [profile], keeping what the day has already earned.
  ///
  /// The profile's own number is the base. Saving the profile used to stamp THAT
  /// onto today, which silently dropped the hot-day adjustment and any activity
  /// top-up until the next app open recomputed them — so editing your weight at
  /// 3pm on a hot day lowered the target you were mid-way through. Both are
  /// re-applied from what is already known on the device (the cached
  /// temperature and today's saved top-up), with no network or health read, and
  /// under exactly the rules [refreshDailyGoal] uses: a custom goal and a fluid
  /// ceiling are never adjusted.
  static Future<int> _goalNowFor(HydrationProfile profile) async {
    if (profile.isRestricted || profile.useCustomGoal) {
      return profile.effectiveGoalMl;
    }
    final c = await HydrationWeatherService.cachedApparentC();
    final base = profile.goalBreakdown(ambientC: c).totalMl;
    return base + (todayActivityGoalNote?.deltaMl ?? 0);
  }

  /// Get calculated daily goal
  static int getDailyGoal() {
    return _profile.effectiveGoalMl;
  }
  
  /// Notify all listeners about data changes
  static void _notifyListeners() {
    // Trigger rebuild by creating a new map reference
    _dailyWaterNotifier.value = Map.from(_dailyWaterNotifier.value);
  }

  // ============ DAILY WATER DATA ============

  /// Get date key
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get today's water data
  static DailyWaterData getTodayData() {
    final key = _getDateKey(clock.now());
    if (!_dailyWaterNotifier.value.containsKey(key)) {
      _dailyWaterNotifier.value[key] = DailyWaterData(
        id: key,
        date: clock.now(),
        dailyGoalMl: getDailyGoal(),
      );
    }
    return _dailyWaterNotifier.value[key]!;
  }

  /// Today's day, stamped with the drinks that were deleted from it — the
  /// shape the cloud uploader has to send.
  ///
  /// [getTodayData] stays synchronous because UI call sites read it during
  /// build, and the tombstones are not in memory until something asks for them
  /// (see [_ensureTombstonesLoaded]). Sync is the caller that must never miss
  /// them: an upload without the tombstone is what lets the next download —
  /// here or on another device — put the drink back.
  static Future<DailyWaterData> todayDataForSync() async {
    await _ensureTombstonesLoaded();
    final key = _getDateKey(clock.now());
    return getTodayData().copyWith(deletedLogIds: _tombstonesFor(key));
  }

  /// Get water data for a specific date.
  ///
  /// Cache-only, so it returns null for a stored day that is older than
  /// [warmCacheWindow] and has not been pulled in yet. Use [loadDataForDate]
  /// (or [ensureRangeLoaded] first) whenever the date can be arbitrary —
  /// treating this null as "no data" is what used to let history be overwritten.
  static DailyWaterData? getDataForDate(DateTime date) {
    final key = _getDateKey(date);
    return _dailyWaterNotifier.value[key];
  }

  /// Loads one day (its row *and* its logs) from Drift into the cache unless it
  /// is already there, and returns it — null only when the day was never saved.
  ///
  /// [init] warms just [warmCacheWindow], so an older day is missing from the
  /// notifier even though it exists on disk. Every read of an arbitrary date,
  /// and *every write*, goes through here: building a write on the empty
  /// in-memory view persisted zeroed totals over the stored day and orphaned its
  /// logs. Errors deliberately propagate to the callers that mutate data, so a
  /// day that could not be read is never rewritten from a blank.
  static Future<DailyWaterData?> _ensureDayLoaded(String key) async {
    final cached = _dailyWaterNotifier.value[key];
    if (cached != null) return cached;

    final row = await _dao.getDailyData(key);
    if (row == null) return null;

    final logRows = await _dao.getLogsForDay(key);
    final data = _dailyFromRow(row, logRows.map(_logFromRow).toList());
    _dailyWaterNotifier.value[key] = data;
    _notifyListeners();
    return data;
  }

  /// Water data for [date], loading it from storage when it falls outside the
  /// warm cache. Display-safe: if the read fails it falls back to whatever is
  /// cached instead of throwing, so a history screen degrades rather than dies.
  static Future<DailyWaterData?> loadDataForDate(DateTime date) async {
    final key = _getDateKey(date);
    try {
      return await _ensureDayLoaded(key);
    } catch (e) {
      debugPrint('⚠️ WaterService load day $key failed: $e');
      return _dailyWaterNotifier.value[key];
    }
  }

  /// Warms the cache for [start]..[end] (inclusive) so the synchronous readers
  /// — [getDataForDate], [getDataForRange], [getMonthlyStats] — can see days
  /// older than [warmCacheWindow]. Call this before rendering a historical
  /// month or range; days already cached are left untouched.
  static Future<void> ensureRangeLoaded(DateTime start, DateTime end) async {
    try {
      final from = DateTime(start.year, start.month, start.day);
      // Calendar-day step for the exclusive upper bound, not +24h.
      final to = DateTime(end.year, end.month, end.day + 1);
      final rows = await _dao.getDataForRange(from, to);
      final missing =
          rows.where((r) => !_dailyWaterNotifier.value.containsKey(r.id)).toList();
      if (missing.isEmpty) return;
      // ONE query for every missing day's logs. This is called per rendered
      // month, so the old per-day `getLogsForDay` loop was up to 31 serialized
      // round trips before the grid could paint.
      final byDay = await _dao.getLogsForDays(missing.map((r) => r.id).toList());
      for (final row in missing) {
        _dailyWaterNotifier.value[row.id] = _dailyFromRow(
            row, (byDay[row.id] ?? const []).map(_logFromRow).toList());
      }
      _notifyListeners();
    } catch (e) {
      debugPrint('⚠️ WaterService range load failed: $e');
    }
  }

  /// Get water data for date range
  static List<DailyWaterData> getDataForRange(DateTime start, DateTime end) {
    final results = <DailyWaterData>[];
    var current = start;
    while (!current.isAfter(end)) {
      final data = getDataForDate(current);
      if (data != null) {
        results.add(data);
      }
      // Step by calendar day, NOT by 24h: a local day is 23 or 25 hours
      // across a DST transition, so adding a fixed Duration re-emits the
      // same date key on the fall-back day (double-counting it) and skips
      // one on the spring-forward day.
      current = DateTime(current.year, current.month, current.day + 1);
    }
    return results;
  }

  static Future<void> saveDailyData(DailyWaterData data) async {
    _dailyWaterNotifier.value[data.id] = data;
    _notifyListeners();
    await _persistDay(data);
  }

  /// Add water log
  static Future<DailyWaterData> addWaterLog({
    required int amountMl,
    required BeverageType beverage,
    WaterContainer? container,
    String? note,
  }) async {
    final now = clock.now();
    return addWaterLogForDate(
      date: now,
      amountMl: amountMl,
      beverage: beverage,
      container: container,
      time: now,
      note: note,
    );
  }

  /// Remove water log
  /// Remove a log without knowing which day it belongs to.
  ///
  /// Resolves the owning day from the stored row rather than assuming today:
  /// the callers are foreground Undo buttons, and a drink added for a PAST date
  /// (the history editor, a quick-add drained from a tap made before midnight)
  /// would otherwise be looked for in today's logs, not found, and — since
  /// [removeWaterLogForDate] now refuses to delete a row that is not in the day
  /// it was handed — silently not removed at all.
  static Future<void> removeWaterLog(String logId) async {
    final owning = await _dao.dayKeyForLog(logId);
    await removeWaterLogForDate(
      owning == null ? clock.now() : _dateFromKey(owning),
      logId,
    );
  }

  /// `yyyy-MM-dd` back to a local DateTime. Inverse of [_getDateKey].
  static DateTime _dateFromKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// Remove water log for a specific date
  static Future<void> removeWaterLogForDate(DateTime date, String logId) async {
    final key = _getDateKey(date);
    // Read the persisted day, not just the warm cache: an older day was seen as
    // null here, so the delete silently did nothing and left the log on disk.
    final data = await _ensureDayLoaded(key);
    if (data == null) return;
    final updatedLogs = data.logs.where((l) => l.id != logId).toList();
    // Bail when the id is not one of THIS day's logs. It used to delete the row
    // anyway: an Undo aimed at the wrong date (yesterday's quick-add undone
    // against today) removed the log from `enhanced_water_logs` while leaving
    // yesterday's totals and cached logs untouched — so history and the weekly
    // stats still counted a drink whose row was gone, and the day no longer
    // agreed with itself.
    if (updatedLogs.length == data.logs.length) return;
    // The counts are patched per drink rather than recounted (see
    // [_refreshUsage]), so a removal has to be taken back out of them here or
    // an undone drink keeps its vote in the favourites ranking for ever.
    _dropUsage(data.logs.firstWhere((l) => l.id == logId));
    // Tombstone the drink before anything else: the cloud merge is a union by
    // log id, so without a record of the deletion the next sync — or, on a
    // single device, the next download of the copy uploaded before the delete —
    // hands it straight back. See [mergeCloudDay].
    await _recordDeletedLogs(key, [logId]); // loads the set if it is not in yet
    final updatedData = _recalculateDailyData(data, updatedLogs)
        .copyWith(deletedLogIds: _tombstonesFor(key));
    _dailyWaterNotifier.value[key] = updatedData;
    _notifyListeners();
    await _dao.deleteWaterLog(logId);
    await _persistDay(updatedData);
    await _evaluateAchievements();
    // The home-screen widget shows today's intake, and only a push refreshes
    // it. The ADD path pushed (aqua_water_dashboard.dart, after every "+"), the
    // delete path did not — so an Undo, a swipe-delete in Today's Log or an
    // edit in the history screen left the widget showing a drink the app had
    // already removed, until the next steps/sleep write happened to refresh it.
    // Pushed from here rather than from each screen so every delete path is
    // covered by one call.
    await HomeWidgetService.pushSnapshot();
  }

  /// Add water log for a specific date (for history editing)
  static Future<DailyWaterData> addWaterLogForDate({
    required DateTime date,
    required int amountMl,
    required BeverageType beverage,
    WaterContainer? container,
    DateTime? time,
    String? note,
  }) async {
    final key = _getDateKey(date);
    final effectiveTime = time ?? date;
    
    // Create the log entry
    final log = EnhancedWaterLog(
      id: _uuid.v4(),
      time: effectiveTime,
      amountMl: amountMl,
      effectiveHydrationMl: beverage.getEffectiveHydration(amountMl),
      beverageId: beverage.id,
      beverageName: beverage.name,
      beverageEmoji: beverage.emoji,
      hydrationPercent: beverage.hydrationPercent,
      containerId: container?.id,
      containerName: container?.name,
      caffeineAmount: beverage.getCaffeineAmount(amountMl),
      isAlcoholic: beverage.isAlcoholic,
      note: note,
    );

    // Get or create daily data. The load must hit storage first: for a day
    // outside the warm cache the in-memory view is empty, and adding an entry
    // on top of that blank would persist it over the day's real totals.
    final data = await _ensureDayLoaded(key) ??
        DailyWaterData(
          id: key,
          date: date,
          dailyGoalMl: getDailyGoal(),
        );

    // Add log and recalculate
    final updatedLogs = [...data.logs, log];
    final updatedData = _recalculateDailyData(data, updatedLogs);
    
    _dailyWaterNotifier.value[key] = updatedData;
    _notifyListeners();

    // Persist to Drift (day totals + the new log).
    await _persistDay(updatedData);
    await _persistLog(key, log);

    // Write-through to Health Connect / HealthKit when the user has opted in.
    // Self-guarding and best-effort: a health-store problem must never stop a
    // drink being recorded here.
    //
    // NOT awaited: it is a platform round trip — a preferences read, a
    // permission query and a Health Connect write — and every one of those
    // milliseconds sat between tapping "+" and the Undo toast being offered.
    // The call is still made on every single add, so a drink still reaches the
    // health store; only the waiting on it is gone. It swallows its own
    // failures, so there is nothing here that could want the result.
    unawaited(HydrationHealthSync.onLogAdded(log));

    // Usage is log-derived, and the log that changed it is right here — so
    // fold it in rather than re-running the grouped COUNT over every row ever
    // logged, which is what `_refreshUsage()` did on every add.
    _bumpUsage(log);
    _lastNewlyUnlocked = await _evaluateAchievements();

    // Same reason as the delete path below: the home-screen widget only ever
    // changes when something pushes. The push used to live in the water
    // dashboard's "+" handler, so a drink added anywhere else — the home
    // "Log something" sheet, the history editor, the calendar — left the widget
    // on its last number. Not awaited: "+" is the app's hottest write path and
    // the push is best-effort (HomeWidgetService swallows its own failures),
    // which is exactly how the dashboard called it.
    unawaited(HomeWidgetService.pushSnapshot());

    return updatedData;
  }

  /// Update water log for a specific date
  static Future<DailyWaterData> updateWaterLogForDate({
    required DateTime date,
    required String logId,
    required int amountMl,
    required BeverageType beverage,
    WaterContainer? container,
    DateTime? time,
    String? note,
  }) async {
    final key = _getDateKey(date);
    // Same rule as the add path: the edit is applied to the persisted day, so
    // editing one entry of an old day cannot drop that day's other entries.
    final data = await _ensureDayLoaded(key);

    if (data == null) {
      return addWaterLogForDate(
        date: date,
        amountMl: amountMl,
        beverage: beverage,
        container: container,
        time: time,
        note: note,
      );
    }

    final effectiveTime = time ?? date;
    EnhancedWaterLog? editedLog;
    final updatedLogs = data.logs.map((log) {
      if (log.id == logId) {
        editedLog = EnhancedWaterLog(
          id: logId,
          time: effectiveTime,
          amountMl: amountMl,
          effectiveHydrationMl: beverage.getEffectiveHydration(amountMl),
          beverageId: beverage.id,
          beverageName: beverage.name,
          beverageEmoji: beverage.emoji,
          hydrationPercent: beverage.hydrationPercent,
          containerId: container?.id,
          containerName: container?.name,
          caffeineAmount: beverage.getCaffeineAmount(amountMl),
          isAlcoholic: beverage.isAlcoholic,
          note: note,
        );
        return editedLog!;
      }
      return log;
    }).toList();

    final updatedData = _recalculateDailyData(data, updatedLogs);
    _dailyWaterNotifier.value[key] = updatedData;
    _notifyListeners();

    // Persist the edit — previously only the in-memory notifier was updated, so
    // edits silently reverted on the next launch (init() reloads from Drift).
    if (editedLog != null) {
      final l = editedLog!;
      // An edit can move the drink to a different beverage or cup, so it is a
      // removal of the old one and an add of the new as far as the patched
      // usage counts are concerned.
      _dropUsage(data.logs.firstWhere((o) => o.id == logId));
      _bumpUsage(l);
      try {
        await _dao.updateWaterLog(_logCompanion(key, l));
      } catch (e) {
        debugPrint('⚠️ update log failed: $e');
      }
    }
    await _persistDay(updatedData);
    await _evaluateAchievements();

    // Editing an entry changes the day's totals just as much as adding or
    // removing one, so the widget has to hear about it too.
    unawaited(HomeWidgetService.pushSnapshot());

    return updatedData;
  }

  /// Recalculate daily totals from logs
  static DailyWaterData _recalculateDailyData(DailyWaterData data, List<EnhancedWaterLog> logs) {
    int totalIntake = 0;
    int effectiveHydration = 0;
    int totalCaffeine = 0;
    int alcoholCount = 0;

    for (final log in logs) {
      totalIntake += log.amountMl;
      effectiveHydration += log.effectiveHydrationMl;
      totalCaffeine += log.caffeineAmount;
      if (log.isAlcoholic) alcoholCount++;
    }

    // Under a fluid RESTRICTION `dailyGoalMl` is a CEILING, not a target — see
    // HydrationProfile.effectiveGoalMl, which returns fluidCeilingMl in that
    // mode. Crossing it is the failure the restriction exists to prevent, so it
    // must never be recorded as the day's goal being reached: `goalReached`
    // feeds daysGoalMet, lastGoalMetDate, the StreakEngine and every
    // streak/perfectWeek/perfectMonth badge. A dialysis patient drinking 1600 ml
    // against a 1500 ml limit was shown a seven-day streak with a flame, a
    // "Goal Achieved!" card and an unlocked badge.
    //
    // Deliberately not inverted into "success = stayed under": at 10:00 a
    // restricted user has trivially "stayed under", and a day with no logs at
    // all would score. Rewarding restraint correctly needs a completed day and
    // a product decision; the honest feedback under a restriction is the dial
    // showing intake against the limit, which is unaffected by this flag. The
    // "overachiever" badge already refuses to fire in this mode (see below) —
    // this extends the same rule to the rest.
    final goalReached =
        !_profile.isRestricted && effectiveHydration >= data.dailyGoalMl;

    // Stamp the moment the goal was crossed — but on the day being
    // recalculated, not wall-clock now. Back-filling a log into last Tuesday
    // used to record that Tuesday's goal as reached at today's time. The last
    // log that took the day over the line is the honest answer; fall back to
    // the day's own date when there is none.
    //
    // Also clear it when the goal is no longer met: deleting or editing a log
    // can drop a day back under its target, and the old code only ever set
    // this field, never unset it — leaving a "reached at" on an unmet day.
    final DateTime? goalReachedAt;
    if (!goalReached) {
      goalReachedAt = null;
    } else if (data.goalReached && data.goalReachedAt != null) {
      goalReachedAt = data.goalReachedAt;
    } else {
      goalReachedAt = logs.isNotEmpty ? logs.last.time : data.date;
    }

    return data.copyWith(
      totalIntakeMl: totalIntake,
      effectiveHydrationMl: effectiveHydration,
      logs: logs,
      totalCaffeineMg: totalCaffeine,
      alcoholicDrinksCount: alcoholCount,
      goalReached: goalReached,
      goalReachedAt: goalReachedAt,
      clearGoalReachedAt: goalReachedAt == null,
    );
  }

  // ============ ACHIEVEMENTS ============

  /// Get user achievements
  static UserAchievements getAchievements() {
    return _achievements;
  }

  // ---- Achievements <-> Drift mapping / persistence ----------------------
  static UserAchievements _achievementsFromRow(db.WaterAchievement r) {
    List<WaterAchievement>? achs;
    final rawAchs = r.achievementsJson;
    if (rawAchs != null && rawAchs.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAchs);
        if (decoded is List) {
          achs = decoded
              .whereType<Map<String, dynamic>>()
              .map(WaterAchievement.fromJson)
              .toList();
        }
      } catch (_) {}
    }
    List<String>? bevUsed;
    final rawBev = r.beverageTypesUsedJson;
    if (rawBev != null && rawBev.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBev);
        if (decoded is List) bevUsed = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return UserAchievements(
      id: r.id,
      achievements: achs,
      totalPoints: r.totalPoints,
      currentStreak: r.currentStreak,
      longestStreak: r.longestStreak,
      totalDrinks: r.totalDrinks,
      totalMl: r.totalMl,
      beverageTypesUsed: bevUsed,
      daysGoalMet: r.daysGoalMet,
      lastGoalMetDate: r.lastGoalMetDate,
      caffeineFreeDays: r.caffeineFreeDays,
      alcoholFreeDays: r.alcoholFreeDays,
      earlyMorningDrinks: r.earlyMorningDrinks,
    );
  }

  static Future<void> _persistAchievements() async {
    try {
      await _dao.saveAchievements(db.WaterAchievementsCompanion(
        id: const Value('user'),
        totalDrinks: Value(_achievements.totalDrinks),
        totalMl: Value(_achievements.totalMl),
        currentStreak: Value(_achievements.currentStreak),
        longestStreak: Value(_achievements.longestStreak),
        daysGoalMet: Value(_achievements.daysGoalMet),
        lastGoalMetDate: Value(_achievements.lastGoalMetDate),
        earlyMorningDrinks: Value(_achievements.earlyMorningDrinks),
        caffeineFreeDays: Value(_achievements.caffeineFreeDays),
        alcoholFreeDays: Value(_achievements.alcoholFreeDays),
        totalPoints: Value(_achievements.totalPoints),
        beverageTypesUsedJson:
            Value(jsonEncode(_achievements.beverageTypesUsed)),
        achievementsJson: Value(jsonEncode(
            _achievements.achievements.map((a) => a.toJson()).toList())),
      ));
    } catch (e) {
      debugPrint('⚠️ persist achievements failed: $e');
    }
  }

  /// Newly-unlocked achievements from the most recent log, buffered so a
  /// dashboard can pick them up and show a celebratory toast.
  static List<WaterAchievement> _lastNewlyUnlocked = [];

  /// Consume (read + clear) achievements unlocked by the last water log.
  /// A dashboard calls this after [addWaterLog] to show a celebration toast.
  static List<WaterAchievement> consumeNewlyUnlockedAchievements() {
    final unlocked = _lastNewlyUnlocked;
    _lastNewlyUnlocked = [];
    return unlocked;
  }

  /// Update achievements based on activity. Re-evaluates all achievements from
  /// persisted daily data and returns any that were newly unlocked.
  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Lifetime day aggregates, keyed by the day's `yyyy-MM-dd` id.
  ///
  /// A `SplayTreeMap` because [_computeLongestRun] and [_goalReachedDays] both
  /// want the rows in date order, and the id's zero-padded `yyyy-MM-dd` sorts
  /// lexicographically into exactly that — the same order
  /// [WaterDao.lifetimeDayAggregates]'s `ORDER BY d.date ASC` produces.
  ///
  /// Null means "not loaded" and triggers one whole-table read. It used to be
  /// read on EVERY write: each "+" ran `lifetimeDayAggregates()`, a full scan
  /// of `daily_water_data` with two correlated subqueries per row, before the
  /// Undo toast could appear. The write path already holds the updated day, so
  /// the snapshot is patched instead ([_patchAggregate], called from
  /// [_persistDay] and [restoreDayWithLogs] — every path that writes a day row).
  static SplayTreeMap<String, WaterDayAggregate>? _aggregates;

  /// Local hour before which a drink counts as an "early" one. Must match the
  /// `earlyDrinkBeforeHour` default [WaterDao.lifetimeDayAggregates] applies,
  /// or a patched day would disagree with a re-read one.
  static const int _earlyDrinkBeforeHour = 7;

  /// [d] as the engines see it — the in-memory equivalent of one
  /// `lifetimeDayAggregates` row.
  static WaterDayAggregate _aggregateOf(DailyWaterData d) => WaterDayAggregate(
        date: d.date,
        totalIntakeMl: d.totalIntakeMl,
        effectiveHydrationMl: d.effectiveHydrationMl,
        dailyGoalMl: d.dailyGoalMl,
        goalReached: d.goalReached,
        totalCaffeineMg: d.totalCaffeineMg,
        alcoholicDrinksCount: d.alcoholicDrinksCount,
        logCount: d.logs.length,
        earlyLogCount:
            d.logs.where((l) => l.time.hour < _earlyDrinkBeforeHour).length,
      );

  /// Fold a just-written day into the lifetime snapshot. No-op while the
  /// snapshot is unloaded — the next read builds it from the table anyway.
  ///
  /// Keyed by `_getDateKey(d.date)`, not by `d.id`, so it is the SAME
  /// derivation [_lifetimeAggregates] uses on the rows it reads back. The two
  /// agree for every day the app creates, but deriving the key twice different
  /// ways is how a patched day and a read one would end up as two entries for
  /// one date.
  static void _patchAggregate(DailyWaterData d) {
    _aggregates?[_getDateKey(d.date)] = _aggregateOf(d);
  }

  /// The lifetime snapshot, read from Drift once and patched on every write
  /// thereafter.
  static Future<List<WaterDayAggregate>> _lifetimeAggregates() async {
    final cached = _aggregates;
    if (cached != null) return cached.values.toList(growable: false);
    final rows = await _dao.lifetimeDayAggregates();
    _aggregates = SplayTreeMap<String, WaterDayAggregate>()
      ..addEntries(rows.map((r) => MapEntry(_getDateKey(r.date), r)));
    return rows;
  }

  /// Days whose hydration goal was reached, read from [aggregates] — the input
  /// to the shared, forgiving [StreakEngine].
  ///
  /// This used to fold the 90-day warm cache, which meant a long-running user's
  /// "longest streak" silently capped at 90 and their lifetime totals shrank as
  /// history aged out — and `_evaluateAchievements` then *persisted* the
  /// shrunken numbers over the good ones. It now reads the whole table via
  /// [WaterDao.lifetimeDayAggregates].
  static Set<DateTime> _goalReachedDays(List<WaterDayAggregate> aggregates) {
    final out = <DateTime>{};
    for (final d in aggregates) {
      if (d.goalReached) out.add(_dayOnly(d.date));
    }
    return out;
  }

  /// Forgiving streak (current + longest) via the shared [StreakEngine] — the
  /// same engine, and the same one-grace-day-per-rolling-week, that medicine
  /// and steps use. Replaces the old naive backward walk that hard-reset the
  /// streak to 0 on a single missed day. Today still only counts once its goal
  /// is reached (it may be in progress); the engine starts from yesterday when
  /// today isn't complete, so an unfinished today never breaks the run.
  static StreakResult _streakResult(List<WaterDayAggregate> aggregates) =>
      StreakEngine.compute(
        completedDays: _goalReachedDays(aggregates),
        today: clock.now(),
        graceDaysPerWeek: 1,
        // Days spent on vacation are neither completions nor misses.
        frozenDays: VacationMode.frozenDays(),
      );

  /// Longest run of consecutive calendar days satisfying [predicate], over the
  /// full persisted history.
  static int _computeLongestRun(
    List<WaterDayAggregate> aggregates,
    bool Function(WaterDayAggregate) predicate,
  ) {
    // [aggregates] already arrives ordered by date ascending (SQL ORDER BY).
    var longest = 0;
    var run = 0;
    DateTime? prevDay;
    for (final d in aggregates) {
      final day = _dayOnly(d.date);
      if (predicate(d)) {
        if (prevDay != null && calendarDaysBetween(prevDay, day) == 1) {
          run++;
        } else {
          run = 1;
        }
        if (run > longest) longest = run;
        prevDay = day;
      } else {
        run = 0;
        prevDay = null;
      }
    }
    return longest;
  }

  /// Recompute every achievement against **persisted** daily data, flip
  /// [WaterAchievement.isUnlocked], accumulate points, and persist. Returns the
  /// achievements that flipped from locked to unlocked in this pass.
  ///
  /// Whole-history, but over the [_lifetimeAggregates] snapshot: one row per
  /// day, read from the table on the first pass and patched in place by every
  /// write after it. Called from `init()` and from every write path, which is
  /// also what keeps [getCurrentStreak] (a synchronous read of the stored
  /// value) fresh.
  static Future<List<WaterAchievement>> _evaluateAchievements(
      {bool persist = true}) async {
    final List<WaterDayAggregate> days;
    try {
      days = await _lifetimeAggregates();
    } catch (e) {
      // A failed aggregate read must never overwrite good stored achievements
      // with zeros — that was the old init() failure mode.
      debugPrint('WaterService._evaluateAchievements: aggregate read failed: $e');
      return const [];
    }

    // Every beverage ever logged. These are the keys of the usage map, which
    // `_refreshUsage` has already built from the same table — so no separate
    // DISTINCT query, which matters because this runs before the first frame.
    final beverageTypes = _beverageUsage.keys.toSet();

    // ---- Aggregate metrics across all persisted days --------------------
    var totalMl = 0;
    var totalDrinks = 0;
    var daysGoalMet = 0;
    var overachieverDays = 0;
    var earlyMorningDays = 0;
    DateTime? lastGoalMetDate;

    for (final d in days) {
      totalMl += d.totalIntakeMl;
      totalDrinks += d.logCount;
      if (d.goalReached) {
        daysGoalMet++;
        if (lastGoalMetDate == null || d.date.isAfter(lastGoalMetDate)) {
          lastGoalMetDate = d.date;
        }
      }
      // "Overachiever" means 20% past the goal. Under a fluid restriction the
      // goal is a CEILING, so this would be a badge for exceeding a clinical
      // limit. Never award it in that mode.
      if (!_profile.isRestricted &&
          d.dailyGoalMl > 0 &&
          d.effectiveHydrationMl >= d.dailyGoalMl * 1.2) {
        overachieverDays++;
      }
      if (d.hasEarlyLog) earlyMorningDays++;
    }

    final streak = _streakResult(days);
    final currentStreak = streak.current;
    final longestStreak = streak.longest;
    final caffeineFreeRun = _computeLongestRun(
        days, (d) => d.hasLogs && d.totalCaffeineMg == 0);
    final alcoholFreeRun = _computeLongestRun(
        days, (d) => d.hasLogs && d.alcoholicDrinksCount == 0);

    // ---- Evaluate each achievement definition ---------------------------
    final prevById = {for (final a in _achievements.achievements) a.id: a};
    final newlyUnlocked = <WaterAchievement>[];
    final updated = <WaterAchievement>[];
    var totalPoints = 0;

    for (final def in WaterAchievement.allAchievements) {
      final prev = prevById[def.id];
      final wasUnlocked = prev?.isUnlocked ?? false;

      int currentValue;
      switch (def.type) {
        case AchievementType.streak:
        case AchievementType.perfectWeek:
        case AchievementType.perfectMonth:
          currentValue = longestStreak;
          break;
        case AchievementType.totalVolume:
          currentValue = totalMl;
          break;
        case AchievementType.variety:
          currentValue = beverageTypes.length;
          break;
        case AchievementType.earlyBird:
          currentValue = earlyMorningDays;
          break;
        case AchievementType.overachiever:
          currentValue = overachieverDays;
          break;
        case AchievementType.caffeineControl:
          currentValue = caffeineFreeRun;
          break;
        case AchievementType.socialDrinker:
          currentValue = alcoholFreeRun;
          break;
        case AchievementType.consistency:
        case AchievementType.nightOwl:
          currentValue = prev?.currentValue ?? 0;
          break;
      }

      final nowUnlocked = wasUnlocked || currentValue >= def.targetValue;
      final unlockedAt = wasUnlocked
          ? prev?.unlockedAt
          : (nowUnlocked ? clock.now() : null);

      final ach = def.copyWith(
        currentValue: currentValue,
        isUnlocked: nowUnlocked,
        unlockedAt: unlockedAt,
      );
      updated.add(ach);
      if (nowUnlocked) totalPoints += ach.points;
      if (nowUnlocked && !wasUnlocked) newlyUnlocked.add(ach);
    }

    _achievements = _achievements.copyWith(
      achievements: updated,
      totalPoints: totalPoints,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDrinks: totalDrinks,
      totalMl: totalMl,
      beverageTypesUsed: beverageTypes.toList(),
      daysGoalMet: daysGoalMet,
      lastGoalMetDate: lastGoalMetDate,
      caffeineFreeDays: caffeineFreeRun,
      alcoholFreeDays: alcoholFreeRun,
      earlyMorningDrinks: earlyMorningDays,
    );

    if (persist) await _persistAchievements();
    return newlyUnlocked;
  }

  /// Apply drinks the user logged from a water reminder's action button, or
  /// from the home-screen widget's quick-add.
  ///
  /// The notification action runs in a background isolate with no Drift, so it
  /// only queues the intent ([WaterActionQueue]); this is where it becomes a
  /// real log. Returns what was written, newest last, so the caller can report
  /// the true volume and offer an Undo that removes each drink FROM THE DAY IT
  /// WAS FILED UNDER — [at] is the tap time, which for a reminder answered at
  /// 23:30 and an app opened next morning is yesterday, not today.
  ///
  /// Only the entries that actually landed are acked, so a failure mid-way
  /// leaves the rest queued for the next resume instead of dropping them.
  /// True while a drain is in flight.
  ///
  /// The queue is now read-then-ack rather than read-and-clear, which fixed
  /// losing drinks on a failed write — but it also means the entries stay
  /// visible until they are acked, so two overlapping drains (AppShell drains
  /// on cold start AND on resume, and a resume can land while the first is
  /// still awaiting its DB writes) would each apply the same taps and log every
  /// drink twice.
  static bool _draining = false;

  static Future<List<AppliedWaterAction>> drainPendingWaterActions() async {
    if (_draining) return const [];
    _draining = true;
    try {
      return await _drainPendingWaterActions();
    } finally {
      _draining = false;
    }
  }

  static Future<List<AppliedWaterAction>> _drainPendingWaterActions() async {
    final pending = await WaterActionQueue.drain();
    if (pending.isEmpty) return const [];

    final beverage =
        getBeverage('water') ?? BeverageType.defaultBeverages.first;
    final applied = <AppliedWaterAction>[];
    for (final p in pending) {
      try {
        // Logged at the time the button was actually tapped, not at resume —
        // otherwise a drink taken at 9am shows up on the timeline at 6pm and
        // the pacing maths is wrong all day.
        final day = await addWaterLogForDate(
          date: p.at,
          amountMl: p.amountMl,
          beverage: beverage,
          time: p.at,
        );
        if (day.logs.isNotEmpty) {
          applied.add((id: day.logs.last.id, at: p.at, amountMl: p.amountMl));
        }
        // Acked one at a time, immediately: being killed half way through then
        // leaves the untouched entries queued and the written ones forgotten,
        // so a restart neither loses a drink nor logs one twice.
        await WaterActionQueue.ack([p]);
      } catch (e) {
        debugPrint('⚠️ applying queued water action failed: $e');
      }
    }
    return applied;
  }

  /// How much fluid was logged in the hour ending at [now].
  ///
  /// Input to the over-hydration guardrail. Uses raw [EnhancedWaterLog.amountMl]
  /// — the physiological load on the kidney is the volume swallowed, not our
  /// beverage-adjusted figure.
  static int intakeInLastHourMl({DateTime? now}) {
    final end = now ?? clock.now();
    final start = end.subtract(const Duration(hours: 1));
    // A window that straddles midnight has its earlier half in YESTERDAY's row.
    // Reading only the end day made the guard blind for the first hour after
    // midnight — precisely when someone drinking a litre in ten minutes at
    // 23:55 gets no warning at 00:05, which is the case it exists for.
    final days = <DailyWaterData>[];
    final endDay = getDataForDate(end);
    if (endDay != null) days.add(endDay);
    if (_getDateKey(start) != _getDateKey(end)) {
      final startDay = getDataForDate(start);
      if (startDay != null) days.add(startDay);
    }
    var sum = 0;
    for (final day in days) {
      for (final log in day.logs) {
        if (log.time.isAfter(start) && !log.time.isAfter(end)) {
          sum += log.amountMl;
        }
      }
    }
    return sum;
  }

  /// Whether the last hour's intake has passed the renal ceiling.
  ///
  /// Every app in this category, this one included, has been built on the
  /// assumption that more is always better. It is not: maximal free-water
  /// clearance is ~800–1000 mL/h, and drinking past it is how exercise-
  /// associated hyponatremia happens. IOM's stated reason for setting no
  /// Tolerable Upper Level on water is precisely that healthy kidneys handle
  /// "more than 0.7 L per hour" — an upper bound, quietly stated.
  ///
  /// WaterMinder is the only competitor that ships an alert for this. Nobody
  /// else warns at all, and our achievements actively rewarded drinking more.
  static bool isDrinkingTooFast({DateTime? now}) =>
      intakeInLastHourMl(now: now) >
      HydrationGoalCalculator.safeHourlyCeilingMl;

  /// The size of a typical drink for this user, in millilitres.
  ///
  /// Median of recent logs rather than mean, so one 1.5 L bottle does not drag
  /// the estimate. Falls back to 250 ml — the category's canonical serving and
  /// the value Samsung Health expects for one "glass".
  ///
  /// Used to decide HOW MANY reminders are actually needed to close the day's
  /// remaining deficit, which is what turns a fixed schedule into a pace-aware
  /// one.
  static int typicalDrinkMl({int sampleSize = 30}) {
    final amounts = <int>[];
    final days = _dailyWaterNotifier.value.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final d in days) {
      for (final l in d.logs.reversed) {
        if (l.amountMl > 0) amounts.add(l.amountMl);
        if (amounts.length >= sampleSize) break;
      }
      if (amounts.length >= sampleSize) break;
    }
    if (amounts.isEmpty) return 250;
    amounts.sort();
    return amounts[amounts.length ~/ 2];
  }

  /// Preference holding today's activity top-up as `day|deltaMl|activeKcal`.
  static const _activityNoteKey = 'water_activity_goal_note';

  /// What today's goal was raised by for measured activity, and why — or null
  /// when it was not raised (no health data, no activity beyond the usual, a
  /// custom goal or a fluid limit). Always for TODAY: a note from another day
  /// is ignored, so it can never explain a goal it did not produce.
  static ({int deltaMl, int activeKcal})? get todayActivityGoalNote {
    final raw = CleanStorageService.getAppPreference(_activityNoteKey, '');
    if (raw is! String) return null;
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0] != _getDateKey(clock.now())) return null;
    final delta = int.tryParse(parts[1]);
    final kcal = int.tryParse(parts[2]);
    if (delta == null || kcal == null || delta <= 0) return null;
    return (deltaMl: delta, activeKcal: kcal);
  }

  /// Stands in for the health store in tests, which have no platform channel.
  @visibleForTesting
  static Future<int?> Function()? activeKcalReaderForTesting;

  /// Today's measured active energy in kcal, or null when the health store has
  /// none (not connected, not permitted, nothing recorded yet).
  ///
  /// Read from the store directly. The steps module's own `activeCalories`
  /// falls back to an estimate derived from step count when there is no sensor
  /// figure, in the same field, and a goal raised by an estimate would be
  /// presented as if it were measured.
  static Future<int?> _measuredActiveKcalToday() async {
    final override = activeKcalReaderForTesting;
    if (override != null) return override();
    try {
      final now = clock.now();
      final kcal = await HealthDataService.instance
          .readActiveEnergy(DateTime(now.year, now.month, now.day), now);
      if (kcal == null || kcal <= 0) return null;
      return kcal.round();
    } catch (_) {
      return null;
    }
  }

  /// Refresh the weather reading and today's measured activity and, if the goal
  /// moved, re-stamp today with it. Kept under its old name for its callers.
  ///
  /// Historical days keep the goal they were created with — a past day must not
  /// silently become "missed" because today got hotter or more active.
  static Future<void> refreshWeatherGoal() => refreshDailyGoal();

  /// The goal for TODAY from weather and measured activity.
  ///
  /// Activity only ever RAISES the goal during the day, and never below what
  /// the profile's own activity level already gave: see
  /// [HydrationProfile.activityDeltaMl]. If an earlier refresh already added
  /// more than this one computes (a glitchy read, or the source changing), the
  /// larger top-up is kept.
  static Future<void> refreshDailyGoal() async {
    try {
      if (_profile.isRestricted) return; // a ceiling is not weather-dependent
      // A custom goal is an explicit user override, so neither the weather nor
      // activity gets to overwrite it. It did: someone who set 2000 ml and left
      // "adjust for the weather" on had their day silently re-stamped at ~3800
      // ml on a hot afternoon, and no screen offered any explanation.
      if (_profile.useCustomGoal) return;
      final weather = await HydrationWeatherService.current();
      final kcal = await _measuredActiveKcalToday();
      if (weather == null && kcal == null) return;

      // The hotter of now and today's forecast high, not the 7 am reading.
      final c = weather?.goalC;
      final base = _profile.goalBreakdown(ambientC: c).totalMl;
      final saved = todayActivityGoalNote;
      var delta = kcal == null
          ? 0
          : _profile.activityDeltaMl(activeKcal: kcal, ambientC: c);
      var shownKcal = kcal ?? 0;
      if (saved != null && saved.deltaMl > delta) {
        delta = saved.deltaMl;
        shownKcal = saved.activeKcal;
      }
      final goal = base + delta;

      final key = _getDateKey(clock.now());
      final note = delta > 0 ? '$key|$delta|$shownKcal' : '';
      final noteChanged =
          CleanStorageService.getAppPreference(_activityNoteKey, '') != note;
      if (noteChanged) {
        await CleanStorageService.setAppPreference(_activityNoteKey, note);
      }

      final today = await _ensureDayLoaded(key);
      if (today == null) return;
      if (today.dailyGoalMl == goal) {
        if (noteChanged) _notifyListeners();
        return;
      }
      final updated = _recalculateDailyData(
          today.copyWith(dailyGoalMl: goal), today.logs);
      _dailyWaterNotifier.value[key] = updated;
      _notifyListeners();
      await _persistDay(updated);
    } catch (e) {
      debugPrint('⚠️ daily goal refresh failed: $e');
    }
  }

  /// The user's real waking window, as minutes since midnight.
  ///
  /// Every [HydrationPacer.compute] call site used the function's default
  /// 07:00–23:00, so pacing was computed against a window nobody had agreed to:
  /// a night-shift worker was measured against office hours, and the profile's
  /// own `wakeUpHour`/`bedtimeHour` — which are persisted and round-tripped —
  /// were read by nothing.
  ///
  /// Resolution order matches `ReminderRescheduleService.rescheduleWaterReminders`
  /// so pacing and reminders can never disagree about when the user is awake:
  /// a real sleep average when there is enough history, then the stated sleep
  /// schedule, then the hydration profile's hours.
  static ({int wakeMinutes, int sleepMinutes}) wakingWindow() {
    try {
      final avg = SleepService.averageActualSchedule();
      if (avg != null) {
        return (
          wakeMinutes: avg.wakeHour * 60 + avg.wakeMinute,
          sleepMinutes: avg.bedHour * 60 + avg.bedMinute,
        );
      }
      final schedule = SleepService.getSchedule();
      return (
        wakeMinutes: schedule.wakeHour * 60 + schedule.wakeMinute,
        sleepMinutes: schedule.bedtimeHour * 60 + schedule.bedtimeMinute,
      );
    } catch (_) {
      final p = _profile;
      return (
        wakeMinutes: (p.wakeUpHour ?? 7) * 60,
        sleepMinutes: (p.bedtimeHour ?? 22) * 60,
      );
    }
  }

  /// The goal a given day should be JUDGED against.
  ///
  /// Every history surface used to divide by `getDailyGoal()` — TODAY's goal —
  /// so raising the goal on Friday retroactively rewrote Monday from "goal
  /// achieved" to 70%, and lowering it awarded goals that were never met. The
  /// day row already stores the goal that was in force (`dailyGoalMl`) and a
  /// persisted `goalReached` flag computed against it, which is why the
  /// statistics badge and the bars beside it could disagree on one screen.
  ///
  /// Falls back to today's goal only for a day with no row at all.
  static int goalForDay(DailyWaterData? day) {
    final stored = day?.dailyGoalMl ?? 0;
    return stored > 0 ? stored : getDailyGoal();
  }

  // ============ FLUID RESTRICTION ============

  /// True when the user is on a prescribed daily fluid ceiling rather than a
  /// target. See [HydrationProfile.fluidCeilingMl].
  static bool get isFluidRestricted => _profile.isRestricted;

  /// How much of the ceiling is left today. Negative once it is exceeded.
  ///
  /// Uses RAW intake, not the hydration-adjusted figure: a clinician's fluid
  /// limit is about the volume of liquid swallowed. Crediting a coffee at less
  /// than its volume, or letting a spirit's negative coefficient buy back
  /// headroom, would understate the load against a limit that exists for
  /// cardiac or renal reasons.
  static int fluidHeadroomMl({DateTime? on}) {
    final ceiling = _profile.fluidCeilingMl;
    if (ceiling == null || ceiling <= 0) return 0;
    final day = getDataForDate(on ?? clock.now());
    return ceiling - (day?.totalIntakeMl ?? 0);
  }

  /// Whether today's intake has passed the prescribed ceiling.
  static bool hasExceededFluidCeiling({DateTime? on}) =>
      isFluidRestricted && fluidHeadroomMl(on: on) < 0;

  // ============ BACKUP ============

  /// Every stored day, with its logs, read from Drift.
  ///
  /// Backup export used to snapshot `listenToDailyData()?.value` — the in-memory
  /// warm cache — so a backup silently contained only the last
  /// [warmCacheWindow] days no matter how long the person had been using the
  /// app. Restoring it then looked successful while quietly dropping years.
  static Future<List<DailyWaterData>> exportAllDaysForBackup() async {
    try {
      // A backup carries each day's tombstones too, so restoring it cannot
      // resurrect a drink the user deleted before taking it.
      await _ensureTombstonesLoaded();
      final rows = await _dao.getAllDailyData();
      if (rows.isEmpty) return const [];
      final byDay = await _dao.getLogsForDays(rows.map((r) => r.id).toList());
      return [
        for (final row in rows)
          _dailyFromRow(row, (byDay[row.id] ?? const []).map(_logFromRow).toList()),
      ];
    } catch (e) {
      debugPrint('⚠️ WaterService backup export failed: $e');
      return const [];
    }
  }

  /// Restore one day *and its per-drink logs*, as a single atomic replacement.
  ///
  /// [saveDailyData] persists only the day row, so restoring through it left
  /// every day's totals with no entries behind them — the day said "2,300 ml
  /// across 8 drinks" and the history screen showed nothing. Because a restore
  /// may run after `clearRestorableData()` has emptied the log table, this
  /// replaces the day's logs rather than merging.
  ///
  /// The replacement runs in ONE transaction because it is three writes —
  /// delete the logs, write the day row, re-insert the logs one by one — that
  /// are only correct together. Interrupted part-way (a failing row, a crash,
  /// the process being killed mid-restore) the old sequence left the day's
  /// totals standing over logs it had just deleted, and nothing ever repaired
  /// it: the next read saw a day claiming eight drinks with none behind it.
  /// A caller that gets an exception from here now knows the day is untouched.
  static Future<void> restoreDayWithLogs(DailyWaterData day) async {
    await _dao.transaction(() async {
      await _dao.deleteLogsForDay(day.id);
      // Deliberately not [_persistDay]: it swallows its own failures, which
      // inside a transaction means committing logs with no day row to match.
      await _dao.saveDailyData(_dayCompanion(day));
      for (final log in day.logs) {
        await _dao.upsertWaterLog(_logCompanion(day.id, log));
      }
    });
    // A backup and a cloud day both carry the drinks that were deleted from
    // them; adopting them here is what stops the merge resurrecting a drink
    // this device has never seen deleted.
    await _recordDeletedLogs(day.id, day.deletedLogIds);
    // Keep the in-memory view consistent with what was just written — after
    // the transaction, so a failed restore leaves the cache alone too. The
    // lifetime snapshot is patched here for the same reason [_persistDay] does
    // it: this is the one other path that writes a day row.
    _dailyWaterNotifier.value[day.id] = day;
    _patchAggregate(day);
    _notifyListeners();
  }

  /// Called once after a restore finishes, so favourites and achievements
  /// reflect the imported history instead of the pre-restore state.
  static Future<void> refreshAfterRestore() async {
    await _refreshUsage();
    await _evaluateAchievements();
  }

  /// Canonical `yyyy-MM-dd` key for [date]. Public because the cloud sync must
  /// address a day by exactly the same id the local store uses — it used to
  /// build its own `'${y}-${m}-${d}'`, which is unpadded, so August wrote
  /// `2026-8-21` where everything local expects `2026-08-21`. A day row created
  /// under the short key was unreachable by every reader in the app.
  static String dateKeyFor(DateTime date) => _getDateKey(date);

  /// Merge a day that came from the cloud into local history and return the
  /// result.
  ///
  /// The old sync was unconditional cloud-wins: if the cloud document existed,
  /// the local day was overwritten by it. Log four drinks on your phone while
  /// the cloud still held one, sync, and three were gone — and because it wrote
  /// through `saveDailyData`, whichever logs did survive were not persisted at
  /// all, only the totals.
  ///
  /// The merge is a union by log id, then a recompute of the totals from the
  /// merged set — never a copy of either side's totals, which is what let the
  /// two disagree. The union is the right shape for an append-mostly log and
  /// means concurrent drinks on two devices both survive.
  ///
  /// Deletion is the one thing a union cannot express, so it travels as a
  /// tombstone ([DailyWaterData.deletedLogIds]): the two sides' sets are
  /// unioned, every id in that union is dropped from BOTH copies' logs, and the
  /// union is carried into the merged day so it reaches the cloud — and from
  /// there the other device. Without it a deleted drink came back on the next
  /// launch even with a single device in play, because the cloud still held the
  /// copy uploaded before the delete.
  ///
  /// The local day's [DailyWaterData.dailyGoalMl] wins, because the goal follows
  /// the profile on this device.
  static Future<DailyWaterData> mergeCloudDay(DailyWaterData cloud) async {
    final key = cloud.id;
    await _ensureTombstonesLoaded();
    final local = await _ensureDayLoaded(key);

    final deleted = <String>{..._tombstonesFor(key), ...cloud.deletedLogIds};

    final byId = <String, EnhancedWaterLog>{};
    for (final l in local?.logs ?? const <EnhancedWaterLog>[]) {
      if (deleted.contains(l.id)) continue;
      byId[l.id] = l;
    }
    for (final l in cloud.logs) {
      if (deleted.contains(l.id)) continue;
      byId.putIfAbsent(l.id, () => l);
    }
    final merged = byId.values.toList()..sort((a, b) => a.time.compareTo(b.time));

    final base = (local ??
            DailyWaterData(
              id: key,
              date: cloud.date,
              dailyGoalMl: cloud.dailyGoalMl,
            ))
        .copyWith(deletedLogIds: deleted);
    final result = _recalculateDailyData(base, merged);

    await restoreDayWithLogs(result);
    await _refreshUsage();
    await _evaluateAchievements();
    return result;
  }

  // ============ STATISTICS ============

  /// Get weekly statistics
  static Map<String, dynamic> getWeeklyStats() {
    final now = clock.now();
    final weekStart = startOfWeek(now);
    final data = getDataForRange(weekStart, now);

    int totalMl = 0;
    int daysTracked = 0;
    int daysGoalMet = 0;
    int totalCaffeine = 0;
    int totalAlcohol = 0;

    for (final day in data) {
      totalMl += day.effectiveHydrationMl;
      daysTracked++;
      if (day.goalReached) daysGoalMet++;
      totalCaffeine += day.totalCaffeineMg;
      totalAlcohol += day.alcoholicDrinksCount;
    }

    return {
      'totalMl': totalMl,
      'averageMl': daysTracked > 0 ? (totalMl / daysTracked).round() : 0,
      'daysTracked': daysTracked,
      'daysGoalMet': daysGoalMet,
      'completionRate': daysTracked > 0 ? daysGoalMet / daysTracked : 0.0,
      'totalCaffeine': totalCaffeine,
      'totalAlcohol': totalAlcohol,
      'dailyData': data,
    };
  }

  /// Get monthly statistics
  static MonthlyWaterStats getMonthlyStats(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final data = getDataForRange(firstDay, lastDay);

    if (data.isEmpty) {
      return MonthlyWaterStats(year: year, month: month);
    }

    int totalMl = 0;
    int daysGoalMet = 0;
    int bestDay = 0;
    int worstDay = data.first.effectiveHydrationMl;
    int totalCaffeine = 0;
    int alcoholDrinks = 0;
    final beverageBreakdown = <String, int>{};

    for (final day in data) {
      totalMl += day.effectiveHydrationMl;
      if (day.goalReached) daysGoalMet++;
      if (day.effectiveHydrationMl > bestDay) bestDay = day.effectiveHydrationMl;
      if (day.effectiveHydrationMl < worstDay) worstDay = day.effectiveHydrationMl;
      totalCaffeine += day.totalCaffeineMg;
      alcoholDrinks += day.alcoholicDrinksCount;

      for (final log in day.logs) {
        beverageBreakdown[log.beverageId] =
            (beverageBreakdown[log.beverageId] ?? 0) + log.amountMl;
      }
    }

    final achievements = getAchievements();

    return MonthlyWaterStats(
      year: year,
      month: month,
      daysTracked: data.length,
      daysGoalMet: daysGoalMet,
      totalIntakeMl: totalMl,
      averageDailyMl: data.isNotEmpty ? (totalMl / data.length).round() : 0,
      bestDayMl: bestDay,
      worstDayMl: worstDay,
      totalCaffeineMg: totalCaffeine,
      alcoholicDrinksTotal: alcoholDrinks,
      beverageBreakdown: beverageBreakdown,
      currentStreak: achievements.currentStreak,
      longestStreak: achievements.longestStreak,
    );
  }

  /// Get current streak.
  ///
  /// Computed by the shared, forgiving [StreakEngine] over the WHOLE persisted
  /// history: consecutive goal-reached days ending at today, with one missed day
  /// forgiven per rolling week. Today may still be in progress, so it only adds
  /// to the streak once already reached; the streak otherwise counts from
  /// yesterday backwards.
  ///
  /// Returns the value stored by the last [_evaluateAchievements] pass rather
  /// than recomputing. That pass runs on `init()` and on every write, i.e. at
  /// every point the streak could have changed — and it reads Drift, so this is
  /// no longer capped by the 90-day warm cache the way the old recompute was.
  /// Keeping it synchronous matters: five UI call sites read it during build.
  static int getCurrentStreak() {
    return _achievements.currentStreak;
  }

  /// The full streak picture, including how many grace days are still in hand.
  ///
  /// Recomputed on demand rather than stored, because only `current`/`longest`
  /// are persisted on the achievements row — `gracesRemaining` (the shield the
  /// dashboard shows) is not. Still cheap: a walk over dates already in memory.
  ///
  /// The day set is the LIFETIME snapshot, not the 90-day warm cache it used to
  /// fold. [StreakEngine] stops walking at the earliest day it is given and
  /// treats everything before that as prehistory rather than as misses, so a
  /// truncated set both capped `current`/`longest` at the cache width and
  /// mis-reported the shield: a run whose break lies just outside the window
  /// looked like the start of history, and the grace day that had in fact
  /// already been spent was reported as still in hand.
  static StreakResult getStreakResult() => StreakEngine.compute(
        completedDays: _completedStreakDays(),
        today: clock.now(),
        graceDaysPerWeek: 1,
        // Days spent on vacation are neither completions nor misses.
        frozenDays: VacationMode.frozenDays(),
      );

  /// Goal-reached days for [getStreakResult].
  ///
  /// Falls back to the warm cache only while the lifetime snapshot is unloaded
  /// — i.e. before `init()` or after its aggregate read threw. Degrading to the
  /// old, capped answer beats showing a streak of zero to someone who has one.
  static Set<DateTime> _completedStreakDays() {
    final snapshot = _aggregates;
    if (snapshot != null) {
      return {
        for (final d in snapshot.values)
          if (d.goalReached) _dayOnly(d.date),
      };
    }
    return {
      for (final d in _dailyWaterNotifier.value.values)
        if (d.goalReached) _dayOnly(d.date),
    };
  }

  // ============ INSIGHTS ============

  /// Generate current insights
  static List<HydrationInsight> getInsights() {
    final todayData = getTodayData();
    final achievements = getAchievements();
    final weeklyStats = getWeeklyStats();

    return HydrationInsight.generateInsights(
      currentStreak: achievements.currentStreak,
      todayProgress: todayData.progress,
      caffeineToday: todayData.totalCaffeineMg,
      alcoholToday: todayData.alcoholicDrinksCount,
      hourOfDay: clock.now().hour,
      avgDailyMl: weeklyStats['averageMl'] as int,
      goalMl: todayData.dailyGoalMl,
      // Suppresses "Goal Achieved!" and the afternoon catch-up nudge when the
      // number is a ceiling rather than a target.
      isRestricted: _profile.isRestricted,
    );
  }

  // ============ EXPORT ============

  /// Whether [date] is inside the optional [start]..[end] export window,
  /// compared by calendar day so a time-of-day on either bound cannot clip the
  /// first or last day.
  static bool _inExportWindow(DateTime date, DateTime? start, DateTime? end) {
    final day = startOfDay(date);
    if (start != null && day.isBefore(startOfDay(start))) return false;
    if (end != null && day.isAfter(startOfDay(end))) return false;
    return true;
  }

  /// Export water data as CSV — every stored day, oldest first.
  ///
  /// Asynchronous, and read straight from Drift, because the sync readers see
  /// only [warmCacheWindow]. Both exports used to default to the last 30 days
  /// of the in-memory cache while the export sheet offered "Daily totals" and
  /// "All drink logs" and shared a file called `water-summary.csv` — so a
  /// two-year history exported as one month and nothing said so.
  ///
  /// [startDate] / [endDate] still narrow the window when a caller wants one;
  /// with neither, it is the whole history.
  static Future<String> exportToCsv(
      {DateTime? startDate, DateTime? endDate}) async {
    // One query for the day rows AND their log counts — the summary needs no
    // log bodies, and this is the same aggregate the achievements pass reads.
    final days = (await _dao.lifetimeDayAggregates())
        .where((d) => _inExportWindow(d.date, startDate, endDate));

    final buffer = StringBuffer();
    buffer.writeln('Date,Total Intake (ml),Effective Hydration (ml),Goal (ml),Progress %,Drinks Count,Caffeine (mg),Alcoholic Drinks');

    for (final day in days) {
      final progress =
          day.dailyGoalMl > 0 ? day.effectiveHydrationMl / day.dailyGoalMl : 0.0;
      buffer.writeln(
        '${_getDateKey(day.date)},${day.totalIntakeMl},${day.effectiveHydrationMl},${day.dailyGoalMl},'
        '${(progress * 100).toStringAsFixed(1)},${day.logCount},'
        '${day.totalCaffeineMg},${day.alcoholicDrinksCount}',
      );
    }

    return buffer.toString();
  }

  /// Export detailed log data — every drink ever logged, oldest day first.
  ///
  /// Same widening as [exportToCsv]; see its doc.
  static Future<String> exportDetailedCsv(
      {DateTime? startDate, DateTime? endDate}) async {
    final rows = (await _dao.getAllDailyData())
        .where((r) => _inExportWindow(r.date, startDate, endDate))
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Beverage,Amount (ml),Effective (ml),Hydration %,Caffeine (mg),Alcoholic,Note');

    // Chunked: `getLogsForDays` binds one SQLite variable per day id and the
    // limit is 999, so a long history cannot go in a single `IN (...)`.
    const chunkSize = 400;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.skip(i).take(chunkSize).toList();
      final byDay = await _dao.getLogsForDays(chunk.map((r) => r.id).toList());
      for (final row in chunk) {
        for (final log in byDay[row.id] ?? const []) {
          buffer.writeln(
            '${row.id},${log.time.hour}:${log.time.minute.toString().padLeft(2, '0')},'
            '${log.beverageName},${log.amountMl},${log.effectiveHydrationMl},'
            '${log.hydrationPercent},${log.caffeineAmount},${log.isAlcoholic},'
            '"${log.note ?? ''}"',
          );
        }
      }
    }

    return buffer.toString();
  }
  /// Clears all in-memory water state after a full data wipe.
  ///
  /// The Drift rows are removed by [CleanStorageService.clearAllPersistentData];
  /// this resets the reactive notifier and cached custom beverages/containers so
  /// the water UI drops to an empty state without needing an app restart.
  ///
  /// Also resets the profile and achievements: leaving them behind meant that
  /// after a wipe the UI still showed the old streak, points and unlocked
  /// badges, and the next write would persist those stale numbers back into the
  /// freshly emptied tables.
  static void clearInMemory() {
    _dailyWaterNotifier.value = {};
    // Emptied, and deliberately left marked as loaded: after a wipe there is
    // nothing for a tombstone to protect, so the row must not be read back in.
    // The row itself outlives the wipe — it lives in the key-value table, which
    // the wipe does not clear — but every id in it ages out of
    // [_persistDeletedLogIds]'s window, and points at a day that no longer
    // exists until it does.
    _deletedLogIds = {};
    _tombstonesLoaded = true;
    _customBeverages.clear();
    _customContainers.clear();
    _profile = HydrationProfile(id: 'profile', createdAt: clock.now());
    _achievements = UserAchievements(id: 'user');
    _beverageUsage = const {};
    _containerUsage = const {};
    // Dropped rather than emptied: null means "re-read the table", which is the
    // right answer whether the wipe emptied it or not.
    _aggregates = null;
  }

  /// Reset every piece of static state so one test cannot leak into the next.
  ///
  /// Previously this only flipped [_isInitialized], so the cached days, custom
  /// beverages, profile and — most misleadingly — the achievements survived
  /// between tests: a suite that seeded a streak in one test saw it in the next.
  /// The Drift rows themselves are the caller's business (tests hand the service
  /// a fresh in-memory database).
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    clearInMemory();
    _tombstonesLoaded = false;
    _lastNewlyUnlocked = [];
  }

  /// Recompute achievements on demand. Exists so tests can assert what a
  /// recompute does — including that a failed read does *not* overwrite good
  /// stored values with zeros.
  @visibleForTesting
  static Future<List<WaterAchievement>> evaluateAchievementsForTesting(
          {bool persist = true}) =>
      _evaluateAchievements(persist: persist);
}
