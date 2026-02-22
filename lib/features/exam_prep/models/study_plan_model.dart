import 'package:hive/hive.dart';

part 'study_plan_model.g.dart';

@HiveType(typeId: 264)
enum StudyPlanStatus {
  @HiveField(0)
  draft,
  @HiveField(1)
  active,
  @HiveField(2)
  paused,
  @HiveField(3)
  completed,
  @HiveField(4)
  abandoned,
}

extension StudyPlanStatusExtension on StudyPlanStatus {
  String get displayName {
    switch (this) {
      case StudyPlanStatus.draft:
        return 'Draft';
      case StudyPlanStatus.active:
        return 'Active';
      case StudyPlanStatus.paused:
        return 'Paused';
      case StudyPlanStatus.completed:
        return 'Completed';
      case StudyPlanStatus.abandoned:
        return 'Abandoned';
    }
  }

  String get emoji {
    switch (this) {
      case StudyPlanStatus.draft:
        return '📝';
      case StudyPlanStatus.active:
        return '▶️';
      case StudyPlanStatus.paused:
        return '⏸️';
      case StudyPlanStatus.completed:
        return '✅';
      case StudyPlanStatus.abandoned:
        return '❌';
    }
  }
}

@HiveType(typeId: 265)
class StudyPlanItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String topicId;

  @HiveField(2)
  final String topicName;

  @HiveField(3)
  final DateTime scheduledDate;

  @HiveField(4)
  final int plannedMinutes;

  @HiveField(5)
  final int actualMinutes;

  @HiveField(6)
  final bool isCompleted;

  @HiveField(7)
  final int orderIndex;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final List<String> sessionIds;

  StudyPlanItem({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.scheduledDate,
    this.plannedMinutes = 30,
    this.actualMinutes = 0,
    this.isCompleted = false,
    this.orderIndex = 0,
    this.notes,
    this.sessionIds = const [],
  });

  double get completionPercentage {
    if (plannedMinutes <= 0) return 0.0;
    return (actualMinutes / plannedMinutes).clamp(0.0, 1.0);
  }

  StudyPlanItem copyWith({
    String? id,
    String? topicId,
    String? topicName,
    DateTime? scheduledDate,
    int? plannedMinutes,
    int? actualMinutes,
    bool? isCompleted,
    int? orderIndex,
    String? notes,
    List<String>? sessionIds,
  }) {
    return StudyPlanItem(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      orderIndex: orderIndex ?? this.orderIndex,
      notes: notes ?? this.notes,
      sessionIds: sessionIds ?? this.sessionIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topicId': topicId,
      'topicName': topicName,
      'scheduledDate': scheduledDate.toIso8601String(),
      'plannedMinutes': plannedMinutes,
      'actualMinutes': actualMinutes,
      'isCompleted': isCompleted,
      'orderIndex': orderIndex,
      'notes': notes,
      'sessionIds': sessionIds,
    };
  }

  factory StudyPlanItem.fromJson(Map<String, dynamic> json) {
    return StudyPlanItem(
      id: json['id'] ?? '',
      topicId: json['topicId'] ?? '',
      topicName: json['topicName'] ?? '',
      scheduledDate: DateTime.parse(json['scheduledDate']),
      plannedMinutes: json['plannedMinutes'] ?? 30,
      actualMinutes: json['actualMinutes'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      orderIndex: json['orderIndex'] ?? 0,
      notes: json['notes'],
      sessionIds: List<String>.from(json['sessionIds'] ?? []),
    );
  }
}

@HiveType(typeId: 266)
class StudyPlan {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? examId;

  @HiveField(4)
  final String? subjectId;

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  final DateTime endDate;

  @HiveField(7)
  final StudyPlanStatus status;

  @HiveField(8)
  final List<StudyPlanItem> items;

  @HiveField(9)
  final int totalPlannedMinutes;

  @HiveField(10)
  final int totalActualMinutes;

  @HiveField(11)
  final int dailyTargetMinutes;

  @HiveField(12)
  final List<int> studyDays;

  @HiveField(13)
  final String? templateId;

  @HiveField(14)
  final bool autoAdjust;

