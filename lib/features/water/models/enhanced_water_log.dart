import 'package:hive/hive.dart';

part 'enhanced_water_log.g.dart';

/// Enhanced water log with beverage type and container info
@HiveType(typeId: 28)
class EnhancedWaterLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime time;

  @HiveField(2)
  final int amountMl;

  @HiveField(3)
  final int effectiveHydrationMl; // After applying hydration percentage

  @HiveField(4)
  final String beverageId;

  @HiveField(5)
  final String beverageName;

  @HiveField(6)
  final String beverageEmoji;

  @HiveField(7)
  final int hydrationPercent;

  @HiveField(8)
  final String? containerId;

  @HiveField(9)
  final String? containerName;

  @HiveField(10)
  final int caffeineAmount; // mg

  @HiveField(11)
  final bool isAlcoholic;

  @HiveField(12)
  final String? note;

  EnhancedWaterLog({
    required this.id,
    required this.time,
    required this.amountMl,
    required this.effectiveHydrationMl,
    required this.beverageId,
    required this.beverageName,
    required this.beverageEmoji,
    this.hydrationPercent = 100,
    this.containerId,
    this.containerName,
    this.caffeineAmount = 0,
    this.isAlcoholic = false,
    this.note,
  });

  EnhancedWaterLog copyWith({
    DateTime? time,
    int? amountMl,
    int? effectiveHydrationMl,
    String? beverageId,
    String? beverageName,
    String? beverageEmoji,
    int? hydrationPercent,
    String? containerId,
    String? containerName,
    int? caffeineAmount,
    bool? isAlcoholic,
    String? note,
  }) {
    return EnhancedWaterLog(
      id: id,
      time: time ?? this.time,
      amountMl: amountMl ?? this.amountMl,
      effectiveHydrationMl: effectiveHydrationMl ?? this.effectiveHydrationMl,
      beverageId: beverageId ?? this.beverageId,
      beverageName: beverageName ?? this.beverageName,
      beverageEmoji: beverageEmoji ?? this.beverageEmoji,
      hydrationPercent: hydrationPercent ?? this.hydrationPercent,
      containerId: containerId ?? this.containerId,
      containerName: containerName ?? this.containerName,
      caffeineAmount: caffeineAmount ?? this.caffeineAmount,
      isAlcoholic: isAlcoholic ?? this.isAlcoholic,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'amountMl': amountMl,
    'effectiveHydrationMl': effectiveHydrationMl,
    'beverageId': beverageId,
    'beverageName': beverageName,
    'beverageEmoji': beverageEmoji,
    'hydrationPercent': hydrationPercent,
    'containerId': containerId,
    'containerName': containerName,
    'caffeineAmount': caffeineAmount,
    'isAlcoholic': isAlcoholic,
    'note': note,
  };

  factory EnhancedWaterLog.fromJson(Map<String, dynamic> json) => EnhancedWaterLog(
    id: json['id'] ?? '',
    time: DateTime.parse(json['time']),
    amountMl: json['amountMl'] ?? 0,
    effectiveHydrationMl: json['effectiveHydrationMl'] ?? json['amountMl'] ?? 0,
    beverageId: json['beverageId'] ?? 'water',
    beverageName: json['beverageName'] ?? 'Water',
    beverageEmoji: json['beverageEmoji'] ?? '💧',
    hydrationPercent: json['hydrationPercent'] ?? 100,
    containerId: json['containerId'],
    containerName: json['containerName'],
    caffeineAmount: json['caffeineAmount'] ?? 0,
    isAlcoholic: json['isAlcoholic'] ?? false,
    note: json['note'],
  );
}

/// Daily water data with enhanced logs
@HiveType(typeId: 29)
class DailyWaterData extends HiveObject {
  @HiveField(0)
  final String id; // Format: YYYY-MM-DD

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int dailyGoalMl;

  @HiveField(3)
  final int totalIntakeMl; // Total raw amount

  @HiveField(4)
  final int effectiveHydrationMl; // Total after hydration %

  @HiveField(5)
  final List<EnhancedWaterLog> logs;

  @HiveField(6)
  final int totalCaffeineMg;

  @HiveField(7)
  final int alcoholicDrinksCount;

  @HiveField(8)
  final bool goalReached;

  @HiveField(9)
  final DateTime? goalReachedAt;

