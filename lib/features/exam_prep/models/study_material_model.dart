/// Study Material Models for Exam Prep Feature

class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String subjectId;
  final String topicId;
  final StudyMaterialType type;
  final String content; // HTML or Markdown content
  final List<String> tags;
  final int estimatedReadTime; // in minutes
  final String? pdfUrl;
  final String? videoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPremium;
  final int viewCount;
  final double rating;

  const StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectId,
    required this.topicId,
    required this.type,
    required this.content,
    this.tags = const [],
    this.estimatedReadTime = 10,
    this.pdfUrl,
    this.videoUrl,
    required this.createdAt,
    this.updatedAt,
    this.isPremium = false,
    this.viewCount = 0,
    this.rating = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'subjectId': subjectId,
    'topicId': topicId,
    'type': type.name,
    'content': content,
    'tags': tags,
    'estimatedReadTime': estimatedReadTime,
    'pdfUrl': pdfUrl,
    'videoUrl': videoUrl,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isPremium': isPremium,
    'viewCount': viewCount,
    'rating': rating,
  };

  factory StudyMaterial.fromJson(Map<String, dynamic> json) => StudyMaterial(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    subjectId: json['subjectId'] as String,
    topicId: json['topicId'] as String,
    type: StudyMaterialType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => StudyMaterialType.notes,
    ),
    content: json['content'] as String,
    tags: List<String>.from(json['tags'] ?? []),
    estimatedReadTime: json['estimatedReadTime'] as int? ?? 10,
    pdfUrl: json['pdfUrl'] as String?,
    videoUrl: json['videoUrl'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt'] as String) 
        : null,
    isPremium: json['isPremium'] as bool? ?? false,
    viewCount: json['viewCount'] as int? ?? 0,
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
  );

  StudyMaterial copyWith({
    String? id,
    String? title,
    String? description,
    String? subjectId,
    String? topicId,
    StudyMaterialType? type,
    String? content,
    List<String>? tags,
    int? estimatedReadTime,
    String? pdfUrl,
    String? videoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPremium,
    int? viewCount,
    double? rating,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      type: type ?? this.type,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      estimatedReadTime: estimatedReadTime ?? this.estimatedReadTime,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPremium: isPremium ?? this.isPremium,
      viewCount: viewCount ?? this.viewCount,
      rating: rating ?? this.rating,
    );
  }
}

enum StudyMaterialType {
  notes,
  formula,
  shortcut,
  concept,
  summary,
  tips,
  pdf,
  video,
}

/// Previous Year Paper Model
class PreviousYearPaper {
  final String id;
  final String examId;
  final String examName;
  final int year;
  final String? shift; // Morning, Evening, etc.
  final DateTime examDate;
  final int totalQuestions;
  final int totalMarks;
  final int durationMinutes;
  final String? pdfUrl;
  final List<String> questionIds;
  final bool isAvailableOffline;
  final int downloadCount;

  const PreviousYearPaper({
    required this.id,
    required this.examId,
    required this.examName,
    required this.year,
    this.shift,
    required this.examDate,
    required this.totalQuestions,
    required this.totalMarks,
    required this.durationMinutes,
    this.pdfUrl,
    this.questionIds = const [],
    this.isAvailableOffline = false,
    this.downloadCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'examId': examId,
    'examName': examName,
    'year': year,
    'shift': shift,
    'examDate': examDate.toIso8601String(),
    'totalQuestions': totalQuestions,
    'totalMarks': totalMarks,
    'durationMinutes': durationMinutes,
    'pdfUrl': pdfUrl,
    'questionIds': questionIds,
    'isAvailableOffline': isAvailableOffline,
    'downloadCount': downloadCount,
  };

  factory PreviousYearPaper.fromJson(Map<String, dynamic> json) => PreviousYearPaper(
    id: json['id'] as String,
    examId: json['examId'] as String,
    examName: json['examName'] as String,
    year: json['year'] as int,
    shift: json['shift'] as String?,
    examDate: DateTime.parse(json['examDate'] as String),
    totalQuestions: json['totalQuestions'] as int,
    totalMarks: json['totalMarks'] as int,
    durationMinutes: json['durationMinutes'] as int,
    pdfUrl: json['pdfUrl'] as String?,
    questionIds: List<String>.from(json['questionIds'] ?? []),
    isAvailableOffline: json['isAvailableOffline'] as bool? ?? false,
    downloadCount: json['downloadCount'] as int? ?? 0,
  );
}

/// Mock Test Model
class MockTest {
  final String id;
  final String title;
  final String description;
  final String examId;
  final MockTestType type;
  final int totalQuestions;
  final int totalMarks;
  final int durationMinutes;
  final List<MockTestSection> sections;
  final double negativeMarking; // e.g., 0.25 for 1/4th negative
  final bool isAttempted;
  final MockTestResult? lastResult;
  final int attemptCount;
  final DateTime createdAt;
  final bool isPremium;

