import 'dart:convert';

/// Exercise difficulty levels
enum ExerciseDifficulty {
  beginner,
  intermediate,
  advanced;

  String get displayName {
    switch (this) {
      case ExerciseDifficulty.beginner:
        return 'Beginner';
      case ExerciseDifficulty.intermediate:
        return 'Intermediate';
      case ExerciseDifficulty.advanced:
        return 'Advanced';
    }
  }
}

/// Body parts that exercises target
enum BodyPart {
  fullBody,
  abs,
  arms,
  legs,
  chest,
  back,
  shoulders,
  cardio;

  String get displayName {
    switch (this) {
      case BodyPart.fullBody:
        return 'Full Body';
      case BodyPart.abs:
        return 'Abs';
      case BodyPart.arms:
        return 'Arms';
      case BodyPart.legs:
        return 'Legs';
      case BodyPart.chest:
        return 'Chest';
      case BodyPart.back:
        return 'Back';
      case BodyPart.shoulders:
        return 'Shoulders';
      case BodyPart.cardio:
        return 'Cardio';
    }
  }

  String get emoji {
    switch (this) {
      case BodyPart.fullBody:
        return '💪';
      case BodyPart.abs:
        return '🎯';
      case BodyPart.arms:
        return '💪';
      case BodyPart.legs:
        return '🦵';
      case BodyPart.chest:
        return '🫁';
      case BodyPart.back:
        return '🔙';
      case BodyPart.shoulders:
        return '🏋️';
      case BodyPart.cardio:
        return '❤️';
    }
  }
}

/// Exercise type - time-based or rep-based
enum ExerciseType {
  timed,
  reps;
}