  DailyWaterData({
    required this.id,
    required this.date,
    this.dailyGoalMl = 2500,
    this.totalIntakeMl = 0,
    this.effectiveHydrationMl = 0,
    List<EnhancedWaterLog>? logs,
    this.totalCaffeineMg = 0,
    this.alcoholicDrinksCount = 0,
    this.goalReached = false,
    this.goalReachedAt,
  }) : logs = logs ?? [];

  double get progress => dailyGoalMl > 0 ? effectiveHydrationMl / dailyGoalMl : 0.0;
  double get rawProgress => dailyGoalMl > 0 ? totalIntakeMl / dailyGoalMl : 0.0;

  int get remainingMl => (dailyGoalMl - effectiveHydrationMl).clamp(0, dailyGoalMl);

  int get drinksCount => logs.length;

  /// Get breakdown by beverage type
  Map<String, int> get beverageBreakdown {
    final breakdown = <String, int>{};
    for (final log in logs) {
      breakdown[log.beverageId] = (breakdown[log.beverageId] ?? 0) + log.amountMl;
    }
    return breakdown;
  }

  /// Get hourly distribution
  Map<int, int> get hourlyDistribution {
    final distribution = <int, int>{};
    for (final log in logs) {
      final hour = log.time.hour;
      distribution[hour] = (distribution[hour] ?? 0) + log.amountMl;
    }
    return distribution;
  }

  DailyWaterData copyWith({
    int? dailyGoalMl,
    int? totalIntakeMl,
    int? effectiveHydrationMl,
    List<EnhancedWaterLog>? logs,
    int? totalCaffeineMg,
    int? alcoholicDrinksCount,
    bool? goalReached,
    DateTime? goalReachedAt,
  }) {
    return DailyWaterData(
      id: id,
      date: date,
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      totalIntakeMl: totalIntakeMl ?? this.totalIntakeMl,
      effectiveHydrationMl: effectiveHydrationMl ?? this.effectiveHydrationMl,
      logs: logs ?? this.logs,
      totalCaffeineMg: totalCaffeineMg ?? this.totalCaffeineMg,
      alcoholicDrinksCount: alcoholicDrinksCount ?? this.alcoholicDrinksCount,
      goalReached: goalReached ?? this.goalReached,
      goalReachedAt: goalReachedAt ?? this.goalReachedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'dailyGoalMl': dailyGoalMl,
    'totalIntakeMl': totalIntakeMl,
    'effectiveHydrationMl': effectiveHydrationMl,
    'logs': logs.map((l) => l.toJson()).toList(),
    'totalCaffeineMg': totalCaffeineMg,
    'alcoholicDrinksCount': alcoholicDrinksCount,
    'goalReached': goalReached,
    'goalReachedAt': goalReachedAt?.toIso8601String(),
  };

  factory DailyWaterData.fromJson(Map<String, dynamic> json) => DailyWaterData(
    id: json['id'] ?? '',
    date: DateTime.parse(json['date']),
    dailyGoalMl: json['dailyGoalMl'] ?? 2500,
    totalIntakeMl: json['totalIntakeMl'] ?? 0,
    effectiveHydrationMl: json['effectiveHydrationMl'] ?? 0,
    logs: (json['logs'] as List<dynamic>?)
        ?.map((l) => EnhancedWaterLog.fromJson(l))
        .toList(),
    totalCaffeineMg: json['totalCaffeineMg'] ?? 0,
    alcoholicDrinksCount: json['alcoholicDrinksCount'] ?? 0,
    goalReached: json['goalReached'] ?? false,
    goalReachedAt: json['goalReachedAt'] != null
        ? DateTime.parse(json['goalReachedAt'])
        : null,
  );
}

/// Monthly statistics
class MonthlyWaterStats {
  final int year;
  final int month;
  final int daysTracked;
  final int daysGoalMet;
  final int totalIntakeMl;
  final int averageDailyMl;
  final int bestDayMl;
  final int worstDayMl;
  final int totalCaffeineMg;
  final int alcoholicDrinksTotal;
  final Map<String, int> beverageBreakdown;
  final int currentStreak;
  final int longestStreak;

  MonthlyWaterStats({
    required this.year,
    required this.month,
    this.daysTracked = 0,
    this.daysGoalMet = 0,
    this.totalIntakeMl = 0,
    this.averageDailyMl = 0,
    this.bestDayMl = 0,
    this.worstDayMl = 0,
    this.totalCaffeineMg = 0,
    this.alcoholicDrinksTotal = 0,
    Map<String, int>? beverageBreakdown,
    this.currentStreak = 0,
    this.longestStreak = 0,
  }) : beverageBreakdown = beverageBreakdown ?? {};

