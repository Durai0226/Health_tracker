import 'dart:math';

enum FlashcardDifficulty {
  easy,
  medium,
  hard,
  veryHard,
}

extension FlashcardDifficultyExtension on FlashcardDifficulty {
  String get displayName {
    switch (this) {
      case FlashcardDifficulty.easy:
        return 'Easy';
      case FlashcardDifficulty.medium:
        return 'Medium';
      case FlashcardDifficulty.hard:
        return 'Hard';
      case FlashcardDifficulty.veryHard:
        return 'Very Hard';
    }
  }

  String get emoji {
    switch (this) {
      case FlashcardDifficulty.easy:
        return '🟢';
      case FlashcardDifficulty.medium:
        return '🟡';
      case FlashcardDifficulty.hard:
        return '🟠';
      case FlashcardDifficulty.veryHard:
        return '🔴';
    }
  }

  int get intervalMultiplier {
    switch (this) {
      case FlashcardDifficulty.easy:
        return 4;
      case FlashcardDifficulty.medium:
        return 2;
      case FlashcardDifficulty.hard:
        return 1;
      case FlashcardDifficulty.veryHard:
        return 0;
    }
  }
}

enum FlashcardStatus {
  new_card,
  learning,
  reviewing,
  mastered,
}

extension FlashcardStatusExtension on FlashcardStatus {
  String get displayName {
    switch (this) {
      case FlashcardStatus.new_card:
        return 'New';
      case FlashcardStatus.learning:
        return 'Learning';
      case FlashcardStatus.reviewing:
        return 'Reviewing';
      case FlashcardStatus.mastered:
        return 'Mastered';
    }
  }

  String get emoji {
    switch (this) {
      case FlashcardStatus.new_card:
        return '✨';
      case FlashcardStatus.learning:
        return '📖';
      case FlashcardStatus.reviewing:
        return '🔄';
      case FlashcardStatus.mastered:
        return '⭐';
    }
  }
}

class Flashcard {
  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? hint;
  final String? imageUrl;
  final String? audioUrl;
  final FlashcardStatus status;
  final int repetitions;
  final double easeFactor;
  final int interval;
  final DateTime? nextReviewDate;
  final DateTime? lastReviewedAt;
  final int correctCount;
  final int incorrectCount;
  final List<String> tags;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;
  final bool isSynced;

  Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.hint,
    this.imageUrl,
    this.audioUrl,
    this.status = FlashcardStatus.new_card,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.nextReviewDate,
    this.lastReviewedAt,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.tags = const [],
    this.orderIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get accuracy {
    final total = correctCount + incorrectCount;
    if (total == 0) return 0.0;
    return correctCount / total;
  }

  bool get isDue {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  Flashcard updateAfterReview(FlashcardDifficulty difficulty) {
    int newRepetitions;
    double newEaseFactor;
    int newInterval;
    FlashcardStatus newStatus;
    int newCorrect = correctCount;
    int newIncorrect = incorrectCount;

    if (difficulty == FlashcardDifficulty.veryHard) {
      newRepetitions = 0;
      newEaseFactor = max(1.3, easeFactor - 0.2);
      newInterval = 1;
      newStatus = FlashcardStatus.learning;
      newIncorrect++;
    } else {
      newRepetitions = repetitions + 1;
      newEaseFactor = easeFactor + (0.1 - (3 - difficulty.index) * (0.08 + (3 - difficulty.index) * 0.02));
      newEaseFactor = max(1.3, newEaseFactor);
      newCorrect++;

      if (newRepetitions == 1) {
        newInterval = 1;
        newStatus = FlashcardStatus.learning;
      } else if (newRepetitions == 2) {
        newInterval = 6;
        newStatus = FlashcardStatus.reviewing;
      } else {
        newInterval = (interval * newEaseFactor * difficulty.intervalMultiplier / 2).round();
        newInterval = max(1, newInterval);
        newStatus = newRepetitions >= 5 ? FlashcardStatus.mastered : FlashcardStatus.reviewing;
      }
    }

    return copyWith(
      repetitions: newRepetitions,
      easeFactor: newEaseFactor,
      interval: newInterval,
      nextReviewDate: DateTime.now().add(Duration(days: newInterval)),
      lastReviewedAt: DateTime.now(),
      status: newStatus,
      correctCount: newCorrect,
      incorrectCount: newIncorrect,
    );
  }

  Flashcard copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    String? hint,
    String? imageUrl,
    String? audioUrl,
    FlashcardStatus? status,
    int? repetitions,
    double? easeFactor,
    int? interval,
    DateTime? nextReviewDate,
    DateTime? lastReviewedAt,
    int? correctCount,
    int? incorrectCount,
    List<String>? tags,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    bool? isSynced,
  }) {
    return Flashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      hint: hint ?? this.hint,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      tags: tags ?? this.tags,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isFavorite: isFavorite ?? this.isFavorite,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deckId': deckId,
      'front': front,
      'back': back,
      'hint': hint,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'status': status.index,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'interval': interval,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'tags': tags,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] ?? '',
      deckId: json['deckId'] ?? '',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      hint: json['hint'],
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      status: FlashcardStatus.values[json['status'] ?? 0],
      repetitions: json['repetitions'] ?? 0,
      easeFactor: (json['easeFactor'] ?? 2.5).toDouble(),
      interval: json['interval'] ?? 0,
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.parse(json['nextReviewDate'])
          : null,
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'])
          : null,
      correctCount: json['correctCount'] ?? 0,
      incorrectCount: json['incorrectCount'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      orderIndex: json['orderIndex'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isFavorite: json['isFavorite'] ?? false,
      isSynced: true,
    );
  }
}