  @HiveField(15)
  final DateTime createdAt;

  @HiveField(16)
  final DateTime updatedAt;

  @HiveField(17)
  final bool isSynced;

  @HiveField(18)
  final String? colorHex;

  StudyPlan({
    required this.id,
    required this.name,
    this.description,
    this.examId,
    this.subjectId,
    required this.startDate,
    required this.endDate,
    this.status = StudyPlanStatus.draft,
    this.items = const [],
    this.totalPlannedMinutes = 0,
    this.totalActualMinutes = 0,
    this.dailyTargetMinutes = 120,
    this.studyDays = const [1, 2, 3, 4, 5, 6, 7],
    this.templateId,
    this.autoAdjust = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.colorHex,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate overall progress
  double get progress {
    if (items.isEmpty) return 0.0;
    final completedCount = items.where((i) => i.isCompleted).length;
    return completedCount / items.length;
  }

  // Calculate time progress
  double get timeProgress {
    if (totalPlannedMinutes <= 0) return 0.0;
    return (totalActualMinutes / totalPlannedMinutes).clamp(0.0, 1.0);
  }

  // Get days remaining
  int get daysRemaining {
    final now = DateTime.now();
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return end.difference(today).inDays;
  }

  // Get total study days
  int get totalStudyDays {
    int count = 0;
    DateTime current = startDate;
    while (!current.isAfter(endDate)) {
      if (studyDays.contains(current.weekday)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  // Get items for a specific date
  List<StudyPlanItem> getItemsForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return items.where((item) {
      final itemDate = DateTime(
        item.scheduledDate.year,
        item.scheduledDate.month,
        item.scheduledDate.day,
      );
      return itemDate == targetDate;
    }).toList();
  }

  // Get pending items
  List<StudyPlanItem> get pendingItems =>
      items.where((i) => !i.isCompleted).toList();

  // Get completed items
  List<StudyPlanItem> get completedItems =>
      items.where((i) => i.isCompleted).toList();

  StudyPlan copyWith({
    String? id,
    String? name,
    String? description,
    String? examId,
    String? subjectId,
    DateTime? startDate,
    DateTime? endDate,
    StudyPlanStatus? status,
    List<StudyPlanItem>? items,
    int? totalPlannedMinutes,
    int? totalActualMinutes,
    int? dailyTargetMinutes,
    List<int>? studyDays,
    String? templateId,
    bool? autoAdjust,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? colorHex,
  }) {
    return StudyPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      examId: examId ?? this.examId,
      subjectId: subjectId ?? this.subjectId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      items: items ?? this.items,
      totalPlannedMinutes: totalPlannedMinutes ?? this.totalPlannedMinutes,
      totalActualMinutes: totalActualMinutes ?? this.totalActualMinutes,
      dailyTargetMinutes: dailyTargetMinutes ?? this.dailyTargetMinutes,
      studyDays: studyDays ?? this.studyDays,
      templateId: templateId ?? this.templateId,
      autoAdjust: autoAdjust ?? this.autoAdjust,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'examId': examId,
      'subjectId': subjectId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.index,
      'items': items.map((i) => i.toJson()).toList(),
      'totalPlannedMinutes': totalPlannedMinutes,
      'totalActualMinutes': totalActualMinutes,
      'dailyTargetMinutes': dailyTargetMinutes,
      'studyDays': studyDays,
      'templateId': templateId,
      'autoAdjust': autoAdjust,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorHex': colorHex,
    };
  }

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      examId: json['examId'],
      subjectId: json['subjectId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: StudyPlanStatus.values[json['status'] ?? 0],
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => StudyPlanItem.fromJson(Map<String, dynamic>.from(i)))
              .toList() ??
          [],
      totalPlannedMinutes: json['totalPlannedMinutes'] ?? 0,
      totalActualMinutes: json['totalActualMinutes'] ?? 0,
      dailyTargetMinutes: json['dailyTargetMinutes'] ?? 120,
      studyDays: List<int>.from(json['studyDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
      templateId: json['templateId'],
      autoAdjust: json['autoAdjust'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
      colorHex: json['colorHex'],
    );
  }
}
