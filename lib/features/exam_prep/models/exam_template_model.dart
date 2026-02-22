import 'package:hive/hive.dart';
import 'exam_model.dart';

part 'exam_template_model.g.dart';

@HiveType(typeId: 267)
enum TemplateCategory {
  @HiveField(0)
  school,
  @HiveField(1)
  college,
  @HiveField(2)
  university,
  @HiveField(3)
  competitive,
  @HiveField(4)
  certification,
  @HiveField(5)
  language,
  @HiveField(6)
  professional,
  @HiveField(7)
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

@HiveType(typeId: 268)
class TopicTemplate {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int estimatedMinutes;

  @HiveField(2)
  final int difficulty;

  @HiveField(3)
  final double weightPercentage;

  @HiveField(4)
  final List<TopicTemplate> subtopics;

  @HiveField(5)
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

@HiveType(typeId: 269)
class ExamTemplate {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final TemplateCategory category;

  @HiveField(4)
  final ExamType examType;

  @HiveField(5)
  final List<TopicTemplate> topics;

  @HiveField(6)
  final int recommendedStudyDays;

  @HiveField(7)
  final int dailyStudyMinutes;

  @HiveField(8)
  final double? totalMarks;

  @HiveField(9)
  final double? passingMarks;

  @HiveField(10)
  final List<int> defaultReminderDays;

  @HiveField(11)
  final String? iconName;

  @HiveField(12)
  final String? colorHex;

  @HiveField(13)
  final bool isBuiltIn;

  @HiveField(14)
  final bool isPublic;

  @HiveField(15)
  final int usageCount;

  @HiveField(16)
  final double? averageRating;

  @HiveField(17)
  final String? createdBy;

  @HiveField(18)
  final DateTime createdAt;

  @HiveField(19)
  final DateTime updatedAt;

  @HiveField(20)
  final bool isSynced;

  @HiveField(21)
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