  const MockTest({
    required this.id,
    required this.title,
    required this.description,
    required this.examId,
    required this.type,
    required this.totalQuestions,
    required this.totalMarks,
    required this.durationMinutes,
    required this.sections,
    this.negativeMarking = 0.25,
    this.isAttempted = false,
    this.lastResult,
    this.attemptCount = 0,
    required this.createdAt,
    this.isPremium = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'examId': examId,
    'type': type.name,
    'totalQuestions': totalQuestions,
    'totalMarks': totalMarks,
    'durationMinutes': durationMinutes,
    'sections': sections.map((s) => s.toJson()).toList(),
    'negativeMarking': negativeMarking,
    'isAttempted': isAttempted,
    'lastResult': lastResult?.toJson(),
    'attemptCount': attemptCount,
    'createdAt': createdAt.toIso8601String(),
    'isPremium': isPremium,
  };

  factory MockTest.fromJson(Map<String, dynamic> json) => MockTest(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    examId: json['examId'] as String,
    type: MockTestType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MockTestType.fullLength,
    ),
    totalQuestions: json['totalQuestions'] as int,
    totalMarks: json['totalMarks'] as int,
    durationMinutes: json['durationMinutes'] as int,
    sections: (json['sections'] as List)
        .map((s) => MockTestSection.fromJson(s))
        .toList(),
    negativeMarking: (json['negativeMarking'] as num?)?.toDouble() ?? 0.25,
    isAttempted: json['isAttempted'] as bool? ?? false,
    lastResult: json['lastResult'] != null
        ? MockTestResult.fromJson(json['lastResult'])
        : null,
    attemptCount: json['attemptCount'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isPremium: json['isPremium'] as bool? ?? false,
  );
}

enum MockTestType {
  fullLength,
  sectional,
  topic,
  previous,
  custom,
}

class MockTestSection {
  final String id;
  final String name;
  final String subjectId;
  final int questionCount;
  final int marks;
  final List<String> questionIds;

  const MockTestSection({
    required this.id,
    required this.name,
    required this.subjectId,
    required this.questionCount,
    required this.marks,
    this.questionIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subjectId': subjectId,
    'questionCount': questionCount,
    'marks': marks,
    'questionIds': questionIds,
  };

  factory MockTestSection.fromJson(Map<String, dynamic> json) => MockTestSection(
    id: json['id'] as String,
    name: json['name'] as String,
    subjectId: json['subjectId'] as String,
    questionCount: json['questionCount'] as int,
    marks: json['marks'] as int,
    questionIds: List<String>.from(json['questionIds'] ?? []),
  );
}

class MockTestResult {
  final String id;
  final String testId;
  final DateTime attemptedAt;
  final int timeTaken; // in seconds
  final int totalQuestions;
  final int attempted;
  final int correct;
  final int wrong;
  final int skipped;
  final double score;
  final double maxScore;
  final double percentage;
  final int rank; // If available
  final Map<String, SectionResult> sectionResults;

