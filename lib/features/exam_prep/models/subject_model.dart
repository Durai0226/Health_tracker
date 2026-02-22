import 'package:hive/hive.dart';

part 'subject_model.g.dart';

@HiveType(typeId: 254)
class Subject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? teacherName;

  @HiveField(4)
  final String colorHex;

  @HiveField(5)
  final String iconName;

  @HiveField(6)
  final int creditHours;

  @HiveField(7)
  final double? targetGrade;

  @HiveField(8)
  final double? currentGrade;

  @HiveField(9)
  final List<String> topicIds;

  @HiveField(10)
  final List<String> examIds;

  @HiveField(11)
  final int totalStudyMinutes;

  @HiveField(12)
  final int weeklyTargetMinutes;

  @HiveField(13)
  final String? parentId;

  @HiveField(14)
  final int orderIndex;

  @HiveField(15)
  final bool isArchived;

  @HiveField(16)
  final DateTime createdAt;

  @HiveField(17)
  final DateTime updatedAt;

  @HiveField(18)
  final bool isSynced;

  @HiveField(19)
  final String? semesterId;

  Subject({
    required this.id,
    required this.name,
    this.description,
    this.teacherName,
    this.colorHex = '#4CAF50',
    this.iconName = 'book',
    this.creditHours = 3,
    this.targetGrade,
    this.currentGrade,
    this.topicIds = const [],
    this.examIds = const [],
    this.totalStudyMinutes = 0,
    this.weeklyTargetMinutes = 120,
    this.parentId,
    this.orderIndex = 0,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.semesterId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate study hours
  double get studyHours => totalStudyMinutes / 60.0;

  // Calculate weekly progress
  double get weeklyProgress {
    if (weeklyTargetMinutes <= 0) return 0.0;
    return (totalStudyMinutes / weeklyTargetMinutes).clamp(0.0, 1.0);
  }

  // Check if subject has nested topics/subjects
  bool get hasChildren => topicIds.isNotEmpty;

  Subject copyWith({
    String? id,
    String? name,
    String? description,
    String? teacherName,
    String? colorHex,
    String? iconName,
    int? creditHours,
    double? targetGrade,
    double? currentGrade,
    List<String>? topicIds,
    List<String>? examIds,
    int? totalStudyMinutes,
    int? weeklyTargetMinutes,
    String? parentId,
    int? orderIndex,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? semesterId,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teacherName: teacherName ?? this.teacherName,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      creditHours: creditHours ?? this.creditHours,
      targetGrade: targetGrade ?? this.targetGrade,
      currentGrade: currentGrade ?? this.currentGrade,
      topicIds: topicIds ?? this.topicIds,
      examIds: examIds ?? this.examIds,
      totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
      weeklyTargetMinutes: weeklyTargetMinutes ?? this.weeklyTargetMinutes,
      parentId: parentId ?? this.parentId,
      orderIndex: orderIndex ?? this.orderIndex,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      semesterId: semesterId ?? this.semesterId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'teacherName': teacherName,
      'colorHex': colorHex,
      'iconName': iconName,
      'creditHours': creditHours,
      'targetGrade': targetGrade,
      'currentGrade': currentGrade,
      'topicIds': topicIds,
      'examIds': examIds,
      'totalStudyMinutes': totalStudyMinutes,
      'weeklyTargetMinutes': weeklyTargetMinutes,
      'parentId': parentId,
      'orderIndex': orderIndex,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'semesterId': semesterId,
    };
  }

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      teacherName: json['teacherName'],
      colorHex: json['colorHex'] ?? '#4CAF50',
      iconName: json['iconName'] ?? 'book',
      creditHours: json['creditHours'] ?? 3,
      targetGrade: json['targetGrade']?.toDouble(),
      currentGrade: json['currentGrade']?.toDouble(),
      topicIds: List<String>.from(json['topicIds'] ?? []),
      examIds: List<String>.from(json['examIds'] ?? []),
      totalStudyMinutes: json['totalStudyMinutes'] ?? 0,
      weeklyTargetMinutes: json['weeklyTargetMinutes'] ?? 120,
      parentId: json['parentId'],
      orderIndex: json['orderIndex'] ?? 0,
      isArchived: json['isArchived'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
      semesterId: json['semesterId'],
    );
  }
}
