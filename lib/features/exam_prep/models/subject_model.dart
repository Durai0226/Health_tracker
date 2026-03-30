class Subject {
  final String id;
  final String name;
  final String? description;
  final String? teacherName;
  final String colorHex;
  final String iconName;
  final int creditHours;
  final double? targetGrade;
  final double? currentGrade;
  final List<String> topicIds;
  final List<String> examIds;
  final int totalStudyMinutes;
  final int weeklyTargetMinutes;
  final String? parentId;
  final int orderIndex;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
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
