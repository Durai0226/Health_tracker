import 'medicine_log.dart' show moodRatingLabels;

/// An immutable daily mood entry. [moodIndex] follows [moodRatingLabels]'
/// convention (0 = Great … 4 = Terrible) — the same scale already used for
/// per-dose mood, so a standalone daily mood is directly comparable.
class MoodEntry {
  final String id;
  final String? dependentId;
  final int moodIndex;
  final DateTime takenAt;
  final List<String> tags;
  final String? note;
  final DateTime createdAt;

  MoodEntry({
    required this.id,
    this.dependentId,
    required this.moodIndex,
    required this.takenAt,
    this.tags = const [],
    this.note,
    required this.createdAt,
  }) : assert(moodIndex >= 0 && moodIndex < moodRatingLabels.length);

  String get label => moodRatingLabels[moodIndex];

  MoodEntry copyWith({
    String? dependentId,
    // See EnhancedMedicine.copyWith's clearDependentId doc — same reason:
    // reassigning an entry back to self needs a real clear, not a no-op.
    bool clearDependentId = false,
    int? moodIndex,
    DateTime? takenAt,
    List<String>? tags,
    String? note,
  }) {
    return MoodEntry(
      id: id,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      moodIndex: moodIndex ?? this.moodIndex,
      takenAt: takenAt ?? this.takenAt,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'moodIndex': moodIndex,
        'takenAt': takenAt.toIso8601String(),
        'tags': tags,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) => MoodEntry(
        id: json['id'] as String,
        dependentId: json['dependentId'] as String?,
        moodIndex: (json['moodIndex'] as num)
            .toInt()
            .clamp(0, moodRatingLabels.length - 1)
            .toInt(),
        takenAt: DateTime.parse(json['takenAt'] as String),
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        note: json['note'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.parse(json['takenAt'] as String),
      );
}
