import 'package:flutter/material.dart';
import '../theme/luna_theme.dart';

/// Enhanced partner feature models for Luna Cycle
/// Partner sharing, permissions, and data sync based on Safeline case study

/// Partner profile with enhanced permissions
class LunaPartnerProfile {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final LunaPartnerStatus status;
  final LunaPartnerPermissions permissions;
  final DateTime? linkedAt;
  final DateTime? lastSyncAt;
  final String? inviteCode;
  final DateTime? inviteExpiresAt;
  final LunaPartnerType partnerType;
  final String? customNickname;
  final bool notificationsEnabled;

  const LunaPartnerProfile({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.status = LunaPartnerStatus.pending,
    this.permissions = const LunaPartnerPermissions(),
    this.linkedAt,
    this.lastSyncAt,
    this.inviteCode,
    this.inviteExpiresAt,
    this.partnerType = LunaPartnerType.partner,
    this.customNickname,
    this.notificationsEnabled = true,
  });

  LunaPartnerProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    LunaPartnerStatus? status,
    LunaPartnerPermissions? permissions,
    DateTime? linkedAt,
    DateTime? lastSyncAt,
    String? inviteCode,
    DateTime? inviteExpiresAt,
    LunaPartnerType? partnerType,
    String? customNickname,
    bool? notificationsEnabled,
  }) {
    return LunaPartnerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      linkedAt: linkedAt ?? this.linkedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
      partnerType: partnerType ?? this.partnerType,
      customNickname: customNickname ?? this.customNickname,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'photoUrl': photoUrl,
    'status': status.index,
    'permissions': permissions.toJson(),
    'linkedAt': linkedAt?.toIso8601String(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'inviteCode': inviteCode,
    'inviteExpiresAt': inviteExpiresAt?.toIso8601String(),
    'partnerType': partnerType.index,
    'customNickname': customNickname,
    'notificationsEnabled': notificationsEnabled,
  };

  factory LunaPartnerProfile.fromJson(Map<String, dynamic> json) {
    return LunaPartnerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: LunaPartnerStatus.values[json['status'] as int? ?? 0],
      permissions: json['permissions'] != null
          ? LunaPartnerPermissions.fromJson(json['permissions'] as Map<String, dynamic>)
          : const LunaPartnerPermissions(),
      linkedAt: json['linkedAt'] != null 
          ? DateTime.parse(json['linkedAt'] as String) 
          : null,
      lastSyncAt: json['lastSyncAt'] != null 
          ? DateTime.parse(json['lastSyncAt'] as String) 
          : null,
      inviteCode: json['inviteCode'] as String?,
      inviteExpiresAt: json['inviteExpiresAt'] != null 
          ? DateTime.parse(json['inviteExpiresAt'] as String) 
          : null,
      partnerType: LunaPartnerType.values[json['partnerType'] as int? ?? 0],
      customNickname: json['customNickname'] as String?,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  bool get isLinked => status == LunaPartnerStatus.linked;
  bool get isPending => status == LunaPartnerStatus.pending;
  
  String get displayName => customNickname ?? name;
  
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (i) => chars[(random + i * 7) % chars.length]).join();
  }
}

/// Partner permissions configuration
class LunaPartnerPermissions {
  final bool canViewCyclePhase;
  final bool canViewPeriodDates;
  final bool canViewFertileWindow;
  final bool canViewSymptoms;
  final bool canViewMood;
  final bool canViewNotes;
  final bool canViewPregnancyMode;
  final bool canReceiveAlerts;
  final bool canSendMessages;
  final bool canViewLocation; // For safety feature
  final bool canViewInsights;

  const LunaPartnerPermissions({
    this.canViewCyclePhase = true,
    this.canViewPeriodDates = true,
    this.canViewFertileWindow = false,
    this.canViewSymptoms = false,
    this.canViewMood = false,
    this.canViewNotes = false,
    this.canViewPregnancyMode = true,
    this.canReceiveAlerts = true,
    this.canSendMessages = true,
    this.canViewLocation = false,
    this.canViewInsights = false,
  });

