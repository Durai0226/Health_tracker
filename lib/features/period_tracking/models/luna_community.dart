import 'package:flutter/material.dart';

/// Community feature models for Luna Cycle
/// Based on Safeline's anonymous support community

/// A community post for sharing experiences
class LunaCommunityPost {
  final String id;
  final String authorId;
  final String? authorName; // null for anonymous
  final bool isAnonymous;
  final String content;
  final List<String> tags;
  final LunaPostCategory category;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByUser;
  final bool isSavedByUser;
  final bool isPinned;
  final bool isVerified; // Verified health info
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? imageUrls;
  final LunaPostMood? mood;

  const LunaCommunityPost({
    required this.id,
    required this.authorId,
    this.authorName,
    this.isAnonymous = true,
    required this.content,
    this.tags = const [],
    required this.category,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLikedByUser = false,
    this.isSavedByUser = false,
    this.isPinned = false,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.imageUrls,
    this.mood,
  });

  LunaCommunityPost copyWith({
    String? id,
    String? authorId,
    String? authorName,
    bool? isAnonymous,
    String? content,
    List<String>? tags,
    LunaPostCategory? category,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLikedByUser,
    bool? isSavedByUser,
    bool? isPinned,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imageUrls,
    LunaPostMood? mood,
  }) {
    return LunaCommunityPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByUser: isLikedByUser ?? this.isLikedByUser,
      isSavedByUser: isSavedByUser ?? this.isSavedByUser,
      isPinned: isPinned ?? this.isPinned,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrls: imageUrls ?? this.imageUrls,
      mood: mood ?? this.mood,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'isAnonymous': isAnonymous,
    'content': content,
    'tags': tags,
    'category': category.index,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'sharesCount': sharesCount,
    'isPinned': isPinned,
    'isVerified': isVerified,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'imageUrls': imageUrls,
    'mood': mood?.index,
  };

  factory LunaCommunityPost.fromJson(Map<String, dynamic> json) {
    return LunaCommunityPost(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? true,
      content: json['content'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      category: LunaPostCategory.values[json['category'] as int? ?? 0],
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>(),
      mood: json['mood'] != null 
          ? LunaPostMood.values[json['mood'] as int] 
          : null,
    );
  }

  String get displayName => isAnonymous ? 'Anonymous' : (authorName ?? 'User');
  
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Comment on a community post
class LunaCommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String? authorName;
  final bool isAnonymous;
  final String content;
  final int likesCount;
  final bool isLikedByUser;
  final DateTime createdAt;
  final String? parentCommentId; // For replies

  const LunaCommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName,
    this.isAnonymous = true,
    required this.content,
    this.likesCount = 0,
    this.isLikedByUser = false,
    required this.createdAt,
    this.parentCommentId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'authorId': authorId,
    'authorName': authorName,
    'isAnonymous': isAnonymous,
    'content': content,
    'likesCount': likesCount,
    'createdAt': createdAt.toIso8601String(),
    'parentCommentId': parentCommentId,
  };

  factory LunaCommunityComment.fromJson(Map<String, dynamic> json) {
    return LunaCommunityComment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String?,
      isAnonymous: json['isAnonymous'] as bool? ?? true,
      content: json['content'] as String,
      likesCount: json['likesCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      parentCommentId: json['parentCommentId'] as String?,
    );
  }

  String get displayName => isAnonymous ? 'Anonymous' : (authorName ?? 'User');
}

/// Support group for women
class LunaSupportGroup {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final LunaGroupCategory category;
  final int memberCount;
  final int postCount;
  final bool isJoined;
  final bool isPrivate;
  final List<String> moderatorIds;
  final DateTime createdAt;
  final String? rules;

