import 'package:hive/hive.dart';

part 'exam_model.g.dart';

@HiveType(typeId: 250)
enum ExamType {
  @HiveField(0)
  midterm,
  @HiveField(1)
  final_exam,
  @HiveField(2)
  quiz,
  @HiveField(3)
  test,
  @HiveField(4)
  assignment,
  @HiveField(5)
  project,
  @HiveField(6)
  presentation,
  @HiveField(7)
  practical,
  @HiveField(8)
  viva,
  @HiveField(9)
  other,
}

extension ExamTypeExtension on ExamType {
  String get displayName {
    switch (this) {
      case ExamType.midterm:
        return 'Midterm';
      case ExamType.final_exam:
        return 'Final Exam';
      case ExamType.quiz:
        return 'Quiz';
      case ExamType.test:
        return 'Test';
      case ExamType.assignment:
        return 'Assignment';
      case ExamType.project:
        return 'Project';
      case ExamType.presentation:
        return 'Presentation';
      case ExamType.practical:
        return 'Practical';
      case ExamType.viva:
        return 'Viva';
      case ExamType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case ExamType.midterm:
        return '📝';
      case ExamType.final_exam:
        return '📚';
      case ExamType.quiz:
        return '❓';
      case ExamType.test:
        return '✍️';
      case ExamType.assignment:
        return '📋';
      case ExamType.project:
        return '🎯';
      case ExamType.presentation:
        return '🎤';
      case ExamType.practical:
        return '🔬';
      case ExamType.viva:
        return '🗣️';
      case ExamType.other:
        return '📌';
    }
  }
}

@HiveType(typeId: 251)
enum ExamStatus {
  @HiveField(0)
  upcoming,
  @HiveField(1)
  in_progress,
  @HiveField(2)
  completed,
  @HiveField(3)
  missed,
  @HiveField(4)
  cancelled,
}

extension ExamStatusExtension on ExamStatus {
  String get displayName {
    switch (this) {
      case ExamStatus.upcoming:
        return 'Upcoming';
      case ExamStatus.in_progress:
        return 'In Progress';
      case ExamStatus.completed:
        return 'Completed';
      case ExamStatus.missed:
        return 'Missed';
      case ExamStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case ExamStatus.upcoming:
        return '⏳';
      case ExamStatus.in_progress:
        return '📖';
      case ExamStatus.completed:
        return '✅';
      case ExamStatus.missed:
        return '❌';
      case ExamStatus.cancelled:
        return '🚫';
    }
  }
}

@HiveType(typeId: 252)
enum ExamPriority {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
  @HiveField(3)
  critical,
}

extension ExamPriorityExtension on ExamPriority {
  String get displayName {
    switch (this) {
      case ExamPriority.low:
        return 'Low';
      case ExamPriority.medium:
        return 'Medium';
      case ExamPriority.high:
        return 'High';
      case ExamPriority.critical:
        return 'Critical';
    }
  }

  int get weight {
    switch (this) {
      case ExamPriority.low:
        return 1;
      case ExamPriority.medium:
        return 2;
      case ExamPriority.high:
        return 3;
      case ExamPriority.critical:
        return 4;
    }
  }
}

@HiveType(typeId: 253)
class Exam {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String subjectId;

  @HiveField(4)
  final ExamType examType;

  @HiveField(5)
  final DateTime examDate;

  @HiveField(6)
  final DateTime? examEndDate;

  @HiveField(7)
  final String? location;

  @HiveField(8)
  final ExamStatus status;

  @HiveField(9)
  final ExamPriority priority;

  @HiveField(10)
  final double? totalMarks;

  @HiveField(11)
  final double? obtainedMarks;

  @HiveField(12)
  final double? passingMarks;

  @HiveField(13)
  final String? grade;

  @HiveField(14)
  final List<String> topicIds;

  @HiveField(15)
  final int targetStudyMinutes;

  @HiveField(16)
  final int actualStudyMinutes;

  @HiveField(17)
  final List<String> attachmentUrls;

  @HiveField(18)
  final List<String> noteIds;

  @HiveField(19)
  final String? templateId;

  @HiveField(20)
  final bool reminderEnabled;

  @HiveField(21)
  final List<DateTime> reminderTimes;

  @HiveField(22)
  final DateTime createdAt;

  @HiveField(23)
  final DateTime updatedAt;

  @HiveField(24)
  final bool isSynced;

  @HiveField(25)
  final int orderIndex;

  @HiveField(26)
  final String? colorHex;

