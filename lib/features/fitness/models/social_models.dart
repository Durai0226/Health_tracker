import 'package:hive/hive.dart';

part 'social_models.g.dart';

/// Segment - Route section for leaderboard competition
@HiveType(typeId: 70)
class Segment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double distanceKm;

  @HiveField(3)
  final int elevationGainM;

  @HiveField(4)
  final String activityType;

  @HiveField(5)
  final List<RoutePointSimple> points;

  @HiveField(6)
  final String difficulty;

  @HiveField(7)
  final int totalAttempts;

  @HiveField(8)
  final String? creatorId;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final bool isStarred;

  Segment({
    required this.id,
    required this.name,
    required this.distanceKm,
    required this.elevationGainM,
    required this.activityType,
    required this.points,
    required this.difficulty,
    required this.totalAttempts,
    this.creatorId,
    required this.createdAt,
    this.isStarred = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'distanceKm': distanceKm,
    'elevationGainM': elevationGainM,
    'activityType': activityType,
    'points': points.map((p) => p.toJson()).toList(),
    'difficulty': difficulty,
    'totalAttempts': totalAttempts,
    'creatorId': creatorId,
    'createdAt': createdAt.toIso8601String(),
    'isStarred': isStarred,
  };

  factory Segment.fromJson(Map<String, dynamic> json) => Segment(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    distanceKm: (json['distanceKm'] ?? 0).toDouble(),
    elevationGainM: json['elevationGainM'] ?? 0,
    activityType: json['activityType'] ?? 'run',
    points: (json['points'] as List<dynamic>?)
        ?.map((p) => RoutePointSimple.fromJson(p))
        .toList() ?? [],
    difficulty: json['difficulty'] ?? 'moderate',
    totalAttempts: json['totalAttempts'] ?? 0,
    creatorId: json['creatorId'],
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    isStarred: json['isStarred'] ?? false,
  );
}

@HiveType(typeId: 71)
class RoutePointSimple extends HiveObject {
  @HiveField(0)
  final double lat;

  @HiveField(1)
  final double lng;

  RoutePointSimple({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory RoutePointSimple.fromJson(Map<String, dynamic> json) => RoutePointSimple(
    lat: (json['lat'] ?? 0).toDouble(),
    lng: (json['lng'] ?? 0).toDouble(),
  );
}

/// Segment Effort - User's attempt at a segment
@HiveType(typeId: 72)
class SegmentEffort extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String segmentId;

  @HiveField(2)
  final String activityId;

  @HiveField(3)
  final String usreId;

  @HiveField(4)
  final int elapsedTimeSeconds;

  @HiveField(5)
  final DateTime startTime;

  @HiveField(6)
  final int? avgHeartRate;

  @HiveField(7)
  final double? avgPower;

  @HiveField(8)
  final int rank; // Position on leaderboard

  @HiveField(9)
  final bool isPR; // Personal Record

  @HiveField(10)
  final int? previousBestSeconds;

  SegmentEffort({
    required this.id,
    required this.segmentId,
    required this.activityId,
    required this.usreId,
    required this.elapsedTimeSeconds,
    required this.startTime,
    this.avgHeartRate,
    this.avgPower,
    required this.rank,
    this.isPR = false,
    this.previousBestSeconds,
  });

  String get formattedTime {
    final minutes = elapsedTimeSeconds ~/ 60;
    final seconds = elapsedTimeSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  int? get improvement {
    if (previousBestSeconds == null) return null;
    return previousBestSeconds! - elapsedTimeSeconds;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'segmentId': segmentId,
    'activityId': activityId,
    'usreId': usreId,
    'elapsedTimeSeconds': elapsedTimeSeconds,
    'startTime': startTime.toIso8601String(),
    'avgHeartRate': avgHeartRate,
    'avgPower': avgPower,
    'rank': rank,
    'isPR': isPR,
    'previousBestSeconds': previousBestSeconds,
  };

  factory SegmentEffort.fromJson(Map<String, dynamic> json) => SegmentEffort(
    id: json['id'] ?? '',
    segmentId: json['segmentId'] ?? '',
    activityId: json['activityId'] ?? '',
    usreId: json['usreId'] ?? '',
    elapsedTimeSeconds: json['elapsedTimeSeconds'] ?? 0,
    startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
    avgHeartRate: json['avgHeartRate'],
    avgPower: json['avgPower']?.toDouble(),
    rank: json['rank'] ?? 0,
    isPR: json['isPR'] ?? false,
    previousBestSeconds: json['previousBestSeconds'],
  );
}

/// Leaderboard Entry
@HiveType(typeId: 73)
class LeaderboardEntry extends HiveObject {
  @HiveField(0)
  final int rank;

  @HiveField(1)
  final String usreId;

  @HiveField(2)
  final String userName;

  @HiveField(3)
  final String? userAvatarUrl;

  @HiveField(4)
  final int elapsedTimeSeconds;

  @HiveField(5)
  final DateTime achievedAt;

  @HiveField(6)
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.rank,
    required this.usreId,
    required this.userName,
    this.userAvatarUrl,
    required this.elapsedTimeSeconds,
    required this.achievedAt,
    this.isCurrentUser = false,
  });

