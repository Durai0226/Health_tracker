enum GradeScale {
  percentage,
  letter,
  gpa_4,
  gpa_10,
  points,
  custom,
}

extension GradeScaleExtension on GradeScale {
  String get displayName {
    switch (this) {
      case GradeScale.percentage:
        return 'Percentage (0-100)';
      case GradeScale.letter:
        return 'Letter Grade (A-F)';
      case GradeScale.gpa_4:
        return 'GPA (0-4)';
      case GradeScale.gpa_10:
        return 'GPA (0-10)';
      case GradeScale.points:
        return 'Points';
      case GradeScale.custom:
        return 'Custom';
    }
  }
}

class Grade {
  final String id;
  final String examId;
  final String subjectId;
  final double obtainedMarks;
  final double totalMarks;
  final double? passingMarks;
  final String? letterGrade;
  final double? gradePoints;
  final GradeScale gradeScale;
  final double? weightPercentage;
  final String? feedback;
  final String? teacherRemarks;
  final int? rank;
  final int? totalStudents;
  final double? classAverage;
  final double? highestScore;
  final double? lowestScore;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? semesterId;

  Grade({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.obtainedMarks,
    required this.totalMarks,
    this.passingMarks,
    this.letterGrade,
    this.gradePoints,
    this.gradeScale = GradeScale.percentage,
    this.weightPercentage,
    this.feedback,
    this.teacherRemarks,
    this.rank,
    this.totalStudents,
    this.classAverage,
    this.highestScore,
    this.lowestScore,
    this.isPublished = false,
    this.publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.semesterId,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Calculate percentage
  double get percentage {
    if (totalMarks <= 0) return 0.0;
    return (obtainedMarks / totalMarks) * 100;
  }

  // Check if passed
  bool get isPassed {
    if (passingMarks == null) return percentage >= 40;
    return obtainedMarks >= passingMarks!;
  }

  // Calculate weighted score
  double get weightedScore {
    if (weightPercentage == null) return percentage;
    return percentage * (weightPercentage! / 100);
  }

  // Get percentile rank
  double? get percentileRank {
    if (rank == null || totalStudents == null || totalStudents == 0) {
      return null;
    }
    return ((totalStudents! - rank!) / totalStudents!) * 100;
  }

  // Get letter grade from percentage
  String get calculatedLetterGrade {
    if (letterGrade != null) return letterGrade!;
    final pct = percentage;
    if (pct >= 90) return 'A+';
    if (pct >= 85) return 'A';
    if (pct >= 80) return 'A-';
    if (pct >= 75) return 'B+';
    if (pct >= 70) return 'B';
    if (pct >= 65) return 'B-';
    if (pct >= 60) return 'C+';
    if (pct >= 55) return 'C';
    if (pct >= 50) return 'C-';
    if (pct >= 45) return 'D+';
    if (pct >= 40) return 'D';
    return 'F';
  }

  // Get GPA (4.0 scale) from percentage
  double get calculatedGpa4 {
    if (gradePoints != null && gradeScale == GradeScale.gpa_4) {
      return gradePoints!;
    }
    final pct = percentage;
    if (pct >= 90) return 4.0;
    if (pct >= 85) return 3.7;
    if (pct >= 80) return 3.3;
    if (pct >= 75) return 3.0;
    if (pct >= 70) return 2.7;
    if (pct >= 65) return 2.3;
    if (pct >= 60) return 2.0;
    if (pct >= 55) return 1.7;
    if (pct >= 50) return 1.3;
    if (pct >= 45) return 1.0;
    if (pct >= 40) return 0.7;
    return 0.0;
  }

  Grade copyWith({
    String? id,
    String? examId,
    String? subjectId,
    double? obtainedMarks,
    double? totalMarks,
    double? passingMarks,
    String? letterGrade,
    double? gradePoints,
    GradeScale? gradeScale,
    double? weightPercentage,
    String? feedback,
    String? teacherRemarks,
    int? rank,
    int? totalStudents,
    double? classAverage,
    double? highestScore,
    double? lowestScore,
    bool? isPublished,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? semesterId,
  }) {
    return Grade(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      subjectId: subjectId ?? this.subjectId,
      obtainedMarks: obtainedMarks ?? this.obtainedMarks,
      totalMarks: totalMarks ?? this.totalMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      letterGrade: letterGrade ?? this.letterGrade,
      gradePoints: gradePoints ?? this.gradePoints,
      gradeScale: gradeScale ?? this.gradeScale,
      weightPercentage: weightPercentage ?? this.weightPercentage,
      feedback: feedback ?? this.feedback,
      teacherRemarks: teacherRemarks ?? this.teacherRemarks,
      rank: rank ?? this.rank,
      totalStudents: totalStudents ?? this.totalStudents,
      classAverage: classAverage ?? this.classAverage,
      highestScore: highestScore ?? this.highestScore,
      lowestScore: lowestScore ?? this.lowestScore,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      semesterId: semesterId ?? this.semesterId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'examId': examId,
      'subjectId': subjectId,
      'obtainedMarks': obtainedMarks,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'letterGrade': letterGrade,
      'gradePoints': gradePoints,
      'gradeScale': gradeScale.index,
      'weightPercentage': weightPercentage,
      'feedback': feedback,
      'teacherRemarks': teacherRemarks,
      'rank': rank,
      'totalStudents': totalStudents,
      'classAverage': classAverage,
      'highestScore': highestScore,
      'lowestScore': lowestScore,
      'isPublished': isPublished,
      'publishedAt': publishedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'semesterId': semesterId,
    };
  }

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'] ?? '',
      examId: json['examId'] ?? '',
      subjectId: json['subjectId'] ?? '',
      obtainedMarks: (json['obtainedMarks'] ?? 0).toDouble(),
      totalMarks: (json['totalMarks'] ?? 100).toDouble(),
      passingMarks: json['passingMarks']?.toDouble(),
      letterGrade: json['letterGrade'],
      gradePoints: json['gradePoints']?.toDouble(),
      gradeScale: GradeScale.values[json['gradeScale'] ?? 0],
      weightPercentage: json['weightPercentage']?.toDouble(),
      feedback: json['feedback'],
      teacherRemarks: json['teacherRemarks'],
      rank: json['rank'],
      totalStudents: json['totalStudents'],
      classAverage: json['classAverage']?.toDouble(),
      highestScore: json['highestScore']?.toDouble(),
      lowestScore: json['lowestScore']?.toDouble(),
      isPublished: json['isPublished'] ?? false,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isSynced: true,
      semesterId: json['semesterId'],
    );
  }
}

