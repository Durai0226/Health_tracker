import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../models/hydration_profile.dart';
import '../models/water_achievement.dart';
import '../models/enhanced_water_log.dart';

/// Comprehensive water tracking service
/// Handles beverages, containers, achievements, statistics, and insights
class WaterService {
  static const String _dailyWaterBoxName = 'daily_water_data';
  static const String _beveragesBoxName = 'custom_beverages';
  static const String _containersBoxName = 'custom_containers';
  static const String _profileBoxName = 'hydration_profile';
  static const String _achievementsBoxName = 'water_achievements';
  static const String _prefsBoxName = 'water_prefs';

  static bool _isInitialized = false;
  static const _uuid = Uuid();

  // Boxes
  static Box<DailyWaterData>? _dailyWaterBox;
  static Box<BeverageType>? _beveragesBox;
  static Box<WaterContainer>? _containersBox;
  static Box<HydrationProfile>? _profileBox;
  static Box<UserAchievements>? _achievementsBox;
  static Box<dynamic>? _prefsBox;

  /// Expose value listenable for daily water data
  static ValueListenable<Box<DailyWaterData>>? listenToDailyData() {
    return _dailyWaterBox?.listenable();
  }

  /// Initialize the water service
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Open boxes - adapters are registered in storage_service
      _dailyWaterBox = await Hive.openBox<DailyWaterData>(_dailyWaterBoxName);
      _beveragesBox = await Hive.openBox<BeverageType>(_beveragesBoxName);
      _containersBox = await Hive.openBox<WaterContainer>(_containersBoxName);
      _profileBox = await Hive.openBox<HydrationProfile>(_profileBoxName);
      _achievementsBox = await Hive.openBox<UserAchievements>(_achievementsBoxName);
      _prefsBox = await Hive.openBox<dynamic>(_prefsBoxName);

      // Initialize default beverages if empty
      if (_beveragesBox!.isEmpty) {
        for (final beverage in BeverageType.defaultBeverages) {
          await _beveragesBox!.put(beverage.id, beverage);
        }
      }

      // Initialize default containers if empty
      if (_containersBox!.isEmpty) {
        for (final container in WaterContainer.defaultContainers) {
          await _containersBox!.put(container.id, container);
        }
      }

      // Initialize achievements if empty
      if (_achievementsBox!.isEmpty) {
        final userAchievements = UserAchievements(id: 'user');
        await _achievementsBox!.put('user', userAchievements);
      }