class FlashcardDeck {
  final String id;
  final String name;
  final String? description;
  final String? subjectId;
  final String? topicId;
  final String? examId;
  final String colorHex;
  final String? iconName;
  final int cardCount;
  final int masteredCount;
  final int dueCount;
  final DateTime? lastStudiedAt;
  final int totalReviews;
  final double averageAccuracy;
  final List<String> tags;
  final bool isPublic;
  final String? authorId;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  FlashcardDeck({
    required this.id,
    required this.name,
    this.description,
    this.subjectId,
    this.topicId,
    this.examId,
    this.colorHex = '#6366F1',
    this.iconName,
    this.cardCount = 0,
    this.masteredCount = 0,
    this.dueCount = 0,
    this.lastStudiedAt,
    this.totalReviews = 0,
    this.averageAccuracy = 0.0,
    this.tags = const [],
    this.isPublic = false,
    this.authorId,
    this.orderIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get masteryProgress {
    if (cardCount == 0) return 0.0;
    return masteredCount / cardCount;
  }

  FlashcardDeck copyWith({
    String? id,
    String? name,
    String? description,
    String? subjectId,
    String? topicId,
    String? examId,
    String? colorHex,
    String? iconName,
    int? cardCount,
    int? masteredCount,
    int? dueCount,
    DateTime? lastStudiedAt,
    int? totalReviews,
    double? averageAccuracy,
    List<String>? tags,
    bool? isPublic,
    String? authorId,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return FlashcardDeck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      examId: examId ?? this.examId,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      cardCount: cardCount ?? this.cardCount,
      masteredCount: masteredCount ?? this.masteredCount,
      dueCount: dueCount ?? this.dueCount,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      totalReviews: totalReviews ?? this.totalReviews,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      authorId: authorId ?? this.authorId,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'subjectId': subjectId,
      'topicId': topicId,
      'examId': examId,
      'colorHex': colorHex,
      'iconName': iconName,
      'cardCount': cardCount,
      'masteredCount': masteredCount,
      'dueCount': dueCount,
      'lastStudiedAt': lastStudiedAt?.toIso8601String(),
      'totalReviews': totalReviews,
      'averageAccuracy': averageAccuracy,
      'tags': tags,
      'isPublic': isPublic,
      'authorId': authorId,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    return FlashcardDeck(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'],
      topicId: json['topicId'],
      examId: json['examId'],
      colorHex: json['colorHex'] ?? '#6366F1',
      iconName: json['iconName'],
      cardCount: json['cardCount'] ?? 0,
      masteredCount: json['masteredCount'] ?? 0,
      dueCount: json['dueCount'] ?? 0,
      lastStudiedAt: json['lastStudiedAt'] != null
          ? DateTime.parse(json['lastStudiedAt'])
          : null,
      totalReviews: json['totalReviews'] ?? 0,
      averageAccuracy: (json['averageAccuracy'] ?? 0.0).toDouble(),
      tags: List<String>.from(json['tags'] ?? []),
      isPublic: json['isPublic'] ?? false,
      authorId: json['authorId'],
      orderIndex: json['orderIndex'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
    );
  }
}

class FlashcardStudySession {
  final String id;
  final String deckId;
  final DateTime startTime;
  final DateTime? endTime;
  final int cardsStudied;
  final int correctCount;
  final int incorrectCount;
  final List<FlashcardReview> reviews;

  FlashcardStudySession({
    required this.id,
    required this.deckId,
    required this.startTime,
    this.endTime,
    this.cardsStudied = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.reviews = const [],
  });

  double get accuracy {
    if (cardsStudied == 0) return 0.0;
    return correctCount / cardsStudied;
  }

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }
}

class FlashcardReview {
  final String flashcardId;
  final FlashcardDifficulty difficulty;
  final DateTime reviewedAt;
  final int responseTimeMs;

  FlashcardReview({
    required this.flashcardId,
    required this.difficulty,
    required this.reviewedAt,
    required this.responseTimeMs,
  });
}
