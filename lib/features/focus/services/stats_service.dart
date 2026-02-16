import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../models/focus_session.dart';
import '../models/detailed_stats.dart';

class StatsService extends ChangeNotifier {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  List<DailyFocusStats> _dailyStats = [];
  ProductivityPattern? _productivityPattern;

  List<DailyFocusStats> get dailyStats => List.unmodifiable(_dailyStats);
  ProductivityPattern? get productivityPattern => _productivityPattern;

  Future<void> init() async {
    await _loadData();
    debugPrint('✓ StatsService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      final statsJson = prefs['focusDailyStats'];
      if (statsJson != null && statsJson is List) {
        _dailyStats = statsJson
            .map((s) => DailyFocusStats.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await StorageService.setAppPreference(
        'focusDailyStats',
        _dailyStats.take(365).map((s) => s.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving stats data: $e');
    }
  }

  Future<void> recordSession(FocusSession session) async {
    final date = DateTime(
      session.startedAt.year,
      session.startedAt.month,
      session.startedAt.day,
    );

    final existingIndex = _dailyStats.indexWhere((s) => 
        s.date.year == date.year && 
        s.date.month == date.month && 
        s.date.day == date.day);

    DailyFocusStats dayStats;
    
    if (existingIndex >= 0) {
      final existing = _dailyStats[existingIndex];
      final updatedActivities = Map<FocusActivityType, int>.from(existing.minutesByActivity);
      updatedActivities[session.activityType] = 
          (updatedActivities[session.activityType] ?? 0) + session.actualMinutes;

      dayStats = DailyFocusStats(
        date: date,
        totalMinutes: existing.totalMinutes + session.actualMinutes,
        sessionsCount: existing.sessionsCount + 1,
        completedSessions: existing.completedSessions + (session.wasCompleted ? 1 : 0),
        abandonedSessions: existing.abandonedSessions + (session.wasAbandoned ? 1 : 0),
        minutesByActivity: updatedActivities,
        minutesByTag: existing.minutesByTag,
        plantsGrown: existing.plantsGrown + (session.wasCompleted ? 1 : 0),
        plantsWithered: existing.plantsWithered + (session.wasAbandoned ? 1 : 0),
        coinsEarned: existing.coinsEarned + (session.wasCompleted ? session.actualMinutes * 2 : 0),
      );
      
      _dailyStats[existingIndex] = dayStats;
    } else {
      dayStats = DailyFocusStats(
        date: date,
        totalMinutes: session.actualMinutes,
        sessionsCount: 1,
        completedSessions: session.wasCompleted ? 1 : 0,
        abandonedSessions: session.wasAbandoned ? 1 : 0,
        minutesByActivity: {session.activityType: session.actualMinutes},
        plantsGrown: session.wasCompleted ? 1 : 0,
        plantsWithered: session.wasAbandoned ? 1 : 0,
        coinsEarned: session.wasCompleted ? session.actualMinutes * 2 : 0,
      );
      
      _dailyStats.add(dayStats);
      _dailyStats.sort((a, b) => b.date.compareTo(a.date));
    }

    await _saveData();
    notifyListeners();
  }

  void updateProductivityPattern(List<FocusSession> sessions) {
    _productivityPattern = ProductivityPattern.analyze(sessions);
    notifyListeners();
  }

  DailyFocusStats? getStatsForDate(DateTime date) {
    try {
      return _dailyStats.firstWhere((s) =>
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  DailyFocusStats getTodayStats() {
    final today = DateTime.now();
    return getStatsForDate(today) ?? DailyFocusStats(date: today);
  }

  WeeklyFocusStats getWeekStats({DateTime? weekStart}) {
    final start = weekStart ?? _getWeekStart(DateTime.now());
    return WeeklyFocusStats.calculate(_dailyStats, start);
  }

  WeeklyFocusStats getLastWeekStats() {
    final lastWeekStart = _getWeekStart(DateTime.now()).subtract(const Duration(days: 7));
    return WeeklyFocusStats.calculate(_dailyStats, lastWeekStart);
  }

  MonthlyFocusStats getMonthStats({int? year, int? month}) {
    final now = DateTime.now();
    return MonthlyFocusStats.calculate(
      _dailyStats,
      year ?? now.year,
      month ?? now.month,
    );
  }

  YearlyFocusStats getYearStats({int? year}) {
    return YearlyFocusStats.calculate(_dailyStats, year ?? DateTime.now().year);
  }

  List<DailyFocusStats> getStatsForRange(DateTime start, DateTime end) {
    return _dailyStats.where((s) =>
        !s.date.isBefore(start) && !s.date.isAfter(end)).toList();
  }

  List<DailyFocusStats> getLast7Days() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return getStatsForRange(weekAgo, now);
  }

  List<DailyFocusStats> getLast30Days() {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    return getStatsForRange(monthAgo, now);
  }

  List<WeeklyFocusStats> getLast4Weeks() {
    final List<WeeklyFocusStats> weeks = [];
    var weekStart = _getWeekStart(DateTime.now());
    
    for (int i = 0; i < 4; i++) {
      weeks.add(WeeklyFocusStats.calculate(_dailyStats, weekStart));
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    
    return weeks;
  }

  List<MonthlyFocusStats> getLast12Months() {
    final List<MonthlyFocusStats> months = [];
    var date = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      months.add(MonthlyFocusStats.calculate(_dailyStats, date.year, date.month));
      date = DateTime(date.year, date.month - 1, 1);
    }
    
    return months;
  }

  List<FocusInsight> getInsights() {
    final currentWeek = getWeekStats();
    final previousWeek = getLastWeekStats();
    final pattern = _productivityPattern;

    if (pattern == null) return [];

    final prefs = StorageService.getAppPreferences();
    final currentStreak = prefs['focusStats']?['currentStreak'] ?? 0;

    return InsightsGenerator.generate(
      currentWeek: currentWeek,
      previousWeek: previousWeek,
      pattern: pattern,
      currentStreak: currentStreak,
    );
  }

  Map<FocusActivityType, int> getActivityBreakdown(StatsPeriod period) {
    List<DailyFocusStats> relevantStats;
    
    switch (period) {
      case StatsPeriod.daily:
        relevantStats = [getTodayStats()];
        break;
      case StatsPeriod.weekly:
        relevantStats = getLast7Days();
        break;
      case StatsPeriod.monthly:
        relevantStats = getLast30Days();
        break;
      case StatsPeriod.yearly:
        relevantStats = _dailyStats.where((s) => s.date.year == DateTime.now().year).toList();
        break;
    }

    final breakdown = <FocusActivityType, int>{};
    for (final day in relevantStats) {
      day.minutesByActivity.forEach((activity, mins) {
        breakdown[activity] = (breakdown[activity] ?? 0) + mins;
      });
    }

    return breakdown;
  }

  int getTotalMinutes(StatsPeriod period) {
    switch (period) {
      case StatsPeriod.daily:
        return getTodayStats().totalMinutes;
      case StatsPeriod.weekly:
        return getWeekStats().totalMinutes;
      case StatsPeriod.monthly:
        return getMonthStats().totalMinutes;
      case StatsPeriod.yearly:
        return getYearStats().totalMinutes;
    }
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }
}
