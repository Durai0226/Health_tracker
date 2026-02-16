import 'package:hive/hive.dart';

part 'cycle_log.g.dart';

@HiveType(typeId: 30)
enum FlowIntensity {
  @HiveField(0)
  spotting,
  @HiveField(1)
  light,
  @HiveField(2)
  medium,
  @HiveField(3)
  heavy,
  @HiveField(4)
  veryHeavy,
}

@HiveType(typeId: 31)
enum CyclePhase {
  @HiveField(0)
  menstrual,
  @HiveField(1)
  follicular,
  @HiveField(2)
  ovulation,
  @HiveField(3)
  luteal,
  @HiveField(4)
  pms,
}

@HiveType(typeId: 32)
class CycleLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime startDate;

  @HiveField(2)
  final DateTime? endDate;

  @HiveField(3)
  final int cycleLength;

  @HiveField(4)
  final int periodDuration;

  @HiveField(5)
  final bool isComplete;

  @HiveField(6)
  final List<DailyLog> dailyLogs;

  @HiveField(7)
  final DateTime? ovulationDate;

  @HiveField(8)
  final DateTime? fertileWindowStart;

  @HiveField(9)
  final DateTime? fertileWindowEnd;

  @HiveField(10)
  final String? notes;

  CycleLog({
    required this.id,
    required this.startDate,
    this.endDate,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.isComplete = false,
    this.dailyLogs = const [],
    this.ovulationDate,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.notes,
  });

  CycleLog copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? cycleLength,
    int? periodDuration,
    bool? isComplete,
    List<DailyLog>? dailyLogs,
    DateTime? ovulationDate,
    DateTime? fertileWindowStart,
    DateTime? fertileWindowEnd,
    String? notes,
  }) {
    return CycleLog(
      id: id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cycleLength: cycleLength ?? this.cycleLength,
      periodDuration: periodDuration ?? this.periodDuration,
      isComplete: isComplete ?? this.isComplete,
      dailyLogs: dailyLogs ?? this.dailyLogs,
      ovulationDate: ovulationDate ?? this.ovulationDate,
      fertileWindowStart: fertileWindowStart ?? this.fertileWindowStart,
      fertileWindowEnd: fertileWindowEnd ?? this.fertileWindowEnd,
      notes: notes ?? this.notes,
    );
  }

  int get actualCycleLength {
    if (endDate != null) {
      return endDate!.difference(startDate).inDays;
    }
    return cycleLength;
  }

  CyclePhase getPhaseForDate(DateTime date) {
    final dayOfCycle = date.difference(startDate).inDays + 1;
    
    if (dayOfCycle <= periodDuration) {
      return CyclePhase.menstrual;
    } else if (dayOfCycle <= cycleLength ~/ 2 - 2) {
      return CyclePhase.follicular;
    } else if (dayOfCycle <= cycleLength ~/ 2 + 2) {
      return CyclePhase.ovulation;
    } else if (dayOfCycle <= cycleLength - 5) {
      return CyclePhase.luteal;
    } else {
      return CyclePhase.pms;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'cycleLength': cycleLength,
    'periodDuration': periodDuration,
    'isComplete': isComplete,
    'dailyLogs': dailyLogs.map((l) => l.toJson()).toList(),
    'ovulationDate': ovulationDate?.toIso8601String(),
    'fertileWindowStart': fertileWindowStart?.toIso8601String(),
    'fertileWindowEnd': fertileWindowEnd?.toIso8601String(),
    'notes': notes,
  };

  factory CycleLog.fromJson(Map<String, dynamic> json) => CycleLog(
    id: json['id'],
    startDate: DateTime.parse(json['startDate']),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    cycleLength: json['cycleLength'] ?? 28,
    periodDuration: json['periodDuration'] ?? 5,
    isComplete: json['isComplete'] ?? false,
    dailyLogs: (json['dailyLogs'] as List?)?.map((l) => DailyLog.fromJson(l)).toList() ?? [],
    ovulationDate: json['ovulationDate'] != null ? DateTime.parse(json['ovulationDate']) : null,
    fertileWindowStart: json['fertileWindowStart'] != null ? DateTime.parse(json['fertileWindowStart']) : null,
    fertileWindowEnd: json['fertileWindowEnd'] != null ? DateTime.parse(json['fertileWindowEnd']) : null,
    notes: json['notes'],
  );
}

@HiveType(typeId: 33)
class DailyLog extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final FlowIntensity? flow;

  @HiveField(2)
  final bool hasSpotting;

  @HiveField(3)
  final String? notes;

  DailyLog({
    required this.date,
    this.flow,
    this.hasSpotting = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'flow': flow?.index,
    'hasSpotting': hasSpotting,
    'notes': notes,
  };

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
    date: DateTime.parse(json['date']),
    flow: json['flow'] != null ? FlowIntensity.values[json['flow']] : null,
    hasSpotting: json['hasSpotting'] ?? false,
    notes: json['notes'],
  );
}
