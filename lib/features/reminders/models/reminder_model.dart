
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'reminder_model.g.dart';

@HiveType(typeId: 202)
enum RepeatType {
  @HiveField(0)
  none,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
  @HiveField(3)
  weekdays,
  @HiveField(4)
  weekends,
  @HiveField(5)
  custom,
}

@HiveType(typeId: 203)
enum ReminderPriority {
  @HiveField(0)
  low,
  @HiveField(1)
  medium,
  @HiveField(2)
  high,
}

@HiveType(typeId: 201)
class Reminder {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final DateTime scheduledTime;

  @HiveField(4)
  final bool isCompleted;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final bool isSynced;

  @HiveField(8)
  final RepeatType repeatType;

  @HiveField(9)
  final List<int>? customDays;

  @HiveField(10)
  final int? snoozeDuration; // Minutes

  @HiveField(11)
  final String? sound;

  @HiveField(12)
  final ReminderPriority priority;

  @HiveField(13)
  final String? categoryId;

  @HiveField(14)
  final String? note;

  @HiveField(15)
  final String? imagePath;

  @HiveField(16)
  final String? noteId;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.repeatType = RepeatType.none,
    this.customDays,
    this.snoozeDuration,
    this.sound = 'default',
    this.priority = ReminderPriority.high,
    this.categoryId,
    this.note,
    this.imagePath,
    this.noteId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Reminder copyWith({
    String? title,
    String? body,
    DateTime? scheduledTime,
    bool? isCompleted,
    bool? isSynced,
    RepeatType? repeatType,
    List<int>? customDays,
    int? snoozeDuration,
    String? sound,
    ReminderPriority? priority,
    String? categoryId,
    String? note,
    String? imagePath,
    String? noteId,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      repeatType: repeatType ?? this.repeatType,
      customDays: customDays ?? this.customDays,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      sound: sound ?? this.sound,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      noteId: noteId ?? this.noteId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'repeatType': repeatType.toString().split('.').last,
      'customDays': customDays,
      'snoozeDuration': snoozeDuration,
      'sound': sound,
      'priority': priority.toString().split('.').last,
      'categoryId': categoryId,
      'note': note,
      'imagePath': imagePath,
      'noteId': noteId,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: true, // Assuming data from JSON (Firestore) is synced
      repeatType: json['repeatType'] != null
          ? RepeatType.values.firstWhere(
              (e) => e.toString().split('.').last == json['repeatType'],
              orElse: () => RepeatType.none,
            )
          : RepeatType.none,
      customDays: json['customDays'] != null
          ? List<int>.from(json['customDays'])
          : null,
      snoozeDuration: json['snoozeDuration'],
      sound: json['sound'] ?? 'default',
      priority: json['priority'] != null
          ? ReminderPriority.values.firstWhere(
              (e) => e.toString().split('.').last == json['priority'],
              orElse: () => ReminderPriority.high,
            )
          : ReminderPriority.high,
      categoryId: json['categoryId'],
      note: json['note'],
      imagePath: json['imagePath'],
      noteId: json['noteId'],
    );
  }
}
