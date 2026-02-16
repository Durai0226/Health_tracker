import 'package:hive/hive.dart';

part 'action_log.g.dart';

/// Enum for different types of actions that can be logged
@HiveType(typeId: 20)
enum ActionType {
  @HiveField(0)
  medicineTaken,
  
  @HiveField(1)
  medicineSkipped,
  
  @HiveField(2)
  fitnessCompleted,
  
  @HiveField(3)
  fitnessSkipped,
  
  @HiveField(4)
  waterLogged,
  
  @HiveField(5)
  healthCheckDone,
  
  @HiveField(6)
  periodStarted,
  
  @HiveField(7)
  periodEnded,
}

/// Model to track all user actions for data persistence and analytics
@HiveType(typeId: 21)
class ActionLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final ActionType type;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String? referenceId; // ID of the related item (medicine id, fitness id, etc.)

  @HiveField(4)
  final String? title; // Display title for the action

  @HiveField(5)
  final Map<String, dynamic>? metadata; // Additional data specific to action type

  @HiveField(6)
  final bool synced; // Whether synced to cloud

  ActionLog({
    required this.id,
    required this.type,
    required this.timestamp,
    this.referenceId,
    this.title,
    this.metadata,
    this.synced = false,
  });

  ActionLog copyWith({
    String? id,
    ActionType? type,
    DateTime? timestamp,
    String? referenceId,
    String? title,
    Map<String, dynamic>? metadata,
    bool? synced,
  }) {
    return ActionLog(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      referenceId: referenceId ?? this.referenceId,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'timestamp': timestamp.toIso8601String(),
    'referenceId': referenceId,
    'title': title,
    'metadata': metadata,
    'synced': synced,
  };

  factory ActionLog.fromJson(Map<String, dynamic> json) => ActionLog(
    id: json['id'] ?? '',
    type: ActionType.values[json['type'] ?? 0],
    timestamp: DateTime.parse(json['timestamp']),
    referenceId: json['referenceId'],
    title: json['title'],
    metadata: json['metadata'] != null 
        ? Map<String, dynamic>.from(json['metadata']) 
        : null,
    synced: json['synced'] ?? false,
  );

  String get displayType {
    switch (type) {
      case ActionType.medicineTaken:
        return '💊 Medicine Taken';
      case ActionType.medicineSkipped:
        return '⏭️ Medicine Skipped';
      case ActionType.fitnessCompleted:
        return '💪 Workout Completed';
      case ActionType.fitnessSkipped:
        return '⏭️ Workout Skipped';
      case ActionType.waterLogged:
        return '💧 Water Logged';
      case ActionType.healthCheckDone:
        return '❤️ Health Check Done';
      case ActionType.periodStarted:
        return '🌸 Period Started';
      case ActionType.periodEnded:
        return '🌸 Period Ended';
    }
  }
}
