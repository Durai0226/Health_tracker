import 'medicine_enums.dart';

/// Display labels for [MedicineLog.moodRating], 1-5, index+1 = rating.
///
/// NOTE the direction: rating 1 is the BEST mood ('Great'), rating 5 is the
/// WORST ('Terrible') — inverted from a typical "5 = best" scale. This was
/// the original mood picker's design and real mood data has already been
/// captured under it, so it is kept as-is rather than "corrected."
const List<String> moodRatingLabels = ['Great', 'Good', 'Okay', 'Bad', 'Terrible'];

/// Display labels for [MedicineLog.effectivenessRating], 1-5, index+1 =
/// rating. Normal direction: rating 1 is the WORST ('None'), rating 5 is the
/// BEST ('Excellent') — higher number = more effective. Chosen independently
/// of [moodRatingLabels]'s direction: effectiveness had no prior captured
/// data to stay consistent with, so it uses the direction a reader would
/// naturally expect from a 1-5 "how well did it work" rating.
const List<String> effectivenessRatingLabels = [
  'None',
  'Slight',
  'Moderate',
  'Good',
  'Excellent',
];

/// The nearest label for a possibly-fractional mean rating (1-5, clamped).
/// Prefer this over displaying a raw "X.X/5" number anywhere mood and
/// effectiveness might appear side by side (e.g. a report table): the two
/// scales run in OPPOSITE directions (see the docs above), so a bare number
/// reads as "higher is better" for both when that's only true for one of
/// them. A label describes the same average without that ambiguity.
String nearestRatingLabel(double mean, List<String> labels) {
  final index = (mean.round() - 1).clamp(0, labels.length - 1);
  return labels[index];
}

/// Fixed rotation of injection sites for injectable medicines — surfaced by
/// the take-medication sheet's site picker and persisted into a log's
/// [MedicineLog.vitals] map as `{'injectionSite': <site>}` (see that field's
/// doc for why this reuses `vitals` instead of a new column).
const List<String> injectionSites = [
  'Left thigh',
  'Right thigh',
  'Left abdomen',
  'Right abdomen',
  'Left upper arm',
  'Right upper arm',
];

/// Given a medicine's past logs (already fetched — this makes no DB call of
/// its own), finds the site used on the most recent log that recorded one and
/// suggests the NEXT site in [injectionSites]'s rotation, cycling past it.
/// Falls back to the first site when no past log recorded a site (or there
/// are no past logs at all, or the recorded site isn't in the current list)
/// — this never throws.
String suggestNextInjectionSite(List<MedicineLog> pastLogs) {
  final withSite = pastLogs
      .where((l) => l.vitals?['injectionSite'] is String)
      .toList()
    ..sort((a, b) => (b.actionTime ?? b.scheduledTime)
        .compareTo(a.actionTime ?? a.scheduledTime));
  if (withSite.isEmpty) return injectionSites.first;
  final lastSite = withSite.first.vitals!['injectionSite'] as String;
  final lastIndex = injectionSites.indexOf(lastSite);
  if (lastIndex == -1) return injectionSites.first;
  return injectionSites[(lastIndex + 1) % injectionSites.length];
}

/// Log entry for each medicine dose taken/skipped/missed
class MedicineLog {
  final String id;
  final String medicineId;
  final DateTime scheduledTime;
  final DateTime? actionTime; // When user took action
  final MedicineStatus status;
  final double dosageTaken;
  final SkipReason? skipReason;
  final String? skipNote;
  final String? sideEffects;
  final int? moodRating; // 1-5
  final int? effectivenessRating; // 1-5
  final String? notes;
  final String? dependentId; // For family member tracking
  // Associated vitals reading; also repurposed by injectable medicines to
  // store `{'injectionSite': '<site name>'}` (see [injectionSites] /
  // [suggestNextInjectionSite] below) instead of adding a new column.
  final Map<String, dynamic>? vitals;

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
  bool get isPreLogged => status == MedicineStatus.preLogged;

  /// The single choke point every adherence/streak/dedupe/terminal-state
  /// call site should use instead of scattering `|| isPreLogged` ad hoc — a
  /// pre-logged dose was physically taken (just ahead of its scheduled
  /// slot), so it counts the same as [isTaken] everywhere except the
  /// adaptive-reminder-time learning signal (which deliberately excludes it
  /// — see MedicationReminderService._adaptiveSuggestionMinutes' doc).
  bool get countsAsTaken => isTaken || isPreLogged;

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
    // See EnhancedMedicine.copyWith's clearDependentId doc — same reason:
    // reassigning a log back to self needs a real clear, not a no-op.
    bool clearDependentId = false,
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
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
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

  /// Create a "pre-logged" entry — the physical dose was taken NOW, ahead of
  /// [scheduledTime]'s real future slot (travel/timezone, pre-filled
  /// pillbox). Unlike [taken], [scheduledTime] is caller-chosen and expected
  /// to be in the future, not defaulted.
  factory MedicineLog.preLogged({
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
      status: MedicineStatus.preLogged,
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
class DailyMedicineSummary {
  final DateTime date;
  final int totalScheduled;
  final int taken;
  final int skipped;
  final int missed;
  final double adherenceRate;
  final List<String> medicinesTaken;
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
