/// Mood types for the mood tracker feature
enum MoodType {
  happy,
  sad,
  love,
  neutral,
  angry,
  anxious,
  excited,
  tired;

  String get value => name;

  String get label {
    switch (this) {
      case MoodType.happy:
        return 'Happy';
      case MoodType.sad:
        return 'Sad';
      case MoodType.love:
        return 'Loved';
      case MoodType.neutral:
        return 'Neutral';
      case MoodType.angry:
        return 'Angry';
      case MoodType.anxious:
        return 'Anxious';
      case MoodType.excited:
        return 'Excited';
      case MoodType.tired:
        return 'Tired';
    }
  }

  String get emoji {
    switch (this) {
      case MoodType.happy:
        return '😊';
      case MoodType.sad:
        return '😢';
      case MoodType.love:
        return '🥰';
      case MoodType.neutral:
        return '😐';
      case MoodType.angry:
        return '😠';
      case MoodType.anxious:
        return '😰';
      case MoodType.excited:
        return '🤩';
      case MoodType.tired:
        return '😴';
    }
  }

  String get description {
    switch (this) {
      case MoodType.happy:
        return 'Feeling joyful and content';
      case MoodType.sad:
        return 'Feeling down or melancholic';
      case MoodType.love:
        return 'Feeling loved and grateful';
      case MoodType.neutral:
        return 'Feeling balanced and calm';
      case MoodType.angry:
        return 'Feeling frustrated or upset';
      case MoodType.anxious:
        return 'Feeling worried or nervous';
      case MoodType.excited:
        return 'Feeling energetic and thrilled';
      case MoodType.tired:
        return 'Feeling exhausted or sleepy';
    }
  }

  /// Score for analytics (1-5 scale, 5 being most positive)
  int get positivityScore {
    switch (this) {
      case MoodType.happy:
        return 5;
      case MoodType.excited:
        return 5;
      case MoodType.love:
        return 5;
      case MoodType.neutral:
        return 3;
      case MoodType.tired:
        return 2;
      case MoodType.anxious:
        return 2;
      case MoodType.sad:
        return 1;
      case MoodType.angry:
        return 1;
    }
  }

  static MoodType fromString(String value) {
    return MoodType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MoodType.neutral,
    );
  }

  static List<MoodType> get primaryMoods => [
        MoodType.happy,
        MoodType.sad,
        MoodType.love,
        MoodType.neutral,
        MoodType.angry,
      ];

  static List<MoodType> get allMoods => MoodType.values;
}

/// Activity types for mood entries
enum ActivityType {
  exercise,
  work,
  social,
  sleep,
  food,
  music,
  nature,
  reading,
  gaming,
  meditation,
  travel,
  shopping,
  family,
  pets,
  creative,
  learning;

  String get value => name;

  String get label {
    switch (this) {
      case ActivityType.exercise:
        return 'Exercise';
      case ActivityType.work:
        return 'Work';
      case ActivityType.social:
        return 'Social';
      case ActivityType.sleep:
        return 'Sleep';
      case ActivityType.food:
        return 'Food';
      case ActivityType.music:
        return 'Music';
      case ActivityType.nature:
        return 'Nature';
      case ActivityType.reading:
        return 'Reading';
      case ActivityType.gaming:
        return 'Gaming';
      case ActivityType.meditation:
        return 'Meditation';
      case ActivityType.travel:
        return 'Travel';
      case ActivityType.shopping:
        return 'Shopping';
      case ActivityType.family:
        return 'Family';
      case ActivityType.pets:
        return 'Pets';
      case ActivityType.creative:
        return 'Creative';
      case ActivityType.learning:
        return 'Learning';
    }
  }

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ActivityType.work,
    );
  }
}
