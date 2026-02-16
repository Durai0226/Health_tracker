import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 100)
class NoteModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content; // JSON delta from Quill or Markdown string

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final String? folderId;

  @HiveField(6)
  final List<String> tagIds;

  @HiveField(7)
  final bool isPinned;

  @HiveField(8)
  final bool isArchived;

  @HiveField(9)
  final bool isDeleted; // Soft delete

  @HiveField(10)
  final List<String> mediaUrls;

  @HiveField(11)
  final String? color; // Hex color string

  @HiveField(12)
  final bool isLocked;

  @HiveField(13)
  final bool isSynced;

  @HiveField(14)
  final String? reminderId;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.tagIds = const [],
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.mediaUrls = const [],
    this.color,
    this.isLocked = false,
    this.isSynced = false,
    this.reminderId,
  });

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    List<String>? tagIds,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    List<String>? mediaUrls,
    String? color,
    bool? isLocked,
    bool? isSynced,
    String? reminderId,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      tagIds: tagIds ?? this.tagIds,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      color: color ?? this.color,
      isLocked: isLocked ?? this.isLocked,
      isSynced: isSynced ?? this.isSynced,
      reminderId: reminderId ?? this.reminderId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'folderId': folderId,
    'tagIds': tagIds,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isDeleted': isDeleted,
    'mediaUrls': mediaUrls,
    'color': color,
    'isLocked': isLocked,
    'isSynced': isSynced,
    'reminderId': reminderId,
  };

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    folderId: json['folderId'],
    tagIds: List<String>.from(json['tagIds'] ?? []),
    isPinned: json['isPinned'] ?? false,
    isArchived: json['isArchived'] ?? false,
    isDeleted: json['isDeleted'] ?? false,
    mediaUrls: List<String>.from(json['mediaUrls'] ?? []),
    color: json['color'],
    isLocked: json['isLocked'] ?? false,
    isSynced: json['isSynced'] ?? false,
    reminderId: json['reminderId'],
  );

  bool get hasUncheckedItems {
    if (content.isEmpty) return false;
    try {
      if (content.trim().startsWith('[')) {
         // Simple string check for performance
         return content.contains('"list":"unchecked"');
      }
    } catch (_) {}
    return false;
  }
}
