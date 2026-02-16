import 'package:flutter/material.dart';

enum LeaderboardType {
  daily,
  weekly,
  monthly,
  allTime,
}

extension LeaderboardTypeExtension on LeaderboardType {
  String get name {
    switch (this) {
      case LeaderboardType.daily:
        return 'Today';
      case LeaderboardType.weekly:
        return 'This Week';
      case LeaderboardType.monthly:
        return 'This Month';
      case LeaderboardType.allTime:
        return 'All Time';
    }
  }

  String get shortName {
    switch (this) {
      case LeaderboardType.daily:
        return 'Day';
      case LeaderboardType.weekly:
        return 'Week';
      case LeaderboardType.monthly:
        return 'Month';
      case LeaderboardType.allTime:
        return 'All';
    }
  }
}

enum LeaderboardCategory {
  focusTime,
  treesPlanted,
  streakDays,
  sessionsCompleted,
  realTreesPlanted,
}

extension LeaderboardCategoryExtension on LeaderboardCategory {
  String get name {
    switch (this) {
      case LeaderboardCategory.focusTime:
        return 'Focus Time';
      case LeaderboardCategory.treesPlanted:
        return 'Virtual Trees';
      case LeaderboardCategory.streakDays:
        return 'Streak Days';
      case LeaderboardCategory.sessionsCompleted:
        return 'Sessions';
      case LeaderboardCategory.realTreesPlanted:
        return 'Real Trees';
    }
  }

  String get emoji {
    switch (this) {
      case LeaderboardCategory.focusTime:
        return '⏱️';
      case LeaderboardCategory.treesPlanted:
        return '🌳';
      case LeaderboardCategory.streakDays:
        return '🔥';
      case LeaderboardCategory.sessionsCompleted:
        return '✅';
      case LeaderboardCategory.realTreesPlanted:
        return '🌍';
    }
  }

  Color get color {
    switch (this) {
      case LeaderboardCategory.focusTime:
        return const Color(0xFF2196F3);
      case LeaderboardCategory.treesPlanted:
        return const Color(0xFF4CAF50);
      case LeaderboardCategory.streakDays:
        return const Color(0xFFFF9800);
      case LeaderboardCategory.sessionsCompleted:
        return const Color(0xFF9C27B0);
      case LeaderboardCategory.realTreesPlanted:
        return const Color(0xFF00BCD4);
    }
  }
}

class LeaderboardEntry {
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  final int rank;
  final int value;
  final bool isCurrentUser;
  final DateTime? lastUpdated;
  final int? previousRank;

  LeaderboardEntry({
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    required this.rank,
    required this.value,
    this.isCurrentUser = false,
    this.lastUpdated,
    this.previousRank,
  });

  int? get rankChange => previousRank != null ? previousRank! - rank : null;
  bool get rankImproved => rankChange != null && rankChange! > 0;
  bool get rankDeclined => rankChange != null && rankChange! < 0;

  Map<String, dynamic> toJson() => {
        'userId': oderId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'rank': rank,
        'value': value,
        'isCurrentUser': isCurrentUser,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'previousRank': previousRank,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        oderId: json['userId'] ?? '',
        displayName: json['displayName'] ?? 'Anonymous',
        avatarUrl: json['avatarUrl'],
        rank: json['rank'] ?? 0,
        value: json['value'] ?? 0,
        isCurrentUser: json['isCurrentUser'] ?? false,
        lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
        previousRank: json['previousRank'],
      );
}

class Leaderboard {
  final LeaderboardType type;
  final LeaderboardCategory category;
  final List<LeaderboardEntry> entries;
  final DateTime lastFetched;
  final LeaderboardEntry? currentUserEntry;

  Leaderboard({
    required this.type,
    required this.category,
    required this.entries,
    required this.lastFetched,
    this.currentUserEntry,
  });

  List<LeaderboardEntry> get topThree => entries.take(3).toList();
  List<LeaderboardEntry> get restOfList => entries.skip(3).toList();

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'category': category.index,
        'entries': entries.map((e) => e.toJson()).toList(),
        'lastFetched': lastFetched.toIso8601String(),
        'currentUserEntry': currentUserEntry?.toJson(),
      };

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        type: LeaderboardType.values[json['type'] ?? 0],
        category: LeaderboardCategory.values[json['category'] ?? 0],
        entries: (json['entries'] as List?)
                ?.map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        lastFetched: DateTime.parse(json['lastFetched']),
        currentUserEntry: json['currentUserEntry'] != null
            ? LeaderboardEntry.fromJson(Map<String, dynamic>.from(json['currentUserEntry']))
            : null,
      );
}

