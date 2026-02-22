import 'package:hive/hive.dart';

part 'study_session_model.g.dart';

@HiveType(typeId: 258)
enum StudySessionType {
  @HiveField(0)
  regular,
  @HiveField(1)
  pomodoro,
  @HiveField(2)
  revision,
  @HiveField(3)
  practice,
  @HiveField(4)
  reading,
  @HiveField(5)
  notes_making,
  @HiveField(6)
  problem_solving,
  @HiveField(7)
  memorization,
  @HiveField(8)
  group_study,
}

extension StudySessionTypeExtension on StudySessionType {
  String get displayName {
    switch (this) {
      case StudySessionType.regular:
        return 'Regular Study';
      case StudySessionType.pomodoro:
        return 'Pomodoro';
      case StudySessionType.revision:
        return 'Revision';
      case StudySessionType.practice:
        return 'Practice';
      case StudySessionType.reading:
        return 'Reading';
      case StudySessionType.notes_making:
        return 'Making Notes';
      case StudySessionType.problem_solving:
        return 'Problem Solving';
      case StudySessionType.memorization:
        return 'Memorization';
      case StudySessionType.group_study:
        return 'Group Study';
    }
  }

  String get emoji {
    switch (this) {
      case StudySessionType.regular:
        return '📚';
      case StudySessionType.pomodoro:
        return '🍅';
      case StudySessionType.revision:
        return '🔄';
      case StudySessionType.practice:
        return '✏️';
      case StudySessionType.reading:
        return '📖';
      case StudySessionType.notes_making:
        return '📝';
      case StudySessionType.problem_solving:
        return '🧮';
      case StudySessionType.memorization:
        return '🧠';
      case StudySessionType.group_study:
        return '👥';
    }
  }
}

@HiveType(typeId: 259)
enum SessionQuality {
  @HiveField(0)
  poor,
  @HiveField(1)
  average,
  @HiveField(2)
  good,
  @HiveField(3)
  excellent,
}

extension SessionQualityExtension on SessionQuality {
  String get displayName {
    switch (this) {
      case SessionQuality.poor:
        return 'Poor';
      case SessionQuality.average:
        return 'Average';
      case SessionQuality.good:
        return 'Good';
      case SessionQuality.excellent:
        return 'Excellent';
    }
  }

  String get emoji {
    switch (this) {
      case SessionQuality.poor:
        return '😔';
      case SessionQuality.average:
        return '😐';
      case SessionQuality.good:
        return '😊';
      case SessionQuality.excellent:
        return '🤩';
    }
  }

  double get multiplier {
    switch (this) {
      case SessionQuality.poor:
        return 0.5;
      case SessionQuality.average:
        return 1.0;
      case SessionQuality.good:
        return 1.25;
      case SessionQuality.excellent:
        return 1.5;
    }
  }
}

@HiveType(typeId: 260)
class StudySession {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? subjectId;

  @HiveField(2)
  final String? topicId;

  @HiveField(3)
  final String? examId;

  @HiveField(4)
  final StudySessionType sessionType;

  @HiveField(5)
  final DateTime startTime;

  @HiveField(6)
  final DateTime? endTime;

  @HiveField(7)
  final int plannedMinutes;

  @HiveField(8)
  final int actualMinutes;

  @HiveField(9)
  final bool isCompleted;

  @HiveField(10)
  final bool wasInterrupted;

  @HiveField(11)
  final int interruptionCount;

  @HiveField(12)
  final SessionQuality? quality;

  @HiveField(13)
  final String? notes;

  @HiveField(14)
  final int pomodoroCount;

  @HiveField(15)
  final int breakMinutes;

  @HiveField(16)
  final double? focusScore;

  @HiveField(17)
  final List<String> distractions;

  @HiveField(18)
  final double? productivityRating;

  @HiveField(19)
  final DateTime createdAt;

  @HiveField(20)
  final DateTime updatedAt;

  @HiveField(21)
  final bool isSynced;

  @HiveField(22)
  final Map<String, dynamic>? metadata;

  StudySession({
    required this.id,
    this.subjectId,
    this.topicId,
    this.examId,
    required this.sessionType,
    required this.startTime,
    this.endTime,
    this.plannedMinutes = 25,
    this.actualMinutes = 0,
    this.isCompleted = false,
    this.wasInterrupted = false,
    this.interruptionCount = 0,
    this.quality,
    this.notes,
    this.pomodoroCount = 0,
    this.breakMinutes = 0,
    this.focusScore,
    this.distractions = const [],
    this.productivityRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate effective study time (accounting for quality)
  double get effectiveMinutes {
    final qualityMultiplier = quality?.multiplier ?? 1.0;
    return actualMinutes * qualityMultiplier;
  }

  // Calculate completion percentage
  double get completionPercentage {
    if (plannedMinutes <= 0) return 0.0;
    return (actualMinutes / plannedMinutes).clamp(0.0, 1.0);
  }

  // Duration as Duration object
  Duration get duration => Duration(minutes: actualMinutes);

  StudySession copyWith({
    String? id,
    String? subjectId,
    String? topicId,
    String? examId,
    StudySessionType? sessionType,
    DateTime? startTime,
    DateTime? endTime,
    int? plannedMinutes,
    int? actualMinutes,
    bool? isCompleted,
    bool? wasInterrupted,
    int? interruptionCount,
    SessionQuality? quality,
    String? notes,
    int? pomodoroCount,
    int? breakMinutes,
    double? focusScore,
    List<String>? distractions,
    double? productivityRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    Map<String, dynamic>? metadata,
  }) {
    return StudySession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      examId: examId ?? this.examId,
      sessionType: sessionType ?? this.sessionType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      wasInterrupted: wasInterrupted ?? this.wasInterrupted,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      quality: quality ?? this.quality,
      notes: notes ?? this.notes,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      focusScore: focusScore ?? this.focusScore,
      distractions: distractions ?? this.distractions,
      productivityRating: productivityRating ?? this.productivityRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'topicId': topicId,
      'examId': examId,
      'sessionType': sessionType.index,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'plannedMinutes': plannedMinutes,
      'actualMinutes': actualMinutes,
      'isCompleted': isCompleted,
      'wasInterrupted': wasInterrupted,
      'interruptionCount': interruptionCount,
      'quality': quality?.index,
      'notes': notes,
      'pomodoroCount': pomodoroCount,
      'breakMinutes': breakMinutes,
      'focusScore': focusScore,
      'distractions': distractions,
      'productivityRating': productivityRating,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] ?? '',
      subjectId: json['subjectId'],
      topicId: json['topicId'],
      examId: json['examId'],
      sessionType: StudySessionType.values[json['sessionType'] ?? 0],
      startTime: DateTime.parse(json['startTime']),
      endTime:
          json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      plannedMinutes: json['plannedMinutes'] ?? 25,
      actualMinutes: json['actualMinutes'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      wasInterrupted: json['wasInterrupted'] ?? false,
      interruptionCount: json['interruptionCount'] ?? 0,
      quality: json['quality'] != null
          ? SessionQuality.values[json['quality']]
          : null,
      notes: json['notes'],
      pomodoroCount: json['pomodoroCount'] ?? 0,
      breakMinutes: json['breakMinutes'] ?? 0,
      focusScore: json['focusScore']?.toDouble(),
      distractions: List<String>.from(json['distractions'] ?? []),
      productivityRating: json['productivityRating']?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }
}
