enum QuestionType {
  multipleChoice,
  trueFalse,
  shortAnswer,
  fillInBlank,
  matching,
  ordering,
  essay,
}

extension QuestionTypeExtension on QuestionType {
  String get displayName {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.shortAnswer:
        return 'Short Answer';
      case QuestionType.fillInBlank:
        return 'Fill in Blank';
      case QuestionType.matching:
        return 'Matching';
      case QuestionType.ordering:
        return 'Ordering';
      case QuestionType.essay:
        return 'Essay';
    }
  }

  String get emoji {
    switch (this) {
      case QuestionType.multipleChoice:
        return '🔘';
      case QuestionType.trueFalse:
        return '✅';
      case QuestionType.shortAnswer:
        return '✏️';
      case QuestionType.fillInBlank:
        return '📝';
      case QuestionType.matching:
        return '🔗';
      case QuestionType.ordering:
        return '📋';
      case QuestionType.essay:
        return '📄';
    }
  }
}

enum TestDifficulty {
  beginner,
  intermediate,
  advanced,
  expert,
}

extension TestDifficultyExtension on TestDifficulty {
  String get displayName {
    switch (this) {
      case TestDifficulty.beginner:
        return 'Beginner';
      case TestDifficulty.intermediate:
        return 'Intermediate';
      case TestDifficulty.advanced:
        return 'Advanced';
      case TestDifficulty.expert:
        return 'Expert';
    }
  }

  String get emoji {
    switch (this) {
      case TestDifficulty.beginner:
        return '🌱';
      case TestDifficulty.intermediate:
        return '🌿';
      case TestDifficulty.advanced:
        return '🌳';
      case TestDifficulty.expert:
        return '🏆';
    }
  }

  double get scoreMultiplier {
    switch (this) {
      case TestDifficulty.beginner:
        return 1.0;
      case TestDifficulty.intermediate:
        return 1.25;
      case TestDifficulty.advanced:
        return 1.5;
      case TestDifficulty.expert:
        return 2.0;
    }
  }
}

enum TestStatus {
  draft,
  ready,
  inProgress,
  completed,
  abandoned,
}

extension TestStatusExtension on TestStatus {
  String get displayName {
    switch (this) {
      case TestStatus.draft:
        return 'Draft';
      case TestStatus.ready:
        return 'Ready';
      case TestStatus.inProgress:
        return 'In Progress';
      case TestStatus.completed:
        return 'Completed';
      case TestStatus.abandoned:
        return 'Abandoned';
    }
  }
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;
  final String? explanation;
  final String? imageUrl;

  QuestionOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
    this.explanation,
    this.imageUrl,
  });

  QuestionOption copyWith({
    String? id,
    String? text,
    bool? isCorrect,
    String? explanation,
    String? imageUrl,
  }) {
    return QuestionOption(
      id: id ?? this.id,
      text: text ?? this.text,
      isCorrect: isCorrect ?? this.isCorrect,
      explanation: explanation ?? this.explanation,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCorrect': isCorrect,
      'explanation': explanation,
      'imageUrl': imageUrl,
    };
  }

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
      explanation: json['explanation'],
      imageUrl: json['imageUrl'],
    );
  }
}

