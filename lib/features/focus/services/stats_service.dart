import 'package:flutter/foundation.dart';
import 'package:clock/clock.dart';
import '../models/focus_session.dart';
import '../models/detailed_stats.dart';
import '../../../core/utils/calendar_day.dart';

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

  /// Per-tag minutes for one day, keyed by the ids the session carried.
  ///
  /// Deliberately does NOT filter against the live tag list. An earlier version
  /// did, on the theory that a deleted tag could be rendered as a row — but the
  /// rendered breakdown does not read this map. Both readers
  /// (`detailed_stats_screen`, `custom_tags_screen`) call
  /// `TagService.calculateTagStatistics`, which builds its rows with
  /// `_tags.map((tag) => TagStatistics(tagId: tag.id, ...))` — it projects over
  /// the LIVE tag list, so a deleted id structurally cannot reach the UI from
  /// there. The filter fixed nothing and made this method depend on
  /// `TagService()` being initialised: called before `TagService.init()`, it
  /// would have silently zeroed every tag's minutes.
  ///
  /// `session.tagIds` is history — what the session was tagged at the time — and
  /// keeping unknown ids here preserves that. Nothing renders them.
  ///
  /// Minutes are completed-only, matching `DailyFocusStats.totalMinutes`, so the
  /// per-tag rows sum to the day's headline instead of exceeding it.
  Map<String, int> _tagMinutes(Map<String, int> base, FocusSession session) {
    if (session.tagIds.isEmpty || !session.wasCompleted) return base;
    final result = Map<String, int>.from(base);
    for (final tagId in session.tagIds) {
      result[tagId] = (result[tagId] ?? 0) + session.actualMinutes;
    }
    return result;
  }

  void updateProductivityPattern(List<FocusSession> sessions) {
    // Null when there is nothing to find a pattern in.
    //
    // `ProductivityPattern.analyze` returns a non-null object for an empty
    // list: its two `forEach` loops never run and `mostProdHour = 0` /
    // `mostProdDay = 1` come back as if they were answers. So the Statistics
    // screen told a user with no completed sessions that their peak hour was
    // 12 AM and their best day Monday — and the `pattern == null` guard the
    // screen already has could never fire.
    //
    // The emptiness test matches `analyze`'s own filter: it walks
    // `sessions.where((s) => s.wasCompleted)`, so a user whose only sessions
    // were abandoned has no pattern either.
    final hasCompleted = sessions.any((s) => s.wasCompleted);
    _productivityPattern =
        hasCompleted ? ProductivityPattern.analyze(sessions) : null;
    notifyListeners();
  }

  /// Minutes focused on ONE calendar day, bucketed by the hour each session
  /// started.
  ///
  /// Deliberately not [productivityPattern]. That is a LIFETIME aggregate — it
  /// answers "which hour do you usually focus in" — and the Statistics screen's
  /// **Day** chart plotted it directly, so a segment labelled Day showed every
  /// session ever recorded and a day with no focus at all still drew last
  /// week's bars. The pattern card lower down the same screen still wants the
  /// lifetime shape, so the two derivations are separate rather than one of
  /// them filtered.
  ///
  /// Completed sessions only, matching [DailyFocusStats.totalMinutes]: focus
  /// time is time you finished.
  Map<int, int> minutesByHourForDay(DateTime day, List<FocusSession> sessions) {
    final byHour = <int, int>{};
    for (final session in sessions) {
      if (!session.wasCompleted) continue;
      if (!isSameCalendarDay(session.startedAt, day)) continue;
      final hour = session.startedAt.hour;
      byHour[hour] = (byHour[hour] ?? 0) + session.actualMinutes;
    }
    return byHour;
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
    // dayOffset, not subtract(Duration(days: 7)): _getWeekStart returns
    // midnight, and 168 hours before midnight is 01:00 (or 23:00) across a DST
    // boundary. WeeklyFocusStats.calculate compares against day-only keys, so
    // an 01:00 start sorts AFTER that Monday and silently drops it.
    final lastWeekStart = dayOffset(_getWeekStart(clock.now()), -7);
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

  /// The last SEVEN calendar days, today included.
  ///
  /// `dayOffset(now, -6)`, not `-7`: [getStatsForRange] is inclusive at both
  /// ends, so `-7` returned EIGHT days — and D-7 is the same weekday as today.
  /// The Week bar chart folds rows by `date.weekday`, so that extra day was
  /// summed into today's bar: 60 minutes last Tuesday and 30 today rendered as
  /// a single 90-minute Tuesday, a number the user never had.
  List<DailyFocusStats> getLast7Days() {
    final now = clock.now();
    return getStatsForRange(dayOffset(now, -6), now);
  }

  /// The last THIRTY calendar days, today included — see [getLast7Days] for
  /// why the offset is one less than the count.
  List<DailyFocusStats> getLast30Days() {
    final now = clock.now();
    return getStatsForRange(dayOffset(now, -29), now);
  }

  List<WeeklyFocusStats> getLast4Weeks() {
    final List<WeeklyFocusStats> weeks = [];
    var weekStart = _getWeekStart(clock.now());
    
    for (int i = 0; i < 4; i++) {
      weeks.add(WeeklyFocusStats.calculate(_dailyStats, weekStart));
      weekStart = dayOffset(weekStart, -7);
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
      // The SAME calendar periods `getTotalMinutes` uses, not rolling windows.
      //
      // The Overview hero two cards above calls `getTotalMinutes(period)`,
      // which for weekly is `getWeekStats()` — the current Mon–Sun week — and
      // for monthly is `getMonthStats()`, the current calendar month. This
      // read `getLast7Days()` / `getLast30Days()`, which roll.
      //
      // On a Wednesday the hero covered Mon–Wed while the breakdown beneath it
      // covered the previous Thursday onward, so the breakdown could total
      // more minutes than the hero said existed at all — under one segmented
      // control labelled "Week".
      case StatsPeriod.weekly:
        relevantStats =
            getStatsForRange(_getWeekStart(clock.now()), clock.now());
        break;
      case StatsPeriod.monthly:
        final now = clock.now();
        relevantStats =
            getStatsForRange(DateTime(now.year, now.month, 1), now);
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

  /// Midnight on the Monday of [date]'s week.
  ///
  /// This used to keep [date]'s time of day, so `!d.date.isBefore(weekStart)`
  /// excluded Monday's midnight-normalised row for the whole of every day
  /// after Monday 00:00 — the Week overview card reported fewer minutes than
  /// the bar chart directly beneath it, which uses getLast7Days.
  DateTime _getWeekStart(DateTime date) => startOfWeek(date);
  /// Fresh-install state between tests. See FocusService.resetForTesting.
  @visibleForTesting
  void resetForTesting() {
    _dailyStats = [];
    _productivityPattern = null;
  }

}
