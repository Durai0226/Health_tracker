
import 'package:hive/hive.dart';

part 'health_check.g.dart';

@HiveType(typeId: 2)
class HealthCheck extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'sugar' or 'pressure'

  @HiveField(2)
  final String title; // Custom title like "Morning Sugar Check"

  @HiveField(3)
  final DateTime reminderTime;

  @HiveField(4)
  final String frequency; // "Once a day", "Twice a day", "Every week"

  @HiveField(5)
  final bool enableReminder;

  @HiveField(6)
  final List<DateTime>? readings; // Optional history of readings

  HealthCheck({
    required this.id,
    required this.type,
    required this.title,
    required this.reminderTime,
    required this.frequency,
    this.enableReminder = true,
    this.readings,
  });

  HealthCheck copyWith({
    String? id,
    String? type,
    String? title,
    DateTime? reminderTime,
    String? frequency,
    bool? enableReminder,
    List<DateTime>? readings,
  }) {
    return HealthCheck(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      reminderTime: reminderTime ?? this.reminderTime,
      frequency: frequency ?? this.frequency,
      enableReminder: enableReminder ?? this.enableReminder,
      readings: readings ?? this.readings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'reminderTime': reminderTime.toIso8601String(),
    'frequency': frequency,
    'enableReminder': enableReminder,
    'readings': readings?.map((r) => r.toIso8601String()).toList(),
  };

  factory HealthCheck.fromJson(Map<String, dynamic> json) => HealthCheck(
    id: json['id'] ?? '',
    type: json['type'] ?? 'sugar',
    title: json['title'] ?? '',
    reminderTime: DateTime.parse(json['reminderTime']),
    frequency: json['frequency'] ?? 'Once a day',
    enableReminder: json['enableReminder'] ?? true,
    readings: (json['readings'] as List<dynamic>?)?.map((r) => DateTime.parse(r as String)).toList(),
  );
}
