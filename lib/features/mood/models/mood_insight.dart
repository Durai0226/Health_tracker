import 'mood_type.dart';
import 'mood_entry.dart';

/// Analytics insights for mood tracking
class MoodInsight {
  final DateTime startDate;
  final DateTime endDate;
  final int totalEntries;
  final Map<MoodType, int> moodCounts;
  final double averageIntensity;
  final double averagePositivity;
  final MoodType? dominantMood;
  final Map<int, MoodType?> dayOfWeekMoods; // 1-7 (Mon-Sun)
  final Map<ActivityType, int> activityCounts;
  final List<MoodTrend> trends;

  MoodInsight({
    required this.startDate,
    required this.endDate,
    required this.totalEntries,
    required this.moodCounts,
    required this.averageIntensity,
    required this.averagePositivity,
    this.dominantMood,
    required this.dayOfWeekMoods,
    required this.activityCounts,
    this.trends = const [],
  });

  /// Create insight from a list of mood entries
  factory MoodInsight.fromEntries(List<MoodEntry> entries, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (entries.isEmpty) {
      final now = DateTime.now();
      return MoodInsight(
        startDate: startDate ?? now.subtract(const Duration(days: 7)),
        endDate: endDate ?? now,
        totalEntries: 0,
        moodCounts: {},
        averageIntensity: 0,
        averagePositivity: 0,
        dominantMood: null,
        dayOfWeekMoods: {},
        activityCounts: {},
        trends: [],
      );
    }

    // Sort entries by timestamp
    final sortedEntries = List<MoodEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate date range
    final actualStart = startDate ?? sortedEntries.first.timestamp;
    final actualEnd = endDate ?? sortedEntries.last.timestamp;

    // Count moods
    final moodCounts = <MoodType, int>{};
    for (final entry in entries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }

    // Find dominant mood
    MoodType? dominantMood;
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantMood = mood;
      }
    });

    // Calculate average intensity
    final totalIntensity = entries.fold<int>(0, (sum, e) => sum + e.intensity);
    final avgIntensity = entries.isNotEmpty ? totalIntensity / entries.length : 0.0;

    // Calculate average positivity score
    final totalPositivity = entries.fold<int>(0, (sum, e) => sum + e.mood.positivityScore);
    final avgPositivity = entries.isNotEmpty ? totalPositivity / entries.length : 0.0;

    // Day of week analysis
    final dayOfWeekMoods = <int, MoodType?>{};
    final dayOfWeekCounts = <int, Map<MoodType, int>>{};
    
    for (final entry in entries) {
      final weekday = entry.timestamp.weekday;
      dayOfWeekCounts[weekday] ??= {};
      dayOfWeekCounts[weekday]![entry.mood] = 
          (dayOfWeekCounts[weekday]![entry.mood] ?? 0) + 1;
    }

    dayOfWeekCounts.forEach((day, counts) {
      MoodType? dominant;
      int max = 0;
      counts.forEach((mood, count) {
        if (count > max) {
          max = count;
          dominant = mood;
        }
      });
      dayOfWeekMoods[day] = dominant;
    });

    // Activity counts
    final activityCounts = <ActivityType, int>{};
    for (final entry in entries) {
      for (final activity in entry.activities) {
        activityCounts[activity] = (activityCounts[activity] ?? 0) + 1;
      }
    }

    // Calculate trends
    final trends = _calculateTrends(sortedEntries);

    return MoodInsight(
      startDate: actualStart,
      endDate: actualEnd,
      totalEntries: entries.length,
      moodCounts: moodCounts,
      averageIntensity: avgIntensity,
      averagePositivity: avgPositivity,
      dominantMood: dominantMood,
      dayOfWeekMoods: dayOfWeekMoods,
      activityCounts: activityCounts,
      trends: trends,
    );
  }

  static List<MoodTrend> _calculateTrends(List<MoodEntry> sortedEntries) {
    if (sortedEntries.length < 3) return [];

    final trends = <MoodTrend>[];
    
    // Calculate 3-day moving average of positivity
    final positivityScores = sortedEntries.map((e) => e.mood.positivityScore.toDouble()).toList();
    
    if (positivityScores.length >= 7) {
      // Compare last 3 days to previous 4 days
      final recentAvg = positivityScores.sublist(positivityScores.length - 3)
          .reduce((a, b) => a + b) / 3;
      final previousAvg = positivityScores.sublist(positivityScores.length - 7, positivityScores.length - 3)
          .reduce((a, b) => a + b) / 4;

      if (recentAvg > previousAvg + 0.5) {
        trends.add(MoodTrend(
          type: TrendType.improving,
          description: 'Your mood has been improving over the past few days!',
          change: recentAvg - previousAvg,
        ));
      } else if (recentAvg < previousAvg - 0.5) {
        trends.add(MoodTrend(
          type: TrendType.declining,
          description: 'Your mood has been lower recently. Take care of yourself!',
          change: recentAvg - previousAvg,
        ));
      } else {
        trends.add(MoodTrend(
          type: TrendType.stable,
          description: 'Your mood has been consistent lately.',
          change: 0,
        ));
      }
    }

    return trends;
  }

  /// Get mood percentage for a specific mood type
  double getMoodPercentage(MoodType mood) {
    if (totalEntries == 0) return 0;
    return ((moodCounts[mood] ?? 0) / totalEntries) * 100;
  }

  /// Get top activities
  List<MapEntry<ActivityType, int>> get topActivities {
    final sorted = activityCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  /// Get best day of the week
  String? get bestDayOfWeek {
    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    int? bestDay;
    int bestScore = 0;

    dayOfWeekMoods.forEach((day, mood) {
      if (mood != null && mood.positivityScore > bestScore) {
        bestScore = mood.positivityScore;
        bestDay = day;
      }
    });

    return bestDay != null ? dayNames[bestDay!] : null;
  }

  /// Get positivity level description
  String get positivityLevel {
    if (averagePositivity >= 4.5) return 'Excellent';
    if (averagePositivity >= 3.5) return 'Good';
    if (averagePositivity >= 2.5) return 'Moderate';
    if (averagePositivity >= 1.5) return 'Low';
    return 'Very Low';
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalEntries': totalEntries,
      'moodCounts': moodCounts.map((k, v) => MapEntry(k.value, v)),
      'averageIntensity': averageIntensity,
      'averagePositivity': averagePositivity,
      'dominantMood': dominantMood?.value,
      'dayOfWeekMoods': dayOfWeekMoods.map((k, v) => MapEntry(k.toString(), v?.value)),
      'activityCounts': activityCounts.map((k, v) => MapEntry(k.value, v)),
    };
  }
}

