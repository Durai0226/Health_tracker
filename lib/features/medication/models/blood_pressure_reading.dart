import '../../../core/health/vitals_analyzer.dart';

/// Which arm the cuff was on.
enum BpArm { left, right }

/// Body position during the measurement.
enum BpPosition { sitting, standing, lying }

/// An immutable blood-pressure reading. Clinical category is derived (never
/// stored authoritatively) via [VitalsAnalyzer].
class BloodPressureReading {
  final String id;
  final String? dependentId;
  final int systolic;
  final int diastolic;
  final int? pulse;
  final BpArm? arm;
  final BpPosition? position;
  final DateTime takenAt;
  final List<String> tags;
  final String? note;
  final DateTime createdAt;

  BloodPressureReading({
    required this.id,
    this.dependentId,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    this.arm,
    this.position,
    required this.takenAt,
    this.tags = const [],
    this.note,
    required this.createdAt,
  });

  BpCategory get category => VitalsAnalyzer.classifyBp(systolic, diastolic);
  bool get isCrisis => category == BpCategory.crisis;

  /// True if taken in the morning window (used for AM/PM averages).
  bool get isMorning => takenAt.hour < 12;

  BloodPressureReading copyWith({
    String? dependentId,
    // See EnhancedMedicine.copyWith's clearDependentId doc — same reason:
    // reassigning a reading back to self needs a real clear, not a no-op.
    bool clearDependentId = false,
    int? systolic,
    int? diastolic,
    int? pulse,
    BpArm? arm,
    BpPosition? position,
    DateTime? takenAt,
    List<String>? tags,
    String? note,
  }) {
    return BloodPressureReading(
      id: id,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      pulse: pulse ?? this.pulse,
      arm: arm ?? this.arm,
      position: position ?? this.position,
      takenAt: takenAt ?? this.takenAt,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'arm': arm?.index,
        'position': position?.index,
        'takenAt': takenAt.toIso8601String(),
        'tags': tags,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BloodPressureReading.fromJson(Map<String, dynamic> json) =>
      BloodPressureReading(
        id: json['id'] as String,
        dependentId: json['dependentId'] as String?,
        systolic: (json['systolic'] as num).toInt(),
        diastolic: (json['diastolic'] as num).toInt(),
        pulse: (json['pulse'] as num?)?.toInt(),
        arm: json['arm'] != null ? BpArm.values[json['arm'] as int] : null,
        position: json['position'] != null
            ? BpPosition.values[json['position'] as int]
            : null,
        takenAt: DateTime.parse(json['takenAt'] as String),
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.parse(json['takenAt'] as String),
      );
}