class FocusFriend {
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  final String? friendCode;
  final DateTime addedAt;
  final int totalFocusMinutes;
  final int currentStreak;
  final int treesPlanted;
  final bool isOnline;
  final bool isInFocusSession;

  FocusFriend({
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    this.friendCode,
    required this.addedAt,
    this.totalFocusMinutes = 0,
    this.currentStreak = 0,
    this.treesPlanted = 0,
    this.isOnline = false,
    this.isInFocusSession = false,
  });

  Map<String, dynamic> toJson() => {
        'userId': oderId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'friendCode': friendCode,
        'addedAt': addedAt.toIso8601String(),
        'totalFocusMinutes': totalFocusMinutes,
        'currentStreak': currentStreak,
        'treesPlanted': treesPlanted,
        'isOnline': isOnline,
        'isInFocusSession': isInFocusSession,
      };

  factory FocusFriend.fromJson(Map<String, dynamic> json) => FocusFriend(
        oderId: json['userId'] ?? '',
        displayName: json['displayName'] ?? 'Friend',
        avatarUrl: json['avatarUrl'],
        friendCode: json['friendCode'],
        addedAt: DateTime.parse(json['addedAt']),
        totalFocusMinutes: json['totalFocusMinutes'] ?? 0,
        currentStreak: json['currentStreak'] ?? 0,
        treesPlanted: json['treesPlanted'] ?? 0,
        isOnline: json['isOnline'] ?? false,
        isInFocusSession: json['isInFocusSession'] ?? false,
      );
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromDisplayName;
  final String? fromAvatarUrl;
  final String toUserId;
  final DateTime sentAt;
  final bool isPending;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromDisplayName,
    this.fromAvatarUrl,
    required this.toUserId,
    required this.sentAt,
    this.isPending = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'fromDisplayName': fromDisplayName,
        'fromAvatarUrl': fromAvatarUrl,
        'toUserId': toUserId,
        'sentAt': sentAt.toIso8601String(),
        'isPending': isPending,
      };

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: json['id'] ?? '',
        fromUserId: json['fromUserId'] ?? '',
        fromDisplayName: json['fromDisplayName'] ?? 'Unknown',
        fromAvatarUrl: json['fromAvatarUrl'],
        toUserId: json['toUserId'] ?? '',
        sentAt: DateTime.parse(json['sentAt']),
        isPending: json['isPending'] ?? true,
      );
}

class UserProfile {
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  final String friendCode;
  final int totalFocusMinutes;
  final int currentStreak;
  final int longestStreak;
  final int treesPlanted;
  final int realTreesPlanted;
  final DateTime joinedAt;
  final bool isPublicProfile;

  UserProfile({
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    required this.friendCode,
    this.totalFocusMinutes = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.treesPlanted = 0,
    this.realTreesPlanted = 0,
    required this.joinedAt,
    this.isPublicProfile = true,
  });

  int get totalFocusHours => totalFocusMinutes ~/ 60;

  Map<String, dynamic> toJson() => {
        'userId': oderId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'friendCode': friendCode,
        'totalFocusMinutes': totalFocusMinutes,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'treesPlanted': treesPlanted,
        'realTreesPlanted': realTreesPlanted,
        'joinedAt': joinedAt.toIso8601String(),
        'isPublicProfile': isPublicProfile,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        oderId: json['userId'] ?? '',
        displayName: json['displayName'] ?? 'User',
        avatarUrl: json['avatarUrl'],
        friendCode: json['friendCode'] ?? '',
        totalFocusMinutes: json['totalFocusMinutes'] ?? 0,
        currentStreak: json['currentStreak'] ?? 0,
        longestStreak: json['longestStreak'] ?? 0,
        treesPlanted: json['treesPlanted'] ?? 0,
        realTreesPlanted: json['realTreesPlanted'] ?? 0,
        joinedAt: DateTime.parse(json['joinedAt']),
        isPublicProfile: json['isPublicProfile'] ?? true,
      );

  UserProfile copyWith({
    String? oderId,
    String? displayName,
    String? avatarUrl,
    String? friendCode,
    int? totalFocusMinutes,
    int? currentStreak,
    int? longestStreak,
    int? treesPlanted,
    int? realTreesPlanted,
    DateTime? joinedAt,
    bool? isPublicProfile,
  }) {
    return UserProfile(
      oderId: oderId ?? this.oderId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      friendCode: friendCode ?? this.friendCode,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      treesPlanted: treesPlanted ?? this.treesPlanted,
      realTreesPlanted: realTreesPlanted ?? this.realTreesPlanted,
      joinedAt: joinedAt ?? this.joinedAt,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
    );
  }
}
