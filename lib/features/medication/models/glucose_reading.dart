import '../../../core/ai/vitals_analyzer.dart';

/// An immutable blood-glucose reading. Value is stored canonically as integer
/// mg/dL; the display unit is a user preference applied only at render. Class is
/// derived (never stored authoritatively) via [VitalsAnalyzer].
class GlucoseReading {
  final String id;
  final String? dependentId;
  final int valueMgdl;
  final GlucoseContext context;
  final DateTime takenAt;
  final int? carbs;
  final double? insulinUnits;
  final String? medNote;
  final List<String> tags;
  final String? note;
  final DateTime createdAt;

  GlucoseReading({
    required this.id,
    this.dependentId,
    required this.valueMgdl,
    this.context = GlucoseContext.random,
    required this.takenAt,
    this.carbs,
    this.insulinUnits,
    this.medNote,
    this.tags = const [],
    this.note,
    required this.createdAt,
  });

  GlucoseClass get glucoseClass =>
      VitalsAnalyzer.classifyGlucose(valueMgdl, context);
  bool get isEmergencyLow => VitalsAnalyzer.isGlucoseEmergencyLow(valueMgdl);

  GlucoseReading copyWith({
    int? valueMgdl,
    GlucoseContext? context,
    DateTime? takenAt,
    int? carbs,
    double? insulinUnits,
    String? medNote,
    List<String>? tags,
    String? note,
  }) {
    return GlucoseReading(
      id: id,
      dependentId: dependentId,
      valueMgdl: valueMgdl ?? this.valueMgdl,
      context: context ?? this.context,
      takenAt: takenAt ?? this.takenAt,
      carbs: carbs ?? this.carbs,
      insulinUnits: insulinUnits ?? this.insulinUnits,
      medNote: medNote ?? this.medNote,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'valueMgdl': valueMgdl,
        'context': context.index,
        'takenAt': takenAt.toIso8601String(),
        'carbs': carbs,
        'insulinUnits': insulinUnits,
        'medNote': medNote,
        'tags': tags,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GlucoseReading.fromJson(Map<String, dynamic> json) => GlucoseReading(
        id: json['id'] as String,
        dependentId: json['dependentId'] as String?,
        valueMgdl: (json['valueMgdl'] as num).toInt(),
        context: GlucoseContext.values[(json['context'] as num?)?.toInt() ?? 4],
        takenAt: DateTime.parse(json['takenAt'] as String),
        carbs: (json['carbs'] as num?)?.toInt(),
        insulinUnits: (json['insulinUnits'] as num?)?.toDouble(),
        medNote: json['medNote'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.parse(json['takenAt'] as String),
      );
}
