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
  final List<String> tagIds;

  @HiveField(6)
  final bool isPinned;

  @HiveField(7)
  final bool isArchived;

  @HiveField(8)
  final bool isDeleted;

  @HiveField(9)
  final String? color;

  @HiveField(10)
  final bool isSynced;

  @HiveField(11)
  final String? reminderId;

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
