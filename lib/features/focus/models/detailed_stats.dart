import '../../../core/utils/enum_json.dart';
import 'focus_session.dart';
import '../../../core/utils/calendar_day.dart';

enum StatsPeriod {
  daily,
  weekly,
  monthly,
  yearly,
}

extension StatsPeriodExtension on StatsPeriod {
  String get name {
    switch (this) {
      case StatsPeriod.daily:
        return 'Daily';
      case StatsPeriod.weekly:
        return 'Weekly';
      case StatsPeriod.monthly:
        return 'Monthly';
      case StatsPeriod.yearly:
        return 'Yearly';
    }
  }

  String get shortName {
    switch (this) {
      case StatsPeriod.daily:
        return 'Day';
      case StatsPeriod.weekly:
        return 'Week';
      case StatsPeriod.monthly:
        return 'Month';
      case StatsPeriod.yearly:
        return 'Year';
    }
  }
}

class DailyFocusStats {
  final DateTime date;

  /// Minutes from **completed** sessions only.
  ///
  /// This used to include abandoned sessions' elapsed minutes, while
  /// `FocusService.todayMinutes` counted completed ones — so the Focus screen and
  /// the Statistics screen reported different totals for the same day, and the
  /// streak derived from them disagreed too ("1 day streak" in the header vs
  /// "0 Day Streak" in Statistics, recorded in docs/ui-audit.md).
  ///
  /// One definition, in one place: "focus time" is time you finished.
  final int totalMinutes;

  /// Elapsed minutes from abandoned sessions, kept separately so the honest
  /// definition above does not throw the data away.
  final int abandonedMinutes;

  final int sessionsCount;
  final int completedSessions;
  final int abandonedSessions;
  final Map<FocusActivityType, int> minutesByActivity;
  final Map<String, int> minutesByTag;
  final int plantsGrown;
  final int plantsWithered;
  final int coinsEarned;

