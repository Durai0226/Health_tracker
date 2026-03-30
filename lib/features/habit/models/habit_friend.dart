import 'dart:convert';

/// Friend request status
enum FriendStatus {
  pending,
  accepted,
  declined,
  blocked,
}

/// User level/tier based on points
enum UserTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

/// Friend profile for habit challenges
class HabitFriend {
  final String oderId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final FriendStatus status;
  final int totalPoints;
  final int cityLevel;
  final String? cityName;
  final int currentStreak;
  final int habitsCount;
  final DateTime? lastActive;
  final DateTime requestedAt;
  final DateTime? acceptedAt;

  const HabitFriend({
    required this.oderId,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.status = FriendStatus.pending,
    this.totalPoints = 0,
    this.cityLevel = 1,
    this.cityName,
    this.currentStreak = 0,
    this.habitsCount = 0,
    this.lastActive,
    required this.requestedAt,
    this.acceptedAt,
  });

  /// Get user tier based on points
  UserTier get tier {
    if (totalPoints >= 10000) return UserTier.diamond;
    if (totalPoints >= 5000) return UserTier.platinum;
    if (totalPoints >= 2000) return UserTier.gold;
    if (totalPoints >= 500) return UserTier.silver;
    return UserTier.bronze;
  }

  /// Get tier label
  String get tierLabel {
    switch (tier) {
      case UserTier.bronze:
        return 'Bronze';
      case UserTier.silver:
        return 'Silver';
      case UserTier.gold:
        return 'Gold';
      case UserTier.platinum:
        return 'Platinum';
      case UserTier.diamond:
        return 'Diamond';
    }
  }

  /// Check if friend request is accepted
  bool get isAccepted => status == FriendStatus.accepted;

  /// Check if friend request is pending
  bool get isPending => status == FriendStatus.pending;

  HabitFriend copyWith({
    String? oderId,
    String? displayName,
    String? email,
    String? avatarUrl,
    FriendStatus? status,
    int? totalPoints,
    int? cityLevel,
    String? cityName,
    int? currentStreak,
    int? habitsCount,
    DateTime? lastActive,
    DateTime? requestedAt,
    DateTime? acceptedAt,
  }) {
    return HabitFriend(
      oderId: oderId ?? this.oderId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      totalPoints: totalPoints ?? this.totalPoints,
      cityLevel: cityLevel ?? this.cityLevel,
      cityName: cityName ?? this.cityName,
      currentStreak: currentStreak ?? this.currentStreak,
      habitsCount: habitsCount ?? this.habitsCount,
      lastActive: lastActive ?? this.lastActive,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': oderId,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'status': status.index,
      'totalPoints': totalPoints,
      'cityLevel': cityLevel,
      'cityName': cityName,
      'currentStreak': currentStreak,
      'habitsCount': habitsCount,
      'lastActive': lastActive?.toIso8601String(),
      'requestedAt': requestedAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
    };
  }

  factory HabitFriend.fromJson(Map<String, dynamic> json) {
    return HabitFriend(
      oderId: json['userId'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: FriendStatus.values[json['status'] as int? ?? 0],
      totalPoints: json['totalPoints'] as int? ?? 0,
      cityLevel: json['cityLevel'] as int? ?? 1,
      cityName: json['cityName'] as String?,
      currentStreak: json['currentStreak'] as int? ?? 0,
      habitsCount: json['habitsCount'] as int? ?? 0,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : null,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitFriend.fromJsonString(String jsonString) {
    return HabitFriend.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitFriend &&
          runtimeType == other.runtimeType &&
          oderId == other.oderId;

  @override
  int get hashCode => oderId.hashCode;
}

/// User's own habit profile (for sharing with friends)
class HabitProfile {
  final String oderId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final int totalPoints;
  final int coins;
  final int cityLevel;
  final String? cityName;
  final int currentStreak;
  final int bestStreak;
  final int habitsCount;
  final int challengesWon;
  final int challengesParticipated;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HabitProfile({
    required this.oderId,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.totalPoints = 0,
    this.coins = 0,
    this.cityLevel = 1,
    this.cityName,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.habitsCount = 0,
    this.challengesWon = 0,
    this.challengesParticipated = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  UserTier get tier {
    if (totalPoints >= 10000) return UserTier.diamond;
    if (totalPoints >= 5000) return UserTier.platinum;
    if (totalPoints >= 2000) return UserTier.gold;
    if (totalPoints >= 500) return UserTier.silver;
    return UserTier.bronze;
  }

  HabitProfile copyWith({
    String? oderId,
    String? displayName,
    String? email,
    String? avatarUrl,
    int? totalPoints,
    int? coins,
    int? cityLevel,
    String? cityName,
    int? currentStreak,
    int? bestStreak,
    int? habitsCount,
    int? challengesWon,
    int? challengesParticipated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitProfile(
      oderId: oderId ?? this.oderId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalPoints: totalPoints ?? this.totalPoints,
      coins: coins ?? this.coins,
      cityLevel: cityLevel ?? this.cityLevel,
      cityName: cityName ?? this.cityName,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      habitsCount: habitsCount ?? this.habitsCount,
      challengesWon: challengesWon ?? this.challengesWon,
      challengesParticipated: challengesParticipated ?? this.challengesParticipated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': oderId,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'totalPoints': totalPoints,
      'coins': coins,
      'cityLevel': cityLevel,
      'cityName': cityName,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'habitsCount': habitsCount,
      'challengesWon': challengesWon,
      'challengesParticipated': challengesParticipated,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HabitProfile.fromJson(Map<String, dynamic> json) {
    return HabitProfile(
      oderId: json['userId'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      totalPoints: json['totalPoints'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      cityLevel: json['cityLevel'] as int? ?? 1,
      cityName: json['cityName'] as String?,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      habitsCount: json['habitsCount'] as int? ?? 0,
      challengesWon: json['challengesWon'] as int? ?? 0,
      challengesParticipated: json['challengesParticipated'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitProfile.fromJsonString(String jsonString) {
    return HabitProfile.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
