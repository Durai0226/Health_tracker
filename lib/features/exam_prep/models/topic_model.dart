import 'package:hive/hive.dart';

part 'topic_model.g.dart';

@HiveType(typeId: 255)
enum TopicStatus {
  @HiveField(0)
  not_started,
  @HiveField(1)
  in_progress,
  @HiveField(2)
  completed,
  @HiveField(3)
  revision_needed,
  @HiveField(4)
  mastered,
}

extension TopicStatusExtension on TopicStatus {
  String get displayName {
    switch (this) {
      case TopicStatus.not_started:
        return 'Not Started';
      case TopicStatus.in_progress:
        return 'In Progress';
      case TopicStatus.completed:
        return 'Completed';
      case TopicStatus.revision_needed:
        return 'Needs Revision';
      case TopicStatus.mastered:
        return 'Mastered';
    }
  }

  String get emoji {
    switch (this) {
      case TopicStatus.not_started:
        return '⚪';
      case TopicStatus.in_progress:
        return '🔵';
      case TopicStatus.completed:
        return '✅';
      case TopicStatus.revision_needed:
        return '🔄';
      case TopicStatus.mastered:
        return '⭐';
    }
  }

  double get progressValue {
    switch (this) {
      case TopicStatus.not_started:
        return 0.0;
      case TopicStatus.in_progress:
        return 0.5;
      case TopicStatus.completed:
        return 0.85;
      case TopicStatus.revision_needed:
        return 0.6;
      case TopicStatus.mastered:
        return 1.0;
    }
  }
}

@HiveType(typeId: 256)
enum TopicDifficulty {
  @HiveField(0)
  easy,
  @HiveField(1)
  medium,
  @HiveField(2)
  hard,
  @HiveField(3)
  very_hard,
}

extension TopicDifficultyExtension on TopicDifficulty {
  String get displayName {
    switch (this) {
      case TopicDifficulty.easy:
        return 'Easy';
      case TopicDifficulty.medium:
        return 'Medium';
      case TopicDifficulty.hard:
        return 'Hard';
      case TopicDifficulty.very_hard:
        return 'Very Hard';
    }
  }

  int get weightage {
    switch (this) {
      case TopicDifficulty.easy:
        return 1;
      case TopicDifficulty.medium:
        return 2;
      case TopicDifficulty.hard:
        return 3;
      case TopicDifficulty.very_hard:
        return 4;
    }
  }
}

@HiveType(typeId: 257)
class Topic {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String subjectId;

  @HiveField(4)
  final String? parentTopicId;

  @HiveField(5)
  final TopicStatus status;

  @HiveField(6)
  final TopicDifficulty difficulty;

  @HiveField(7)
  final int estimatedMinutes;

  @HiveField(8)
  final int actualStudyMinutes;

  @HiveField(9)
  final double confidenceLevel;

  @HiveField(10)
  final int timesRevised;

  @HiveField(11)
  final DateTime? lastStudiedAt;

  @HiveField(12)
  final DateTime? nextRevisionDate;

  @HiveField(13)
  final List<String> childTopicIds;

  @HiveField(14)
  final List<String> noteIds;

  @HiveField(15)
  final List<String> resourceUrls;

  @HiveField(16)
  final int orderIndex;

  @HiveField(17)
  final double weightPercentage;

  @HiveField(18)
  final bool isImportantForExam;

  @HiveField(19)
  final DateTime createdAt;

  @HiveField(20)
  final DateTime updatedAt;

  @HiveField(21)
  final bool isSynced;

  @HiveField(22)
  final List<String> tags;

