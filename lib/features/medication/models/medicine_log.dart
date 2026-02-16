import 'package:hive/hive.dart';
import 'medicine_enums.dart';

part 'medicine_log.g.dart';

/// Log entry for each medicine dose taken/skipped/missed
@HiveType(typeId: 60)
class MedicineLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String medicineId;

  @HiveField(2)
  final DateTime scheduledTime;

  @HiveField(3)
  final DateTime? actionTime; // When user took action

  @HiveField(4)
  final MedicineStatus status;

  @HiveField(5)
  final double dosageTaken;

  @HiveField(6)
  final SkipReason? skipReason;

  @HiveField(7)
  final String? skipNote;

  @HiveField(8)
  final String? sideEffects;

  @HiveField(9)
  final int? moodRating; // 1-5

  @HiveField(10)
  final int? effectivenessRating; // 1-5

  @HiveField(11)
  final String? notes;

  @HiveField(12)
  final String? dependentId; // For family member tracking

  @HiveField(13)
  final Map<String, dynamic>? vitals; // Associated vitals reading

  MedicineLog({
    required this.id,
    required this.medicineId,
    required this.scheduledTime,
    this.actionTime,
    required this.status,
    this.dosageTaken = 1,
    this.skipReason,
    this.skipNote,
    this.sideEffects,
    this.moodRating,
    this.effectivenessRating,
    this.notes,
    this.dependentId,
    this.vitals,
  });

  bool get isTaken => status == MedicineStatus.taken;
  bool get isSkipped => status == MedicineStatus.skipped;
  bool get isMissed => status == MedicineStatus.missed;
  bool get isPending => status == MedicineStatus.pending;

  Duration? get timeDifference {
    if (actionTime == null) return null;
    return actionTime!.difference(scheduledTime);
  }

  bool get wasTakenOnTime {
    final diff = timeDifference;
    if (diff == null) return false;
    return diff.inMinutes.abs() <= 30; // Within 30 minutes
  }

  bool get wasTakenLate {
    final diff = timeDifference;
    if (diff == null) return false;
    return diff.inMinutes > 30;
  }

  bool get wasTakenEarly {
    final diff = timeDifference;
    if (diff == null) return false;
    return diff.inMinutes < -30;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'medicineId': medicineId,
    'scheduledTime': scheduledTime.toIso8601String(),
    'actionTime': actionTime?.toIso8601String(),
    'status': status.index,
    'dosageTaken': dosageTaken,
    'skipReason': skipReason?.index,
    'skipNote': skipNote,
    'sideEffects': sideEffects,
    'moodRating': moodRating,
    'effectivenessRating': effectivenessRating,
    'notes': notes,
    'dependentId': dependentId,
    'vitals': vitals,
  };

  factory MedicineLog.fromJson(Map<String, dynamic> json) => MedicineLog(
    id: json['id'] ?? '',
    medicineId: json['medicineId'] ?? '',
    scheduledTime: DateTime.parse(json['scheduledTime']),
    actionTime: json['actionTime'] != null ? DateTime.parse(json['actionTime']) : null,
    status: MedicineStatus.values[json['status'] ?? 4],
    dosageTaken: (json['dosageTaken'] ?? 1).toDouble(),
    skipReason: json['skipReason'] != null ? SkipReason.values[json['skipReason']] : null,
    skipNote: json['skipNote'],
    sideEffects: json['sideEffects'],
    moodRating: json['moodRating'],
    effectivenessRating: json['effectivenessRating'],
    notes: json['notes'],
    dependentId: json['dependentId'],
    vitals: json['vitals'],
  );

  MedicineLog copyWith({
    String? id,
    String? medicineId,
    DateTime? scheduledTime,
    DateTime? actionTime,
    MedicineStatus? status,
    double? dosageTaken,
    SkipReason? skipReason,
    String? skipNote,
    String? sideEffects,
    int? moodRating,
    int? effectivenessRating,
    String? notes,
    String? dependentId,
    Map<String, dynamic>? vitals,
  }) {
    return MedicineLog(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actionTime: actionTime ?? this.actionTime,
      status: status ?? this.status,
      dosageTaken: dosageTaken ?? this.dosageTaken,
      skipReason: skipReason ?? this.skipReason,
      skipNote: skipNote ?? this.skipNote,
      sideEffects: sideEffects ?? this.sideEffects,
      moodRating: moodRating ?? this.moodRating,
      effectivenessRating: effectivenessRating ?? this.effectivenessRating,
      notes: notes ?? this.notes,
      dependentId: dependentId ?? this.dependentId,
      vitals: vitals ?? this.vitals,
    );
  }

  /// Create a "taken" log entry
  factory MedicineLog.taken({
    required String id,
    required String medicineId,
    required DateTime scheduledTime,
    DateTime? actionTime,
    double dosageTaken = 1,
    String? notes,
    String? sideEffects,
    int? moodRating,
    int? effectivenessRating,
    String? dependentId,
    Map<String, dynamic>? vitals,
  }) {
    return MedicineLog(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actionTime: actionTime ?? DateTime.now(),
      status: MedicineStatus.taken,
      dosageTaken: dosageTaken,
      notes: notes,
      sideEffects: sideEffects,
      moodRating: moodRating,
      effectivenessRating: effectivenessRating,
      dependentId: dependentId,
      vitals: vitals,
    );
  }

  /// Create a "skipped" log entry
  factory MedicineLog.skipped({
    required String id,
    required String medicineId,
    required DateTime scheduledTime,
    required SkipReason reason,
    String? skipNote,
    String? dependentId,
  }) {
    return MedicineLog(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      actionTime: DateTime.now(),
      status: MedicineStatus.skipped,
      skipReason: reason,
      skipNote: skipNote,
      dependentId: dependentId,
    );
  }

  /// Create a "missed" log entry
  factory MedicineLog.missed({
    required String id,
    required String medicineId,
    required DateTime scheduledTime,
    String? dependentId,
  }) {
    return MedicineLog(
      id: id,
      medicineId: medicineId,
      scheduledTime: scheduledTime,
      status: MedicineStatus.missed,
      dependentId: dependentId,
    );
  }
}

