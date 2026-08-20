import 'package:flutter/foundation.dart';
import 'tag_service.dart';
import 'package:clock/clock.dart';
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

  /// Rebuilds the in-memory daily aggregates directly from [FocusService.sessions].
  ///
  /// This is the ONLY derivation of daily focus stats. There used to be a second
  /// one — an incremental `recordSession()` writing a `focusDailyStats` blob —
  /// which had no production caller, and whose async `_loadData()` raced this
  /// method to assign `_dailyStats`. Two sources of truth for the same number is
  /// how the header and the Statistics screen came to disagree about one day's
  /// streak, so the aggregate is now always recomputed and never stored.
  void buildFromSessions(List<FocusSession> sessions) {
    final Map<String, DailyFocusStats> byDay = {};

    for (final session in sessions) {
      final date = DateTime(
        session.startedAt.year,
        session.startedAt.month,
        session.startedAt.day,
      );
      final key = '${date.year}-${date.month}-${date.day}';

      final existing = byDay[key];
      if (existing == null) {
        byDay[key] = DailyFocusStats(
          date: date,
          // Completed minutes only — see DailyFocusStats.totalMinutes. Counting
          // abandoned time here is what made this screen disagree with the Focus
          // screen about the same day.
          totalMinutes: session.wasCompleted ? session.actualMinutes : 0,
          abandonedMinutes: session.wasAbandoned ? session.actualMinutes : 0,
          sessionsCount: 1,
          completedSessions: session.wasCompleted ? 1 : 0,
          abandonedSessions: session.wasAbandoned ? 1 : 0,
          minutesByActivity: {
            session.activityType:
                session.wasCompleted ? session.actualMinutes : 0
          },
          minutesByTag: _tagMinutes({}, session),
          plantsGrown: session.wasCompleted ? 1 : 0,
          plantsWithered: session.wasAbandoned ? 1 : 0,
          coinsEarned: session.wasCompleted ? session.actualMinutes * 2 : 0,
        );
      } else {
        final activities =
            Map<FocusActivityType, int>.from(existing.minutesByActivity);
        activities[session.activityType] =
            (activities[session.activityType] ?? 0) +
                (session.wasCompleted ? session.actualMinutes : 0);

        byDay[key] = DailyFocusStats(
          date: date,
          totalMinutes: existing.totalMinutes +
              (session.wasCompleted ? session.actualMinutes : 0),
          abandonedMinutes: existing.abandonedMinutes +
              (session.wasAbandoned ? session.actualMinutes : 0),
          sessionsCount: existing.sessionsCount + 1,
          completedSessions:
              existing.completedSessions + (session.wasCompleted ? 1 : 0),
          abandonedSessions:
              existing.abandonedSessions + (session.wasAbandoned ? 1 : 0),
          minutesByActivity: activities,
          minutesByTag: _tagMinutes(existing.minutesByTag, session),
          plantsGrown: existing.plantsGrown + (session.wasCompleted ? 1 : 0),
          plantsWithered:
              existing.plantsWithered + (session.wasAbandoned ? 1 : 0),
          coinsEarned: existing.coinsEarned +
              (session.wasCompleted ? session.actualMinutes * 2 : 0),
        );
      }
    }

    _dailyStats = byDay.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  /// Tag minutes for a session, skipping tags that no longer exist.
  ///
  /// `TagService.deleteTag` scrubs its own `_sessionTags` map but cannot scrub the
  /// `tagIds` list copied onto each `FocusSession` — that is history, and rewriting
  /// it would be a lie about what the session was tagged at the time. So the
  /// breakdown filtered nothing and happily rendered a deleted tag's id as a row,
  /// attributing minutes to a tag the user had removed.
  ///
  /// Filtering here keeps the history honest and the UI correct, and it also
  /// covers any other source of an unknown id (a restored backup from a build with
  /// different tags, for instance).
  ///
  /// Minutes are completed-only, matching `DailyFocusStats.totalMinutes`, so the
  /// per-tag rows sum to the day's headline instead of exceeding it.
  Map<String, int> _tagMinutes(Map<String, int> base, FocusSession session) {
    if (session.tagIds.isEmpty || !session.wasCompleted) return base;
    final known = TagService().tags.map((t) => t.id).toSet();
    final result = Map<String, int>.from(base);
    for (final tagId in session.tagIds) {
      if (!known.contains(tagId)) continue;
      result[tagId] = (result[tagId] ?? 0) + session.actualMinutes;
    }
    return result;
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
    final today = clock.now();
    return getStatsForDate(today) ?? DailyFocusStats(date: today);
  }

  WeeklyFocusStats getWeekStats({DateTime? weekStart}) {
    final start = weekStart ?? _getWeekStart(clock.now());
    return WeeklyFocusStats.calculate(_dailyStats, start);
  }

  WeeklyFocusStats getLastWeekStats() {
    final lastWeekStart = _getWeekStart(clock.now()).subtract(const Duration(days: 7));
    return WeeklyFocusStats.calculate(_dailyStats, lastWeekStart);
  }

  MonthlyFocusStats getMonthStats({int? year, int? month}) {
    final now = clock.now();
    return MonthlyFocusStats.calculate(
      _dailyStats,
      year ?? now.year,
      month ?? now.month,
    );
  }

  YearlyFocusStats getYearStats({int? year}) {
    return YearlyFocusStats.calculate(_dailyStats, year ?? clock.now().year);
  }

  List<DailyFocusStats> getStatsForRange(DateTime start, DateTime end) {
    return _dailyStats.where((s) =>
        !s.date.isBefore(start) && !s.date.isAfter(end)).toList();
  }

  List<DailyFocusStats> getLast7Days() {
    final now = clock.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return getStatsForRange(weekAgo, now);
  }

  List<DailyFocusStats> getLast30Days() {
    final now = clock.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    return getStatsForRange(monthAgo, now);
  }

  List<WeeklyFocusStats> getLast4Weeks() {
    final List<WeeklyFocusStats> weeks = [];
    var weekStart = _getWeekStart(clock.now());
    
    for (int i = 0; i < 4; i++) {
      weeks.add(WeeklyFocusStats.calculate(_dailyStats, weekStart));
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    
    return weeks;
  }

  List<MonthlyFocusStats> getLast12Months() {
    final List<MonthlyFocusStats> months = [];
    var date = clock.now();
    
    for (int i = 0; i < 12; i++) {
      months.add(MonthlyFocusStats.calculate(_dailyStats, date.year, date.month));
      date = DateTime(date.year, date.month - 1, 1);
    }
    
    return months;
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
        relevantStats = _dailyStats.where((s) => s.date.year == clock.now().year).toList();
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
  /// Fresh-install state between tests. See FocusService.resetForTesting.
  @visibleForTesting
  void resetForTesting() {
    _dailyStats = [];
    _productivityPattern = null;
  }

}
