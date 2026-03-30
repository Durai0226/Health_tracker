import 'package:flutter/material.dart';
import '../theme/manrope_theme.dart';

/// Enum representing all available wellness activity types
enum WellnessActivityType {
  meditation,
  yoga,
  breathing,
  focus,
  walking,
  journaling,
}

extension WellnessActivityTypeExtension on WellnessActivityType {
  String get id {
    switch (this) {
      case WellnessActivityType.meditation:
        return 'meditation';
      case WellnessActivityType.yoga:
        return 'yoga';
      case WellnessActivityType.breathing:
        return 'breathing';
      case WellnessActivityType.focus:
        return 'focus';
      case WellnessActivityType.walking:
        return 'walking';
      case WellnessActivityType.journaling:
        return 'journaling';
    }
  }

  String get displayName {
    switch (this) {
      case WellnessActivityType.meditation:
        return 'Meditation';
      case WellnessActivityType.yoga:
        return 'Yoga';
      case WellnessActivityType.breathing:
        return 'Breathing';
      case WellnessActivityType.focus:
        return 'Focus';
      case WellnessActivityType.walking:
        return 'Walking';
      case WellnessActivityType.journaling:
        return 'Journaling';
    }
  }

  String get description {
    switch (this) {
      case WellnessActivityType.meditation:
        return 'Calm your mind with guided or unguided meditation sessions';
      case WellnessActivityType.yoga:
        return 'Practice mindful yoga poses and stretches';
      case WellnessActivityType.breathing:
        return 'Deep breathing exercises for relaxation and focus';
      case WellnessActivityType.focus:
        return 'Distraction-free work sessions with timer';
      case WellnessActivityType.walking:
        return 'Mindful walking meditation outdoors';
      case WellnessActivityType.journaling:
        return 'Reflect and write your thoughts';
    }
  }

  String get emoji {
    switch (this) {
      case WellnessActivityType.meditation:
        return '🧘';
      case WellnessActivityType.yoga:
        return '🧘‍♀️';
      case WellnessActivityType.breathing:
        return '🌬️';
      case WellnessActivityType.focus:
        return '🎯';
      case WellnessActivityType.walking:
        return '🚶';
      case WellnessActivityType.journaling:
        return '📝';
    }
  }

  IconData get icon {
    switch (this) {
      case WellnessActivityType.meditation:
        return Icons.self_improvement_rounded;
      case WellnessActivityType.yoga:
        return Icons.accessibility_new_rounded;
      case WellnessActivityType.breathing:
        return Icons.air_rounded;
      case WellnessActivityType.focus:
        return Icons.center_focus_strong_rounded;
      case WellnessActivityType.walking:
        return Icons.directions_walk_rounded;
      case WellnessActivityType.journaling:
        return Icons.edit_note_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case WellnessActivityType.meditation:
        return ManropeTheme.meditationColor;
      case WellnessActivityType.yoga:
        return ManropeTheme.yogaColor;
      case WellnessActivityType.breathing:
        return ManropeTheme.breathingColor;
      case WellnessActivityType.focus:
        return ManropeTheme.focusColor;
      case WellnessActivityType.walking:
        return ManropeTheme.walkingColor;
      case WellnessActivityType.journaling:
        return ManropeTheme.journalingColor;
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case WellnessActivityType.meditation:
        return ManropeTheme.meditationGradient;
      case WellnessActivityType.yoga:
        return ManropeTheme.yogaGradient;
      case WellnessActivityType.breathing:
        return ManropeTheme.breathingGradient;
      case WellnessActivityType.focus:
        return ManropeTheme.focusGradient;
      case WellnessActivityType.walking:
        return ManropeTheme.walkingGradient;
      case WellnessActivityType.journaling:
        return ManropeTheme.journalingGradient;
    }
  }

  List<int> get suggestedDurations {
    switch (this) {
      case WellnessActivityType.meditation:
        return [5, 10, 15, 20, 30, 45, 60];
      case WellnessActivityType.yoga:
        return [10, 15, 20, 30, 45, 60, 90];
      case WellnessActivityType.breathing:
        return [3, 5, 10, 15, 20];
      case WellnessActivityType.focus:
        return [15, 25, 30, 45, 60, 90, 120];
      case WellnessActivityType.walking:
        return [10, 15, 20, 30, 45, 60];
      case WellnessActivityType.journaling:
        return [5, 10, 15, 20, 30];
    }
  }

