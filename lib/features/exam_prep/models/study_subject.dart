import 'package:flutter/material.dart';

class StudySubject {
  final String id;
  final String name;
  final String examId;
  final Color color;
  final String? icon;
  final int targetHours;
  final int completedMinutes;
  final List<String> topics;
  final Map<String, bool> topicCompletion;
  final int priority; // 1-5, 5 being highest
  final double confidence; // 0.0 - 1.0
  final DateTime createdAt;

  StudySubject({
    required this.id,
    required this.name,
    required this.examId,
    this.color = const Color(0xFF6366F1),
    this.icon,
    this.targetHours = 50,
    this.completedMinutes = 0,
    this.topics = const [],
    this.topicCompletion = const {},
    this.priority = 3,
    this.confidence = 0.0,
    required this.createdAt,
  });

  double get progressPercent {
    if (targetHours <= 0) return 0.0;
    return (completedMinutes / (targetHours * 60)).clamp(0.0, 1.0);
  }

  int get completedHours => completedMinutes ~/ 60;
  int get remainingMinutes => (targetHours * 60) - completedMinutes;

  int get completedTopics => topicCompletion.values.where((v) => v).length;
  double get topicProgressPercent {
    if (topics.isEmpty) return 0.0;
    return completedTopics / topics.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'examId': examId,
        'color': color.value,
        'icon': icon,
        'targetHours': targetHours,
        'completedMinutes': completedMinutes,
        'topics': topics,
        'topicCompletion': topicCompletion,
        'priority': priority,
        'confidence': confidence,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudySubject.fromJson(Map<String, dynamic> json) => StudySubject(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        examId: json['examId'] ?? '',
        color: Color(json['color'] ?? 0xFF6366F1),
        icon: json['icon'],
        targetHours: json['targetHours'] ?? 50,
        completedMinutes: json['completedMinutes'] ?? 0,
        topics: List<String>.from(json['topics'] ?? []),
        topicCompletion: Map<String, bool>.from(json['topicCompletion'] ?? {}),
        priority: json['priority'] ?? 3,
        confidence: (json['confidence'] ?? 0.0).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      );

  StudySubject copyWith({
    String? id,
    String? name,
    String? examId,
    Color? color,
    String? icon,
    int? targetHours,
    int? completedMinutes,
    List<String>? topics,
    Map<String, bool>? topicCompletion,
    int? priority,
    double? confidence,
    DateTime? createdAt,
  }) {
    return StudySubject(
      id: id ?? this.id,
      name: name ?? this.name,
      examId: examId ?? this.examId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      targetHours: targetHours ?? this.targetHours,
      completedMinutes: completedMinutes ?? this.completedMinutes,
      topics: topics ?? this.topics,
      topicCompletion: topicCompletion ?? this.topicCompletion,
      priority: priority ?? this.priority,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SubjectColors {
  static const List<Color> colors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFF59E0B), // Amber
    Color(0xFF84CC16), // Lime
    Color(0xFF22C55E), // Green
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF6B7280), // Gray
  ];

  static Color getColor(int index) {
    return colors[index % colors.length];
  }
}