  DailyFocusStats({
    required this.date,
    this.totalMinutes = 0,
    this.abandonedMinutes = 0,
    this.sessionsCount = 0,
    this.completedSessions = 0,
    this.abandonedSessions = 0,
    this.minutesByActivity = const {},
    this.minutesByTag = const {},
    this.plantsGrown = 0,
    this.plantsWithered = 0,
    this.coinsEarned = 0,
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => sessionsCount > 0 ? completedSessions / sessionsCount : 0;
  bool get hasData => totalMinutes > 0 || sessionsCount > 0;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'totalMinutes': totalMinutes,
        'abandonedMinutes': abandonedMinutes,
        'sessionsCount': sessionsCount,
        'completedSessions': completedSessions,
        'abandonedSessions': abandonedSessions,
        'minutesByActivity': minutesByActivity.map((k, v) => MapEntry(k.index.toString(), v)),
        'minutesByTag': minutesByTag,
        'plantsGrown': plantsGrown,
        'plantsWithered': plantsWithered,
        'coinsEarned': coinsEarned,
      };

  factory DailyFocusStats.fromJson(Map<String, dynamic> json) {
    Map<FocusActivityType, int> activities = {};
    if (json['minutesByActivity'] != null) {
      (json['minutesByActivity'] as Map).forEach((key, value) {
        final k = EnumJson.key(FocusActivityType.values, key);
        if (k != null && value is int) activities[k] = value;
      });
    }

    return DailyFocusStats(
      date: DateTime.parse(json['date']),
      totalMinutes: json['totalMinutes'] ?? 0,
      abandonedMinutes: json['abandonedMinutes'] ?? 0,
      sessionsCount: json['sessionsCount'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      abandonedSessions: json['abandonedSessions'] ?? 0,
      minutesByActivity: activities,
      minutesByTag: Map<String, int>.from(json['minutesByTag'] ?? {}),
      plantsGrown: json['plantsGrown'] ?? 0,
      plantsWithered: json['plantsWithered'] ?? 0,
      coinsEarned: json['coinsEarned'] ?? 0,
    );
  }
}

class WeeklyFocusStats {
  final DateTime weekStart;
  final DateTime weekEnd;
  final List<DailyFocusStats> dailyStats;
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final double averageDailyMinutes;
  final int bestDay;
  final Map<FocusActivityType, int> minutesByActivity;

  WeeklyFocusStats({
    required this.weekStart,
    required this.weekEnd,
    required this.dailyStats,
    required this.totalMinutes,
    required this.totalSessions,
    required this.completedSessions,
    required this.averageDailyMinutes,
    required this.bestDay,
    required this.minutesByActivity,
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => totalSessions > 0 ? completedSessions / totalSessions : 0;

  static WeeklyFocusStats calculate(List<DailyFocusStats> dailyStats, DateTime weekStart) {
    // dayOffset, not add(Duration(days: 6)): weekStart is midnight and the
    // rows are keyed to midnight, so on a spring-forward week 144 hours later
    // lands at 23:00 the previous day and isAfter() drops that final day.
    final weekEnd = dayOffset(weekStart, 6);
    final weeklyData = dailyStats.where((d) =>
        !d.date.isBefore(weekStart) && !d.date.isAfter(weekEnd)).toList();

    int totalMins = 0;
    int totalSess = 0;
    int completedSess = 0;
    int bestDayMins = 0;
    int bestDayIndex = 0;
    Map<FocusActivityType, int> activities = {};

    for (int i = 0; i < weeklyData.length; i++) {
      final day = weeklyData[i];
      totalMins += day.totalMinutes;
      totalSess += day.sessionsCount;
      completedSess += day.completedSessions;
      
      if (day.totalMinutes > bestDayMins) {
        bestDayMins = day.totalMinutes;
        bestDayIndex = day.date.weekday;
      }

      day.minutesByActivity.forEach((activity, mins) {
        activities[activity] = (activities[activity] ?? 0) + mins;
      });
    }

    return WeeklyFocusStats(
      weekStart: weekStart,
      weekEnd: weekEnd,
      dailyStats: weeklyData,
      totalMinutes: totalMins,
      totalSessions: totalSess,
      completedSessions: completedSess,
      averageDailyMinutes: weeklyData.isNotEmpty ? totalMins / 7 : 0,
      bestDay: bestDayIndex,
      minutesByActivity: activities,
    );
  }
}

class MonthlyFocusStats {
  final int year;
  final int month;
  final List<DailyFocusStats> dailyStats;
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final double averageDailyMinutes;
  final int activeDays;
  final int bestDay;
  final Map<FocusActivityType, int> minutesByActivity;

  MonthlyFocusStats({
    required this.year,
    required this.month,
    required this.dailyStats,
    required this.totalMinutes,
    required this.totalSessions,
    required this.completedSessions,
    required this.averageDailyMinutes,
    required this.activeDays,
    required this.bestDay,
    required this.minutesByActivity,
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => totalSessions > 0 ? completedSessions / totalSessions : 0;

  String get monthName {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  static MonthlyFocusStats calculate(List<DailyFocusStats> dailyStats, int year, int month) {
    final monthlyData = dailyStats.where((d) =>
        d.date.year == year && d.date.month == month).toList();

    int totalMins = 0;
    int totalSess = 0;
    int completedSess = 0;
    int activeDays = 0;
    int bestDayMins = 0;
    int bestDayNum = 0;
    Map<FocusActivityType, int> activities = {};

    for (final day in monthlyData) {
      if (day.hasData) activeDays++;
      totalMins += day.totalMinutes;
      totalSess += day.sessionsCount;
      completedSess += day.completedSessions;
      
      if (day.totalMinutes > bestDayMins) {
        bestDayMins = day.totalMinutes;
        bestDayNum = day.date.day;
      }

      day.minutesByActivity.forEach((activity, mins) {
        activities[activity] = (activities[activity] ?? 0) + mins;
      });
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;

    return MonthlyFocusStats(
      year: year,
      month: month,
      dailyStats: monthlyData,
      totalMinutes: totalMins,
      totalSessions: totalSess,
      completedSessions: completedSess,
      averageDailyMinutes: totalMins / daysInMonth,
      activeDays: activeDays,
      bestDay: bestDayNum,
      minutesByActivity: activities,
    );
  }
}

class YearlyFocusStats {
  final int year;
  final List<MonthlyFocusStats> monthlyStats;
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final int activeDays;
  final int bestMonth;
  final Map<FocusActivityType, int> minutesByActivity;

  YearlyFocusStats({
    required this.year,
    required this.monthlyStats,
    required this.totalMinutes,
    required this.totalSessions,
    required this.completedSessions,
    required this.activeDays,
    required this.bestMonth,
    required this.minutesByActivity,
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => totalSessions > 0 ? completedSessions / totalSessions : 0;
  double get averageMonthlyMinutes => totalMinutes / 12;

  static YearlyFocusStats calculate(List<DailyFocusStats> dailyStats, int year) {
    final yearlyData = dailyStats.where((d) => d.date.year == year).toList();
    
    List<MonthlyFocusStats> monthlyStats = [];
    for (int month = 1; month <= 12; month++) {
      monthlyStats.add(MonthlyFocusStats.calculate(yearlyData, year, month));
    }

    int totalMins = 0;
    int totalSess = 0;
    int completedSess = 0;
    int activeDays = 0;
    int bestMonthMins = 0;
    int bestMonthNum = 0;
    Map<FocusActivityType, int> activities = {};

    for (int i = 0; i < monthlyStats.length; i++) {
      final month = monthlyStats[i];
      totalMins += month.totalMinutes;
      totalSess += month.totalSessions;
      completedSess += month.completedSessions;
      activeDays += month.activeDays;
      
      if (month.totalMinutes > bestMonthMins) {
        bestMonthMins = month.totalMinutes;
        bestMonthNum = i + 1;
      }

      month.minutesByActivity.forEach((activity, mins) {
        activities[activity] = (activities[activity] ?? 0) + mins;
      });
    }

    return YearlyFocusStats(
      year: year,
      monthlyStats: monthlyStats,
      totalMinutes: totalMins,
      totalSessions: totalSess,
      completedSessions: completedSess,
      activeDays: activeDays,
      bestMonth: bestMonthNum,
      minutesByActivity: activities,
    );
  }
}

class ProductivityPattern {
  final Map<int, int> minutesByHour;
  final Map<int, int> minutesByDayOfWeek;
  final int mostProductiveHour;
  final int mostProductiveDay;
  final int leastProductiveHour;
  final int leastProductiveDay;

  ProductivityPattern({
    required this.minutesByHour,
    required this.minutesByDayOfWeek,
    required this.mostProductiveHour,
    required this.mostProductiveDay,
    required this.leastProductiveHour,
    required this.leastProductiveDay,
  });

  String get mostProductiveDayLabel {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[mostProductiveDay - 1];
  }

  static ProductivityPattern analyze(List<FocusSession> sessions) {
    Map<int, int> byHour = {};
    Map<int, int> byDay = {};

    for (final session in sessions.where((s) => s.wasCompleted)) {
      final hour = session.startedAt.hour;
      final day = session.startedAt.weekday;
      
      byHour[hour] = (byHour[hour] ?? 0) + session.actualMinutes;
      byDay[day] = (byDay[day] ?? 0) + session.actualMinutes;
    }

    int mostProdHour = 0;
    int mostProdHourMins = 0;
    int leastProdHour = 0;
    int leastProdHourMins = double.maxFinite.toInt();

    byHour.forEach((hour, mins) {
      if (mins > mostProdHourMins) {
        mostProdHourMins = mins;
        mostProdHour = hour;
      }
      if (mins < leastProdHourMins) {
        leastProdHourMins = mins;
        leastProdHour = hour;
      }
    });

    int mostProdDay = 1;
    int mostProdDayMins = 0;
    int leastProdDay = 1;
    int leastProdDayMins = double.maxFinite.toInt();

    byDay.forEach((day, mins) {
      if (mins > mostProdDayMins) {
        mostProdDayMins = mins;
        mostProdDay = day;
      }
      if (mins < leastProdDayMins) {
        leastProdDayMins = mins;
        leastProdDay = day;
      }
    });

    return ProductivityPattern(
      minutesByHour: byHour,
      minutesByDayOfWeek: byDay,
      mostProductiveHour: mostProdHour,
      mostProductiveDay: mostProdDay,
      leastProductiveHour: leastProdHour,
      leastProductiveDay: leastProdDay,
    );
  }
}

/// One distraction's tally across many sessions.
///
/// Deliberately NOT a score. Taps ÷ minutes would convert a self-awareness tool
/// into a thing you can be bad at, and would punish the honest logger — the user
/// who taps every time would look worse than the one who never opens the screen.
/// These are counts and a position, and the user draws the conclusion.
class DistractionSummary {
  final String appId;

  /// Total taps.
  final int taps;

  /// How many distinct sessions this pulled at the user in.
  final int sessions;

  /// Median seconds into the session. Median rather than mean because one late
  /// tap in a 90-minute session should not move where this reads as happening.
  final int medianSecond;

  const DistractionSummary({
    required this.appId,
    required this.taps,
    required this.sessions,
    required this.medianSecond,
  });

  /// "mostly in the first 10 minutes" — the actionable half.
  ///
  /// A bucket, not a precise figure: the honest resolution of a handful of
  /// self-reported taps is "early / mid / late", and quoting "at 7m 12s" would
  /// imply a precision the data does not have.
  String get whenLabel {
    if (medianSecond < 600) return 'mostly in the first 10 minutes';
    if (medianSecond < 1800) return 'mostly 10–30 minutes in';
    return 'mostly later in the session';
  }

  /// Ranked tallies, heaviest first. Empty when nothing was ever logged.
  static List<DistractionSummary> summarise(List<FocusSession> sessions) {
    final taps = <String, List<int>>{};
    final inSessions = <String, Set<String>>{};
    for (final s in sessions) {
      for (final d in s.distractions) {
        taps.putIfAbsent(d.appId, () => []).add(d.atSecond);
        inSessions.putIfAbsent(d.appId, () => {}).add(s.id);
      }
    }

    final out = <DistractionSummary>[];
    taps.forEach((appId, seconds) {
      seconds.sort();
      final mid = seconds.length ~/ 2;
      final median = seconds.length.isOdd
          ? seconds[mid]
          : ((seconds[mid - 1] + seconds[mid]) / 2).round();
      out.add(DistractionSummary(
        appId: appId,
        taps: seconds.length,
        sessions: inSessions[appId]!.length,
        medianSecond: median,
      ));
    });
    out.sort((a, b) => b.taps.compareTo(a.taps));
    return out;
  }
}
