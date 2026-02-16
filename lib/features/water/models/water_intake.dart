
import 'package:hive/hive.dart';

part 'water_intake.g.dart';

@HiveType(typeId: 3)
class WaterIntake extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final int dailyGoalMl;

  @HiveField(3)
  final int currentIntakeMl;

  @HiveField(4)
  final List<WaterLog> logs;

  WaterIntake({
    required this.id,
    required this.date,
    this.dailyGoalMl = 2500,
    this.currentIntakeMl = 0,
    List<WaterLog>? logs,
  }) : logs = logs ?? [];

  double get progress => dailyGoalMl > 0 ? currentIntakeMl / dailyGoalMl : 0.0;

  WaterIntake copyWith({
    int? dailyGoalMl,
    int? currentIntakeMl,
    List<WaterLog>? logs,
  }) {
    return WaterIntake(
      id: id,
      date: date,
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      currentIntakeMl: currentIntakeMl ?? this.currentIntakeMl,
      logs: logs ?? this.logs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'dailyGoalMl': dailyGoalMl,
    'currentIntakeMl': currentIntakeMl,
    'logs': logs.map((log) => {
      'time': log.time.toIso8601String(),
      'amountMl': log.amountMl,
    }).toList(),
  };

  factory WaterIntake.fromJson(Map<String, dynamic> json) => WaterIntake(
    id: json['id'] ?? '',
    date: DateTime.parse(json['date']),
    dailyGoalMl: json['dailyGoalMl'] ?? 2500,
    currentIntakeMl: json['currentIntakeMl'] ?? 0,
    logs: (json['logs'] as List<dynamic>?)?.map((log) => WaterLog(
      time: DateTime.parse(log['time']),
      amountMl: log['amountMl'] ?? 0,
    )).toList(),
  );
}

@HiveType(typeId: 4)
class WaterLog {
  @HiveField(0)
  final DateTime time;

  @HiveField(1)
  final int amountMl;

  WaterLog({
    required this.time,
    required this.amountMl,
  });
}
