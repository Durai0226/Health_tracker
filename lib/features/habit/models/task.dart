import 'dart:convert';
import 'package:flutter/material.dart';

/// Priority level for tasks
enum TaskPriority {
  low,
  medium,
  high,
}

/// One-time task model (different from recurring habits)
class HabitTask {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? dueTime; // HH:mm format
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;
  final String? groupId;
  final DateTime createdAt;
  final int sortOrder;

  const HabitTask({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
    this.groupId,
    required this.createdAt,
    this.sortOrder = 0,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    final now = DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return due.isBefore(today);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  HabitTask copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    TaskPriority? priority,
    DateTime? dueDate,
    String? dueTime,
    bool? isCompleted,
    DateTime? completedAt,
    String? notes,
    String? groupId,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return HabitTask(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'priority': priority.index,
      'dueDate': dueDate?.toIso8601String(),
      'dueTime': dueTime,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
      'groupId': groupId,
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  factory HabitTask.fromJson(Map<String, dynamic> json) {
    return HabitTask(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      colorValue: json['colorValue'] as int,
      priority: TaskPriority.values[json['priority'] as int? ?? 1],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      dueTime: json['dueTime'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      notes: json['notes'] as String?,
      groupId: json['groupId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitTask.fromJsonString(String jsonString) {
    return HabitTask.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitTask && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
