import 'package:uuid/uuid.dart';

class TaskModel {
  final String id;
  final String noteId;
  final String title;
  final bool isCompleted;
  final int order;
  final DateTime? dueDate;
  final String? priority; // 'low', 'medium', 'high'
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.noteId,
    required this.title,
    this.isCompleted = false,
    this.order = 0,
    this.dueDate,
    this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.create({
    required String noteId,
    required String title,
    int order = 0,
    DateTime? dueDate,
    String? priority,
  }) {
    final now = DateTime.now();
    return TaskModel(
      id: const Uuid().v4(),
      noteId: noteId,
      title: title,
      order: order,
      dueDate: dueDate,
      priority: priority,
      createdAt: now,
      updatedAt: now,
    );
  }

  TaskModel copyWith({
    String? id,
    String? noteId,
    String? title,
    bool? isCompleted,
    int? order,
    DateTime? dueDate,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      order: order ?? this.order,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'noteId': noteId,
    'title': title,
    'isCompleted': isCompleted,
    'order': order,
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] ?? '',
    noteId: json['noteId'] ?? '',
    title: json['title'] ?? '',
    isCompleted: json['isCompleted'] ?? false,
    order: json['order'] ?? 0,
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    priority: json['priority'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );

  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;
  
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year && 
           dueDate!.month == now.month && 
           dueDate!.day == now.day;
  }
}
