import 'package:flutter/material.dart';

/// Education feature models for Luna Cycle
/// Health articles, tips, myths vs facts based on Safeline case study

/// An educational article
class LunaArticle {
  final String id;
  final String title;
  final String summary;
  final String content; // Markdown or HTML
  final String? imageUrl;
  final String? thumbnailUrl;
  final LunaArticleCategory category;
  final List<String> tags;
  final String authorName;
  final String? authorCredentials; // e.g., "MD, OB-GYN"
  final bool isVerified;
  final int readTimeMinutes;
  final int viewCount;
  final int bookmarkCount;
  final bool isBookmarked;
  final DateTime publishedAt;
  final DateTime? updatedAt;
  final List<String>? relatedArticleIds;
  final LunaArticleDifficulty difficulty;

  const LunaArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    this.tags = const [],
    required this.authorName,
    this.authorCredentials,
    this.isVerified = false,
    required this.readTimeMinutes,
    this.viewCount = 0,
    this.bookmarkCount = 0,
    this.isBookmarked = false,
    required this.publishedAt,
    this.updatedAt,
    this.relatedArticleIds,
    this.difficulty = LunaArticleDifficulty.beginner,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'content': content,
    'imageUrl': imageUrl,
    'thumbnailUrl': thumbnailUrl,
    'category': category.index,
    'tags': tags,
    'authorName': authorName,
    'authorCredentials': authorCredentials,
    'isVerified': isVerified,
    'readTimeMinutes': readTimeMinutes,
    'viewCount': viewCount,
    'bookmarkCount': bookmarkCount,
    'publishedAt': publishedAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'relatedArticleIds': relatedArticleIds,
    'difficulty': difficulty.index,
  };

  factory LunaArticle.fromJson(Map<String, dynamic> json) {
    return LunaArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      category: LunaArticleCategory.values[json['category'] as int? ?? 0],
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      authorName: json['authorName'] as String,
      authorCredentials: json['authorCredentials'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      readTimeMinutes: json['readTimeMinutes'] as int? ?? 5,
      viewCount: json['viewCount'] as int? ?? 0,
      bookmarkCount: json['bookmarkCount'] as int? ?? 0,
      publishedAt: DateTime.parse(json['publishedAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      relatedArticleIds: (json['relatedArticleIds'] as List<dynamic>?)?.cast<String>(),
      difficulty: LunaArticleDifficulty.values[json['difficulty'] as int? ?? 0],
    );
  }

  LunaArticle copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    String? imageUrl,
    String? thumbnailUrl,
    LunaArticleCategory? category,
    List<String>? tags,
    String? authorName,
    String? authorCredentials,
    bool? isVerified,
    int? readTimeMinutes,
    int? viewCount,
    int? bookmarkCount,
    bool? isBookmarked,
    DateTime? publishedAt,
    DateTime? updatedAt,
    List<String>? relatedArticleIds,
    LunaArticleDifficulty? difficulty,
  }) {
    return LunaArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      authorName: authorName ?? this.authorName,
      authorCredentials: authorCredentials ?? this.authorCredentials,
      isVerified: isVerified ?? this.isVerified,
      readTimeMinutes: readTimeMinutes ?? this.readTimeMinutes,
      viewCount: viewCount ?? this.viewCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      relatedArticleIds: relatedArticleIds ?? this.relatedArticleIds,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

/// Health tip for daily insights
class LunaHealthTip {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final LunaTipCategory category;
  final LunaCyclePhaseRelevance? phaseRelevance;
  final bool isLiked;
  final DateTime? shownAt;

  const LunaHealthTip({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.category,
    this.phaseRelevance,
    this.isLiked = false,
    this.shownAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'imageUrl': imageUrl,
    'category': category.index,
    'phaseRelevance': phaseRelevance?.index,
    'isLiked': isLiked,
    'shownAt': shownAt?.toIso8601String(),
  };

  factory LunaHealthTip.fromJson(Map<String, dynamic> json) {
    return LunaHealthTip(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      category: LunaTipCategory.values[json['category'] as int? ?? 0],
      phaseRelevance: json['phaseRelevance'] != null 
          ? LunaCyclePhaseRelevance.values[json['phaseRelevance'] as int] 
          : null,
      isLiked: json['isLiked'] as bool? ?? false,
      shownAt: json['shownAt'] != null 
          ? DateTime.parse(json['shownAt'] as String) 
          : null,
    );
  }
}

/// Myth vs Fact entry
class LunaMythFact {
  final String id;
  final String myth;
  final String fact;
  final String explanation;
  final String? sourceUrl;
  final String? sourceName;
  final LunaMythCategory category;
  final bool isDebunked;

  const LunaMythFact({
    required this.id,
    required this.myth,
    required this.fact,
    required this.explanation,
    this.sourceUrl,
    this.sourceName,
    required this.category,
    this.isDebunked = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'myth': myth,
    'fact': fact,
    'explanation': explanation,
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
    'category': category.index,
    'isDebunked': isDebunked,
  };

  factory LunaMythFact.fromJson(Map<String, dynamic> json) {
    return LunaMythFact(
      id: json['id'] as String,
      myth: json['myth'] as String,
      fact: json['fact'] as String,
      explanation: json['explanation'] as String,
      sourceUrl: json['sourceUrl'] as String?,
      sourceName: json['sourceName'] as String?,
      category: LunaMythCategory.values[json['category'] as int? ?? 0],
      isDebunked: json['isDebunked'] as bool? ?? true,
    );
  }
}

/// Article categories
enum LunaArticleCategory {
  cycleBasics,
  symptoms,
  nutrition,
  fitness,
  mentalHealth,
  selfCare,
  fertility,
  pregnancy,
  contraception,
  conditions,
  menopause,
  relationships,
  sexuality,
  lifestyle,
}

extension LunaArticleCategoryExtension on LunaArticleCategory {
  String get displayName {
    switch (this) {
      case LunaArticleCategory.cycleBasics: return 'Cycle Basics';
      case LunaArticleCategory.symptoms: return 'Symptoms';
      case LunaArticleCategory.nutrition: return 'Nutrition';
      case LunaArticleCategory.fitness: return 'Fitness';
      case LunaArticleCategory.mentalHealth: return 'Mental Health';
      case LunaArticleCategory.selfCare: return 'Self Care';
      case LunaArticleCategory.fertility: return 'Fertility';
      case LunaArticleCategory.pregnancy: return 'Pregnancy';
      case LunaArticleCategory.contraception: return 'Contraception';
      case LunaArticleCategory.conditions: return 'Health Conditions';
      case LunaArticleCategory.menopause: return 'Menopause';
      case LunaArticleCategory.relationships: return 'Relationships';
      case LunaArticleCategory.sexuality: return 'Sexual Health';
      case LunaArticleCategory.lifestyle: return 'Lifestyle';
    }
  }

  IconData get icon {
    switch (this) {
      case LunaArticleCategory.cycleBasics: return Icons.loop;
      case LunaArticleCategory.symptoms: return Icons.healing_outlined;
      case LunaArticleCategory.nutrition: return Icons.restaurant_outlined;
      case LunaArticleCategory.fitness: return Icons.fitness_center;
      case LunaArticleCategory.mentalHealth: return Icons.psychology_outlined;
      case LunaArticleCategory.selfCare: return Icons.spa_outlined;
      case LunaArticleCategory.fertility: return Icons.child_friendly;
      case LunaArticleCategory.pregnancy: return Icons.pregnant_woman;
      case LunaArticleCategory.contraception: return Icons.shield_outlined;
      case LunaArticleCategory.conditions: return Icons.medical_services_outlined;
      case LunaArticleCategory.menopause: return Icons.elderly_woman;
      case LunaArticleCategory.relationships: return Icons.favorite_outline;
      case LunaArticleCategory.sexuality: return Icons.favorite;
      case LunaArticleCategory.lifestyle: return Icons.wb_sunny_outlined;
    }
  }

  Color get color {
    switch (this) {
      case LunaArticleCategory.cycleBasics: return const Color(0xFFFF6B8A);
      case LunaArticleCategory.symptoms: return const Color(0xFFFFB74D);
      case LunaArticleCategory.nutrition: return const Color(0xFF81C784);
      case LunaArticleCategory.fitness: return const Color(0xFF4FC3F7);
      case LunaArticleCategory.mentalHealth: return const Color(0xFF9575CD);
      case LunaArticleCategory.selfCare: return const Color(0xFFFFB6C1);
      case LunaArticleCategory.fertility: return const Color(0xFF4DD0E1);
      case LunaArticleCategory.pregnancy: return const Color(0xFFF48FB1);
      case LunaArticleCategory.contraception: return const Color(0xFF90A4AE);
      case LunaArticleCategory.conditions: return const Color(0xFFE57373);
      case LunaArticleCategory.menopause: return const Color(0xFFBA68C8);
      case LunaArticleCategory.relationships: return const Color(0xFFE91E63);
      case LunaArticleCategory.sexuality: return const Color(0xFFFF8A80);
      case LunaArticleCategory.lifestyle: return const Color(0xFFFFD54F);
    }
  }
}

/// Tip categories
enum LunaTipCategory {
  daily,
  nutrition,
  fitness,
  sleep,
  stress,
  selfCare,
  hydration,
  mindfulness,
}

extension LunaTipCategoryExtension on LunaTipCategory {
  String get displayName {
    switch (this) {
      case LunaTipCategory.daily: return 'Daily Tip';
      case LunaTipCategory.nutrition: return 'Nutrition';
      case LunaTipCategory.fitness: return 'Fitness';
      case LunaTipCategory.sleep: return 'Sleep';
      case LunaTipCategory.stress: return 'Stress Relief';
      case LunaTipCategory.selfCare: return 'Self Care';
      case LunaTipCategory.hydration: return 'Hydration';
      case LunaTipCategory.mindfulness: return 'Mindfulness';
    }
  }

  String get emoji {
    switch (this) {
      case LunaTipCategory.daily: return '💡';
      case LunaTipCategory.nutrition: return '🥗';
      case LunaTipCategory.fitness: return '🏃‍♀️';
      case LunaTipCategory.sleep: return '😴';
      case LunaTipCategory.stress: return '🧘';
      case LunaTipCategory.selfCare: return '🛁';
      case LunaTipCategory.hydration: return '💧';
      case LunaTipCategory.mindfulness: return '🧠';
    }
  }
}

/// Myth categories
enum LunaMythCategory {
  periods,
  fertility,
  pregnancy,
  contraception,
  pms,
  exercise,
  food,
  hygiene,
}

extension LunaMythCategoryExtension on LunaMythCategory {
  String get displayName {
    switch (this) {
      case LunaMythCategory.periods: return 'Period Myths';
      case LunaMythCategory.fertility: return 'Fertility Myths';
      case LunaMythCategory.pregnancy: return 'Pregnancy Myths';
      case LunaMythCategory.contraception: return 'Contraception Myths';
      case LunaMythCategory.pms: return 'PMS Myths';
      case LunaMythCategory.exercise: return 'Exercise Myths';
      case LunaMythCategory.food: return 'Food Myths';
      case LunaMythCategory.hygiene: return 'Hygiene Myths';
    }
  }
}

/// Cycle phase relevance for tips
enum LunaCyclePhaseRelevance {
  menstrual,
  follicular,
  ovulation,
  luteal,
  pms,
  all,
}

/// Article difficulty level
enum LunaArticleDifficulty {
  beginner,
  intermediate,
  advanced,
}

extension LunaArticleDifficultyExtension on LunaArticleDifficulty {
  String get displayName {
    switch (this) {
      case LunaArticleDifficulty.beginner: return 'Beginner';
      case LunaArticleDifficulty.intermediate: return 'Intermediate';
      case LunaArticleDifficulty.advanced: return 'Advanced';
    }
  }

  Color get color {
    switch (this) {
      case LunaArticleDifficulty.beginner: return const Color(0xFF81C784);
      case LunaArticleDifficulty.intermediate: return const Color(0xFFFFB74D);
      case LunaArticleDifficulty.advanced: return const Color(0xFFE57373);
    }
  }
}

/// Predefined myths and facts
class LunaPredefinedMyths {
  static List<LunaMythFact> get all => [
    const LunaMythFact(
      id: 'myth-1',
      myth: 'You can\'t get pregnant during your period',
      fact: 'You CAN get pregnant during your period',
      explanation: 'Sperm can survive in the body for up to 5 days. If you have a short cycle, ovulation could occur shortly after your period ends, making pregnancy possible.',
      category: LunaMythCategory.fertility,
    ),
    const LunaMythFact(
      id: 'myth-2',
      myth: 'PMS is just an excuse for bad moods',
      fact: 'PMS is a real medical condition',
      explanation: 'Premenstrual syndrome affects up to 75% of women and involves real hormonal changes that can cause physical and emotional symptoms.',
      category: LunaMythCategory.pms,
    ),
    const LunaMythFact(
      id: 'myth-3',
      myth: 'You shouldn\'t exercise during your period',
      fact: 'Exercise can actually help relieve period symptoms',
      explanation: 'Light to moderate exercise releases endorphins which can reduce cramps, improve mood, and decrease fatigue.',
      category: LunaMythCategory.exercise,
    ),
    const LunaMythFact(
      id: 'myth-4',
      myth: 'Periods sync up with friends',
      fact: 'Period syncing is largely a myth',
      explanation: 'Studies have found no scientific evidence for menstrual synchrony. What appears to be syncing is usually coincidental overlap of varying cycle lengths.',
      category: LunaMythCategory.periods,
    ),
    const LunaMythFact(
      id: 'myth-5',
      myth: 'You lose a lot of blood during your period',
      fact: 'The average blood loss is only 2-3 tablespoons',
      explanation: 'While it may feel like more, the average period produces only 30-40ml of blood. If you\'re losing more, consult a doctor.',
      category: LunaMythCategory.periods,
    ),
    const LunaMythFact(
      id: 'myth-6',
      myth: 'Tampons can get lost inside you',
      fact: 'Tampons cannot get lost inside your body',
      explanation: 'The cervix is too small for a tampon to pass through. If you have trouble removing one, stay calm and try again, or see a healthcare provider.',
      category: LunaMythCategory.hygiene,
    ),
    const LunaMythFact(
      id: 'myth-7',
      myth: 'Eating certain foods can delay your period',
      fact: 'No food can significantly delay menstruation',
      explanation: 'While nutrition affects overall health, no specific food can reliably delay your period. Stress and major lifestyle changes are more likely to affect timing.',
      category: LunaMythCategory.food,
    ),
    const LunaMythFact(
      id: 'myth-8',
      myth: 'Irregular periods always mean something is wrong',
      fact: 'Some irregularity is normal, especially in teens',
      explanation: 'It can take several years for periods to become regular after they start. However, consistently irregular cycles in adults should be discussed with a doctor.',
      category: LunaMythCategory.periods,
    ),
  ];
}

/// Predefined health tips
class LunaPredefinedTips {
  static List<LunaHealthTip> get menstrualTips => [
    const LunaHealthTip(
      id: 'tip-m1',
      title: 'Stay Warm',
      content: 'Apply a heating pad to your lower abdomen to help relieve cramps naturally.',
      category: LunaTipCategory.selfCare,
      phaseRelevance: LunaCyclePhaseRelevance.menstrual,
    ),
    const LunaHealthTip(
      id: 'tip-m2',
      title: 'Hydrate More',
      content: 'Drinking extra water can help reduce bloating and ease cramps during your period.',
      category: LunaTipCategory.hydration,
      phaseRelevance: LunaCyclePhaseRelevance.menstrual,
    ),
    const LunaHealthTip(
      id: 'tip-m3',
      title: 'Iron-Rich Foods',
      content: 'Eat iron-rich foods like spinach, lentils, and lean red meat to replenish iron lost during menstruation.',
      category: LunaTipCategory.nutrition,
      phaseRelevance: LunaCyclePhaseRelevance.menstrual,
    ),
  ];

  static List<LunaHealthTip> get follicularTips => [
    const LunaHealthTip(
      id: 'tip-f1',
      title: 'Try Something New',
      content: 'Your energy is rising! This is a great time to start new projects or try a new workout routine.',
      category: LunaTipCategory.fitness,
      phaseRelevance: LunaCyclePhaseRelevance.follicular,
    ),
    const LunaHealthTip(
      id: 'tip-f2',
      title: 'High-Intensity Workouts',
      content: 'Your body recovers faster during this phase. Try HIIT or strength training for best results.',
      category: LunaTipCategory.fitness,
      phaseRelevance: LunaCyclePhaseRelevance.follicular,
    ),
  ];

  static List<LunaHealthTip> get ovulationTips => [
    const LunaHealthTip(
      id: 'tip-o1',
      title: 'Peak Communication',
      content: 'Your verbal skills peak during ovulation. Schedule important conversations or presentations now.',
      category: LunaTipCategory.daily,
      phaseRelevance: LunaCyclePhaseRelevance.ovulation,
    ),
    const LunaHealthTip(
      id: 'tip-o2',
      title: 'Social Time',
      content: 'You may feel more social and confident. Great time for networking or meeting new people.',
      category: LunaTipCategory.daily,
      phaseRelevance: LunaCyclePhaseRelevance.ovulation,
    ),
  ];

  static List<LunaHealthTip> get lutealTips => [
    const LunaHealthTip(
      id: 'tip-l1',
      title: 'Complex Carbs',
      content: 'Include whole grains and complex carbs to help stabilize mood and energy levels.',
      category: LunaTipCategory.nutrition,
      phaseRelevance: LunaCyclePhaseRelevance.luteal,
    ),
    const LunaHealthTip(
      id: 'tip-l2',
      title: 'Gentle Movement',
      content: 'Switch to yoga, pilates, or walking as your energy naturally decreases.',
      category: LunaTipCategory.fitness,
      phaseRelevance: LunaCyclePhaseRelevance.luteal,
    ),
  ];

  static List<LunaHealthTip> get pmsTips => [
    const LunaHealthTip(
      id: 'tip-p1',
      title: 'Reduce Salt',
      content: 'Limiting sodium intake can help reduce bloating and water retention.',
      category: LunaTipCategory.nutrition,
      phaseRelevance: LunaCyclePhaseRelevance.pms,
    ),
    const LunaHealthTip(
      id: 'tip-p2',
      title: 'Self-Compassion',
      content: 'Be gentle with yourself. It\'s okay to say no to extra commitments right now.',
      category: LunaTipCategory.mindfulness,
      phaseRelevance: LunaCyclePhaseRelevance.pms,
    ),
  ];
}