  const MockTestResult({
    required this.id,
    required this.testId,
    required this.attemptedAt,
    required this.timeTaken,
    required this.totalQuestions,
    required this.attempted,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.score,
    required this.maxScore,
    required this.percentage,
    this.rank = 0,
    this.sectionResults = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'testId': testId,
    'attemptedAt': attemptedAt.toIso8601String(),
    'timeTaken': timeTaken,
    'totalQuestions': totalQuestions,
    'attempted': attempted,
    'correct': correct,
    'wrong': wrong,
    'skipped': skipped,
    'score': score,
    'maxScore': maxScore,
    'percentage': percentage,
    'rank': rank,
    'sectionResults': sectionResults.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory MockTestResult.fromJson(Map<String, dynamic> json) => MockTestResult(
    id: json['id'] as String,
    testId: json['testId'] as String,
    attemptedAt: DateTime.parse(json['attemptedAt'] as String),
    timeTaken: json['timeTaken'] as int,
    totalQuestions: json['totalQuestions'] as int,
    attempted: json['attempted'] as int,
    correct: json['correct'] as int,
    wrong: json['wrong'] as int,
    skipped: json['skipped'] as int,
    score: (json['score'] as num).toDouble(),
    maxScore: (json['maxScore'] as num).toDouble(),
    percentage: (json['percentage'] as num).toDouble(),
    rank: json['rank'] as int? ?? 0,
    sectionResults: (json['sectionResults'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, SectionResult.fromJson(v)),
    ) ?? {},
  );
}

class SectionResult {
  final String sectionId;
  final int attempted;
  final int correct;
  final int wrong;
  final double score;
  final int timeTaken;

  const SectionResult({
    required this.sectionId,
    required this.attempted,
    required this.correct,
    required this.wrong,
    required this.score,
    required this.timeTaken,
  });

  Map<String, dynamic> toJson() => {
    'sectionId': sectionId,
    'attempted': attempted,
    'correct': correct,
    'wrong': wrong,
    'score': score,
    'timeTaken': timeTaken,
  };

  factory SectionResult.fromJson(Map<String, dynamic> json) => SectionResult(
    sectionId: json['sectionId'] as String,
    attempted: json['attempted'] as int,
    correct: json['correct'] as int,
    wrong: json['wrong'] as int,
    score: (json['score'] as num).toDouble(),
    timeTaken: json['timeTaken'] as int,
  );
}

/// User Progress Model
class UserProgress {
  final String subjectId;
  final int totalQuestions;
  final int attempted;
  final int correct;
  final double accuracy;
  final int streak;
  final DateTime lastPracticed;
  final Map<String, TopicProgress> topicProgress;

  const UserProgress({
    required this.subjectId,
    required this.totalQuestions,
    required this.attempted,
    required this.correct,
    required this.accuracy,
    required this.streak,
    required this.lastPracticed,
    this.topicProgress = const {},
  });

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'totalQuestions': totalQuestions,
    'attempted': attempted,
    'correct': correct,
    'accuracy': accuracy,
    'streak': streak,
    'lastPracticed': lastPracticed.toIso8601String(),
    'topicProgress': topicProgress.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
    subjectId: json['subjectId'] as String,
    totalQuestions: json['totalQuestions'] as int,
    attempted: json['attempted'] as int,
    correct: json['correct'] as int,
    accuracy: (json['accuracy'] as num).toDouble(),
    streak: json['streak'] as int,
    lastPracticed: DateTime.parse(json['lastPracticed'] as String),
    topicProgress: (json['topicProgress'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, TopicProgress.fromJson(v)),
    ) ?? {},
  );
}

class TopicProgress {
  final String topicId;
  final int attempted;
  final int correct;
  final double accuracy;
  final bool isCompleted;

