/// Breathing exercise model matching Behance design
/// Exercises: Calm Flow, Soft Rest, Deep Ease, Slow Calm
class BreathingExercise {
  final String id;
  final String name;
  final String description;
  final BreathingPattern pattern;
  final int durationMinutes;
  final String imageAsset;
  final BreathingExerciseColor colorScheme;

  const BreathingExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.pattern,
    required this.durationMinutes,
    required this.imageAsset,
    required this.colorScheme,
  });

  String get patternLabel => pattern.label;
  String get durationLabel => '$durationMinutes ${durationMinutes == 1 ? 'minute' : 'minutes'}';

  static List<BreathingExercise> get defaultExercises => [
        const BreathingExercise(
          id: 'calm_flow',
          name: 'Calm Flow',
          description: 'A gentle breathing exercise for relaxation',
          pattern: BreathingPattern.twoToOne,
          durationMinutes: 1,
          imageAsset: 'assets/images/breathing/fluffy_purple.png',
          colorScheme: BreathingExerciseColor.purple,
        ),
        const BreathingExercise(
          id: 'soft_rest',
          name: 'Soft Rest',
          description: 'Balanced breathing for peaceful rest',
          pattern: BreathingPattern.oneToOne,
          durationMinutes: 2,
          imageAsset: 'assets/images/breathing/fluffy_beige.png',
          colorScheme: BreathingExerciseColor.beige,
        ),
        const BreathingExercise(
          id: 'deep_ease',
          name: 'Deep Ease',
          description: 'Extended exhale for deep relaxation',
          pattern: BreathingPattern.twoToOne,
          durationMinutes: 3,
          imageAsset: 'assets/images/breathing/fluffy_lavender.png',
          colorScheme: BreathingExerciseColor.lavender,
        ),
        const BreathingExercise(
          id: 'slow_calm',
          name: 'Slow Calm',
          description: 'Slow, balanced breathing for extended calm',
          pattern: BreathingPattern.oneToOne,
          durationMinutes: 5,
          imageAsset: 'assets/images/breathing/fluffy_cream.png',
          colorScheme: BreathingExerciseColor.cream,
        ),
      ];
}

/// Breathing pattern types
enum BreathingPattern {
  oneToOne,
  twoToOne,
  fourSevenEight,
  boxBreathing;

  String get label {
    switch (this) {
      case BreathingPattern.oneToOne:
        return '1-to-1 breathing';
      case BreathingPattern.twoToOne:
        return '2-to-1 breathing';
      case BreathingPattern.fourSevenEight:
        return '4-7-8 breathing';
      case BreathingPattern.boxBreathing:
        return 'Box breathing';
    }
  }

  /// Inhale duration in seconds
  int get inhaleDuration {
    switch (this) {
      case BreathingPattern.oneToOne:
        return 4;
      case BreathingPattern.twoToOne:
        return 4;
      case BreathingPattern.fourSevenEight:
        return 4;
      case BreathingPattern.boxBreathing:
        return 4;
    }
  }

  /// Hold duration in seconds (0 if no hold)
  int get holdDuration {
    switch (this) {
      case BreathingPattern.oneToOne:
        return 0;
      case BreathingPattern.twoToOne:
        return 0;
      case BreathingPattern.fourSevenEight:
        return 7;
      case BreathingPattern.boxBreathing:
        return 4;
    }
  }

  /// Exhale duration in seconds
  int get exhaleDuration {
    switch (this) {
      case BreathingPattern.oneToOne:
        return 4;
      case BreathingPattern.twoToOne:
        return 8;
      case BreathingPattern.fourSevenEight:
        return 8;
      case BreathingPattern.boxBreathing:
        return 4;
    }
  }

  /// Total cycle duration
  int get cycleDuration => inhaleDuration + holdDuration + exhaleDuration;
}

/// Color scheme for breathing exercises
enum BreathingExerciseColor {
  purple,
  beige,
  lavender,
  cream;
}

/// Breathing session state
enum BreathingPhase {
  idle,
  inhale,
  hold,
  exhale;

  String get label {
    switch (this) {
      case BreathingPhase.idle:
        return 'Get Ready';
      case BreathingPhase.inhale:
        return 'Breathe In';
      case BreathingPhase.hold:
        return 'Hold';
      case BreathingPhase.exhale:
        return 'Breathe Out';
    }
  }
}

/// Breathing session data for history
class BreathingSession {
  final String id;
  final String? userId;
  final String exerciseId;
  final int durationSeconds;
  final int completedCycles;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool wasCompleted;

  const BreathingSession({
    required this.id,
    this.userId,
    required this.exerciseId,
    required this.durationSeconds,
    required this.completedCycles,
    required this.startedAt,
    this.completedAt,
    this.wasCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'exerciseId': exerciseId,
        'durationSeconds': durationSeconds,
        'completedCycles': completedCycles,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'wasCompleted': wasCompleted,
      };

  factory BreathingSession.fromJson(Map<String, dynamic> json) {
    return BreathingSession(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      exerciseId: json['exerciseId'] as String,
      durationSeconds: json['durationSeconds'] as int,
      completedCycles: json['completedCycles'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      wasCompleted: json['wasCompleted'] as bool? ?? false,
    );
  }
}
