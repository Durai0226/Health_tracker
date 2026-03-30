/// Leaderboard Model for Exam Prep Feature
/// Tracks user rankings based on test scores and performance

class LeaderboardEntry {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int rank;
  final int score;
  final int testsCompleted;
  final double accuracy;
  final int streak;
  final DateTime lastActive;
  final LeaderboardPeriod period;

  const LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.rank,
    required this.score,
    required this.testsCompleted,
    required this.accuracy,
    this.streak = 0,
    required this.lastActive,
    required this.period,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'avatarUrl': avatarUrl,
    'rank': rank,
    'score': score,
    'testsCompleted': testsCompleted,
    'accuracy': accuracy,
    'streak': streak,
    'lastActive': lastActive.toIso8601String(),
    'period': period.name,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    id: json['id'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    rank: json['rank'] as int,
    score: json['score'] as int,
    testsCompleted: json['testsCompleted'] as int,
    accuracy: (json['accuracy'] as num).toDouble(),
    streak: json['streak'] as int? ?? 0,
    lastActive: DateTime.parse(json['lastActive'] as String),
    period: LeaderboardPeriod.values.firstWhere(
      (e) => e.name == json['period'],
      orElse: () => LeaderboardPeriod.weekly,
    ),
  );

  LeaderboardEntry copyWith({
    String? id,
    String? userId,
    String? userName,
    String? avatarUrl,
    int? rank,
    int? score,
    int? testsCompleted,
    double? accuracy,
    int? streak,
    DateTime? lastActive,
    LeaderboardPeriod? period,
  }) {
    return LeaderboardEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rank: rank ?? this.rank,
      score: score ?? this.score,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      accuracy: accuracy ?? this.accuracy,
      streak: streak ?? this.streak,
      lastActive: lastActive ?? this.lastActive,
      period: period ?? this.period,
    );
  }
}

enum LeaderboardPeriod {
  daily,
  weekly,
  monthly,
  allTime,
}

class LeaderboardStats {
  final int totalParticipants;
  final int averageScore;
  final double averageAccuracy;
  final int topScore;
  final String topScorerName;
  final DateTime lastUpdated;

  const LeaderboardStats({
    required this.totalParticipants,
    required this.averageScore,
    required this.averageAccuracy,
    required this.topScore,
    required this.topScorerName,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'totalParticipants': totalParticipants,
    'averageScore': averageScore,
    'averageAccuracy': averageAccuracy,
    'topScore': topScore,
    'topScorerName': topScorerName,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) => LeaderboardStats(
    totalParticipants: json['totalParticipants'] as int,
    averageScore: json['averageScore'] as int,
    averageAccuracy: (json['averageAccuracy'] as num).toDouble(),
    topScore: json['topScore'] as int,
    topScorerName: json['topScorerName'] as String,
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  );
}

/// Sample Leaderboard Data
class SampleLeaderboard {
  static List<LeaderboardEntry> getSampleEntries(LeaderboardPeriod period) {
    final now = DateTime.now();
    final names = [
      'Rahul Sharma', 'Priya Patel', 'Amit Kumar', 'Sneha Gupta',
      'Vikram Singh', 'Ananya Das', 'Rohan Verma', 'Neha Reddy',
      'Arjun Nair', 'Pooja Iyer', 'Karthik Raj', 'Divya Menon',
      'Sanjay Rao', 'Meera Pillai', 'Aditya Joshi', 'Kavitha Nambiar',
      'Ravi Krishnan', 'Lakshmi Suresh', 'Deepak Pandey', 'Anjali Mishra',
    ];

    return List.generate(names.length, (index) {
      final baseScore = period == LeaderboardPeriod.daily 
          ? 500 
          : period == LeaderboardPeriod.weekly 
              ? 2000 
              : period == LeaderboardPeriod.monthly 
                  ? 8000 
                  : 50000;
      
      return LeaderboardEntry(
        id: 'entry_${period.name}_$index',
        userId: 'user_$index',
        userName: names[index],
        rank: index + 1,
        score: baseScore - (index * (baseScore ~/ 25)),
        testsCompleted: 20 - index,
        accuracy: 95 - (index * 2.5),
        streak: 30 - index,
        lastActive: now.subtract(Duration(hours: index)),
        period: period,
      );
    });
  }

  static LeaderboardStats getSampleStats(LeaderboardPeriod period) {
    return LeaderboardStats(
      totalParticipants: period == LeaderboardPeriod.daily 
          ? 1250 
          : period == LeaderboardPeriod.weekly 
              ? 5430 
              : period == LeaderboardPeriod.monthly 
                  ? 12500 
                  : 45000,
      averageScore: period == LeaderboardPeriod.daily 
          ? 350 
          : period == LeaderboardPeriod.weekly 
              ? 1500 
              : period == LeaderboardPeriod.monthly 
                  ? 6000 
                  : 35000,
      averageAccuracy: 72.5,
      topScore: period == LeaderboardPeriod.daily 
          ? 500 
          : period == LeaderboardPeriod.weekly 
              ? 2000 
              : period == LeaderboardPeriod.monthly 
                  ? 8000 
                  : 50000,
      topScorerName: 'Rahul Sharma',
      lastUpdated: DateTime.now(),
    );
  }
}