  const LunaSupportGroup({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.category,
    this.memberCount = 0,
    this.postCount = 0,
    this.isJoined = false,
    this.isPrivate = false,
    this.moderatorIds = const [],
    required this.createdAt,
    this.rules,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'category': category.index,
    'memberCount': memberCount,
    'postCount': postCount,
    'isPrivate': isPrivate,
    'moderatorIds': moderatorIds,
    'createdAt': createdAt.toIso8601String(),
    'rules': rules,
  };

  factory LunaSupportGroup.fromJson(Map<String, dynamic> json) {
    return LunaSupportGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String?,
      category: LunaGroupCategory.values[json['category'] as int? ?? 0],
      memberCount: json['memberCount'] as int? ?? 0,
      postCount: json['postCount'] as int? ?? 0,
      isPrivate: json['isPrivate'] as bool? ?? false,
      moderatorIds: (json['moderatorIds'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      rules: json['rules'] as String?,
    );
  }
}

/// Post categories
enum LunaPostCategory {
  general,
  periodTalk,
  symptoms,
  selfCare,
  relationships,
  mentalHealth,
  fitness,
  nutrition,
  pregnancy,
  fertility,
  menopause,
  askCommunity,
  success,
  support,
}

extension LunaPostCategoryExtension on LunaPostCategory {
  String get displayName {
    switch (this) {
      case LunaPostCategory.general: return 'General';
      case LunaPostCategory.periodTalk: return 'Period Talk';
      case LunaPostCategory.symptoms: return 'Symptoms';
      case LunaPostCategory.selfCare: return 'Self Care';
      case LunaPostCategory.relationships: return 'Relationships';
      case LunaPostCategory.mentalHealth: return 'Mental Health';
      case LunaPostCategory.fitness: return 'Fitness';
      case LunaPostCategory.nutrition: return 'Nutrition';
      case LunaPostCategory.pregnancy: return 'Pregnancy';
      case LunaPostCategory.fertility: return 'Fertility';
      case LunaPostCategory.menopause: return 'Menopause';
      case LunaPostCategory.askCommunity: return 'Ask Community';
      case LunaPostCategory.success: return 'Success Stories';
      case LunaPostCategory.support: return 'Support';
    }
  }

  IconData get icon {
    switch (this) {
      case LunaPostCategory.general: return Icons.chat_bubble_outline;
      case LunaPostCategory.periodTalk: return Icons.water_drop_outlined;
      case LunaPostCategory.symptoms: return Icons.healing_outlined;
      case LunaPostCategory.selfCare: return Icons.spa_outlined;
      case LunaPostCategory.relationships: return Icons.favorite_outline;
      case LunaPostCategory.mentalHealth: return Icons.psychology_outlined;
      case LunaPostCategory.fitness: return Icons.fitness_center_outlined;
      case LunaPostCategory.nutrition: return Icons.restaurant_outlined;
      case LunaPostCategory.pregnancy: return Icons.pregnant_woman_outlined;
      case LunaPostCategory.fertility: return Icons.child_friendly_outlined;
      case LunaPostCategory.menopause: return Icons.elderly_woman_outlined;
      case LunaPostCategory.askCommunity: return Icons.help_outline;
      case LunaPostCategory.success: return Icons.celebration_outlined;
      case LunaPostCategory.support: return Icons.support_outlined;
    }
  }

  Color get color {
    switch (this) {
      case LunaPostCategory.general: return const Color(0xFF9E9E9E);
      case LunaPostCategory.periodTalk: return const Color(0xFFFF6B8A);
      case LunaPostCategory.symptoms: return const Color(0xFFFFB74D);
      case LunaPostCategory.selfCare: return const Color(0xFF81C784);
      case LunaPostCategory.relationships: return const Color(0xFFE91E63);
      case LunaPostCategory.mentalHealth: return const Color(0xFF9575CD);
      case LunaPostCategory.fitness: return const Color(0xFF4FC3F7);
      case LunaPostCategory.nutrition: return const Color(0xFF81C784);
      case LunaPostCategory.pregnancy: return const Color(0xFFFFB6C1);
      case LunaPostCategory.fertility: return const Color(0xFF4DD0E1);
      case LunaPostCategory.menopause: return const Color(0xFFBA68C8);
      case LunaPostCategory.askCommunity: return const Color(0xFF64B5F6);
      case LunaPostCategory.success: return const Color(0xFFFFD54F);
      case LunaPostCategory.support: return const Color(0xFF4DB6AC);
    }
  }
}

/// Group categories
enum LunaGroupCategory {
  general,
  ageGroup,
  lifeStage,
  condition,
  interest,
  location,
}

extension LunaGroupCategoryExtension on LunaGroupCategory {
  String get displayName {
    switch (this) {
      case LunaGroupCategory.general: return 'General';
      case LunaGroupCategory.ageGroup: return 'Age Group';
      case LunaGroupCategory.lifeStage: return 'Life Stage';
      case LunaGroupCategory.condition: return 'Health Condition';
      case LunaGroupCategory.interest: return 'Interest';
      case LunaGroupCategory.location: return 'Location';
    }
  }
}

/// Post mood indicator
enum LunaPostMood {
  happy,
  grateful,
  hopeful,
  neutral,
  anxious,
  sad,
  frustrated,
  seeking,
}

extension LunaPostMoodExtension on LunaPostMood {
  String get emoji {
    switch (this) {
      case LunaPostMood.happy: return '😊';
      case LunaPostMood.grateful: return '🙏';
      case LunaPostMood.hopeful: return '✨';
      case LunaPostMood.neutral: return '😐';
      case LunaPostMood.anxious: return '😰';
      case LunaPostMood.sad: return '😢';
      case LunaPostMood.frustrated: return '😤';
      case LunaPostMood.seeking: return '🤔';
    }
  }

  String get label {
    switch (this) {
      case LunaPostMood.happy: return 'Happy';
      case LunaPostMood.grateful: return 'Grateful';
      case LunaPostMood.hopeful: return 'Hopeful';
      case LunaPostMood.neutral: return 'Neutral';
      case LunaPostMood.anxious: return 'Anxious';
      case LunaPostMood.sad: return 'Sad';
      case LunaPostMood.frustrated: return 'Frustrated';
      case LunaPostMood.seeking: return 'Seeking Advice';
    }
  }
}

/// Community guidelines
class LunaCommunityGuidelines {
  static const List<String> rules = [
    'Be respectful and supportive of all members',
    'No hate speech, bullying, or harassment',
    'Keep medical advice general - consult professionals for personal health',
    'Respect privacy - don\'t share others\' posts outside the app',
    'No spam, promotions, or advertisements',
    'Use content warnings for sensitive topics',
    'Report violations to moderators',
    'Anonymous posting is a privilege - use it responsibly',
  ];

  static const String privacyNote = 
    'Your identity is protected. Anonymous posts cannot be traced back to you. '
    'However, we may share data with authorities if there\'s a safety concern.';
}

/// Predefined support groups
class LunaPredefinedGroups {
  static List<LunaSupportGroup> get all => [
    LunaSupportGroup(
      id: 'pcos-warriors',
      name: 'PCOS Warriors',
      description: 'Support for women managing PCOS',
      category: LunaGroupCategory.condition,
      memberCount: 5420,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'endo-fighters',
      name: 'Endo Fighters',
      description: 'Endometriosis support and awareness',
      category: LunaGroupCategory.condition,
      memberCount: 3891,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'ttc-journey',
      name: 'TTC Journey',
      description: 'Trying to conceive support group',
      category: LunaGroupCategory.lifeStage,
      memberCount: 8234,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'new-moms',
      name: 'New Moms Circle',
      description: 'Postpartum support and advice',
      category: LunaGroupCategory.lifeStage,
      memberCount: 12450,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'perimenopause-talk',
      name: 'Perimenopause Talk',
      description: 'Navigating perimenopause together',
      category: LunaGroupCategory.lifeStage,
      memberCount: 6789,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'teen-health',
      name: 'Teen Health',
      description: 'Safe space for teens to discuss health',
      category: LunaGroupCategory.ageGroup,
      memberCount: 4521,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'fitness-motivation',
      name: 'Cycle-Synced Fitness',
      description: 'Exercise tips based on your cycle',
      category: LunaGroupCategory.interest,
      memberCount: 7823,
      createdAt: DateTime(2024, 1, 1),
    ),
    LunaSupportGroup(
      id: 'mental-wellness',
      name: 'Mental Wellness',
      description: 'Supporting emotional health',
      category: LunaGroupCategory.interest,
      memberCount: 9102,
      createdAt: DateTime(2024, 1, 1),
    ),
  ];
}
