import 'exam_model.dart';

enum TemplateCategory {
  school,
  college,
  university,
  competitive,
  certification,
  language,
  professional,
  custom,
}

extension TemplateCategoryExtension on TemplateCategory {
  String get displayName {
    switch (this) {
      case TemplateCategory.school:
        return 'School';
      case TemplateCategory.college:
        return 'College';
      case TemplateCategory.university:
        return 'University';
      case TemplateCategory.competitive:
        return 'Competitive Exam';
      case TemplateCategory.certification:
        return 'Certification';
      case TemplateCategory.language:
        return 'Language';
      case TemplateCategory.professional:
        return 'Professional';
      case TemplateCategory.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case TemplateCategory.school:
        return '🏫';
      case TemplateCategory.college:
        return '🎓';
      case TemplateCategory.university:
        return '🏛️';
      case TemplateCategory.competitive:
        return '🏆';
      case TemplateCategory.certification:
        return '📜';
      case TemplateCategory.language:
        return '🌍';
      case TemplateCategory.professional:
        return '💼';
      case TemplateCategory.custom:
        return '⚙️';
    }
  }
}

class TopicTemplate {
  final String name;
  final int estimatedMinutes;
  final int difficulty;
  final double weightPercentage;
  final List<TopicTemplate> subtopics;
  final bool isImportant;

  TopicTemplate({
    required this.name,
    this.estimatedMinutes = 30,
    this.difficulty = 1,
    this.weightPercentage = 0.0,
    this.subtopics = const [],
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'estimatedMinutes': estimatedMinutes,
      'difficulty': difficulty,
      'weightPercentage': weightPercentage,
      'subtopics': subtopics.map((t) => t.toJson()).toList(),
      'isImportant': isImportant,
    };
  }

  factory TopicTemplate.fromJson(Map<String, dynamic> json) {
    return TopicTemplate(
      name: json['name'] ?? '',
      estimatedMinutes: json['estimatedMinutes'] ?? 30,
      difficulty: json['difficulty'] ?? 1,
      weightPercentage: (json['weightPercentage'] ?? 0.0).toDouble(),
      subtopics: (json['subtopics'] as List<dynamic>?)
              ?.map((t) => TopicTemplate.fromJson(Map<String, dynamic>.from(t)))
              .toList() ??
          [],
      isImportant: json['isImportant'] ?? false,
    );
  }

  TopicTemplate copyWith({
    String? name,
    int? estimatedMinutes,
    int? difficulty,
    double? weightPercentage,
    List<TopicTemplate>? subtopics,
    bool? isImportant,
  }) {
    return TopicTemplate(
      name: name ?? this.name,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      difficulty: difficulty ?? this.difficulty,
      weightPercentage: weightPercentage ?? this.weightPercentage,
      subtopics: subtopics ?? this.subtopics,
      isImportant: isImportant ?? this.isImportant,
    );
  }
}

class ExamTemplate {
  final String id;
  final String name;
  final String? description;
  final TemplateCategory category;
  final ExamType examType;
  final List<TopicTemplate> topics;
  final int recommendedStudyDays;
  final int dailyStudyMinutes;
  final double? totalMarks;
  final double? passingMarks;
  final List<int> defaultReminderDays;
  final String? iconName;
  final String? colorHex;
  final bool isBuiltIn;
  final bool isPublic;
  final int usageCount;
  final double? averageRating;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final Map<String, dynamic>? metadata;

  ExamTemplate({
    required this.id,
    required this.name,
    this.description,
    this.category = TemplateCategory.custom,
    this.examType = ExamType.test,
    this.topics = const [],
    this.recommendedStudyDays = 7,
    this.dailyStudyMinutes = 120,
    this.totalMarks,
    this.passingMarks,
    this.defaultReminderDays = const [7, 3, 1],
    this.iconName,
    this.colorHex,
    this.isBuiltIn = false,
    this.isPublic = false,
    this.usageCount = 0,
    this.averageRating,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.metadata,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate total estimated study time
  int get totalEstimatedMinutes {
    int total = 0;
    for (final topic in topics) {
      total += _calculateTopicMinutes(topic);
    }
    return total;
  }

  int _calculateTopicMinutes(TopicTemplate topic) {
    int total = topic.estimatedMinutes;
    for (final subtopic in topic.subtopics) {
      total += _calculateTopicMinutes(subtopic);
    }
    return total;
  }

  // Get total topic count (including nested)
  int get totalTopicCount {
    int count = 0;
    for (final topic in topics) {
      count += _countTopics(topic);
    }
    return count;
  }

  int _countTopics(TopicTemplate topic) {
    int count = 1;
    for (final subtopic in topic.subtopics) {
      count += _countTopics(subtopic);
    }
    return count;
  }

  ExamTemplate copyWith({
    String? id,
    String? name,
    String? description,
    TemplateCategory? category,
    ExamType? examType,
    List<TopicTemplate>? topics,
    int? recommendedStudyDays,
    int? dailyStudyMinutes,
    double? totalMarks,
    double? passingMarks,
    List<int>? defaultReminderDays,
    String? iconName,
    String? colorHex,
    bool? isBuiltIn,
    bool? isPublic,
    int? usageCount,
    double? averageRating,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    Map<String, dynamic>? metadata,
  }) {
    return ExamTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      examType: examType ?? this.examType,
      topics: topics ?? this.topics,
      recommendedStudyDays: recommendedStudyDays ?? this.recommendedStudyDays,
      dailyStudyMinutes: dailyStudyMinutes ?? this.dailyStudyMinutes,
      totalMarks: totalMarks ?? this.totalMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      defaultReminderDays: defaultReminderDays ?? this.defaultReminderDays,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isPublic: isPublic ?? this.isPublic,
      usageCount: usageCount ?? this.usageCount,
      averageRating: averageRating ?? this.averageRating,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.index,
      'examType': examType.index,
      'topics': topics.map((t) => t.toJson()).toList(),
      'recommendedStudyDays': recommendedStudyDays,
      'dailyStudyMinutes': dailyStudyMinutes,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'defaultReminderDays': defaultReminderDays,
      'iconName': iconName,
      'colorHex': colorHex,
      'isBuiltIn': isBuiltIn,
      'isPublic': isPublic,
      'usageCount': usageCount,
      'averageRating': averageRating,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory ExamTemplate.fromJson(Map<String, dynamic> json) {
    return ExamTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: TemplateCategory.values[json['category'] ?? 7],
      examType: ExamType.values[json['examType'] ?? 0],
      topics: (json['topics'] as List<dynamic>?)
              ?.map((t) => TopicTemplate.fromJson(Map<String, dynamic>.from(t)))
              .toList() ??
          [],
      recommendedStudyDays: json['recommendedStudyDays'] ?? 7,
      dailyStudyMinutes: json['dailyStudyMinutes'] ?? 120,
      totalMarks: json['totalMarks']?.toDouble(),
      passingMarks: json['passingMarks']?.toDouble(),
      defaultReminderDays:
          List<int>.from(json['defaultReminderDays'] ?? [7, 3, 1]),
      iconName: json['iconName'],
      colorHex: json['colorHex'],
      isBuiltIn: json['isBuiltIn'] ?? false,
      isPublic: json['isPublic'] ?? false,
      usageCount: json['usageCount'] ?? 0,
      averageRating: json['averageRating']?.toDouble(),
      createdBy: json['createdBy'],
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
