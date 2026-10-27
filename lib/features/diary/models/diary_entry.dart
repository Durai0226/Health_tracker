/// An immutable free-form journal entry: an optional title, a free-text body,
/// a timestamp, and — both optional — how the writer was feeling and what the
/// entry was about.
///
/// The mood is the Mood log's scale (0 = Great … 4 = Terrible) but is the
/// entry's own: writing one here does not add a Mood log entry.
class DiaryEntry {
  final String id;
  final String? dependentId;
  final String? title;
  final String body;
  final DateTime entryAt;
  final DateTime createdAt;

  /// 0 (Great) … 4 (Terrible), as in `moodRatingLabels`; null when not said.
  final int? moodIndex;

  /// Tag ids (see `MoodTags`). An id from a later version is kept and shown
  /// title-cased rather than dropped.
  final List<String> tags;

  DiaryEntry({
    required this.id,
    this.dependentId,
    this.title,
    required this.body,
    required this.entryAt,
    required this.createdAt,
    this.moodIndex,
    this.tags = const [],
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

  /// The part of [body] that [displayTitle] has not already shown.
  ///
  /// [displayTitle] falls back to the body's FIRST LINE when the entry has no
  /// title of its own, so a list row that renders the heading and then the
  /// whole body prints the same sentence twice. That is what the Diary list
  /// did on device, for every entry — a one-line note with no title is the
  /// ordinary way to use a diary, not an edge case.
  ///
  /// Empty when the heading already said everything, so the caller can leave
  /// the row out rather than render a blank line.
  String get previewBody {
    final heading = displayTitle;
    final b = body.trim();
    return b.startsWith(heading) ? b.substring(heading.length).trim() : b;
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
    int? moodIndex,
    bool clearMood = false,
    List<String>? tags,
  }) {
    return DiaryEntry(
      id: id,
      dependentId: clearDependentId ? null : (dependentId ?? this.dependentId),
      title: clearTitle ? null : (title ?? this.title),
      body: body ?? this.body,
      entryAt: entryAt ?? this.entryAt,
      createdAt: createdAt,
      moodIndex: clearMood ? null : (moodIndex ?? this.moodIndex),
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dependentId': dependentId,
        'title': title,
        'body': body,
        'entryAt': entryAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'moodIndex': moodIndex,
        'tags': tags,
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
        // Absent in a backup made before these existed.
        moodIndex: (json['moodIndex'] as num?)?.toInt(),
        tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
      );
}