  Exam({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    required this.examType,
    required this.examDate,
    this.examEndDate,
    this.location,
    this.status = ExamStatus.upcoming,
    this.priority = ExamPriority.medium,
    this.totalMarks,
    this.obtainedMarks,
    this.passingMarks,
    this.grade,
    this.topicIds = const [],
    this.targetStudyMinutes = 0,
    this.actualStudyMinutes = 0,
    this.attachmentUrls = const [],
    this.noteIds = const [],
    this.templateId,
    this.reminderEnabled = true,
    this.reminderTimes = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.orderIndex = 0,
    this.colorHex,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate days remaining until exam
  int get daysRemaining {
    final now = DateTime.now();
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return examDay.difference(today).inDays;
  }

  // Calculate study progress percentage
  double get studyProgress {
    if (targetStudyMinutes <= 0) return 0.0;
    return (actualStudyMinutes / targetStudyMinutes).clamp(0.0, 1.0);
  }

  // Calculate grade percentage
  double? get gradePercentage {
    if (totalMarks == null || obtainedMarks == null || totalMarks == 0) {
      return null;
    }
    return (obtainedMarks! / totalMarks!) * 100;
  }

  // Check if passed
  bool? get isPassed {
    if (passingMarks == null || obtainedMarks == null) return null;
    return obtainedMarks! >= passingMarks!;
  }

  Exam copyWith({
    String? id,
    String? title,
    String? description,
    String? subjectId,
    ExamType? examType,
    DateTime? examDate,
    DateTime? examEndDate,
    String? location,
    ExamStatus? status,
    ExamPriority? priority,
    double? totalMarks,
    double? obtainedMarks,
    double? passingMarks,
    String? grade,
    List<String>? topicIds,
    int? targetStudyMinutes,
    int? actualStudyMinutes,
    List<String>? attachmentUrls,
    List<String>? noteIds,
    String? templateId,
    bool? reminderEnabled,
    List<DateTime>? reminderTimes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    int? orderIndex,
    String? colorHex,
  }) {
    return Exam(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subjectId: subjectId ?? this.subjectId,
      examType: examType ?? this.examType,
      examDate: examDate ?? this.examDate,
      examEndDate: examEndDate ?? this.examEndDate,
      location: location ?? this.location,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      totalMarks: totalMarks ?? this.totalMarks,
      obtainedMarks: obtainedMarks ?? this.obtainedMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      grade: grade ?? this.grade,
      topicIds: topicIds ?? this.topicIds,
      targetStudyMinutes: targetStudyMinutes ?? this.targetStudyMinutes,
      actualStudyMinutes: actualStudyMinutes ?? this.actualStudyMinutes,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      noteIds: noteIds ?? this.noteIds,
      templateId: templateId ?? this.templateId,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      orderIndex: orderIndex ?? this.orderIndex,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'examType': examType.index,
      'examDate': examDate.toIso8601String(),
      'examEndDate': examEndDate?.toIso8601String(),
      'location': location,
      'status': status.index,
      'priority': priority.index,
      'totalMarks': totalMarks,
      'obtainedMarks': obtainedMarks,
      'passingMarks': passingMarks,
      'grade': grade,
      'topicIds': topicIds,
      'targetStudyMinutes': targetStudyMinutes,
      'actualStudyMinutes': actualStudyMinutes,
      'attachmentUrls': attachmentUrls,
      'noteIds': noteIds,
      'templateId': templateId,
      'reminderEnabled': reminderEnabled,
      'reminderTimes': reminderTimes.map((dt) => dt.toIso8601String()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'orderIndex': orderIndex,
      'colorHex': colorHex,
    };
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'] ?? '',
      examType: ExamType.values[json['examType'] ?? 0],
      examDate: DateTime.parse(json['examDate']),
      examEndDate: json['examEndDate'] != null
          ? DateTime.parse(json['examEndDate'])
          : null,
      location: json['location'],
      status: ExamStatus.values[json['status'] ?? 0],
      priority: ExamPriority.values[json['priority'] ?? 1],
      totalMarks: json['totalMarks']?.toDouble(),
      obtainedMarks: json['obtainedMarks']?.toDouble(),
      passingMarks: json['passingMarks']?.toDouble(),
      grade: json['grade'],
      topicIds: List<String>.from(json['topicIds'] ?? []),
      targetStudyMinutes: json['targetStudyMinutes'] ?? 0,
      actualStudyMinutes: json['actualStudyMinutes'] ?? 0,
      attachmentUrls: List<String>.from(json['attachmentUrls'] ?? []),
      noteIds: List<String>.from(json['noteIds'] ?? []),
      templateId: json['templateId'],
      reminderEnabled: json['reminderEnabled'] ?? true,
      reminderTimes: (json['reminderTimes'] as List<dynamic>?)
              ?.map((dt) => DateTime.parse(dt))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
      orderIndex: json['orderIndex'] ?? 0,
      colorHex: json['colorHex'],
    );
  }
}
