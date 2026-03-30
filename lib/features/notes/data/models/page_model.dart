import 'stroke_model.dart';
import 'audio_clip_model.dart';

/// Template types for notebook pages
enum NotebookTemplate {
  blank,
  lined,
  grid,
  dotted,
  cornell,
  music,
}

/// Represents a single page within a notebook
class PageModel {
  final String id;
  final String notebookId;
  final int pageNumber;
  final NotebookTemplate template;
  final String? backgroundColor; // Hex color or null for default
  final List<StrokeModel> strokes;
  final List<AudioClipModel> audioClips;
  final String? textContent; // Optional text overlay (JSON delta)
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? thumbnailPath; // Cached thumbnail for quick preview
  final double? scrollOffsetX;
  final double? scrollOffsetY;
  final double? zoomLevel;

  PageModel({
    required this.id,
    required this.notebookId,
    required this.pageNumber,
    this.template = NotebookTemplate.blank,
    this.backgroundColor,
    this.strokes = const [],
    this.audioClips = const [],
    this.textContent,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.thumbnailPath,
    this.scrollOffsetX,
    this.scrollOffsetY,
    this.zoomLevel,
  });

  PageModel copyWith({
    String? id,
    String? notebookId,
    int? pageNumber,
    NotebookTemplate? template,
    String? backgroundColor,
    List<StrokeModel>? strokes,
    List<AudioClipModel>? audioClips,
    String? textContent,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? thumbnailPath,
    double? scrollOffsetX,
    double? scrollOffsetY,
    double? zoomLevel,
  }) {
    return PageModel(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      pageNumber: pageNumber ?? this.pageNumber,
      template: template ?? this.template,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      strokes: strokes ?? this.strokes,
      audioClips: audioClips ?? this.audioClips,
      textContent: textContent ?? this.textContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      scrollOffsetX: scrollOffsetX ?? this.scrollOffsetX,
      scrollOffsetY: scrollOffsetY ?? this.scrollOffsetY,
      zoomLevel: zoomLevel ?? this.zoomLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'notebookId': notebookId,
    'pageNumber': pageNumber,
    'template': template.index,
    'backgroundColor': backgroundColor,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'audioClips': audioClips.map((a) => a.toJson()).toList(),
    'textContent': textContent,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced,
    'thumbnailPath': thumbnailPath,
    'scrollOffsetX': scrollOffsetX,
    'scrollOffsetY': scrollOffsetY,
    'zoomLevel': zoomLevel,
  };

  factory PageModel.fromJson(Map<String, dynamic> json) => PageModel(
    id: json['id'] ?? '',
    notebookId: json['notebookId'] ?? '',
    pageNumber: json['pageNumber'] ?? 0,
    template: NotebookTemplate.values[json['template'] ?? 0],
    backgroundColor: json['backgroundColor'],
    strokes: (json['strokes'] as List<dynamic>?)
        ?.map((s) => StrokeModel.fromJson(s))
        .toList() ?? [],
    audioClips: (json['audioClips'] as List<dynamic>?)
        ?.map((a) => AudioClipModel.fromJson(a))
        .toList() ?? [],
    textContent: json['textContent'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    isSynced: json['isSynced'] ?? false,
    thumbnailPath: json['thumbnailPath'],
    scrollOffsetX: json['scrollOffsetX']?.toDouble(),
    scrollOffsetY: json['scrollOffsetY']?.toDouble(),
    zoomLevel: json['zoomLevel']?.toDouble(),
  );

  /// Create a new empty page
  factory PageModel.create({
    required String id,
    required String notebookId,
    required int pageNumber,
    NotebookTemplate template = NotebookTemplate.blank,
    String? backgroundColor,
  }) {
    final now = DateTime.now();
    return PageModel(
      id: id,
      notebookId: notebookId,
      pageNumber: pageNumber,
      template: template,
      backgroundColor: backgroundColor,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Check if page has any content
  bool get hasContent => strokes.isNotEmpty || audioClips.isNotEmpty || (textContent?.isNotEmpty ?? false);

  /// Check if page has audio
  bool get hasAudio => audioClips.isNotEmpty;

  /// Get total stroke count
  int get strokeCount => strokes.length;

  /// Get total audio duration in seconds
  int get totalAudioDuration => 
      audioClips.fold(0, (sum, clip) => sum + clip.durationSeconds);

  /// Get template display name
  String get templateName {
    switch (template) {
      case NotebookTemplate.blank:
        return 'Blank';
      case NotebookTemplate.lined:
        return 'Lined';
      case NotebookTemplate.grid:
        return 'Grid';
      case NotebookTemplate.dotted:
        return 'Dotted';
      case NotebookTemplate.cornell:
        return 'Cornell';
      case NotebookTemplate.music:
        return 'Music';
    }
  }

  /// Get template icon
  String get templateIcon {
    switch (template) {
      case NotebookTemplate.blank:
        return '📄';
      case NotebookTemplate.lined:
        return '📝';
      case NotebookTemplate.grid:
        return '📊';
      case NotebookTemplate.dotted:
        return '⚫';
      case NotebookTemplate.cornell:
        return '📋';
      case NotebookTemplate.music:
        return '🎵';
    }
  }
}