  Topic({
    required this.id,
    required this.name,
    this.description,
    required this.subjectId,
    this.parentTopicId,
    this.status = TopicStatus.not_started,
    this.difficulty = TopicDifficulty.medium,
    this.estimatedMinutes = 30,
    this.actualStudyMinutes = 0,
    this.confidenceLevel = 0.0,
    this.timesRevised = 0,
    this.lastStudiedAt,
    this.nextRevisionDate,
    this.childTopicIds = const [],
    this.noteIds = const [],
    this.resourceUrls = const [],
    this.orderIndex = 0,
    this.weightPercentage = 0.0,
    this.isImportantForExam = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.tags = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Check if topic has sub-topics
  bool get hasChildren => childTopicIds.isNotEmpty;

  // Calculate study progress
  double get studyProgress {
    if (estimatedMinutes <= 0) return 0.0;
    return (actualStudyMinutes / estimatedMinutes).clamp(0.0, 1.0);
  }

  // Check if revision is due
  bool get isRevisionDue {
    if (nextRevisionDate == null) return false;
    return DateTime.now().isAfter(nextRevisionDate!);
  }

  // Days since last study
  int? get daysSinceLastStudy {
    if (lastStudiedAt == null) return null;
    return DateTime.now().difference(lastStudiedAt!).inDays;
  }

  Topic copyWith({
    String? id,
    String? name,
    String? description,
    String? subjectId,
    String? parentTopicId,
    TopicStatus? status,
    TopicDifficulty? difficulty,
    int? estimatedMinutes,
    int? actualStudyMinutes,
    double? confidenceLevel,
    int? timesRevised,
    DateTime? lastStudiedAt,
    DateTime? nextRevisionDate,
    List<String>? childTopicIds,
    List<String>? noteIds,
    List<String>? resourceUrls,
    int? orderIndex,
    double? weightPercentage,
    bool? isImportantForExam,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    List<String>? tags,
  }) {
    return Topic(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subjectId: subjectId ?? this.subjectId,
      parentTopicId: parentTopicId ?? this.parentTopicId,
      status: status ?? this.status,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualStudyMinutes: actualStudyMinutes ?? this.actualStudyMinutes,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      timesRevised: timesRevised ?? this.timesRevised,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      nextRevisionDate: nextRevisionDate ?? this.nextRevisionDate,
      childTopicIds: childTopicIds ?? this.childTopicIds,
      noteIds: noteIds ?? this.noteIds,
      resourceUrls: resourceUrls ?? this.resourceUrls,
      orderIndex: orderIndex ?? this.orderIndex,
      weightPercentage: weightPercentage ?? this.weightPercentage,
      isImportantForExam: isImportantForExam ?? this.isImportantForExam,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'subjectId': subjectId,
      'parentTopicId': parentTopicId,
      'status': status.index,
      'difficulty': difficulty.index,
      'estimatedMinutes': estimatedMinutes,
      'actualStudyMinutes': actualStudyMinutes,
      'confidenceLevel': confidenceLevel,
      'timesRevised': timesRevised,
      'lastStudiedAt': lastStudiedAt?.toIso8601String(),
      'nextRevisionDate': nextRevisionDate?.toIso8601String(),
      'childTopicIds': childTopicIds,
      'noteIds': noteIds,
      'resourceUrls': resourceUrls,
      'orderIndex': orderIndex,
      'weightPercentage': weightPercentage,
      'isImportantForExam': isImportantForExam,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'] ?? '',
      parentTopicId: json['parentTopicId'],
      status: TopicStatus.values[json['status'] ?? 0],
      difficulty: TopicDifficulty.values[json['difficulty'] ?? 1],
      estimatedMinutes: json['estimatedMinutes'] ?? 30,
      actualStudyMinutes: json['actualStudyMinutes'] ?? 0,
      confidenceLevel: (json['confidenceLevel'] ?? 0.0).toDouble(),
      timesRevised: json['timesRevised'] ?? 0,
      lastStudiedAt: json['lastStudiedAt'] != null
          ? DateTime.parse(json['lastStudiedAt'])
          : null,
      nextRevisionDate: json['nextRevisionDate'] != null
          ? DateTime.parse(json['nextRevisionDate'])
          : null,
      childTopicIds: List<String>.from(json['childTopicIds'] ?? []),
      noteIds: List<String>.from(json['noteIds'] ?? []),
      resourceUrls: List<String>.from(json['resourceUrls'] ?? []),
      orderIndex: json['orderIndex'] ?? 0,
      weightPercentage: (json['weightPercentage'] ?? 0.0).toDouble(),
      isImportantForExam: json['isImportantForExam'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}
