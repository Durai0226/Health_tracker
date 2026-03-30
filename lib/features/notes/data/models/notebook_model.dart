import 'page_model.dart';

/// Represents a notebook containing multiple pages
/// Inspired by Livescribe's notebook metaphor
class NotebookModel {
  final String id;
  final String title;
  final String? description;
  final String coverColor; // Hex color string
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final bool isSynced;
  final bool isLocked;
  final String? password;
  final List<String> tagIds;
  final int pageCount;
  final String? lastPageThumbnail; // Base64 or file path
  final NotebookTemplate defaultTemplate;

  NotebookModel({
    required this.id,
    required this.title,
    this.description,
    required this.coverColor,
    this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isSynced = false,
    this.isLocked = false,
    this.password,
    this.tagIds = const [],
    this.pageCount = 0,
    this.lastPageThumbnail,
    this.defaultTemplate = NotebookTemplate.blank,
  });

  NotebookModel copyWith({
    String? id,
    String? title,
    String? description,
    String? coverColor,
    String? coverImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    bool? isSynced,
    bool? isLocked,
    String? password,
    List<String>? tagIds,
    int? pageCount,
    String? lastPageThumbnail,
    NotebookTemplate? defaultTemplate,
  }) {
    return NotebookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverColor: coverColor ?? this.coverColor,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      isLocked: isLocked ?? this.isLocked,
      password: password ?? this.password,
      tagIds: tagIds ?? this.tagIds,
      pageCount: pageCount ?? this.pageCount,
      lastPageThumbnail: lastPageThumbnail ?? this.lastPageThumbnail,
      defaultTemplate: defaultTemplate ?? this.defaultTemplate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'coverColor': coverColor,
    'coverImagePath': coverImagePath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'folderId': folderId,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isDeleted': isDeleted,
    'isSynced': isSynced,
    'isLocked': isLocked,
    'password': password,
    'tagIds': tagIds,
    'pageCount': pageCount,
    'lastPageThumbnail': lastPageThumbnail,
    'defaultTemplate': defaultTemplate.index,
  };

  factory NotebookModel.fromJson(Map<String, dynamic> json) => NotebookModel(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Untitled Notebook',
    description: json['description'],
    coverColor: json['coverColor'] ?? '#0066FF',
    coverImagePath: json['coverImagePath'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    folderId: json['folderId'],
    isPinned: json['isPinned'] ?? false,
    isArchived: json['isArchived'] ?? false,
    isDeleted: json['isDeleted'] ?? false,
    isSynced: json['isSynced'] ?? false,
    isLocked: json['isLocked'] ?? false,
    password: json['password'],
    tagIds: List<String>.from(json['tagIds'] ?? []),
    pageCount: json['pageCount'] ?? 0,
    lastPageThumbnail: json['lastPageThumbnail'],
    defaultTemplate: NotebookTemplate.values[json['defaultTemplate'] ?? 0],
  );

  /// Create a new empty notebook
  factory NotebookModel.create({
    required String id,
    required String title,
    String? description,
    String coverColor = '#0066FF',
    String? folderId,
    NotebookTemplate defaultTemplate = NotebookTemplate.blank,
  }) {
    final now = DateTime.now();
    return NotebookModel(
      id: id,
      title: title,
      description: description,
      coverColor: coverColor,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      defaultTemplate: defaultTemplate,
    );
  }

  /// Check if notebook has content
  bool get hasContent => pageCount > 0;

  /// Get formatted page count text
  String get pageCountText {
    if (pageCount == 0) return 'Empty';
    if (pageCount == 1) return '1 page';
    return '$pageCount pages';
  }

  /// Get formatted last modified text
  String get lastModifiedText {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }
}