  LunaPartnerPermissions copyWith({
    bool? canViewCyclePhase,
    bool? canViewPeriodDates,
    bool? canViewFertileWindow,
    bool? canViewSymptoms,
    bool? canViewMood,
    bool? canViewNotes,
    bool? canViewPregnancyMode,
    bool? canReceiveAlerts,
    bool? canSendMessages,
    bool? canViewLocation,
    bool? canViewInsights,
  }) {
    return LunaPartnerPermissions(
      canViewCyclePhase: canViewCyclePhase ?? this.canViewCyclePhase,
      canViewPeriodDates: canViewPeriodDates ?? this.canViewPeriodDates,
      canViewFertileWindow: canViewFertileWindow ?? this.canViewFertileWindow,
      canViewSymptoms: canViewSymptoms ?? this.canViewSymptoms,
      canViewMood: canViewMood ?? this.canViewMood,
      canViewNotes: canViewNotes ?? this.canViewNotes,
      canViewPregnancyMode: canViewPregnancyMode ?? this.canViewPregnancyMode,
      canReceiveAlerts: canReceiveAlerts ?? this.canReceiveAlerts,
      canSendMessages: canSendMessages ?? this.canSendMessages,
      canViewLocation: canViewLocation ?? this.canViewLocation,
      canViewInsights: canViewInsights ?? this.canViewInsights,
    );
  }

  Map<String, dynamic> toJson() => {
    'canViewCyclePhase': canViewCyclePhase,
    'canViewPeriodDates': canViewPeriodDates,
    'canViewFertileWindow': canViewFertileWindow,
    'canViewSymptoms': canViewSymptoms,
    'canViewMood': canViewMood,
    'canViewNotes': canViewNotes,
    'canViewPregnancyMode': canViewPregnancyMode,
    'canReceiveAlerts': canReceiveAlerts,
    'canSendMessages': canSendMessages,
    'canViewLocation': canViewLocation,
    'canViewInsights': canViewInsights,
  };

  factory LunaPartnerPermissions.fromJson(Map<String, dynamic> json) {
    return LunaPartnerPermissions(
      canViewCyclePhase: json['canViewCyclePhase'] as bool? ?? true,
      canViewPeriodDates: json['canViewPeriodDates'] as bool? ?? true,
      canViewFertileWindow: json['canViewFertileWindow'] as bool? ?? false,
      canViewSymptoms: json['canViewSymptoms'] as bool? ?? false,
      canViewMood: json['canViewMood'] as bool? ?? false,
      canViewNotes: json['canViewNotes'] as bool? ?? false,
      canViewPregnancyMode: json['canViewPregnancyMode'] as bool? ?? true,
      canReceiveAlerts: json['canReceiveAlerts'] as bool? ?? true,
      canSendMessages: json['canSendMessages'] as bool? ?? true,
      canViewLocation: json['canViewLocation'] as bool? ?? false,
      canViewInsights: json['canViewInsights'] as bool? ?? false,
    );
  }

  /// Preset: Minimal sharing
  static const minimal = LunaPartnerPermissions(
    canViewCyclePhase: true,
    canViewPeriodDates: false,
    canViewFertileWindow: false,
    canViewSymptoms: false,
    canViewMood: false,
    canViewNotes: false,
    canViewPregnancyMode: false,
    canReceiveAlerts: false,
    canSendMessages: true,
    canViewLocation: false,
    canViewInsights: false,
  );

  /// Preset: Standard sharing
  static const standard = LunaPartnerPermissions(
    canViewCyclePhase: true,
    canViewPeriodDates: true,
    canViewFertileWindow: false,
    canViewSymptoms: false,
    canViewMood: true,
    canViewNotes: false,
    canViewPregnancyMode: true,
    canReceiveAlerts: true,
    canSendMessages: true,
    canViewLocation: false,
    canViewInsights: false,
  );

  /// Preset: Full sharing (TTC couples)
  static const full = LunaPartnerPermissions(
    canViewCyclePhase: true,
    canViewPeriodDates: true,
    canViewFertileWindow: true,
    canViewSymptoms: true,
    canViewMood: true,
    canViewNotes: true,
    canViewPregnancyMode: true,
    canReceiveAlerts: true,
    canSendMessages: true,
    canViewLocation: true,
    canViewInsights: true,
  );
}

