import 'package:flutter/material.dart';
import 'focus_plant.dart';

enum GroupSessionStatus {
  waiting,
  inProgress,
  completed,
  failed,
  cancelled,
}

extension GroupSessionStatusExtension on GroupSessionStatus {
  String get name {
    switch (this) {
      case GroupSessionStatus.waiting:
        return 'Waiting';
      case GroupSessionStatus.inProgress:
        return 'In Progress';
      case GroupSessionStatus.completed:
        return 'Completed';
      case GroupSessionStatus.failed:
        return 'Failed';
      case GroupSessionStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case GroupSessionStatus.waiting:
        return '⏳';
      case GroupSessionStatus.inProgress:
        return '🌱';
      case GroupSessionStatus.completed:
        return '🌳';
      case GroupSessionStatus.failed:
        return '💀';
      case GroupSessionStatus.cancelled:
        return '❌';
    }
  }

  Color get color {
    switch (this) {
      case GroupSessionStatus.waiting:
        return const Color(0xFFFF9800);
      case GroupSessionStatus.inProgress:
        return const Color(0xFF4CAF50);
      case GroupSessionStatus.completed:
        return const Color(0xFF2196F3);
      case GroupSessionStatus.failed:
        return const Color(0xFFF44336);
      case GroupSessionStatus.cancelled:
        return const Color(0xFF9E9E9E);
    }
  }
}

class GroupFocusSession {
  final String id;
  final String hostUserId;
  final String hostDisplayName;
  final String roomCode;
  final int targetMinutes;
  final PlantType plantType;
  final List<GroupParticipant> participants;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final GroupSessionStatus status;
  final int maxParticipants;
  final bool isPublic;
  final String? failedByUserId;

  GroupFocusSession({
    required this.id,
    required this.hostUserId,
    required this.hostDisplayName,
    required this.roomCode,
    required this.targetMinutes,
    required this.plantType,
    required this.participants,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.status = GroupSessionStatus.waiting,
    this.maxParticipants = 10,
    this.isPublic = false,
    this.failedByUserId,
  });

  bool get canStart => participants.where((p) => p.isReady).length >= 2;
  bool get isHost => hostUserId == hostUserId;
  int get participantCount => participants.length;
  int get readyCount => participants.where((p) => p.isReady).length;

  Duration? get remainingTime {
    if (startedAt == null || status != GroupSessionStatus.inProgress) return null;
    final endTime = startedAt!.add(Duration(minutes: targetMinutes));
    final now = DateTime.now();
    if (now.isAfter(endTime)) return Duration.zero;
    return endTime.difference(now);
  }

  double get progress {
    if (startedAt == null || status != GroupSessionStatus.inProgress) return 0;
    final elapsed = DateTime.now().difference(startedAt!).inSeconds;
    final total = targetMinutes * 60;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostUserId': hostUserId,
        'hostDisplayName': hostDisplayName,
        'roomCode': roomCode,
        'targetMinutes': targetMinutes,
        'plantType': plantType.index,
        'participants': participants.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'status': status.index,
        'maxParticipants': maxParticipants,
        'isPublic': isPublic,
        'failedByUserId': failedByUserId,
      };

  factory GroupFocusSession.fromJson(Map<String, dynamic> json) => GroupFocusSession(
        id: json['id'] ?? '',
        hostUserId: json['hostUserId'] ?? '',
        hostDisplayName: json['hostDisplayName'] ?? 'Host',
        roomCode: json['roomCode'] ?? '',
        targetMinutes: json['targetMinutes'] ?? 25,
        plantType: PlantType.values[json['plantType'] ?? 0],
        participants: (json['participants'] as List?)
                ?.map((p) => GroupParticipant.fromJson(Map<String, dynamic>.from(p)))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt']),
        startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
        endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
        status: GroupSessionStatus.values[json['status'] ?? 0],
        maxParticipants: json['maxParticipants'] ?? 10,
        isPublic: json['isPublic'] ?? false,
        failedByUserId: json['failedByUserId'],
      );

  GroupFocusSession copyWith({
    String? id,
    String? hostUserId,
    String? hostDisplayName,
    String? roomCode,
    int? targetMinutes,
    PlantType? plantType,
    List<GroupParticipant>? participants,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    GroupSessionStatus? status,
    int? maxParticipants,
    bool? isPublic,
    String? failedByUserId,
  }) {
    return GroupFocusSession(
      id: id ?? this.id,
      hostUserId: hostUserId ?? this.hostUserId,
      hostDisplayName: hostDisplayName ?? this.hostDisplayName,
      roomCode: roomCode ?? this.roomCode,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      plantType: plantType ?? this.plantType,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      isPublic: isPublic ?? this.isPublic,
      failedByUserId: failedByUserId ?? this.failedByUserId,
    );
  }
}

class GroupParticipant {
  final String oderId;
  final String displayName;
  final String? avatarUrl;
  final bool isHost;
  final bool isReady;
  final DateTime joinedAt;
  final ParticipantStatus status;
  final double currentProgress;

  GroupParticipant({
    required this.oderId,
    required this.displayName,
    this.avatarUrl,
    this.isHost = false,
    this.isReady = false,
    required this.joinedAt,
    this.status = ParticipantStatus.waiting,
    this.currentProgress = 0,
  });

