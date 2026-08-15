import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/water_dao.dart';
import '../../../core/health/streak_engine.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../models/hydration_profile.dart';
import '../models/water_achievement.dart';
import '../models/enhanced_water_log.dart';

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
  static HydrationProfile _profile = HydrationProfile(id: 'profile', createdAt: DateTime.now());
  static UserAchievements _achievements = UserAchievements(id: 'user');

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
      final now = DateTime.now();
      final rows = await _dao.getDataForRange(
        now.subtract(warmCacheWindow),
        now.add(const Duration(days: 1)),
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
    );
  }

  static Future<void> _persistDay(DailyWaterData d) async {
    try {
      await _dao.saveDailyData(db.DailyWaterDataTableCompanion(
        id: Value(d.id),
        date: Value(d.date),
        dailyGoalMl: Value(d.dailyGoalMl),
        totalIntakeMl: Value(d.totalIntakeMl),
        effectiveHydrationMl: Value(d.effectiveHydrationMl),
        totalCaffeineMg: Value(d.totalCaffeineMg),
        alcoholicDrinksCount: Value(d.alcoholicDrinksCount),
        goalReached: Value(d.goalReached),
        goalReachedAt: Value(d.goalReachedAt),
      ));
    } catch (e) {
      debugPrint('⚠️ persist day failed: $e');
    }
  }

  static Future<void> _persistLog(String dayId, EnhancedWaterLog l) async {
    try {
      await _dao.addWaterLog(db.EnhancedWaterLogsCompanion(
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
      ));
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
        createdAt: Value(p.createdAt ?? DateTime.now()),
        updatedAt: Value(p.updatedAt ?? DateTime.now()),
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
  static List<BeverageType> getFavoriteBeverages({int limit = 6}) {
    return getAllBeverages().take(limit).toList();
  }

  /// Track beverage usage
  static Future<void> _trackBeverageUsage(String beverageId) async {
    // Track usage for favorites calculation
  }

  // ============ CONTAINERS ============

  /// Get all containers
  static List<WaterContainer> getAllContainers() {
    return [...WaterContainer.defaultContainers, ..._customContainers];
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
  static List<WaterContainer> getFrequentContainers({int limit = 4}) {
    return getAllContainers().take(limit).toList();
  }

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
    final key = _getDateKey(DateTime.now());
    final newGoal = profile.effectiveGoalMl;
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
        DailyWaterData(id: key, date: DateTime.now(), dailyGoalMl: newGoal),
      );
    }
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
    final key = _getDateKey(DateTime.now());
    if (!_dailyWaterNotifier.value.containsKey(key)) {
      _dailyWaterNotifier.value[key] = DailyWaterData(
        id: key,
        date: DateTime.now(),
        dailyGoalMl: getDailyGoal(),
      );
    }
    return _dailyWaterNotifier.value[key]!;
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
      final to = DateTime(end.year, end.month, end.day)
          .add(const Duration(days: 1));
      final rows = await _dao.getDataForRange(from, to);
      var loadedAny = false;
      for (final row in rows) {
        if (_dailyWaterNotifier.value.containsKey(row.id)) continue;
        final logRows = await _dao.getLogsForDay(row.id);
        _dailyWaterNotifier.value[row.id] =
            _dailyFromRow(row, logRows.map(_logFromRow).toList());
        loadedAny = true;
      }
      if (loadedAny) _notifyListeners();
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
      current = current.add(const Duration(days: 1));
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
    final now = DateTime.now();
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
  static Future<void> removeWaterLog(String logId) async {
    await removeWaterLogForDate(DateTime.now(), logId);
  }

  /// Remove water log for a specific date
  static Future<void> removeWaterLogForDate(DateTime date, String logId) async {
    final key = _getDateKey(date);
    // Read the persisted day, not just the warm cache: an older day was seen as
    // null here, so the delete silently did nothing and left the log on disk.
    final data = await _ensureDayLoaded(key);
    if (data != null) {
      final updatedLogs = data.logs.where((l) => l.id != logId).toList();
      final updatedData = _recalculateDailyData(data, updatedLogs);
      _dailyWaterNotifier.value[key] = updatedData;
      _notifyListeners();
      await _dao.deleteWaterLog(logId);
      await _persistDay(updatedData);
      await _evaluateAchievements();
    }
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

    // Track usage and update achievements
    await _trackBeverageUsage(beverage.id);
    _lastNewlyUnlocked =
        await _updateAchievements(updatedData, beverage, effectiveTime);

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
      try {
        await _dao.updateWaterLog(db.EnhancedWaterLogsCompanion(
          id: Value(l.id),
          dailyDataId: Value(key),
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
        ));
      } catch (e) {
        debugPrint('⚠️ update log failed: $e');
      }
    }
    await _persistDay(updatedData);
    await _evaluateAchievements();

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

    final goalReached = effectiveHydration >= data.dailyGoalMl;
    final goalReachedAt = goalReached && !data.goalReached ? DateTime.now() : data.goalReachedAt;

    return data.copyWith(
      totalIntakeMl: totalIntake,
      effectiveHydrationMl: effectiveHydration,
      logs: logs,
      totalCaffeineMg: totalCaffeine,
      alcoholicDrinksCount: alcoholCount,
      goalReached: goalReached,
      goalReachedAt: goalReachedAt,
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
  static Future<List<WaterAchievement>> _updateAchievements(
    DailyWaterData todayData,
    BeverageType beverage,
    DateTime now,
  ) async {
    return _evaluateAchievements();
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Days (in persisted history) whose hydration goal was reached — the input
  /// to the shared, forgiving [StreakEngine].
  static Set<DateTime> _goalReachedDays() {
    final out = <DateTime>{};
    for (final d in _dailyWaterNotifier.value.values) {
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
  static StreakResult _streakResult() => StreakEngine.compute(
        completedDays: _goalReachedDays(),
        today: DateTime.now(),
        graceDaysPerWeek: 1,
      );

  /// Consecutive (grace-forgiven) goal-reached days ending at or just before
  /// today.
  static int _computeCurrentStreak() => _streakResult().current;

  /// Longest run of consecutive calendar days satisfying [predicate].
  static int _computeLongestRun(bool Function(DailyWaterData) predicate) {
    final entries = _dailyWaterNotifier.value.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    var longest = 0;
    var run = 0;
    DateTime? prevDay;
    for (final d in entries) {
      final day = _dayOnly(d.date);
      if (predicate(d)) {
        if (prevDay != null && day.difference(prevDay).inDays == 1) {
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

  /// Longest goal-reached run, from the same [StreakEngine] pass as the current
  /// streak so the two can never disagree (a forgiven current streak must not
  /// be able to exceed the "longest" it is part of).
  static int _computeLongestStreak() => _streakResult().longest;

  /// Recompute every achievement against persisted daily data, flip
  /// [WaterAchievement.isUnlocked], accumulate points, and persist. Returns the
  /// achievements that flipped from locked to unlocked in this pass.
  static Future<List<WaterAchievement>> _evaluateAchievements(
      {bool persist = true}) async {
    final days = _dailyWaterNotifier.value.values.toList();

    // ---- Aggregate metrics across all persisted days --------------------
    var totalMl = 0;
    var totalDrinks = 0;
    var daysGoalMet = 0;
    var overachieverDays = 0;
    final beverageTypes = <String>{};
    final earlyMorningDays = <String>{}; // distinct days with a pre-7AM drink
    DateTime? lastGoalMetDate;

    for (final d in days) {
      totalMl += d.totalIntakeMl;
      totalDrinks += d.logs.length;
      if (d.goalReached) {
        daysGoalMet++;
        if (lastGoalMetDate == null || d.date.isAfter(lastGoalMetDate)) {
          lastGoalMetDate = d.date;
        }
      }
      if (d.dailyGoalMl > 0 && d.effectiveHydrationMl >= d.dailyGoalMl * 1.2) {
        overachieverDays++;
      }
      for (final log in d.logs) {
        beverageTypes.add(log.beverageId);
        if (log.time.hour < 7) earlyMorningDays.add(d.id);
      }
    }

    final currentStreak = _computeCurrentStreak();
    final longestStreak = _computeLongestStreak();
    final caffeineFreeRun =
        _computeLongestRun((d) => d.logs.isNotEmpty && d.totalCaffeineMg == 0);
    final alcoholFreeRun = _computeLongestRun(
        (d) => d.logs.isNotEmpty && d.alcoholicDrinksCount == 0);

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
          currentValue = earlyMorningDays.length;
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
          : (nowUnlocked ? DateTime.now() : null);

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
      earlyMorningDrinks: earlyMorningDays.length,
    );

    if (persist) await _persistAchievements();
    return newlyUnlocked;
  }

  // ============ STATISTICS ============

  /// Get weekly statistics
  static Map<String, dynamic> getWeeklyStats() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
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
  /// Derived from persisted [DailyWaterData] (survives restart) and computed by
  /// the shared, forgiving [StreakEngine]: consecutive goal-reached days ending
  /// at today, with one missed day forgiven per rolling week. Today may still be
  /// in progress, so it only adds to the streak once already reached; the streak
  /// otherwise counts from yesterday backwards.
  static int getCurrentStreak() {
    return _computeCurrentStreak();
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
      hourOfDay: DateTime.now().hour,
      avgDailyMl: weeklyStats['averageMl'] as int,
      goalMl: todayData.dailyGoalMl,
    );
  }

  // ============ EXPORT ============

  /// Export water data as CSV
  static String exportToCsv({DateTime? startDate, DateTime? endDate}) {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();
    final data = getDataForRange(start, end);

    final buffer = StringBuffer();
    buffer.writeln('Date,Total Intake (ml),Effective Hydration (ml),Goal (ml),Progress %,Drinks Count,Caffeine (mg),Alcoholic Drinks');

    for (final day in data) {
      buffer.writeln(
        '${day.id},${day.totalIntakeMl},${day.effectiveHydrationMl},${day.dailyGoalMl},'
        '${(day.progress * 100).toStringAsFixed(1)},${day.drinksCount},'
        '${day.totalCaffeineMg},${day.alcoholicDrinksCount}',
      );
    }

    return buffer.toString();
  }

  /// Export detailed log data
  static String exportDetailedCsv({DateTime? startDate, DateTime? endDate}) {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();
    final data = getDataForRange(start, end);

    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Beverage,Amount (ml),Effective (ml),Hydration %,Caffeine (mg),Alcoholic,Note');

    for (final day in data) {
      for (final log in day.logs) {
        buffer.writeln(
          '${day.id},${log.time.hour}:${log.time.minute.toString().padLeft(2, '0')},'
          '${log.beverageName},${log.amountMl},${log.effectiveHydrationMl},'
          '${log.hydrationPercent},${log.caffeineAmount},${log.isAlcoholic},'
          '"${log.note ?? ''}"',
        );
      }
    }

    return buffer.toString();
  }
  /// Clears all in-memory water state after a full data wipe.
  ///
  /// The Drift rows are removed by [CleanStorageService.clearAllPersistentData];
  /// this resets the reactive notifier and cached custom beverages/containers so
  /// the water UI drops to an empty state without needing an app restart.
  static void clearInMemory() {
    _dailyWaterNotifier.value = {};
    _customBeverages.clear();
    _customContainers.clear();
  }

  /// Reset service state for testing
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    // TODO: Reset Drift storage state
  }
}