class Question {
  final String id;
  final String testId;
  final String questionText;
  final QuestionType type;
  final List<QuestionOption> options;
  final String? correctAnswer;
  final List<String>? correctAnswers;
  final String? explanation;
  final String? hint;
  final String? imageUrl;
  final String? audioUrl;
  final int points;
  final int timeLimitSeconds;
  final String? topicId;
  final List<String> tags;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  Question({
    required this.id,
    required this.testId,
    required this.questionText,
    required this.type,
    this.options = const [],
    this.correctAnswer,
    this.correctAnswers,
    this.explanation,
    this.hint,
    this.imageUrl,
    this.audioUrl,
    this.points = 1,
    this.timeLimitSeconds = 60,
    this.topicId,
    this.tags = const [],
    this.orderIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool checkAnswer(dynamic userAnswer) {
    switch (type) {
      case QuestionType.multipleChoice:
        if (userAnswer is String) {
          return options.any((o) => o.id == userAnswer && o.isCorrect);
        }
        return false;
      case QuestionType.trueFalse:
        return userAnswer.toString().toLowerCase() == correctAnswer?.toLowerCase();
      case QuestionType.shortAnswer:
        if (correctAnswers != null && correctAnswers!.isNotEmpty) {
          return correctAnswers!.any(
            (a) => a.toLowerCase().trim() == userAnswer.toString().toLowerCase().trim(),
          );
        }
        return correctAnswer?.toLowerCase().trim() == userAnswer.toString().toLowerCase().trim();
      case QuestionType.fillInBlank:
        return correctAnswer?.toLowerCase().trim() == userAnswer.toString().toLowerCase().trim();
      case QuestionType.matching:
        if (userAnswer is Map && correctAnswers != null) {
          return userAnswer.toString() == correctAnswers.toString();
        }
        return false;
      case QuestionType.ordering:
        if (userAnswer is List && correctAnswers != null) {
          if (userAnswer.length != correctAnswers!.length) return false;
          for (int i = 0; i < userAnswer.length; i++) {
            if (userAnswer[i] != correctAnswers![i]) return false;
          }
          return true;
        }
        return false;
      case QuestionType.essay:
        return true;
    }
  }

  Question copyWith({
    String? id,
    String? testId,
    String? questionText,
    QuestionType? type,
    List<QuestionOption>? options,
    String? correctAnswer,
    List<String>? correctAnswers,
    String? explanation,
    String? hint,
    String? imageUrl,
    String? audioUrl,
    int? points,
    int? timeLimitSeconds,
    String? topicId,
    List<String>? tags,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Question(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      questionText: questionText ?? this.questionText,
      type: type ?? this.type,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      explanation: explanation ?? this.explanation,
      hint: hint ?? this.hint,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      points: points ?? this.points,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      topicId: topicId ?? this.topicId,
      tags: tags ?? this.tags,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'testId': testId,
      'questionText': questionText,
      'type': type.index,
      'options': options.map((o) => o.toJson()).toList(),
      'correctAnswer': correctAnswer,
      'correctAnswers': correctAnswers,
      'explanation': explanation,
      'hint': hint,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'points': points,
      'timeLimitSeconds': timeLimitSeconds,
      'topicId': topicId,
      'tags': tags,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? '',
      testId: json['testId'] ?? '',
      questionText: json['questionText'] ?? '',
      type: QuestionType.values[json['type'] ?? 0],
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => QuestionOption.fromJson(Map<String, dynamic>.from(o)))
              .toList() ??
          [],
      correctAnswer: json['correctAnswer'],
      correctAnswers: json['correctAnswers'] != null
          ? List<String>.from(json['correctAnswers'])
          : null,
      explanation: json['explanation'],
      hint: json['hint'],
      imageUrl: json['imageUrl'],
      audioUrl: json['audioUrl'],
      points: json['points'] ?? 1,
      timeLimitSeconds: json['timeLimitSeconds'] ?? 60,
      topicId: json['topicId'],
      tags: List<String>.from(json['tags'] ?? []),
      orderIndex: json['orderIndex'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

class PracticeTest {
  final String id;
  final String title;
  final String? description;
  final String? subjectId;
  final String? topicId;
  final String? examId;
  final TestDifficulty difficulty;
  final TestStatus status;
  final int questionCount;
  final int totalPoints;
  final int timeLimitMinutes;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showExplanations;
  final bool allowReview;
  final int passingScore;
  final String colorHex;
  final String? imageUrl;
  final List<String> tags;
  final int attemptCount;
  final double bestScore;
  final double averageScore;
  final DateTime? lastAttemptAt;
  final bool isPublic;
  final String? authorId;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  PracticeTest({
    required this.id,
    required this.title,
    this.description,
    this.subjectId,
    this.topicId,
    this.examId,
    this.difficulty = TestDifficulty.intermediate,
    this.status = TestStatus.ready,
    this.questionCount = 0,
    this.totalPoints = 0,
    this.timeLimitMinutes = 30,
    this.shuffleQuestions = true,
    this.shuffleOptions = true,
    this.showExplanations = true,
    this.allowReview = true,
    this.passingScore = 60,
    this.colorHex = '#8B5CF6',
    this.imageUrl,
    this.tags = const [],
    this.attemptCount = 0,
    this.bestScore = 0.0,
    this.averageScore = 0.0,
    this.lastAttemptAt,
    this.isPublic = false,
    this.authorId,
    this.orderIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isPassed => bestScore >= passingScore;

  String get durationFormatted {
    if (timeLimitMinutes < 60) {
      return '$timeLimitMinutes min';
    }
    final hours = timeLimitMinutes ~/ 60;
    final mins = timeLimitMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  PracticeTest copyWith({
    String? id,
    String? title,
    String? description,
    String? subjectId,
    String? topicId,
    String? examId,
    TestDifficulty? difficulty,
    TestStatus? status,
    int? questionCount,
    int? totalPoints,
    int? timeLimitMinutes,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    bool? showExplanations,
    bool? allowReview,
    int? passingScore,
    String? colorHex,
    String? imageUrl,
    List<String>? tags,
    int? attemptCount,
    double? bestScore,
    double? averageScore,
    DateTime? lastAttemptAt,
    bool? isPublic,
    String? authorId,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return PracticeTest(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      examId: examId ?? this.examId,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      questionCount: questionCount ?? this.questionCount,
      totalPoints: totalPoints ?? this.totalPoints,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleOptions: shuffleOptions ?? this.shuffleOptions,
      showExplanations: showExplanations ?? this.showExplanations,
      allowReview: allowReview ?? this.allowReview,
      passingScore: passingScore ?? this.passingScore,
      colorHex: colorHex ?? this.colorHex,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      attemptCount: attemptCount ?? this.attemptCount,
      bestScore: bestScore ?? this.bestScore,
      averageScore: averageScore ?? this.averageScore,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
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
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'topicId': topicId,
      'examId': examId,
      'difficulty': difficulty.index,
      'status': status.index,
      'questionCount': questionCount,
      'totalPoints': totalPoints,
      'timeLimitMinutes': timeLimitMinutes,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'showExplanations': showExplanations,
      'allowReview': allowReview,
      'passingScore': passingScore,
      'colorHex': colorHex,
      'imageUrl': imageUrl,
      'tags': tags,
      'attemptCount': attemptCount,
      'bestScore': bestScore,
      'averageScore': averageScore,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'isPublic': isPublic,
      'authorId': authorId,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PracticeTest.fromJson(Map<String, dynamic> json) {
    return PracticeTest(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subjectId'],
      topicId: json['topicId'],
      examId: json['examId'],
      difficulty: TestDifficulty.values[json['difficulty'] ?? 1],
      status: TestStatus.values[json['status'] ?? 1],
      questionCount: json['questionCount'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      timeLimitMinutes: json['timeLimitMinutes'] ?? 30,
      shuffleQuestions: json['shuffleQuestions'] ?? true,
      shuffleOptions: json['shuffleOptions'] ?? true,
      showExplanations: json['showExplanations'] ?? true,
      allowReview: json['allowReview'] ?? true,
      passingScore: json['passingScore'] ?? 60,
      colorHex: json['colorHex'] ?? '#8B5CF6',
      imageUrl: json['imageUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      attemptCount: json['attemptCount'] ?? 0,
      bestScore: (json['bestScore'] ?? 0.0).toDouble(),
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'])
          : null,
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

class TestAttempt {
  final String id;
  final String testId;
  final DateTime startTime;
  final DateTime? endTime;
  final TestStatus status;
  final int questionsAnswered;
  final int correctAnswers;
  final int totalQuestions;
  final int totalPoints;
  final int earnedPoints;
  final double score;
  final bool passed;
  final List<QuestionAnswer> answers;
  final int timeSpentSeconds;
  final DateTime createdAt;

  TestAttempt({
    required this.id,
    required this.testId,
    required this.startTime,
    this.endTime,
    this.status = TestStatus.inProgress,
    this.questionsAnswered = 0,
    this.correctAnswers = 0,
    this.totalQuestions = 0,
    this.totalPoints = 0,
    this.earnedPoints = 0,
    this.score = 0.0,
    this.passed = false,
    this.answers = const [],
    this.timeSpentSeconds = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get accuracy {
    if (questionsAnswered == 0) return 0.0;
    return correctAnswers / questionsAnswered;
  }

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }

  String get durationFormatted {
    final mins = timeSpentSeconds ~/ 60;
    final secs = timeSpentSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  TestAttempt copyWith({
    String? id,
    String? testId,
    DateTime? startTime,
    DateTime? endTime,
    TestStatus? status,
    int? questionsAnswered,
    int? correctAnswers,
    int? totalQuestions,
    int? totalPoints,
    int? earnedPoints,
    double? score,
    bool? passed,
    List<QuestionAnswer>? answers,
    int? timeSpentSeconds,
    DateTime? createdAt,
  }) {
    return TestAttempt(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalPoints: totalPoints ?? this.totalPoints,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      score: score ?? this.score,
      passed: passed ?? this.passed,
      answers: answers ?? this.answers,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'testId': testId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status.index,
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'totalPoints': totalPoints,
      'earnedPoints': earnedPoints,
      'score': score,
      'passed': passed,
      'answers': answers.map((a) => a.toJson()).toList(),
      'timeSpentSeconds': timeSpentSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    return TestAttempt(
      id: json['id'] ?? '',
      testId: json['testId'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: TestStatus.values[json['status'] ?? 2],
      questionsAnswered: json['questionsAnswered'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
      earnedPoints: json['earnedPoints'] ?? 0,
      score: (json['score'] ?? 0.0).toDouble(),
      passed: json['passed'] ?? false,
      answers: (json['answers'] as List<dynamic>?)
              ?.map((a) => QuestionAnswer.fromJson(Map<String, dynamic>.from(a)))
              .toList() ??
          [],
      timeSpentSeconds: json['timeSpentSeconds'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class QuestionAnswer {
  final String questionId;
  final dynamic userAnswer;
  final bool isCorrect;
  final int pointsEarned;
  final int responseTimeSeconds;
  final bool usedHint;
  final DateTime answeredAt;

  QuestionAnswer({
    required this.questionId,
    required this.userAnswer,
    this.isCorrect = false,
    this.pointsEarned = 0,
    this.responseTimeSeconds = 0,
    this.usedHint = false,
    DateTime? answeredAt,
  }) : answeredAt = answeredAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'responseTimeSeconds': responseTimeSeconds,
      'usedHint': usedHint,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      questionId: json['questionId'] ?? '',
      userAnswer: json['userAnswer'],
      isCorrect: json['isCorrect'] ?? false,
      pointsEarned: json['pointsEarned'] ?? 0,
      responseTimeSeconds: json['responseTimeSeconds'] ?? 0,
      usedHint: json['usedHint'] ?? false,
      answeredAt: json['answeredAt'] != null
          ? DateTime.parse(json['answeredAt'])
          : DateTime.now(),
    );
  }
}