      _isInitialized = true;
      debugPrint('WaterService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing WaterService: $e');
    }
  }

  // ============ BEVERAGES ============

  /// Get all beverages (default + custom)
  static List<BeverageType> getAllBeverages() {
    return _beveragesBox?.values.toList() ?? BeverageType.defaultBeverages;
  }

  /// Get beverage by ID
  static BeverageType? getBeverage(String id) {
    return _beveragesBox?.get(id);
  }

  /// Add custom beverage
  static Future<void> addCustomBeverage(BeverageType beverage) async {
    if (_beveragesBox == null) {
      debugPrint('Error: WaterService not initialized when adding beverage');
      throw Exception('WaterService not initialized');
    }
    await _beveragesBox!.put(beverage.id, beverage);
  }

  /// Delete custom beverage (only non-default)
  static Future<void> deleteBeverage(String id) async {
    if (_beveragesBox == null) {
      debugPrint('Error: WaterService not initialized when deleting beverage');
      throw Exception('WaterService not initialized');
    }
    final beverage = _beveragesBox!.get(id);
    if (beverage != null && !beverage.isDefault) {
      await _beveragesBox!.delete(id);
    }
  }

  /// Get favorite beverages (most used)
  static List<BeverageType> getFavoriteBeverages({int limit = 6}) {
    final prefs = _prefsBox?.get('beverage_usage') as Map<dynamic, dynamic>? ?? {};
    final sorted = prefs.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    
    final favoriteIds = sorted.take(limit).map((e) => e.key.toString()).toList();
    return favoriteIds
        .map((id) => getBeverage(id))
        .where((b) => b != null)
        .cast<BeverageType>()
        .toList();
  }

  /// Track beverage usage
  static Future<void> _trackBeverageUsage(String beverageId) async {
    if (_prefsBox == null) return; // Silent return or throw? Since this is internal, maybe log.
    
    final usage = Map<String, int>.from(
      _prefsBox!.get('beverage_usage') as Map? ?? {},
    );
    usage[beverageId] = (usage[beverageId] ?? 0) + 1;
    await _prefsBox!.put('beverage_usage', usage);
  }

  // ============ CONTAINERS ============

  /// Get all containers
  static List<WaterContainer> getAllContainers() {
    return _containersBox?.values.toList() ?? WaterContainer.defaultContainers;
  }

  /// Get container by ID
  static WaterContainer? getContainer(String id) {
    return _containersBox?.get(id);
  }

  /// Add custom container
  static Future<void> addCustomContainer(WaterContainer container) async {
    if (_containersBox == null) {
      debugPrint('Error: WaterService not initialized when adding container');
      throw Exception('WaterService not initialized');
    }
    await _containersBox!.put(container.id, container);
  }

  /// Update container
  static Future<void> updateContainer(WaterContainer container) async {
    if (_containersBox == null) {
      debugPrint('Error: WaterService not initialized when updating container');
      throw Exception('WaterService not initialized');
    }
    await _containersBox!.put(container.id, container);
  }

  /// Delete custom container
  static Future<void> deleteContainer(String id) async {
    if (_containersBox == null) {
      debugPrint('Error: WaterService not initialized when deleting container');
      throw Exception('WaterService not initialized');
    }
    final container = _containersBox!.get(id);
    if (container != null && !container.isDefault) {
      await _containersBox!.delete(id);
    }
  }

  /// Get frequently used containers
  static List<WaterContainer> getFrequentContainers({int limit = 4}) {
    final containers = getAllContainers();
    containers.sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return containers.take(limit).toList();
  }

  // ============ HYDRATION PROFILE ============

  /// Get or create hydration profile
  static HydrationProfile getProfile() {
    return _profileBox?.get('profile') ?? HydrationProfile(
      id: 'profile',
      createdAt: DateTime.now(),
    );
  }

  /// Save hydration profile
  static Future<void> saveProfile(HydrationProfile profile) async {
    if (_profileBox == null) {
      debugPrint('Error: WaterService not initialized when saving profile');
      throw Exception('WaterService not initialized');
    }
    await _profileBox!.put('profile', profile);
  }

  /// Get calculated daily goal
  static int getDailyGoal() {
    final profile = getProfile();
    return profile.effectiveGoalMl;
  }

  // ============ DAILY WATER DATA ============

  /// Get date key
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get today's water data
  static DailyWaterData getTodayData() {
    final key = _getDateKey(DateTime.now());
    return _dailyWaterBox?.get(key) ?? DailyWaterData(
      id: key,
      date: DateTime.now(),
      dailyGoalMl: getDailyGoal(),
    );
  }

  /// Get water data for a specific date
  static DailyWaterData? getDataForDate(DateTime date) {
    final key = _getDateKey(date);
    return _dailyWaterBox?.get(key);
  }

  /// Get water data for date range
  static List<DailyWaterData> getDataForRange(DateTime start, DateTime end) {
    final data = <DailyWaterData>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      final dayData = getDataForDate(current);
      if (dayData != null) {
        data.add(dayData);
      }
      current = current.add(const Duration(days: 1));
    }
    return data;
  }

  static Future<void> saveDailyData(DailyWaterData data) async {
    if (_dailyWaterBox == null) {
      debugPrint('Error: WaterService not initialized when saving daily data');
      throw Exception('WaterService not initialized');
    }
    final key = _getDateKey(data.date);
    await _dailyWaterBox!.put(key, data);
  }

  /// Add water log
  static Future<DailyWaterData> addWaterLog({
    required int amountMl,
    required BeverageType beverage,
    WaterContainer? container,
    String? note,
  }) async {
    if (_dailyWaterBox == null) {
      debugPrint('Error: WaterService not initialized when adding water log');
      throw Exception('WaterService not initialized');
    }
    
    final now = DateTime.now();
    final key = _getDateKey(now);
    var todayData = _dailyWaterBox!.get(key) ?? DailyWaterData(
      id: key,
      date: now,
      dailyGoalMl: getDailyGoal(),
    );

    // Calculate effective hydration
    final effectiveHydration = beverage.getEffectiveHydration(amountMl);
    final caffeineAmount = beverage.hasCaffeine
        ? (amountMl * beverage.caffeinePerMl / 100).round()
        : 0;

    // Create log entry
    final log = EnhancedWaterLog(
      id: _uuid.v4(),
      time: now,
      amountMl: amountMl,
      effectiveHydrationMl: effectiveHydration,
      beverageId: beverage.id,
      beverageName: beverage.name,
      beverageEmoji: beverage.emoji,
      hydrationPercent: beverage.hydrationPercent,
      containerId: container?.id,
      containerName: container?.name,
      caffeineAmount: caffeineAmount,
      isAlcoholic: beverage.isAlcoholic,
      note: note,
    );

    // Check if goal was just reached
    final wasGoalMet = todayData.goalReached;
    final newEffectiveHydration = todayData.effectiveHydrationMl + effectiveHydration;
    final isGoalNowMet = newEffectiveHydration >= todayData.dailyGoalMl;

    // Update today's data
    todayData = todayData.copyWith(
      totalIntakeMl: todayData.totalIntakeMl + amountMl,
      effectiveHydrationMl: newEffectiveHydration,
      logs: [...todayData.logs, log],
      totalCaffeineMg: todayData.totalCaffeineMg + caffeineAmount,
      alcoholicDrinksCount: todayData.alcoholicDrinksCount + (beverage.isAlcoholic ? 1 : 0),
      goalReached: isGoalNowMet,
      goalReachedAt: (!wasGoalMet && isGoalNowMet) ? now : todayData.goalReachedAt,
    );

    await _dailyWaterBox?.put(key, todayData);

    // Track beverage usage
    await _trackBeverageUsage(beverage.id);

    // Update container usage
    if (container != null) {
      final updated = container.copyWith(
        usageCount: container.usageCount + 1,
        lastUsed: now,
      );
      await updateContainer(updated);
    }

    // Update achievements
    await _updateAchievements(todayData, beverage, now);

    return todayData;
  }

  /// Remove water log
  static Future<void> removeWaterLog(String logId) async {
    if (_dailyWaterBox == null) {
      debugPrint('Error: WaterService not initialized when removing water log');
      throw Exception('WaterService not initialized');
    }
    
    final key = _getDateKey(DateTime.now());
    var todayData = _dailyWaterBox!.get(key);
    if (todayData == null) return;

    final logIndex = todayData.logs.indexWhere((l) => l.id == logId);
    if (logIndex == -1) return;

    final log = todayData.logs[logIndex];
    final newLogs = [...todayData.logs]..removeAt(logIndex);

    todayData = todayData.copyWith(
      totalIntakeMl: todayData.totalIntakeMl - log.amountMl,
      effectiveHydrationMl: todayData.effectiveHydrationMl - log.effectiveHydrationMl,
      logs: newLogs,
      totalCaffeineMg: todayData.totalCaffeineMg - log.caffeineAmount,
      alcoholicDrinksCount: todayData.alcoholicDrinksCount - (log.isAlcoholic ? 1 : 0),
    );

    await _dailyWaterBox?.put(key, todayData);
  }

  /// Remove water log for a specific date
  static Future<void> removeWaterLogForDate(DateTime date, String logId) async {
    if (_dailyWaterBox == null) {
      debugPrint('Error: WaterService not initialized when removing water log for date');
      throw Exception('WaterService not initialized');
    }
    
    final key = _getDateKey(date);
    var dayData = _dailyWaterBox!.get(key);
    if (dayData == null) return;

    final logIndex = dayData.logs.indexWhere((l) => l.id == logId);
    if (logIndex == -1) return;

    final log = dayData.logs[logIndex];
    final newLogs = [...dayData.logs]..removeAt(logIndex);

    dayData = dayData.copyWith(
      totalIntakeMl: dayData.totalIntakeMl - log.amountMl,
      effectiveHydrationMl: dayData.effectiveHydrationMl - log.effectiveHydrationMl,
      logs: newLogs,
      totalCaffeineMg: dayData.totalCaffeineMg - log.caffeineAmount,
      alcoholicDrinksCount: dayData.alcoholicDrinksCount - (log.isAlcoholic ? 1 : 0),
    );

    await _dailyWaterBox?.put(key, dayData);
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
    if (_dailyWaterBox == null) {
      debugPrint('Error: WaterService not initialized when adding water log for date');
      throw Exception('WaterService not initialized');
    }
    
    final key = _getDateKey(date);
    final logTime = time ?? date;
    var dayData = _dailyWaterBox!.get(key) ?? DailyWaterData(
      id: key,
      date: date,
      dailyGoalMl: getDailyGoal(),
    );

    // Calculate effective hydration
    final effectiveHydration = beverage.getEffectiveHydration(amountMl);
    final caffeineAmount = beverage.hasCaffeine
        ? (amountMl * beverage.caffeinePerMl / 100).round()
        : 0;

    // Create log entry
    final log = EnhancedWaterLog(
      id: _uuid.v4(),
      time: logTime,
      amountMl: amountMl,
      effectiveHydrationMl: effectiveHydration,
      beverageId: beverage.id,
      beverageName: beverage.name,
      beverageEmoji: beverage.emoji,
      hydrationPercent: beverage.hydrationPercent,
      containerId: container?.id,
      containerName: container?.name,
      caffeineAmount: caffeineAmount,
      isAlcoholic: beverage.isAlcoholic,
      note: note,
    );

    // Check if goal was just reached
    final wasGoalMet = dayData.goalReached;
    final newEffectiveHydration = dayData.effectiveHydrationMl + effectiveHydration;
    final isGoalNowMet = newEffectiveHydration >= dayData.dailyGoalMl;

    // Sort logs by time
    final newLogs = [...dayData.logs, log];
    newLogs.sort((a, b) => a.time.compareTo(b.time));

    // Update day data
    dayData = dayData.copyWith(
      totalIntakeMl: dayData.totalIntakeMl + amountMl,
      effectiveHydrationMl: newEffectiveHydration,
      logs: newLogs,
      totalCaffeineMg: dayData.totalCaffeineMg + caffeineAmount,
      alcoholicDrinksCount: dayData.alcoholicDrinksCount + (beverage.isAlcoholic ? 1 : 0),
      goalReached: isGoalNowMet,
      goalReachedAt: (!wasGoalMet && isGoalNowMet) ? logTime : dayData.goalReachedAt,
    );

    await _dailyWaterBox?.put(key, dayData);

    return dayData;
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
    if (_dailyWaterBox == null) {
      debugPrint('Error: WaterService not initialized when updating water log for date');
      throw Exception('WaterService not initialized');
    }
    
    final key = _getDateKey(date);
    var dayData = _dailyWaterBox!.get(key);
    if (dayData == null) {
      throw Exception('No data for this date');
    }

    final logIndex = dayData.logs.indexWhere((l) => l.id == logId);
    if (logIndex == -1) {
      throw Exception('Log not found');
    }

    final oldLog = dayData.logs[logIndex];
    final logTime = time ?? oldLog.time;

    // Calculate new values
    final effectiveHydration = beverage.getEffectiveHydration(amountMl);
    final caffeineAmount = beverage.hasCaffeine
        ? (amountMl * beverage.caffeinePerMl / 100).round()
        : 0;

    // Create updated log entry
    final updatedLog = EnhancedWaterLog(
      id: logId,
      time: logTime,
      amountMl: amountMl,
      effectiveHydrationMl: effectiveHydration,
      beverageId: beverage.id,
      beverageName: beverage.name,
      beverageEmoji: beverage.emoji,
      hydrationPercent: beverage.hydrationPercent,
      containerId: container?.id,
      containerName: container?.name,
      caffeineAmount: caffeineAmount,
      isAlcoholic: beverage.isAlcoholic,
      note: note,
    );

    // Calculate deltas
    final deltaIntake = amountMl - oldLog.amountMl;
    final deltaEffective = effectiveHydration - oldLog.effectiveHydrationMl;
    final deltaCaffeine = caffeineAmount - oldLog.caffeineAmount;
    final deltaAlcohol = (beverage.isAlcoholic ? 1 : 0) - (oldLog.isAlcoholic ? 1 : 0);

    // Update logs list
    final newLogs = [...dayData.logs];
    newLogs[logIndex] = updatedLog;
    newLogs.sort((a, b) => a.time.compareTo(b.time));

    // Update totals
    final newEffectiveHydration = dayData.effectiveHydrationMl + deltaEffective;
    final isGoalNowMet = newEffectiveHydration >= dayData.dailyGoalMl;

    dayData = dayData.copyWith(
      totalIntakeMl: dayData.totalIntakeMl + deltaIntake,
      effectiveHydrationMl: newEffectiveHydration,
      logs: newLogs,
      totalCaffeineMg: dayData.totalCaffeineMg + deltaCaffeine,
      alcoholicDrinksCount: dayData.alcoholicDrinksCount + deltaAlcohol,
      goalReached: isGoalNowMet,
    );

    await _dailyWaterBox?.put(key, dayData);

    return dayData;
  }

  // ============ ACHIEVEMENTS ============

  /// Get user achievements
  static UserAchievements getAchievements() {
    return _achievementsBox?.get('user') ?? UserAchievements(id: 'user');
  }

  /// Update achievements based on activity
  static Future<List<WaterAchievement>> _updateAchievements(
    DailyWaterData todayData,
    BeverageType beverage,
    DateTime now,
  ) async {
    if (_achievementsBox == null) return []; // Silent return or throw? Internal method.
    
    var userAchievements = getAchievements();
    final newlyUnlocked = <WaterAchievement>[];

    // Update stats
    final isEarlyMorning = now.hour < 7;
    final lastGoalDate = userAchievements.lastGoalMetDate;
    final isConsecutiveDay = lastGoalDate != null &&
        DateTime(now.year, now.month, now.day)
                .difference(DateTime(lastGoalDate.year, lastGoalDate.month, lastGoalDate.day))
                .inDays ==
            1;

    // Update streak
    int newStreak = userAchievements.currentStreak;
    if (todayData.goalReached) {
      if (isConsecutiveDay || lastGoalDate == null) {
        newStreak = userAchievements.currentStreak + 1;
      } else {
        newStreak = 1;
      }
    }

    // Update beverage types used
    final beverageTypes = List<String>.from(userAchievements.beverageTypesUsed);
    if (!beverageTypes.contains(beverage.id)) {
      beverageTypes.add(beverage.id);
    }

    userAchievements = userAchievements.copyWith(
      totalDrinks: userAchievements.totalDrinks + 1,
      totalMl: userAchievements.totalMl + todayData.logs.last.amountMl,
      beverageTypesUsed: beverageTypes,
      currentStreak: newStreak,
      longestStreak: newStreak > userAchievements.longestStreak
          ? newStreak
          : userAchievements.longestStreak,
      daysGoalMet: todayData.goalReached
          ? userAchievements.daysGoalMet + 1
          : userAchievements.daysGoalMet,
      lastGoalMetDate: todayData.goalReached ? now : userAchievements.lastGoalMetDate,
      earlyMorningDrinks: isEarlyMorning
          ? userAchievements.earlyMorningDrinks + 1
          : userAchievements.earlyMorningDrinks,
      caffeineFreeDays: beverage.hasCaffeine ? 0 : userAchievements.caffeineFreeDays,
      alcoholFreeDays: beverage.isAlcoholic ? 0 : userAchievements.alcoholFreeDays,
    );

    // Check each achievement
    final updatedAchievements = <WaterAchievement>[];
    for (final achievement in userAchievements.achievements) {
      if (achievement.isUnlocked) {
        updatedAchievements.add(achievement);
        continue;
      }

      int currentValue = 0;
      switch (achievement.type) {
        case AchievementType.streak:
          currentValue = newStreak;
          break;
        case AchievementType.totalVolume:
          currentValue = userAchievements.totalMl;
          break;
        case AchievementType.variety:
          currentValue = beverageTypes.length;
          break;
        case AchievementType.earlyBird:
          currentValue = userAchievements.earlyMorningDrinks;
          break;
        case AchievementType.caffeineControl:
          currentValue = userAchievements.caffeineFreeDays;
          break;
        case AchievementType.socialDrinker:
          currentValue = userAchievements.alcoholFreeDays;
          break;
        default:
          currentValue = achievement.currentValue;
      }

      final isNowUnlocked = currentValue >= achievement.targetValue;
      final updated = achievement.copyWith(
        currentValue: currentValue,
        isUnlocked: isNowUnlocked,
        unlockedAt: isNowUnlocked && !achievement.isUnlocked ? now : null,
      );

      if (isNowUnlocked && !achievement.isUnlocked) {
        newlyUnlocked.add(updated);
      }

      updatedAchievements.add(updated);
    }

    // Calculate total points
    int totalPoints = 0;
    for (final a in updatedAchievements) {
      if (a.isUnlocked) totalPoints += a.points;
    }

    userAchievements = userAchievements.copyWith(
      achievements: updatedAchievements,
      totalPoints: totalPoints,
    );

    await _achievementsBox?.put('user', userAchievements);

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
    _dailyWaterBox = null;
    _beveragesBox = null;
    _containersBox = null;
    _profileBox = null;
    _achievementsBox = null;
    _prefsBox = null;
  }
}
