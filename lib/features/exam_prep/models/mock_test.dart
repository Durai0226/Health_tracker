class MockTest {
  final String id;
  final String examId;
  final String name;
  final DateTime attemptedAt;
  final int totalMarks;
  final int scoredMarks;
  final int totalQuestions;
  final int attemptedQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int durationMinutes;
  final int timeTakenMinutes;
  final Map<String, SubjectScore> subjectWiseScores;
  final String? notes;
  final String? source; // Platform/book name
  final bool isOfficial;

  MockTest({
    required this.id,
    required this.examId,
    required this.name,
    required this.attemptedAt,
    required this.totalMarks,
    required this.scoredMarks,
    required this.totalQuestions,
    this.attemptedQuestions = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.durationMinutes = 180,
    this.timeTakenMinutes = 0,
    this.subjectWiseScores = const {},
    this.notes,
    this.source,
    this.isOfficial = false,
  });

  double get percentageScore => totalMarks > 0 ? (scoredMarks / totalMarks) * 100 : 0;
  double get accuracy => attemptedQuestions > 0 ? (correctAnswers / attemptedQuestions) * 100 : 0;
  int get unattempted => totalQuestions - attemptedQuestions;

  String get grade {
    final percent = percentageScore;
    if (percent >= 90) return 'A+';
    if (percent >= 80) return 'A';
    if (percent >= 70) return 'B+';
    if (percent >= 60) return 'B';
    if (percent >= 50) return 'C';
    if (percent >= 40) return 'D';
    return 'F';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'name': name,
        'attemptedAt': attemptedAt.toIso8601String(),
        'totalMarks': totalMarks,
        'scoredMarks': scoredMarks,
        'totalQuestions': totalQuestions,
        'attemptedQuestions': attemptedQuestions,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'durationMinutes': durationMinutes,
        'timeTakenMinutes': timeTakenMinutes,
        'subjectWiseScores': subjectWiseScores.map((k, v) => MapEntry(k, v.toJson())),
        'notes': notes,
        'source': source,
        'isOfficial': isOfficial,
      };

  factory MockTest.fromJson(Map<String, dynamic> json) {
    Map<String, SubjectScore> scores = {};
    if (json['subjectWiseScores'] != null) {
      (json['subjectWiseScores'] as Map).forEach((key, value) {
        scores[key] = SubjectScore.fromJson(Map<String, dynamic>.from(value));
      });
    }

    return MockTest(
      id: json['id'] ?? '',
      examId: json['examId'] ?? '',
      name: json['name'] ?? '',
      attemptedAt: DateTime.parse(json['attemptedAt']),
      totalMarks: json['totalMarks'] ?? 0,
      scoredMarks: json['scoredMarks'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      attemptedQuestions: json['attemptedQuestions'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      wrongAnswers: json['wrongAnswers'] ?? 0,
      durationMinutes: json['durationMinutes'] ?? 180,
      timeTakenMinutes: json['timeTakenMinutes'] ?? 0,
      subjectWiseScores: scores,
      notes: json['notes'],
      source: json['source'],
      isOfficial: json['isOfficial'] ?? false,
    );
  }

  MockTest copyWith({
    String? id,
    String? examId,
    String? name,
    DateTime? attemptedAt,
    int? totalMarks,
    int? scoredMarks,
    int? totalQuestions,
    int? attemptedQuestions,
    int? correctAnswers,
    int? wrongAnswers,
    int? durationMinutes,
    int? timeTakenMinutes,
    Map<String, SubjectScore>? subjectWiseScores,
    String? notes,
    String? source,
    bool? isOfficial,
  }) {
    return MockTest(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      name: name ?? this.name,
      attemptedAt: attemptedAt ?? this.attemptedAt,
      totalMarks: totalMarks ?? this.totalMarks,
      scoredMarks: scoredMarks ?? this.scoredMarks,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      attemptedQuestions: attemptedQuestions ?? this.attemptedQuestions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      timeTakenMinutes: timeTakenMinutes ?? this.timeTakenMinutes,
      subjectWiseScores: subjectWiseScores ?? this.subjectWiseScores,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      isOfficial: isOfficial ?? this.isOfficial,
    );
  }
}

class SubjectScore {
  final String subjectName;
  final int totalMarks;
  final int scoredMarks;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;

  SubjectScore({
    required this.subjectName,
    required this.totalMarks,
    required this.scoredMarks,
    required this.totalQuestions,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
  });

  double get percentage => totalMarks > 0 ? (scoredMarks / totalMarks) * 100 : 0;

  Map<String, dynamic> toJson() => {
        'subjectName': subjectName,
        'totalMarks': totalMarks,
        'scoredMarks': scoredMarks,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
      };

  factory SubjectScore.fromJson(Map<String, dynamic> json) => SubjectScore(
        subjectName: json['subjectName'] ?? '',
        totalMarks: json['totalMarks'] ?? 0,
        scoredMarks: json['scoredMarks'] ?? 0,
        totalQuestions: json['totalQuestions'] ?? 0,
        correctAnswers: json['correctAnswers'] ?? 0,
        wrongAnswers: json['wrongAnswers'] ?? 0,
      );
}
