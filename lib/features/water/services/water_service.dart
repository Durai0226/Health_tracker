import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/app_database.dart' as db;
import '../../../core/database/daos/water_dao.dart';
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

  /// Initialize the water service — loads persisted data from Drift.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final now = DateTime.now();
      final rows = await _dao.getDataForRange(
        now.subtract(const Duration(days: 90)),
        now.add(const Duration(days: 1)),
      );
      final map = <String, DailyWaterData>{};
      for (final row in rows) {
        final logRows = await _dao.getLogsForDay(row.id);
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

  /// Get water data for a specific date
  static DailyWaterData? getDataForDate(DateTime date) {
    final key = _getDateKey(date);
    return _dailyWaterNotifier.value[key];
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
    final data = _dailyWaterNotifier.value[key];
    if (data != null) {
      final updatedLogs = data.logs.where((l) => l.id != logId).toList();
      final updatedData = _recalculateDailyData(data, updatedLogs);
      _dailyWaterNotifier.value[key] = updatedData;
      _notifyListeners();
      await _dao.deleteWaterLog(logId);
      await _persistDay(updatedData);
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

    // Get or create daily data
    var data = _dailyWaterNotifier.value[key];
    if (data == null) {
      data = DailyWaterData(
        id: key,
        date: date,
        dailyGoalMl: getDailyGoal(),
      );
    }

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
    final data = _dailyWaterNotifier.value[key];
    
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
    final updatedLogs = data.logs.map((log) {
      if (log.id == logId) {
        return EnhancedWaterLog(
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
      }
      return log;
    }).toList();

    final updatedData = _recalculateDailyData(data, updatedLogs);
    _dailyWaterNotifier.value[key] = updatedData;
    _notifyListeners();
    
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

  /// Update achievements based on activity
  static Future<List<WaterAchievement>> _updateAchievements(
    DailyWaterData todayData,
    BeverageType beverage,
    DateTime now,
  ) async {
    final newlyUnlocked = <WaterAchievement>[];
    
    // Update streak if goal reached
    if (todayData.goalReached) {
      _achievements = _achievements.copyWith(
        currentStreak: _achievements.currentStreak + 1,
        longestStreak: (_achievements.currentStreak + 1) > _achievements.longestStreak 
            ? _achievements.currentStreak + 1 
            : _achievements.longestStreak,
      );
    }
    
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

  /// Get current streak
  static int getCurrentStreak() {
    return getAchievements().currentStreak;
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
  /// Reset service state for testing
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _isInitialized = false;
    // TODO: Reset Drift storage state
  }
}