  double get completionRate => daysTracked > 0 ? daysGoalMet / daysTracked : 0.0;

  Map<String, dynamic> toJson() => {
    'year': year,
    'month': month,
    'daysTracked': daysTracked,
    'daysGoalMet': daysGoalMet,
    'totalIntakeMl': totalIntakeMl,
    'averageDailyMl': averageDailyMl,
    'bestDayMl': bestDayMl,
    'worstDayMl': worstDayMl,
    'totalCaffeineMg': totalCaffeineMg,
    'alcoholicDrinksTotal': alcoholicDrinksTotal,
    'beverageBreakdown': beverageBreakdown,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
  };
}

/// Hydration insight types
enum InsightType {
  tip,
  warning,
  achievement,
  reminder,
  suggestion,
}

/// Hydration insights and tips
class HydrationInsight {
  final String id;
  final InsightType type;
  final String title;
  final String description;
  final String emoji;
  final DateTime createdAt;
  final bool isRead;

  HydrationInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'description': description,
    'emoji': emoji,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  factory HydrationInsight.fromJson(Map<String, dynamic> json) => HydrationInsight(
    id: json['id'] ?? '',
    type: InsightType.values[json['type'] ?? 0],
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    emoji: json['emoji'] ?? '💡',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    isRead: json['isRead'] ?? false,
  );

  /// Generate insights based on user data
  static List<HydrationInsight> generateInsights({
    required int currentStreak,
    required double todayProgress,
    required int caffeineToday,
    required int alcoholToday,
    required int hourOfDay,
    required int avgDailyMl,
    required int goalMl,
  }) {
    final insights = <HydrationInsight>[];
    final now = DateTime.now();

    // Morning hydration tip
    if (hourOfDay >= 6 && hourOfDay <= 9 && todayProgress < 0.1) {
      insights.add(HydrationInsight(
        id: 'morning_hydrate_${now.day}',
        type: InsightType.tip,
        title: 'Start Your Day Right',
        description: 'Drinking water first thing in the morning helps kickstart your metabolism and rehydrate after sleep.',
        emoji: '🌅',
      ));
    }

    // Caffeine warning
    if (caffeineToday > 400) {
      insights.add(HydrationInsight(
        id: 'caffeine_warning_${now.day}',
        type: InsightType.warning,
        title: 'High Caffeine Intake',
        description: 'You\'ve consumed ${caffeineToday}mg of caffeine today. Consider switching to water or herbal tea.',
        emoji: '☕',
      ));
    }

    // Streak celebration
    if (currentStreak == 7) {
      insights.add(HydrationInsight(
        id: 'streak_7_${now.day}',
        type: InsightType.achievement,
        title: 'One Week Streak!',
        description: 'Amazing! You\'ve met your hydration goal for 7 days straight. Keep it up!',
        emoji: '🎉',
      ));
    }

    // Afternoon reminder
    if (hourOfDay >= 14 && hourOfDay <= 16 && todayProgress < 0.5) {
      insights.add(HydrationInsight(
        id: 'afternoon_reminder_${now.day}',
        type: InsightType.reminder,
        title: 'Afternoon Hydration Check',
        description: 'You\'re at ${(todayProgress * 100).toInt()}% of your goal. Time to catch up!',
        emoji: '⏰',
      ));
    }

    // Below average warning
    if (avgDailyMl > 0 && avgDailyMl < goalMl * 0.7) {
      insights.add(HydrationInsight(
        id: 'below_avg_${now.day}',
        type: InsightType.suggestion,
        title: 'Below Average Intake',
        description: 'Your average daily intake is ${avgDailyMl}ml, which is below your goal. Try setting more reminders.',
        emoji: '📊',
      ));
    }

    // Evening completion
    if (hourOfDay >= 18 && todayProgress >= 1.0) {
      insights.add(HydrationInsight(
        id: 'goal_complete_${now.day}',
        type: InsightType.achievement,
        title: 'Goal Achieved!',
        description: 'Great job! You\'ve reached your hydration goal for today.',
        emoji: '🏆',
      ));
    }

    // Alcohol dehydration tip
    if (alcoholToday > 0) {
      insights.add(HydrationInsight(
        id: 'alcohol_tip_${now.day}',
        type: InsightType.tip,
        title: 'Stay Hydrated',
        description: 'Alcohol is dehydrating. Try drinking a glass of water between alcoholic beverages.',
        emoji: '🍷',
      ));
    }

    return insights;
  }
}
