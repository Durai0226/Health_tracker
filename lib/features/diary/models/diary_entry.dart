/// An immutable free-form journal entry. No rating/severity — just an
/// optional title, a free-text body, and a timestamp.
class DiaryEntry {
  final String id;
  final String? dependentId;
  final String? title;
  final String body;
  final DateTime entryAt;
  final DateTime createdAt;

  DiaryEntry({
    required this.id,
    this.dependentId,
    this.title,
    required this.body,
    required this.entryAt,
    required this.createdAt,
  });

  /// A short preview for list rows — the title if set, else the first
  /// non-empty line of the body, else a placeholder.
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final firstLine =
        body.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return firstLine.isNotEmpty ? firstLine : 'Untitled entry';
  }

  DiaryEntry copyWith({
    String? dependentId,
    // See MoodEntry.copyWith's clearDependentId doc — same reason:
    // reassigning an entry back to self needs a real clear, not a no-op.
    bool clearDependentId = false,
    String? title,
    bool clearTitle = false,
    String? body,
    DateTime? entryAt,
  }) {
    return DiaryEntry(
      id: id,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      title: clearTitle ? null : (title ?? this.title),
      body: body ?? this.body,
      entryAt: entryAt ?? this.entryAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'title': title,
        'body': body,
        'entryAt': entryAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
        id: json['id'] as String,
        dependentId: json['dependentId'] as String?,
        title: json['title'] as String?,
        body: json['body'] as String? ?? '',
        entryAt: DateTime.parse(json['entryAt'] as String),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.parse(json['entryAt'] as String),
      );
}
