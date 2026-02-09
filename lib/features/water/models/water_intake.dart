
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