/// Shared data snapshot for partner
class LunaPartnerSharedData {
  final LunaCyclePhase? currentPhase;
  final int? daysUntilPeriod;
  final int? daysIntoPeriod;
  final bool? isOnPeriod;
  final bool? isFertile;
  final String? currentMood;
  final List<String>? recentSymptoms;
  final bool? isPregnancyMode;
  final int? pregnancyWeek;
  final DateTime? nextPeriodDate;
  final DateTime? ovulationDate;
  final DateTime updatedAt;

  const LunaPartnerSharedData({
    this.currentPhase,
    this.daysUntilPeriod,
    this.daysIntoPeriod,
    this.isOnPeriod,
    this.isFertile,
    this.currentMood,
    this.recentSymptoms,
    this.isPregnancyMode,
    this.pregnancyWeek,
    this.nextPeriodDate,
    this.ovulationDate,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'currentPhase': currentPhase?.index,
    'daysUntilPeriod': daysUntilPeriod,
    'daysIntoPeriod': daysIntoPeriod,
    'isOnPeriod': isOnPeriod,
    'isFertile': isFertile,
    'currentMood': currentMood,
    'recentSymptoms': recentSymptoms,
    'isPregnancyMode': isPregnancyMode,
    'pregnancyWeek': pregnancyWeek,
    'nextPeriodDate': nextPeriodDate?.toIso8601String(),
    'ovulationDate': ovulationDate?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LunaPartnerSharedData.fromJson(Map<String, dynamic> json) {
    return LunaPartnerSharedData(
      currentPhase: json['currentPhase'] != null 
          ? LunaCyclePhase.values[json['currentPhase'] as int] 
          : null,
      daysUntilPeriod: json['daysUntilPeriod'] as int?,
      daysIntoPeriod: json['daysIntoPeriod'] as int?,
      isOnPeriod: json['isOnPeriod'] as bool?,
      isFertile: json['isFertile'] as bool?,
      currentMood: json['currentMood'] as String?,
      recentSymptoms: (json['recentSymptoms'] as List<dynamic>?)?.cast<String>(),
      isPregnancyMode: json['isPregnancyMode'] as bool?,
      pregnancyWeek: json['pregnancyWeek'] as int?,
      nextPeriodDate: json['nextPeriodDate'] != null 
          ? DateTime.parse(json['nextPeriodDate'] as String) 
          : null,
      ovulationDate: json['ovulationDate'] != null 
          ? DateTime.parse(json['ovulationDate'] as String) 
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Partner message for communication
class LunaPartnerMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final LunaMessageType type;
  final DateTime sentAt;
  final bool isRead;
  final String? relatedDataJson; // For quick actions, emoji reactions, etc.

  const LunaPartnerMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = LunaMessageType.text,
    required this.sentAt,
    this.isRead = false,
    this.relatedDataJson,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'type': type.index,
    'sentAt': sentAt.toIso8601String(),
    'isRead': isRead,
    'relatedDataJson': relatedDataJson,
  };

  factory LunaPartnerMessage.fromJson(Map<String, dynamic> json) {
    return LunaPartnerMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      content: json['content'] as String,
      type: LunaMessageType.values[json['type'] as int? ?? 0],
      sentAt: DateTime.parse(json['sentAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      relatedDataJson: json['relatedDataJson'] as String?,
    );
  }
}

/// Partner status
enum LunaPartnerStatus {
  pending,
  linked,
  paused,
  removed,
}

extension LunaPartnerStatusExtension on LunaPartnerStatus {
  String get displayName {
    switch (this) {
      case LunaPartnerStatus.pending: return 'Pending';
      case LunaPartnerStatus.linked: return 'Linked';
      case LunaPartnerStatus.paused: return 'Paused';
      case LunaPartnerStatus.removed: return 'Removed';
    }
  }

  Color get color {
    switch (this) {
      case LunaPartnerStatus.pending: return const Color(0xFFFF9800);
      case LunaPartnerStatus.linked: return const Color(0xFF4CAF50);
      case LunaPartnerStatus.paused: return const Color(0xFF9E9E9E);
      case LunaPartnerStatus.removed: return const Color(0xFFE57373);
    }
  }
}

/// Partner type
enum LunaPartnerType {
  partner,
  spouse,
  friend,
  familyMember,
  caregiver,
}

extension LunaPartnerTypeExtension on LunaPartnerType {
  String get displayName {
    switch (this) {
      case LunaPartnerType.partner: return 'Partner';
      case LunaPartnerType.spouse: return 'Spouse';
      case LunaPartnerType.friend: return 'Friend';
      case LunaPartnerType.familyMember: return 'Family Member';
      case LunaPartnerType.caregiver: return 'Caregiver';
    }
  }

  IconData get icon {
    switch (this) {
      case LunaPartnerType.partner: return Icons.favorite;
      case LunaPartnerType.spouse: return Icons.favorite;
      case LunaPartnerType.friend: return Icons.people;
      case LunaPartnerType.familyMember: return Icons.family_restroom;
      case LunaPartnerType.caregiver: return Icons.health_and_safety;
    }
  }
}

/// Message types
enum LunaMessageType {
  text,
  emoji,
  quickAction,
  supportRequest,
  cycleUpdate,
}

extension LunaMessageTypeExtension on LunaMessageType {
  String get displayName {
    switch (this) {
      case LunaMessageType.text: return 'Message';
      case LunaMessageType.emoji: return 'Emoji';
      case LunaMessageType.quickAction: return 'Quick Action';
      case LunaMessageType.supportRequest: return 'Support Request';
      case LunaMessageType.cycleUpdate: return 'Cycle Update';
    }
  }
}

/// Predefined quick actions for partner communication
class LunaPartnerQuickActions {
  static const List<LunaQuickAction> all = [
    LunaQuickAction('hug', 'Send a hug', '🤗'),
    LunaQuickAction('love', 'Send love', '❤️'),
    LunaQuickAction('thinking', 'Thinking of you', '💭'),
    LunaQuickAction('chocolate', 'Bring chocolate', '🍫'),
    LunaQuickAction('tea', 'Bring tea', '🍵'),
    LunaQuickAction('heating-pad', 'Bring heating pad', '🔥'),
    LunaQuickAction('rest', 'I need rest', '😴'),
    LunaQuickAction('company', 'Want company', '👥'),
    LunaQuickAction('space', 'Need space', '🌙'),
    LunaQuickAction('talk', 'Want to talk', '💬'),
  ];
}

/// Quick action for partner
class LunaQuickAction {
  final String id;
  final String label;
  final String emoji;

  const LunaQuickAction(this.id, this.label, this.emoji);
}

/// Partner notification preferences
class LunaPartnerNotificationPrefs {
  final bool periodStarting;
  final bool periodEnded;
  final bool fertileWindowStarting;
  final bool ovulationDay;
  final bool moodChanges;
  final bool symptomAlerts;
  final bool dailySummary;
  final bool weeklyInsights;
  final bool safetyAlerts;

  const LunaPartnerNotificationPrefs({
    this.periodStarting = true,
    this.periodEnded = false,
    this.fertileWindowStarting = false,
    this.ovulationDay = false,
    this.moodChanges = false,
    this.symptomAlerts = false,
    this.dailySummary = false,
    this.weeklyInsights = true,
    this.safetyAlerts = true,
  });

  Map<String, dynamic> toJson() => {
    'periodStarting': periodStarting,
    'periodEnded': periodEnded,
    'fertileWindowStarting': fertileWindowStarting,
    'ovulationDay': ovulationDay,
    'moodChanges': moodChanges,
    'symptomAlerts': symptomAlerts,
    'dailySummary': dailySummary,
    'weeklyInsights': weeklyInsights,
    'safetyAlerts': safetyAlerts,
  };

  factory LunaPartnerNotificationPrefs.fromJson(Map<String, dynamic> json) {
    return LunaPartnerNotificationPrefs(
      periodStarting: json['periodStarting'] as bool? ?? true,
      periodEnded: json['periodEnded'] as bool? ?? false,
      fertileWindowStarting: json['fertileWindowStarting'] as bool? ?? false,
      ovulationDay: json['ovulationDay'] as bool? ?? false,
      moodChanges: json['moodChanges'] as bool? ?? false,
      symptomAlerts: json['symptomAlerts'] as bool? ?? false,
      dailySummary: json['dailySummary'] as bool? ?? false,
      weeklyInsights: json['weeklyInsights'] as bool? ?? true,
      safetyAlerts: json['safetyAlerts'] as bool? ?? true,
    );
  }
}