/// Individual exercise model
class Exercise {
  final String id;
  final String name;
  final String description;
  final List<String> instructions;
  final BodyPart primaryBodyPart;
  final List<BodyPart> secondaryBodyParts;
  final ExerciseDifficulty difficulty;
  final ExerciseType type;
  final int? defaultDurationSeconds;
  final int? defaultReps;
  final String? lottieAsset;
  final String? lottieUrl;
  final String? gifUrl; // Exercise GIF/Image URL (wger.de or other source)
  final String? imageUrl;
  final String? youtubeUrl; // YouTube video URL for fallback
  final List<String> commonMistakes;
  final List<String> tips;
  final int caloriesPerMinute;
  final bool requiresEquipment;
  final String? equipmentNeeded;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.primaryBodyPart,
    this.secondaryBodyParts = const [],
    required this.difficulty,
    required this.type,
    this.defaultDurationSeconds,
    this.defaultReps,
    this.lottieAsset,
    this.lottieUrl,
    this.gifUrl,
    this.imageUrl,
    this.youtubeUrl,
    this.commonMistakes = const [],
    this.tips = const [],
    this.caloriesPerMinute = 5,
    this.requiresEquipment = false,
    this.equipmentNeeded,
    this.isCustom = false,
  });

  Exercise copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? instructions,
    BodyPart? primaryBodyPart,
    List<BodyPart>? secondaryBodyParts,
    ExerciseDifficulty? difficulty,
    ExerciseType? type,
    int? defaultDurationSeconds,
    int? defaultReps,
    String? lottieAsset,
    String? lottieUrl,
    String? gifUrl,
    String? imageUrl,
    String? youtubeUrl,
    List<String>? commonMistakes,
    List<String>? tips,
    int? caloriesPerMinute,
    bool? requiresEquipment,
    String? equipmentNeeded,
    bool? isCustom,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      primaryBodyPart: primaryBodyPart ?? this.primaryBodyPart,
      secondaryBodyParts: secondaryBodyParts ?? this.secondaryBodyParts,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      defaultDurationSeconds: defaultDurationSeconds ?? this.defaultDurationSeconds,
      defaultReps: defaultReps ?? this.defaultReps,
      lottieAsset: lottieAsset ?? this.lottieAsset,
      lottieUrl: lottieUrl ?? this.lottieUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      tips: tips ?? this.tips,
      caloriesPerMinute: caloriesPerMinute ?? this.caloriesPerMinute,
      requiresEquipment: requiresEquipment ?? this.requiresEquipment,
      equipmentNeeded: equipmentNeeded ?? this.equipmentNeeded,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
    'primaryBodyPart': primaryBodyPart.index,
    'secondaryBodyParts': secondaryBodyParts.map((b) => b.index).toList(),
    'difficulty': difficulty.index,
    'type': type.index,
    'defaultDurationSeconds': defaultDurationSeconds,
    'defaultReps': defaultReps,
    'lottieAsset': lottieAsset,
    'lottieUrl': lottieUrl,
    'gifUrl': gifUrl,
    'imageUrl': imageUrl,
    'youtubeUrl': youtubeUrl,
    'commonMistakes': commonMistakes,
    'tips': tips,
    'caloriesPerMinute': caloriesPerMinute,
    'requiresEquipment': requiresEquipment,
    'equipmentNeeded': equipmentNeeded,
    'isCustom': isCustom,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    instructions: (json['instructions'] as List<dynamic>?)?.cast<String>() ?? [],
    primaryBodyPart: BodyPart.values[json['primaryBodyPart'] ?? 0],
    secondaryBodyParts: (json['secondaryBodyParts'] as List<dynamic>?)
        ?.map((i) => BodyPart.values[i as int])
        .toList() ?? [],
    difficulty: ExerciseDifficulty.values[json['difficulty'] ?? 0],
    type: ExerciseType.values[json['type'] ?? 0],
    defaultDurationSeconds: json['defaultDurationSeconds'],
    defaultReps: json['defaultReps'],
    lottieAsset: json['lottieAsset'],
    lottieUrl: json['lottieUrl'],
    gifUrl: json['gifUrl'],
    imageUrl: json['imageUrl'],
    youtubeUrl: json['youtubeUrl'],
    commonMistakes: (json['commonMistakes'] as List<dynamic>?)?.cast<String>() ?? [],
    tips: (json['tips'] as List<dynamic>?)?.cast<String>() ?? [],
    caloriesPerMinute: json['caloriesPerMinute'] ?? 5,
    requiresEquipment: json['requiresEquipment'] ?? false,
    equipmentNeeded: json['equipmentNeeded'],
    isCustom: json['isCustom'] ?? false,
  );

  String toJsonString() => jsonEncode(toJson());

  factory Exercise.fromJsonString(String jsonString) =>
      Exercise.fromJson(jsonDecode(jsonString));

  /// Get display string for duration or reps
  String get displayDuration {
    if (type == ExerciseType.timed && defaultDurationSeconds != null) {
      if (defaultDurationSeconds! >= 60) {
        final mins = defaultDurationSeconds! ~/ 60;
        final secs = defaultDurationSeconds! % 60;
        return secs > 0 ? '${mins}m ${secs}s' : '${mins}m';
      }
      return '${defaultDurationSeconds}s';
    }
    if (type == ExerciseType.reps && defaultReps != null) {
      return '$defaultReps reps';
    }
    return '30s';
  }

  /// Estimate calories for given duration
  int estimateCalories(int durationSeconds) {
    return ((durationSeconds / 60) * caloriesPerMinute).round();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Exercise within a workout with custom settings
class WorkoutExercise {
  final String exerciseId;
  final Exercise? exercise;
  final int? customDurationSeconds;
  final int? customReps;
  final int restAfterSeconds;
  final int orderIndex;

  const WorkoutExercise({
    required this.exerciseId,
    this.exercise,
    this.customDurationSeconds,
    this.customReps,
    this.restAfterSeconds = 30,
    this.orderIndex = 0,
  });

  WorkoutExercise copyWith({
    String? exerciseId,
    Exercise? exercise,
    int? customDurationSeconds,
    int? customReps,
    int? restAfterSeconds,
    int? orderIndex,
  }) {
    return WorkoutExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exercise: exercise ?? this.exercise,
      customDurationSeconds: customDurationSeconds ?? this.customDurationSeconds,
      customReps: customReps ?? this.customReps,
      restAfterSeconds: restAfterSeconds ?? this.restAfterSeconds,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  /// Get effective duration (custom or default)
  int get effectiveDurationSeconds {
    if (customDurationSeconds != null) return customDurationSeconds!;
    return exercise?.defaultDurationSeconds ?? 30;
  }

  /// Get effective reps (custom or default)
  int? get effectiveReps {
    if (customReps != null) return customReps;
    return exercise?.defaultReps;
  }

  /// Get display string
  String get displayDuration {
    if (exercise?.type == ExerciseType.reps) {
      return '${effectiveReps ?? 10} reps';
    }
    final secs = effectiveDurationSeconds;
    if (secs >= 60) {
      final mins = secs ~/ 60;
      final remainingSecs = secs % 60;
      return remainingSecs > 0 ? '${mins}m ${remainingSecs}s' : '${mins}m';
    }
    return '${secs}s';
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'customDurationSeconds': customDurationSeconds,
    'customReps': customReps,
    'restAfterSeconds': restAfterSeconds,
    'orderIndex': orderIndex,
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) => WorkoutExercise(
    exerciseId: json['exerciseId'] ?? '',
    customDurationSeconds: json['customDurationSeconds'],
    customReps: json['customReps'],
    restAfterSeconds: json['restAfterSeconds'] ?? 30,
    orderIndex: json['orderIndex'] ?? 0,
  );
}
