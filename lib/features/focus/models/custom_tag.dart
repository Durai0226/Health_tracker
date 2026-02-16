import 'package:flutter/material.dart';

class FocusTag {
  final String id;
  final String name;
  final Color color;
  final String? emoji;
  final DateTime createdAt;
  final int usageCount;
  final bool isDefault;

  FocusTag({
    required this.id,
    required this.name,
    required this.color,
    this.emoji,
    required this.createdAt,
    this.usageCount = 0,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        'emoji': emoji,
        'createdAt': createdAt.toIso8601String(),
        'usageCount': usageCount,
        'isDefault': isDefault,
      };

  factory FocusTag.fromJson(Map<String, dynamic> json) => FocusTag(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        color: Color(json['color'] ?? 0xFF4CAF50),
        emoji: json['emoji'],
        createdAt: DateTime.parse(json['createdAt']),
        usageCount: json['usageCount'] ?? 0,
        isDefault: json['isDefault'] ?? false,
      );

  FocusTag copyWith({
    String? id,
    String? name,
    Color? color,
    String? emoji,
    DateTime? createdAt,
    int? usageCount,
    bool? isDefault,
  }) {
    return FocusTag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      usageCount: usageCount ?? this.usageCount,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static List<Color> get availableColors => [
        const Color(0xFF4CAF50),
        const Color(0xFF2196F3),
        const Color(0xFF9C27B0),
        const Color(0xFFE91E63),
        const Color(0xFFFF9800),
        const Color(0xFFFF5722),
        const Color(0xFF00BCD4),
        const Color(0xFF795548),
        const Color(0xFF607D8B),
        const Color(0xFF3F51B5),
        const Color(0xFF009688),
        const Color(0xFFCDDC39),
      ];

  static List<String> get availableEmojis => [
        '📚', '💼', '✍️', '💻', '🎨', '🎵',
        '📖', '🧠', '🎯', '💪', '🧘', '📝',
        '🔬', '🔧', '📊', '🎮', '🌱', '⭐',
      ];
}

class TagCategory {
  final String id;
  final String name;
  final List<FocusTag> tags;
  final DateTime createdAt;

  TagCategory({
    required this.id,
    required this.name,
    required this.tags,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tags': tags.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory TagCategory.fromJson(Map<String, dynamic> json) => TagCategory(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        tags: (json['tags'] as List?)
                ?.map((t) => FocusTag.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class TaggedSession {
  final String sessionId;
  final List<String> tagIds;
  final DateTime taggedAt;

  TaggedSession({
    required this.sessionId,
    required this.tagIds,
    required this.taggedAt,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'tagIds': tagIds,
        'taggedAt': taggedAt.toIso8601String(),
      };

  factory TaggedSession.fromJson(Map<String, dynamic> json) => TaggedSession(
        sessionId: json['sessionId'] ?? '',
        tagIds: List<String>.from(json['tagIds'] ?? []),
        taggedAt: DateTime.parse(json['taggedAt']),
      );
}

class TagStatistics {
  final String tagId;
  final String tagName;
  final Color tagColor;
  final int totalMinutes;
  final int sessionCount;
  final DateTime? lastUsed;

  TagStatistics({
    required this.tagId,
    required this.tagName,
    required this.tagColor,
    required this.totalMinutes,
    required this.sessionCount,
    this.lastUsed,
  });

  double get averageSessionMinutes =>
      sessionCount > 0 ? totalMinutes / sessionCount : 0;

  int get totalHours => totalMinutes ~/ 60;
}

class DefaultTags {
  static List<FocusTag> getDefaultTags() {
    final now = DateTime.now();
    return [
      FocusTag(
        id: 'study',
        name: 'Study',
        color: const Color(0xFF2196F3),
        emoji: '📚',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'work',
        name: 'Work',
        color: const Color(0xFF4CAF50),
        emoji: '💼',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'reading',
        name: 'Reading',
        color: const Color(0xFF9C27B0),
        emoji: '📖',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'creative',
        name: 'Creative',
        color: const Color(0xFFE91E63),
        emoji: '🎨',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'coding',
        name: 'Coding',
        color: const Color(0xFF00BCD4),
        emoji: '💻',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'writing',
        name: 'Writing',
        color: const Color(0xFFFF9800),
        emoji: '✍️',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'exercise',
        name: 'Exercise',
        color: const Color(0xFFFF5722),
        emoji: '💪',
        createdAt: now,
        isDefault: true,
      ),
      FocusTag(
        id: 'meditation',
        name: 'Meditation',
        color: const Color(0xFF795548),
        emoji: '🧘',
        createdAt: now,
        isDefault: true,
      ),
    ];
  }
}
