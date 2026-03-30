/// Streak tracking for mood entries
class MoodStreak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastEntryDate;
  final int totalEntries;
  final int totalDaysTracked;
  final List<int> milestones; // Achieved milestone days

  MoodStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastEntryDate,
    this.totalEntries = 0,
    this.totalDaysTracked = 0,
    this.milestones = const [],
  });

  /// Standard milestones to celebrate
  static const List<int> standardMilestones = [7, 14, 21, 30, 50, 100, 365];

  /// Check if today's entry would continue the streak
  bool get canContinueStreak {
    if (lastEntryDate == null) return true;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(
      lastEntryDate!.year, 
      lastEntryDate!.month, 
      lastEntryDate!.day
    );
    
    final difference = today.difference(lastDate).inDays;
    return difference <= 1; // Same day or next day
  }

  /// Check if streak was broken
  bool get isStreakBroken {
    if (lastEntryDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(
      lastEntryDate!.year, 
      lastEntryDate!.month, 
      lastEntryDate!.day
    );
    
    return today.difference(lastDate).inDays > 1;
  }

  /// Check if entry was made today
  bool get hasEntryToday {
    if (lastEntryDate == null) return false;
    
    final now = DateTime.now();
    return lastEntryDate!.year == now.year &&
        lastEntryDate!.month == now.month &&
        lastEntryDate!.day == now.day;
  }

  /// Get next milestone to achieve
  int? get nextMilestone {
    for (final milestone in standardMilestones) {
      if (currentStreak < milestone) {
        return milestone;
      }
    }
    // After 365, use 365-day increments
    if (currentStreak >= 365) {
      return ((currentStreak ~/ 365) + 1) * 365;
    }
    return null;
  }

  /// Get progress to next milestone (0.0 - 1.0)
  double get progressToNextMilestone {
    final next = nextMilestone;
    if (next == null) return 1.0;
    
    // Find previous milestone
    int previous = 0;
    for (final milestone in standardMilestones) {
      if (milestone < next && milestone <= currentStreak) {
        previous = milestone;
      }
    }
    
    final total = next - previous;
    final progress = currentStreak - previous;
    return progress / total;
  }

  /// Get motivational message based on streak
  String get motivationalMessage {
    if (currentStreak == 0) {
      return "Start your journey today! 🌟";
    } else if (currentStreak == 1) {
      return "Great start! Keep it up! 💪";
    } else if (currentStreak < 7) {
      return "You're building momentum! $currentStreak days! 🔥";
    } else if (currentStreak < 14) {
      return "One week strong! Amazing! 🎉";
    } else if (currentStreak < 30) {
      return "Two weeks! You're on fire! 🔥🔥";
    } else if (currentStreak < 100) {
      return "A whole month! Incredible! 🏆";
    } else if (currentStreak < 365) {
      return "$currentStreak days! You're unstoppable! 🚀";
    } else {
      return "Over a year! You're a legend! 👑";
    }
  }

  /// Get streak emoji based on length
  String get streakEmoji {
    if (currentStreak == 0) return '⭐';
    if (currentStreak < 7) return '🔥';
    if (currentStreak < 14) return '🔥';
    if (currentStreak < 30) return '💪';
    if (currentStreak < 100) return '🏆';
    if (currentStreak < 365) return '🚀';
    return '👑';
  }

  /// Update streak with new entry
  MoodStreak recordEntry() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    int newStreak = currentStreak;
    int newLongest = longestStreak;
    List<int> newMilestones = List.from(milestones);

    if (lastEntryDate == null) {
      // First entry ever
      newStreak = 1;
    } else {
      final lastDate = DateTime(
        lastEntryDate!.year,
        lastEntryDate!.month,
        lastEntryDate!.day,
      );
      
      final difference = today.difference(lastDate).inDays;
      
      if (difference == 0) {
        // Already logged today, no streak change
        return copyWith(
          lastEntryDate: now,
          totalEntries: totalEntries + 1,
        );
      } else if (difference == 1) {
        // Consecutive day - increase streak
        newStreak = currentStreak + 1;
      } else {
        // Streak broken - start fresh
        newStreak = 1;
      }
    }

    // Update longest streak
    if (newStreak > newLongest) {
      newLongest = newStreak;
    }

    // Check for new milestones
    for (final milestone in standardMilestones) {
      if (newStreak >= milestone && !newMilestones.contains(milestone)) {
        newMilestones.add(milestone);
      }
    }

    return MoodStreak(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastEntryDate: now,
      totalEntries: totalEntries + 1,
      totalDaysTracked: _calculateTotalDays(now),
      milestones: newMilestones,
    );
  }

  int _calculateTotalDays(DateTime now) {
    // This is a simplified calculation
    // In a real app, you'd track unique days with entries
    return totalDaysTracked + (hasEntryToday ? 0 : 1);
  }

  MoodStreak copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastEntryDate,
    int? totalEntries,
    int? totalDaysTracked,
    List<int>? milestones,
  }) {
    return MoodStreak(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastEntryDate: lastEntryDate ?? this.lastEntryDate,
      totalEntries: totalEntries ?? this.totalEntries,
      totalDaysTracked: totalDaysTracked ?? this.totalDaysTracked,
      milestones: milestones ?? this.milestones,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastEntryDate': lastEntryDate?.toIso8601String(),
      'totalEntries': totalEntries,
      'totalDaysTracked': totalDaysTracked,
      'milestones': milestones,
    };
  }

  factory MoodStreak.fromJson(Map<String, dynamic> json) {
    return MoodStreak(
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastEntryDate: json['lastEntryDate'] != null
          ? DateTime.parse(json['lastEntryDate'] as String)
          : null,
      totalEntries: json['totalEntries'] as int? ?? 0,
      totalDaysTracked: json['totalDaysTracked'] as int? ?? 0,
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}
