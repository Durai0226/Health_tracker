class StudySession {
  final String id;
  final String examId;
  final String subjectId;
  final String? topicName;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final StudyType type;
  final String? notes;
  final int productivityRating; // 1-5
  final bool wasInterrupted;

  StudySession({
    required this.id,
    required this.examId,
    required this.subjectId,
    this.topicName,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.type = StudyType.reading,
    this.notes,
    this.productivityRating = 3,
    this.wasInterrupted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'subjectId': subjectId,
        'topicName': topicName,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'type': type.index,
        'notes': notes,
        'productivityRating': productivityRating,
        'wasInterrupted': wasInterrupted,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] ?? '',
        examId: json['examId'] ?? '',
        subjectId: json['subjectId'] ?? '',
        topicName: json['topicName'],
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
        durationMinutes: json['durationMinutes'] ?? 0,
        type: StudyType.values[json['type'] ?? 0],
        notes: json['notes'],
        productivityRating: json['productivityRating'] ?? 3,
        wasInterrupted: json['wasInterrupted'] ?? false,
      );

  StudySession copyWith({
    String? id,
    String? examId,
    String? subjectId,
    String? topicName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    StudyType? type,
    String? notes,
    int? productivityRating,
    bool? wasInterrupted,
  }) {
    return StudySession(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      subjectId: subjectId ?? this.subjectId,
      topicName: topicName ?? this.topicName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      productivityRating: productivityRating ?? this.productivityRating,
      wasInterrupted: wasInterrupted ?? this.wasInterrupted,
    );
  }
}

enum StudyType {
  reading,
  notes,
  practice,
  revision,
  video,
  mockTest,
  discussion,
  flashcards,
}

extension StudyTypeExtension on StudyType {
  String get name {
    switch (this) {
      case StudyType.reading:
        return 'Reading';
      case StudyType.notes:
        return 'Making Notes';
      case StudyType.practice:
        return 'Practice Questions';
      case StudyType.revision:
        return 'Revision';
      case StudyType.video:
        return 'Video Lecture';
      case StudyType.mockTest:
        return 'Mock Test';
      case StudyType.discussion:
        return 'Discussion';
      case StudyType.flashcards:
        return 'Flashcards';
    }
  }

  String get emoji {
    switch (this) {
      case StudyType.reading:
        return '📖';
      case StudyType.notes:
        return '📝';
      case StudyType.practice:
        return '✍️';
      case StudyType.revision:
        return '🔄';
      case StudyType.video:
        return '🎥';
      case StudyType.mockTest:
        return '📋';
      case StudyType.discussion:
        return '💬';
      case StudyType.flashcards:
        return '🗂️';
    }
  }
}