/// Daily summary of medicine logs
@HiveType(typeId: 61)
class DailyMedicineSummary extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final int totalScheduled;

  @HiveField(2)
  final int taken;

  @HiveField(3)
  final int skipped;

  @HiveField(4)
  final int missed;

  @HiveField(5)
  final double adherenceRate;

  @HiveField(6)
  final List<String> medicinesTaken;

  @HiveField(7)
  final List<String> medicinesMissed;

  DailyMedicineSummary({
    required this.date,
    required this.totalScheduled,
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.adherenceRate,
    required this.medicinesTaken,
    required this.medicinesMissed,
  });

  bool get isComplete => taken == totalScheduled;
  bool get hasIssues => skipped > 0 || missed > 0;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'totalScheduled': totalScheduled,
    'taken': taken,
    'skipped': skipped,
    'missed': missed,
    'adherenceRate': adherenceRate,
    'medicinesTaken': medicinesTaken,
    'medicinesMissed': medicinesMissed,
  };

  factory DailyMedicineSummary.fromJson(Map<String, dynamic> json) => DailyMedicineSummary(
    date: DateTime.parse(json['date']),
    totalScheduled: json['totalScheduled'] ?? 0,
    taken: json['taken'] ?? 0,
    skipped: json['skipped'] ?? 0,
    missed: json['missed'] ?? 0,
    adherenceRate: (json['adherenceRate'] ?? 0).toDouble(),
    medicinesTaken: (json['medicinesTaken'] as List?)?.cast<String>() ?? [],
    medicinesMissed: (json['medicinesMissed'] as List?)?.cast<String>() ?? [],
  );
}