  int get defaultDuration {
    switch (this) {
      case WellnessActivityType.meditation:
        return 10;
      case WellnessActivityType.yoga:
        return 20;
      case WellnessActivityType.breathing:
        return 5;
      case WellnessActivityType.focus:
        return 25;
      case WellnessActivityType.walking:
        return 15;
      case WellnessActivityType.journaling:
        return 10;
    }
  }

  bool get supportsAmbientSound {
    switch (this) {
      case WellnessActivityType.meditation:
      case WellnessActivityType.yoga:
      case WellnessActivityType.breathing:
      case WellnessActivityType.focus:
        return true;
      case WellnessActivityType.walking:
      case WellnessActivityType.journaling:
        return false;
    }
  }

  bool get supportsBreathingGuide {
    switch (this) {
      case WellnessActivityType.meditation:
      case WellnessActivityType.breathing:
        return true;
      default:
        return false;
    }
  }

  static WellnessActivityType fromString(String value) {
    return WellnessActivityType.values.firstWhere(
      (e) => e.id == value || e.name == value,
      orElse: () => WellnessActivityType.meditation,
    );
  }
}

/// Model representing a wellness activity configuration
class WellnessActivity {
  final String id;
  final WellnessActivityType type;
  final String? customName;
  final int preferredDuration;
  final bool isEnabled;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? settings;

  const WellnessActivity({
    required this.id,
    required this.type,
    this.customName,
    this.preferredDuration = 10,
    this.isEnabled = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.settings,
  });

  String get displayName => customName ?? type.displayName;
  String get description => type.description;
  String get emoji => type.emoji;
  IconData get icon => type.icon;
  Color get primaryColor => type.primaryColor;
  LinearGradient get gradient => type.gradient;

  WellnessActivity copyWith({
    String? id,
    WellnessActivityType? type,
    String? customName,
    int? preferredDuration,
    bool? isEnabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? settings,
  }) {
    return WellnessActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      preferredDuration: preferredDuration ?? this.preferredDuration,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.id,
    'customName': customName,
    'preferredDuration': preferredDuration,
    'isEnabled': isEnabled,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'settings': settings,
  };