  String get formattedTime {
    final minutes = elapsedTimeSeconds ~/ 60;
    final seconds = elapsedTimeSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get rankEmoji {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '';
    }
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'usreId': usreId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'elapsedTimeSeconds': elapsedTimeSeconds,
    'achievedAt': achievedAt.toIso8601String(),
    'isCurrentUser': isCurrentUser,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    rank: json['rank'] ?? 0,
    usreId: json['usreId'] ?? '',
    userName: json['userName'] ?? '',
    userAvatarUrl: json['userAvatarUrl'],
    elapsedTimeSeconds: json['elapsedTimeSeconds'] ?? 0,
    achievedAt: DateTime.parse(json['achievedAt'] ?? DateTime.now().toIso8601String()),
    isCurrentUser: json['isCurrentUser'] ?? false,
  );
}

/// Challenge - Group fitness challenge
@HiveType(typeId: 74)
class FitnessChallenge extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String challengeType; // distance, duration, frequency, elevation

  @HiveField(4)
  final String activityType; // run, cycling, any

  @HiveField(5)
  final double targetValue; // Target to achieve

  @HiveField(6)
  final String targetUnit; // km, minutes, workouts, m

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final DateTime endDate;

  @HiveField(9)
  final List<ChallengeParticipant> participants;

  @HiveField(10)
  final String? imageUrl;

  @HiveField(11)
  final bool isJoined;

  @HiveField(12)
  final double currentProgress;

  @HiveField(13)
  final String privacy; // public, private, invite-only

  @HiveField(14)
  final String? creatorId;

  @HiveField(15)
  final List<String>? prizes;

  FitnessChallenge({
    required this.id,
    required this.name,
    required this.description,
    required this.challengeType,
    required this.activityType,
    required this.targetValue,
    required this.targetUnit,
    required this.startDate,
    required this.endDate,
    required this.participants,
    this.imageUrl,
    this.isJoined = false,
    this.currentProgress = 0,
    required this.privacy,
    this.creatorId,
    this.prizes,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isUpcoming => DateTime.now().isBefore(startDate);
  bool get isCompleted => DateTime.now().isAfter(endDate);

  double get progressPercentage => (currentProgress / targetValue * 100).clamp(0, 100);

  int get daysRemaining {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  String get statusEmoji {
    if (isCompleted) return '✅';
    if (isActive) return '🔥';
    return '📅';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'challengeType': challengeType,
    'activityType': activityType,
    'targetValue': targetValue,
    'targetUnit': targetUnit,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'participants': participants.map((p) => p.toJson()).toList(),
    'imageUrl': imageUrl,
    'isJoined': isJoined,
    'currentProgress': currentProgress,
    'privacy': privacy,
    'creatorId': creatorId,
    'prizes': prizes,
  };

  factory FitnessChallenge.fromJson(Map<String, dynamic> json) => FitnessChallenge(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    challengeType: json['challengeType'] ?? 'distance',
    activityType: json['activityType'] ?? 'any',
    targetValue: (json['targetValue'] ?? 0).toDouble(),
    targetUnit: json['targetUnit'] ?? 'km',
    startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
    endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
    participants: (json['participants'] as List<dynamic>?)
        ?.map((p) => ChallengeParticipant.fromJson(p))
        .toList() ?? [],
    imageUrl: json['imageUrl'],
    isJoined: json['isJoined'] ?? false,
    currentProgress: (json['currentProgress'] ?? 0).toDouble(),
    privacy: json['privacy'] ?? 'public',
    creatorId: json['creatorId'],
    prizes: (json['prizes'] as List<dynamic>?)?.cast<String>(),
  );
}

@HiveType(typeId: 75)
class ChallengeParticipant extends HiveObject {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String userName;

  @HiveField(2)
  final String? avatarUrl;

  @HiveField(3)
  final double progress;

  @HiveField(4)
  final int rank;

  @HiveField(5)
  final DateTime joinedAt;

  @HiveField(6)
  final bool isCurrentUser;

  ChallengeParticipant({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.progress,
    required this.rank,
    required this.joinedAt,
    this.isCurrentUser = false,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'avatarUrl': avatarUrl,
    'progress': progress,
    'rank': rank,
    'joinedAt': joinedAt.toIso8601String(),
    'isCurrentUser': isCurrentUser,
  };

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) => ChallengeParticipant(
    userId: json['userId'] ?? '',
    userName: json['userName'] ?? '',
    avatarUrl: json['avatarUrl'],
    progress: (json['progress'] ?? 0).toDouble(),
    rank: json['rank'] ?? 0,
    joinedAt: DateTime.parse(json['joinedAt'] ?? DateTime.now().toIso8601String()),
    isCurrentUser: json['isCurrentUser'] ?? false,
  );
}

/// Social Activity Feed Item
@HiveType(typeId: 76)
class SocialActivityItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String userName;

  @HiveField(3)
  final String? userAvatarUrl;

  @HiveField(4)
  final String activityType; // workout, achievement, challenge_joined, etc.

  @HiveField(5)
  final String title;

  @HiveField(6)
  final String? description;

  @HiveField(7)
  final DateTime timestamp;

  @HiveField(8)
  final Map<String, dynamic>? activityData;

  @HiveField(9)
  final int kudosCount;

  @HiveField(10)
  final List<String>? commentIds;

  @HiveField(11)
  final bool hasGivenKudos;

  SocialActivityItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.activityType,
    required this.title,
    this.description,
    required this.timestamp,
    this.activityData,
    this.kudosCount = 0,
    this.commentIds,
    this.hasGivenKudos = false,
  });

  String get activityEmoji {
    switch (activityType) {
      case 'workout': return '🏃';
      case 'achievement': return '🏆';
      case 'challenge_joined': return '🎯';
      case 'pr': return '⚡';
      case 'streak': return '🔥';
      default: return '💪';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userAvatarUrl': userAvatarUrl,
    'activityType': activityType,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'activityData': activityData,
    'kudosCount': kudosCount,
    'commentIds': commentIds,
    'hasGivenKudos': hasGivenKudos,
  };

  factory SocialActivityItem.fromJson(Map<String, dynamic> json) => SocialActivityItem(
    id: json['id'] ?? '',
    userId: json['userId'] ?? '',
    userName: json['userName'] ?? '',
    userAvatarUrl: json['userAvatarUrl'],
    activityType: json['activityType'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    activityData: json['activityData'],
    kudosCount: json['kudosCount'] ?? 0,
    commentIds: (json['commentIds'] as List<dynamic>?)?.cast<String>(),
    hasGivenKudos: json['hasGivenKudos'] ?? false,
  );
}

/// User Profile Stats for Social
class SocialProfile {
  final String userId;
  final String userName;
  final String? avatarUrl;
  final int totalActivities;
  final double totalDistanceKm;
  final int totalDurationMinutes;
  final int followersCount;
  final int followingCount;
  final int kudosReceived;
  final int achievementsCount;
  final List<String> recentAchievements;

  SocialProfile({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.totalActivities,
    required this.totalDistanceKm,
    required this.totalDurationMinutes,
    required this.followersCount,
    required this.followingCount,
    required this.kudosReceived,
    required this.achievementsCount,
    required this.recentAchievements,
  });
}