class SemesterGPA {
  final String id;
  final String semesterId;
  final String semesterName;
  final double gpa;
  final int totalCredits;
  final int completedCredits;
  final List<String> gradeIds;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  SemesterGPA({
    required this.id,
    required this.semesterId,
    required this.semesterName,
    required this.gpa,
    this.totalCredits = 0,
    this.completedCredits = 0,
    this.gradeIds = const [],
    required this.startDate,
    required this.endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get creditCompletionRate {
    if (totalCredits <= 0) return 0.0;
    return completedCredits / totalCredits;
  }

  SemesterGPA copyWith({
    String? id,
    String? semesterId,
    String? semesterName,
    double? gpa,
    int? totalCredits,
    int? completedCredits,
    List<String>? gradeIds,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return SemesterGPA(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      semesterName: semesterName ?? this.semesterName,
      gpa: gpa ?? this.gpa,
      totalCredits: totalCredits ?? this.totalCredits,
      completedCredits: completedCredits ?? this.completedCredits,
      gradeIds: gradeIds ?? this.gradeIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'semesterId': semesterId,
      'semesterName': semesterName,
      'gpa': gpa,
      'totalCredits': totalCredits,
      'completedCredits': completedCredits,
      'gradeIds': gradeIds,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SemesterGPA.fromJson(Map<String, dynamic> json) {
    return SemesterGPA(
      id: json['id'] ?? '',
      semesterId: json['semesterId'] ?? '',
      semesterName: json['semesterName'] ?? '',
      gpa: (json['gpa'] ?? 0).toDouble(),
      totalCredits: json['totalCredits'] ?? 0,
      completedCredits: json['completedCredits'] ?? 0,
      gradeIds: List<String>.from(json['gradeIds'] ?? []),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
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