  factory WellnessActivity.fromJson(Map<String, dynamic> json) {
    return WellnessActivity(
      id: json['id'] as String,
      type: WellnessActivityTypeExtension.fromString(json['type'] as String),
      customName: json['customName'] as String?,
      preferredDuration: json['preferredDuration'] as int? ?? 10,
      isEnabled: json['isEnabled'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }

  factory WellnessActivity.create(WellnessActivityType type, {int? sortOrder}) {
    final now = DateTime.now();
    return WellnessActivity(
      id: '${type.id}_${now.millisecondsSinceEpoch}',
      type: type,
      preferredDuration: type.defaultDuration,
      sortOrder: sortOrder ?? type.index,
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<WellnessActivity> createDefaults() {
    return WellnessActivityType.values
        .map((type) => WellnessActivity.create(type, sortOrder: type.index))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WellnessActivity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model for a completed wellness session
class WellnessSession {
  final String id;
  final WellnessActivityType activityType;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetMinutes;
  final int actualMinutes;
  final bool wasCompleted;
  final bool wasAbandoned;
  final String? note;
  final int? moodBefore;
  final int? moodAfter;
  final String? ambientSoundUsed;
  final Map<String, dynamic>? metadata;

  const WellnessSession({
    required this.id,
    required this.activityType,
    required this.startedAt,
    this.completedAt,
    required this.targetMinutes,
    this.actualMinutes = 0,
    this.wasCompleted = false,
    this.wasAbandoned = false,
    this.note,
    this.moodBefore,
    this.moodAfter,
    this.ambientSoundUsed,
    this.metadata,
  });

  Duration get duration => Duration(minutes: actualMinutes);
  
  double get completionRate => 
      targetMinutes > 0 ? (actualMinutes / targetMinutes).clamp(0.0, 1.0) : 0.0;

  WellnessSession copyWith({
    String? id,
    WellnessActivityType? activityType,
    DateTime? startedAt,
    DateTime? completedAt,
    int? targetMinutes,
    int? actualMinutes,
    bool? wasCompleted,
    bool? wasAbandoned,
    String? note,
    int? moodBefore,
    int? moodAfter,
    String? ambientSoundUsed,
    Map<String, dynamic>? metadata,
  }) {
    return WellnessSession(
      id: id ?? this.id,
      activityType: activityType ?? this.activityType,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
      note: note ?? this.note,
      moodBefore: moodBefore ?? this.moodBefore,
      moodAfter: moodAfter ?? this.moodAfter,
      ambientSoundUsed: ambientSoundUsed ?? this.ambientSoundUsed,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityType': activityType.id,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'targetMinutes': targetMinutes,
    'actualMinutes': actualMinutes,
    'wasCompleted': wasCompleted,
    'wasAbandoned': wasAbandoned,
    'note': note,
    'moodBefore': moodBefore,
    'moodAfter': moodAfter,
    'ambientSoundUsed': ambientSoundUsed,
    'metadata': metadata,
  };

  factory WellnessSession.fromJson(Map<String, dynamic> json) {
    return WellnessSession(
      id: json['id'] as String,
      activityType: WellnessActivityTypeExtension.fromString(json['activityType'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      targetMinutes: json['targetMinutes'] as int,
      actualMinutes: json['actualMinutes'] as int? ?? 0,
      wasCompleted: json['wasCompleted'] as bool? ?? false,
      wasAbandoned: json['wasAbandoned'] as bool? ?? false,
      note: json['note'] as String?,
      moodBefore: json['moodBefore'] as int?,
      moodAfter: json['moodAfter'] as int?,
      ambientSoundUsed: json['ambientSoundUsed'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  factory WellnessSession.start({
    required WellnessActivityType activityType,
    required int targetMinutes,
    int? moodBefore,
    String? ambientSoundUsed,
  }) {
    final now = DateTime.now();
    return WellnessSession(
      id: '${activityType.id}_${now.millisecondsSinceEpoch}',
      activityType: activityType,
      startedAt: now,
      targetMinutes: targetMinutes,
      moodBefore: moodBefore,
      ambientSoundUsed: ambientSoundUsed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WellnessSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Aggregated statistics for wellness activities
class WellnessStats {
  final int totalSessions;
  final int totalMinutes;
  final int completedSessions;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastSessionDate;
  final Map<String, int> minutesByActivity;
  final Map<String, int> sessionsByActivity;

  const WellnessStats({
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.completedSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastSessionDate,
    this.minutesByActivity = const {},
    this.sessionsByActivity = const {},
  });

  double get completionRate => 
      totalSessions > 0 ? completedSessions / totalSessions : 0.0;

  int get averageSessionMinutes =>
      completedSessions > 0 ? totalMinutes ~/ completedSessions : 0;

  WellnessStats copyWith({
    int? totalSessions,
    int? totalMinutes,
    int? completedSessions,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastSessionDate,
    Map<String, int>? minutesByActivity,
    Map<String, int>? sessionsByActivity,
  }) {
    return WellnessStats(
      totalSessions: totalSessions ?? this.totalSessions,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      completedSessions: completedSessions ?? this.completedSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      minutesByActivity: minutesByActivity ?? this.minutesByActivity,
      sessionsByActivity: sessionsByActivity ?? this.sessionsByActivity,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalSessions': totalSessions,
    'totalMinutes': totalMinutes,
    'completedSessions': completedSessions,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastSessionDate': lastSessionDate?.toIso8601String(),
    'minutesByActivity': minutesByActivity,
    'sessionsByActivity': sessionsByActivity,
  };

  factory WellnessStats.fromJson(Map<String, dynamic> json) {
    return WellnessStats(
      totalSessions: json['totalSessions'] as int? ?? 0,
      totalMinutes: json['totalMinutes'] as int? ?? 0,
      completedSessions: json['completedSessions'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastSessionDate: json['lastSessionDate'] != null
          ? DateTime.parse(json['lastSessionDate'] as String)
          : null,
      minutesByActivity: Map<String, int>.from(json['minutesByActivity'] ?? {}),
      sessionsByActivity: Map<String, int>.from(json['sessionsByActivity'] ?? {}),
    );
  }
}