/// Mood trend information
class MoodTrend {
  final TrendType type;
  final String description;
  final double change;

  MoodTrend({
    required this.type,
    required this.description,
    required this.change,
  });
}

enum TrendType {
  improving,
  declining,
  stable;

  String get emoji {
    switch (this) {
      case TrendType.improving:
        return '📈';
      case TrendType.declining:
        return '📉';
      case TrendType.stable:
        return '➡️';
    }
  }
}

/// Daily mood summary for calendar view
class DailyMoodSummary {
  final DateTime date;
  final MoodType? dominantMood;
  final int entryCount;
  final double averageIntensity;

  DailyMoodSummary({
    required this.date,
    this.dominantMood,
    this.entryCount = 0,
    this.averageIntensity = 0,
  });

  factory DailyMoodSummary.fromEntries(DateTime date, List<MoodEntry> entries) {
    if (entries.isEmpty) {
      return DailyMoodSummary(date: date);
    }

    // Find dominant mood
    final moodCounts = <MoodType, int>{};
    int totalIntensity = 0;

    for (final entry in entries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
      totalIntensity += entry.intensity;
    }

    MoodType? dominant;
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        dominant = mood;
      }
    });

    return DailyMoodSummary(
      date: date,
      dominantMood: dominant,
      entryCount: entries.length,
      averageIntensity: totalIntensity / entries.length,
    );
  }

  String get dateKey {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
