import 'package:hive/hive.dart';

part 'period_reminder.g.dart';

@HiveType(typeId: 7)
class PeriodReminder extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int daysBefore;

  @HiveField(2)
  final DateTime reminderTime;

  @HiveField(3)
  final bool isEnabled;

  PeriodReminder({
    required this.id,
    this.daysBefore = 2,
    required this.reminderTime,
    this.isEnabled = true,
  });

  PeriodReminder copyWith({
    int? daysBefore,
    DateTime? reminderTime,
    bool? isEnabled,
  }) {
    return PeriodReminder(
      id: id,
      daysBefore: daysBefore ?? this.daysBefore,
      reminderTime: reminderTime ?? this.reminderTime,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'daysBefore': daysBefore,
    'reminderTime': reminderTime.toIso8601String(),
    'isEnabled': isEnabled,
  };

  factory PeriodReminder.fromJson(Map<String, dynamic> json) => PeriodReminder(
    id: json['id'] ?? '',
    daysBefore: json['daysBefore'] ?? 2,
    reminderTime: DateTime.parse(json['reminderTime']),
    isEnabled: json['isEnabled'] ?? true,
  );
}