  const TopicProgress({
    required this.topicId,
    required this.attempted,
    required this.correct,
    required this.accuracy,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'topicId': topicId,
    'attempted': attempted,
    'correct': correct,
    'accuracy': accuracy,
    'isCompleted': isCompleted,
  };

  factory TopicProgress.fromJson(Map<String, dynamic> json) => TopicProgress(
    topicId: json['topicId'] as String,
    attempted: json['attempted'] as int,
    correct: json['correct'] as int,
    accuracy: (json['accuracy'] as num).toDouble(),
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

/// Sample Study Materials for demonstration
class SampleStudyMaterials {
  static List<StudyMaterial> getSampleMaterials() {
    final now = DateTime.now();
    return [
      StudyMaterial(
        id: 'sm_1',
        title: 'Number System Basics',
        description: 'Complete guide to number system including types, properties, and shortcuts for quick calculations.',
        subjectId: 'quant',
        topicId: 'number_system',
        type: StudyMaterialType.notes,
        content: '''
# Number System

## Types of Numbers
1. **Natural Numbers (N)**: 1, 2, 3, 4, 5...
2. **Whole Numbers (W)**: 0, 1, 2, 3, 4...
3. **Integers (Z)**: ...-3, -2, -1, 0, 1, 2, 3...
4. **Rational Numbers (Q)**: Numbers that can be expressed as p/q
5. **Irrational Numbers**: Numbers that cannot be expressed as p/q (e.g., √2, π)

## Divisibility Rules
- **By 2**: Last digit is even (0, 2, 4, 6, 8)
- **By 3**: Sum of digits is divisible by 3
- **By 4**: Last two digits form a number divisible by 4
- **By 5**: Last digit is 0 or 5
- **By 6**: Divisible by both 2 and 3
- **By 8**: Last three digits form a number divisible by 8
- **By 9**: Sum of digits is divisible by 9
- **By 11**: Difference of sum of alternate digits is 0 or divisible by 11

## Quick Tips
- Product of n consecutive numbers is always divisible by n!
- Sum of first n natural numbers = n(n+1)/2
- Sum of squares of first n natural numbers = n(n+1)(2n+1)/6
        ''',
        tags: ['quant', 'basics', 'number-system'],
        estimatedReadTime: 15,
        createdAt: now.subtract(const Duration(days: 30)),
        viewCount: 1250,
        rating: 4.8,
      ),
      StudyMaterial(
        id: 'sm_2',
        title: 'Percentage Formulas',
        description: 'All important percentage formulas with examples and shortcuts.',
        subjectId: 'quant',
        topicId: 'percentage',
        type: StudyMaterialType.formula,
        content: '''
# Percentage Formulas

## Basic Formulas
1. **Percentage** = (Part/Whole) × 100
2. **Part** = (Percentage × Whole) / 100
3. **Whole** = (Part × 100) / Percentage

## Important Conversions
- 1/2 = 50%
- 1/3 = 33.33%
- 1/4 = 25%
- 1/5 = 20%
- 1/6 = 16.67%
- 1/8 = 12.5%

## Successive Percentage Change
If a value changes by a% and then by b%:
Net change = a + b + (ab/100)

## Population Formula
P = P₀(1 + r/100)^n
Where P₀ = initial population, r = rate, n = years
        ''',
        tags: ['quant', 'percentage', 'formulas'],
        estimatedReadTime: 10,
        createdAt: now.subtract(const Duration(days: 25)),
        viewCount: 980,
        rating: 4.7,
      ),
      StudyMaterial(
        id: 'sm_3',
        title: 'Coding-Decoding Shortcuts',
        description: 'Quick tricks to solve coding-decoding problems in seconds.',
        subjectId: 'reasoning',
        topicId: 'coding_decoding',
        type: StudyMaterialType.shortcut,
        content: '''
# Coding-Decoding Shortcuts

## Type 1: Letter Shifting
- Identify the pattern (forward/backward shift)
- Common shifts: +1, +2, -1, -2, reverse alphabet

## Type 2: Position-based Coding
A=1, B=2, C=3... or A=26, B=25, C=24...
- Look for arithmetic operations on positions

## Type 3: Symbol-based Coding
- Map symbols to letters/numbers
- Find the consistent pattern

## Quick Tips
1. Always check if pattern is same for all letters
2. Look for reverse alphabet coding (A↔Z, B↔Y)
3. Check for vowel/consonant specific rules
4. Odd/Even position letters may have different rules
        ''',
        tags: ['reasoning', 'coding-decoding', 'shortcuts'],
        estimatedReadTime: 8,
        createdAt: now.subtract(const Duration(days: 20)),
        viewCount: 756,
        rating: 4.5,
      ),
      StudyMaterial(
        id: 'sm_4',
        title: 'Error Spotting Rules',
        description: 'Complete guide to common grammatical errors in English.',
        subjectId: 'english',
        topicId: 'error_spotting',
        type: StudyMaterialType.notes,
        content: '''
# Error Spotting Rules

## Subject-Verb Agreement
1. Singular subject → Singular verb
2. Plural subject → Plural verb
3. "Each", "Every", "Neither", "Either" → Singular verb

## Common Errors
1. **Tense consistency**: Don't mix tenses unnecessarily
2. **Articles**: a/an/the usage
3. **Prepositions**: Correct preposition with verbs
4. **Pronouns**: Agreement in number and gender

## Important Rules
- "Neither...nor" - verb agrees with nearest subject
- "Either...or" - verb agrees with nearest subject
- Collective nouns - usually singular verb
- "The number of" - singular verb
- "A number of" - plural verb
        ''',
        tags: ['english', 'grammar', 'error-spotting'],
        estimatedReadTime: 12,
        createdAt: now.subtract(const Duration(days: 15)),
        viewCount: 1100,
        rating: 4.6,
      ),
      StudyMaterial(
        id: 'sm_5',
        title: 'Banking Awareness Capsule',
        description: 'Quick revision notes on banking terms, RBI policies, and financial institutions.',
        subjectId: 'gk',
        topicId: 'banking_awareness',
        type: StudyMaterialType.notes,
        content: '''
# Banking Awareness

## RBI Basics
- Established: April 1, 1935
- Headquarters: Mumbai
- Governor: Current RBI Governor
- Monetary Policy Committee (MPC): 6 members

## Key Rates
- Repo Rate: Rate at which RBI lends to banks
- Reverse Repo: Rate at which banks lend to RBI
- CRR: Cash Reserve Ratio
- SLR: Statutory Liquidity Ratio
- Bank Rate: Long-term lending rate

## Important Banking Terms
- NEFT: National Electronic Funds Transfer
- RTGS: Real Time Gross Settlement
- IMPS: Immediate Payment Service
- UPI: Unified Payments Interface
        ''',
        tags: ['gk', 'banking', 'current-affairs'],
        estimatedReadTime: 20,
        createdAt: now.subtract(const Duration(days: 10)),
        viewCount: 1500,
        rating: 4.9,
      ),
      StudyMaterial(
        id: 'sm_6',
        title: 'Computer Fundamentals',
        description: 'Basic computer concepts for competitive exams.',
        subjectId: 'computer',
        topicId: 'basics',
        type: StudyMaterialType.notes,
        content: '''
# Computer Fundamentals

## Generations of Computers
1. **1st Gen (1940-56)**: Vacuum tubes
2. **2nd Gen (1956-63)**: Transistors
3. **3rd Gen (1964-71)**: Integrated Circuits
4. **4th Gen (1971-present)**: Microprocessors
5. **5th Gen**: AI-based

## Memory Types
- RAM: Random Access Memory (volatile)
- ROM: Read Only Memory (non-volatile)
- Cache: High-speed memory

## Storage Units
1 Byte = 8 Bits
1 KB = 1024 Bytes
1 MB = 1024 KB
1 GB = 1024 MB
1 TB = 1024 GB
        ''',
        tags: ['computer', 'basics', 'fundamentals'],
        estimatedReadTime: 15,
        createdAt: now.subtract(const Duration(days: 5)),
        viewCount: 890,
        rating: 4.4,
      ),
    ];
  }
}
