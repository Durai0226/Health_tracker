/// An immutable body-weight reading. Value is stored canonically in
/// kilograms; the display unit (kg vs lb) is a user preference applied only
/// at render, same convention as [GlucoseReading]'s mg/dL.
class WeightReading {
  final String id;
  final String? dependentId;
  final double valueKg;
  final DateTime takenAt;
  final List<String> tags;
  final String? note;
  final DateTime createdAt;

  WeightReading({
    required this.id,
    this.dependentId,
    required this.valueKg,
    required this.takenAt,
    this.tags = const [],
    this.note,
    required this.createdAt,
  });

  double get valueLb => valueKg * 2.2046226218;

  WeightReading copyWith({
    String? dependentId,
    // See EnhancedMedicine.copyWith's clearDependentId doc — same reason:
    // reassigning a reading back to self needs a real clear, not a no-op.
    bool clearDependentId = false,
    double? valueKg,
    DateTime? takenAt,
    List<String>? tags,
    String? note,
  }) {
    return WeightReading(
      id: id,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      valueKg: valueKg ?? this.valueKg,
      takenAt: takenAt ?? this.takenAt,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'valueKg': valueKg,
        'takenAt': takenAt.toIso8601String(),
        'tags': tags,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WeightReading.fromJson(Map<String, dynamic> json) => WeightReading(
        id: json['id'] as String,
        dependentId: json['dependentId'] as String?,
        valueKg: (json['valueKg'] as num).toDouble(),
        takenAt: DateTime.parse(json['takenAt'] as String),
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.parse(json['takenAt'] as String),
      );
}
