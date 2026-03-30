enum NoteType { text, checklist, voice, image, meeting }

enum NotePriority { none, low, medium, high }

class NoteModel {
  final String id;
  final String title;
  final String content; // JSON delta from Quill or Markdown string
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tagIds;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final String? color;
  final bool isSynced;
  final String? reminderId;
  final NoteType noteType;
  final String? folderId;
  final String? aiSummary;
  final List<String> attachments;
  final String? voiceRecordingPath;
  final int? voiceDurationSeconds;
  final String? voiceTranscript;
  final NotePriority priority;
  final bool isFavorite;
  final int wordCount;
  final String? coverImagePath;
  final DateTime? reminderDate;
  final bool isLocked;
  final String? password;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tagIds = const [],
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.color,
    this.isSynced = false,
    this.reminderId,
    this.noteType = NoteType.text,
    this.folderId,
    this.aiSummary,
    this.attachments = const [],
    this.voiceRecordingPath,
    this.voiceDurationSeconds,
    this.voiceTranscript,
    this.priority = NotePriority.none,
    this.isFavorite = false,
    this.wordCount = 0,
    this.coverImagePath,
    this.reminderDate,
    this.isLocked = false,
    this.password,
  });

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tagIds,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    String? color,
    bool? isSynced,
    String? reminderId,
    NoteType? noteType,
    String? folderId,
    String? aiSummary,
    List<String>? attachments,
    String? voiceRecordingPath,
    int? voiceDurationSeconds,
    String? voiceTranscript,
    NotePriority? priority,
    bool? isFavorite,
    int? wordCount,
    String? coverImagePath,
    DateTime? reminderDate,
    bool? isLocked,
    String? password,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tagIds: tagIds ?? this.tagIds,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      color: color ?? this.color,
      isSynced: isSynced ?? this.isSynced,
      reminderId: reminderId ?? this.reminderId,
      noteType: noteType ?? this.noteType,
      folderId: folderId ?? this.folderId,
      aiSummary: aiSummary ?? this.aiSummary,
      attachments: attachments ?? this.attachments,
      voiceRecordingPath: voiceRecordingPath ?? this.voiceRecordingPath,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      priority: priority ?? this.priority,
      isFavorite: isFavorite ?? this.isFavorite,
      wordCount: wordCount ?? this.wordCount,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      reminderDate: reminderDate ?? this.reminderDate,
      isLocked: isLocked ?? this.isLocked,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tagIds': tagIds,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isDeleted': isDeleted,
    'color': color,
    'isSynced': isSynced,
    'reminderId': reminderId,
    'noteType': noteType.index,
    'folderId': folderId,
    'aiSummary': aiSummary,
    'attachments': attachments,
    'voiceRecordingPath': voiceRecordingPath,
    'voiceDurationSeconds': voiceDurationSeconds,
    'voiceTranscript': voiceTranscript,
    'priority': priority.index,
    'isFavorite': isFavorite,
    'wordCount': wordCount,
    'coverImagePath': coverImagePath,
    'reminderDate': reminderDate?.toIso8601String(),
    'isLocked': isLocked,
    'password': password,
  };

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    tagIds: List<String>.from(json['tagIds'] ?? []),
    isPinned: json['isPinned'] ?? false,
    isArchived: json['isArchived'] ?? false,
    isDeleted: json['isDeleted'] ?? false,
    color: json['color'],
    isSynced: json['isSynced'] ?? false,
    reminderId: json['reminderId'],
    noteType: NoteType.values[json['noteType'] ?? 0],
    folderId: json['folderId'],
    aiSummary: json['aiSummary'],
    attachments: List<String>.from(json['attachments'] ?? []),
    voiceRecordingPath: json['voiceRecordingPath'],
    voiceDurationSeconds: json['voiceDurationSeconds'],
    voiceTranscript: json['voiceTranscript'],
    priority: NotePriority.values[json['priority'] ?? 0],
    isFavorite: json['isFavorite'] ?? false,
    wordCount: json['wordCount'] ?? 0,
    coverImagePath: json['coverImagePath'],
    reminderDate: json['reminderDate'] != null ? DateTime.parse(json['reminderDate']) : null,
    isLocked: json['isLocked'] ?? false,
    password: json['password'],
  );

  bool get hasUncheckedItems {
    if (content.isEmpty) return false;
    try {
      if (content.trim().startsWith('[')) {
         return content.contains('"list":"unchecked"');
      }
    } catch (_) {}
    return false;
  }

  bool get isVoiceNote => noteType == NoteType.voice;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasAiSummary => aiSummary != null && aiSummary!.isNotEmpty;
  bool get hasReminder => reminderDate != null;
  
  String get priorityLabel {
    switch (priority) {
      case NotePriority.low: return 'Low';
      case NotePriority.medium: return 'Medium';
      case NotePriority.high: return 'High';
      default: return '';
    }
  }

  String get formattedVoiceDuration {
    if (voiceDurationSeconds == null) return '0:00';
    final minutes = voiceDurationSeconds! ~/ 60;
    final seconds = voiceDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
