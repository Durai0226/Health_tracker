import 'dart:convert';

/// Challenge status
enum ChallengeStatus {
  pending,    // Waiting for participants to accept
  active,     // Currently running
  completed,  // Ended successfully
  cancelled,  // Cancelled by creator
  expired,    // Ended without completion
}

/// Participant in a challenge
class ChallengeParticipant {
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  final bool hasAccepted;
  final int completedDays;
  final int totalDays;
  final DateTime? joinedAt;

  const ChallengeParticipant({
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    this.hasAccepted = false,
    this.completedDays = 0,
    this.totalDays = 0,
    this.joinedAt,
  });

  double get completionRate {
    if (totalDays == 0) return 0.0;
    return completedDays / totalDays;
  }

  int get completionPercentage => (completionRate * 100).round();

  ChallengeParticipant copyWith({
    String? oderId,
    String? displayName,
    String? avatarUrl,
    bool? hasAccepted,
    int? completedDays,
    int? totalDays,
    DateTime? joinedAt,
  }) {
    return ChallengeParticipant(
      oderId: oderId ?? this.oderId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasAccepted: hasAccepted ?? this.hasAccepted,
      completedDays: completedDays ?? this.completedDays,
      totalDays: totalDays ?? this.totalDays,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': oderId,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'hasAccepted': hasAccepted,
      'completedDays': completedDays,
      'totalDays': totalDays,
      'joinedAt': joinedAt?.toIso8601String(),
    };
  }

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      oderId: json['userId'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hasAccepted: json['hasAccepted'] as bool? ?? false,
      completedDays: json['completedDays'] as int? ?? 0,
      totalDays: json['totalDays'] as int? ?? 0,
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
    );
  }
}

/// Habit challenge with friends
class HabitChallenge {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String? description;
  final List<String> habitIds; // Habits included in challenge
  final List<String> habitNames;
  final List<ChallengeParticipant> participants;
  final DateTime startDate;
  final DateTime endDate;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HabitChallenge({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    this.description,
    required this.habitIds,
    this.habitNames = const [],
    this.participants = const [],
    required this.startDate,
    required this.endDate,
    this.status = ChallengeStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total days of challenge
  int get totalDays => endDate.difference(startDate).inDays + 1;

  /// Days elapsed
  int get daysElapsed {
    final now = DateTime.now();
    if (now.isBefore(startDate)) return 0;
    if (now.isAfter(endDate)) return totalDays;
    return now.difference(startDate).inDays + 1;
  }

  /// Days remaining
  int get daysRemaining => totalDays - daysElapsed;

  /// Progress (0.0 - 1.0)
  double get progress => daysElapsed / totalDays;

  /// Check if challenge is active
  bool get isActive => status == ChallengeStatus.active;

  /// Check if user has accepted
  bool hasUserAccepted(String oderId) {
    return participants.any((p) => p.oderId == oderId && p.hasAccepted);
  }

  /// Get leaderboard (sorted by completion)
  List<ChallengeParticipant> get leaderboard {
    final sorted = List<ChallengeParticipant>.from(participants);
    sorted.sort((a, b) => b.completedDays.compareTo(a.completedDays));
    return sorted;
  }

  HabitChallenge copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? title,
    String? description,
    List<String>? habitIds,
    List<String>? habitNames,
    List<ChallengeParticipant>? participants,
    DateTime? startDate,
    DateTime? endDate,
    ChallengeStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitChallenge(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      description: description ?? this.description,
      habitIds: habitIds ?? this.habitIds,
      habitNames: habitNames ?? this.habitNames,
      participants: participants ?? this.participants,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'description': description,
      'habitIds': habitIds,
      'habitNames': habitNames,
      'participants': participants.map((p) => p.toJson()).toList(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HabitChallenge.fromJson(Map<String, dynamic> json) {
    return HabitChallenge(
      id: json['id'] as String,
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      habitIds: (json['habitIds'] as List<dynamic>).cast<String>(),
      habitNames: (json['habitNames'] as List<dynamic>?)?.cast<String>() ?? [],
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => ChallengeParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: ChallengeStatus.values[json['status'] as int? ?? 0],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitChallenge.fromJsonString(String jsonString) {
    return HabitChallenge.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitChallenge &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