  Map<String, dynamic> toJson() => {
        'userId': oderId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'isHost': isHost,
        'isReady': isReady,
        'joinedAt': joinedAt.toIso8601String(),
        'status': status.index,
        'currentProgress': currentProgress,
      };

  factory GroupParticipant.fromJson(Map<String, dynamic> json) => GroupParticipant(
        oderId: json['userId'] ?? '',
        displayName: json['displayName'] ?? 'Participant',
        avatarUrl: json['avatarUrl'],
        isHost: json['isHost'] ?? false,
        isReady: json['isReady'] ?? false,
        joinedAt: DateTime.parse(json['joinedAt']),
        status: ParticipantStatus.values[json['status'] ?? 0],
        currentProgress: (json['currentProgress'] ?? 0).toDouble(),
      );

  GroupParticipant copyWith({
    String? oderId,
    String? displayName,
    String? avatarUrl,
    bool? isHost,
    bool? isReady,
    DateTime? joinedAt,
    ParticipantStatus? status,
    double? currentProgress,
  }) {
    return GroupParticipant(
      oderId: oderId ?? this.oderId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }
}

enum ParticipantStatus {
  waiting,
  ready,
  focusing,
  completed,
  abandoned,
  disconnected,
}

extension ParticipantStatusExtension on ParticipantStatus {
  String get name {
    switch (this) {
      case ParticipantStatus.waiting:
        return 'Waiting';
      case ParticipantStatus.ready:
        return 'Ready';
      case ParticipantStatus.focusing:
        return 'Focusing';
      case ParticipantStatus.completed:
        return 'Completed';
      case ParticipantStatus.abandoned:
        return 'Left Early';
      case ParticipantStatus.disconnected:
        return 'Disconnected';
    }
  }

  String get emoji {
    switch (this) {
      case ParticipantStatus.waiting:
        return '⏳';
      case ParticipantStatus.ready:
        return '✅';
      case ParticipantStatus.focusing:
        return '🎯';
      case ParticipantStatus.completed:
        return '🏆';
      case ParticipantStatus.abandoned:
        return '💔';
      case ParticipantStatus.disconnected:
        return '📵';
    }
  }

  Color get color {
    switch (this) {
      case ParticipantStatus.waiting:
        return const Color(0xFFFF9800);
      case ParticipantStatus.ready:
        return const Color(0xFF4CAF50);
      case ParticipantStatus.focusing:
        return const Color(0xFF2196F3);
      case ParticipantStatus.completed:
        return const Color(0xFF9C27B0);
      case ParticipantStatus.abandoned:
        return const Color(0xFFF44336);
      case ParticipantStatus.disconnected:
        return const Color(0xFF9E9E9E);
    }
  }
}

class GroupSessionInvite {
  final String id;
  final String sessionId;
  final String roomCode;
  final String hostDisplayName;
  final int targetMinutes;
  final int currentParticipants;
  final int maxParticipants;
  final DateTime expiresAt;

  GroupSessionInvite({
    required this.id,
    required this.sessionId,
    required this.roomCode,
    required this.hostDisplayName,
    required this.targetMinutes,
    required this.currentParticipants,
    required this.maxParticipants,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isFull => currentParticipants >= maxParticipants;

  String get shareLink => 'dlyminder://focus/join/$roomCode';

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'roomCode': roomCode,
        'hostDisplayName': hostDisplayName,
        'targetMinutes': targetMinutes,
        'currentParticipants': currentParticipants,
        'maxParticipants': maxParticipants,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory GroupSessionInvite.fromJson(Map<String, dynamic> json) => GroupSessionInvite(
        id: json['id'] ?? '',
        sessionId: json['sessionId'] ?? '',
        roomCode: json['roomCode'] ?? '',
        hostDisplayName: json['hostDisplayName'] ?? 'Host',
        targetMinutes: json['targetMinutes'] ?? 25,
        currentParticipants: json['currentParticipants'] ?? 0,
        maxParticipants: json['maxParticipants'] ?? 10,
        expiresAt: DateTime.parse(json['expiresAt']),
      );
}

class GroupSessionHistory {
  final String sessionId;
  final String hostDisplayName;
  final int targetMinutes;
  final int participantCount;
  final bool wasSuccessful;
  final DateTime completedAt;
  final PlantType plantType;

  GroupSessionHistory({
    required this.sessionId,
    required this.hostDisplayName,
    required this.targetMinutes,
    required this.participantCount,
    required this.wasSuccessful,
    required this.completedAt,
    required this.plantType,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'hostDisplayName': hostDisplayName,
        'targetMinutes': targetMinutes,
        'participantCount': participantCount,
        'wasSuccessful': wasSuccessful,
        'completedAt': completedAt.toIso8601String(),
        'plantType': plantType.index,
      };

  factory GroupSessionHistory.fromJson(Map<String, dynamic> json) => GroupSessionHistory(
        sessionId: json['sessionId'] ?? '',
        hostDisplayName: json['hostDisplayName'] ?? 'Host',
        targetMinutes: json['targetMinutes'] ?? 25,
        participantCount: json['participantCount'] ?? 0,
        wasSuccessful: json['wasSuccessful'] ?? false,
        completedAt: DateTime.parse(json['completedAt']),
        plantType: PlantType.values[json['plantType'] ?? 0],
      );
}
