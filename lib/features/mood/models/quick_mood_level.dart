import 'mood_type.dart';

/// 5-level quick mood selection matching Behance design
/// Maps to detailed MoodType for storage and analytics
enum QuickMoodLevel {
  awful,
  bad,
  ok,
  good,
  great;

  String get value => name;

  String get label {
    switch (this) {
      case QuickMoodLevel.awful:
        return 'Awful';
      case QuickMoodLevel.bad:
        return 'Bad';
      case QuickMoodLevel.ok:
        return 'Ok';
      case QuickMoodLevel.good:
        return 'Good';
      case QuickMoodLevel.great:
        return 'Great';
    }
  }

  /// Cute 3D-style emoji matching Behance design
  String get emoji {
    switch (this) {
      case QuickMoodLevel.awful:
        return '😣';
      case QuickMoodLevel.bad:
        return '😔';
      case QuickMoodLevel.ok:
        return '😐';
      case QuickMoodLevel.good:
        return '😊';
      case QuickMoodLevel.great:
        return '🥰';
    }
  }

  /// Positivity score (1-5)
  int get score {
    switch (this) {
      case QuickMoodLevel.awful:
        return 1;
      case QuickMoodLevel.bad:
        return 2;
      case QuickMoodLevel.ok:
        return 3;
      case QuickMoodLevel.good:
        return 4;
      case QuickMoodLevel.great:
        return 5;
    }
  }

  /// Map to detailed MoodType for storage
  MoodType get toMoodType {
    switch (this) {
      case QuickMoodLevel.awful:
        return MoodType.angry;
      case QuickMoodLevel.bad:
        return MoodType.sad;
      case QuickMoodLevel.ok:
        return MoodType.neutral;
      case QuickMoodLevel.good:
        return MoodType.happy;
      case QuickMoodLevel.great:
        return MoodType.love;
    }
  }

  /// Create from MoodType
  static QuickMoodLevel fromMoodType(MoodType mood) {
    switch (mood) {
      case MoodType.angry:
      case MoodType.anxious:
        return QuickMoodLevel.awful;
      case MoodType.sad:
      case MoodType.tired:
        return QuickMoodLevel.bad;
      case MoodType.neutral:
        return QuickMoodLevel.ok;
      case MoodType.happy:
      case MoodType.excited:
        return QuickMoodLevel.good;
      case MoodType.love:
        return QuickMoodLevel.great;
    }
  }

  /// Create from positivity score
  static QuickMoodLevel fromScore(int score) {
    if (score <= 1) return QuickMoodLevel.awful;
    if (score == 2) return QuickMoodLevel.bad;
    if (score == 3) return QuickMoodLevel.ok;
    if (score == 4) return QuickMoodLevel.good;
    return QuickMoodLevel.great;
  }

  static QuickMoodLevel fromString(String value) {
    return QuickMoodLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => QuickMoodLevel.ok,
    );
  }

  static List<QuickMoodLevel> get all => QuickMoodLevel.values;
}
