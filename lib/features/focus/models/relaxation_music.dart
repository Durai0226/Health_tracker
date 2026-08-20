import 'package:flutter/material.dart';
import '../../../core/utils/enum_json.dart';
import 'package:material_symbols_icons/symbols.dart';

enum RelaxationCategory {
  deepFocus,
  stressRelief,
  nervousSystemReset,
}

extension RelaxationCategoryExtension on RelaxationCategory {
  String get name {
    switch (this) {
      case RelaxationCategory.deepFocus:
        return 'Deep Focus';
      case RelaxationCategory.stressRelief:
        return 'Stress Relief';
      case RelaxationCategory.nervousSystemReset:
        return 'Full Reset';
    }
  }

  String get emoji {
    switch (this) {
      case RelaxationCategory.deepFocus:
        return '🧠';
      case RelaxationCategory.stressRelief:
        return '😌';
      case RelaxationCategory.nervousSystemReset:
        return '💤';
    }
  }

  String get description {
    switch (this) {
      case RelaxationCategory.deepFocus:
        return 'Work, Study, Coding';
      case RelaxationCategory.stressRelief:
        return 'Anxiety & Stress Release';
      case RelaxationCategory.nervousSystemReset:
        return 'Maximum Calm & Sleep';
    }
  }

  Color get color {
    switch (this) {
      case RelaxationCategory.deepFocus:
        return const Color(0xFF6366F1);
      case RelaxationCategory.stressRelief:
        return const Color(0xFF10B981);
      case RelaxationCategory.nervousSystemReset:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get icon {
    switch (this) {
      case RelaxationCategory.deepFocus:
        return Symbols.psychology_rounded;
      case RelaxationCategory.stressRelief:
        return Symbols.spa_rounded;
      case RelaxationCategory.nervousSystemReset:
        return Symbols.bedtime_rounded;
    }
  }

  List<RelaxationMusicType> get tracks {
    switch (this) {
      case RelaxationCategory.deepFocus:
        return [
          RelaxationMusicType.binauralBeatsAlpha,
          RelaxationMusicType.lofiHipHop,
          RelaxationMusicType.ambientInstrumental,
          RelaxationMusicType.gammaFocus40Hz,
        ];
      case RelaxationCategory.stressRelief:
        return [
          RelaxationMusicType.healing432Hz,
          RelaxationMusicType.miracleTone528Hz,
          RelaxationMusicType.tibetanBowls,
          RelaxationMusicType.rainOnWindow,
          RelaxationMusicType.oceanWaves,
          RelaxationMusicType.forestBirds,
        ];
      case RelaxationCategory.nervousSystemReset:
        return [
          RelaxationMusicType.rainPiano432Hz,
          RelaxationMusicType.deepSleepDelta,
          RelaxationMusicType.softPianoRain,
          RelaxationMusicType.healingNightSounds,
        ];
    }
  }
}

enum RelaxationMusicType {
  // Deep Focus
  binauralBeatsAlpha,
  lofiHipHop,
  ambientInstrumental,
  gammaFocus40Hz,
  
  // Stress Relief
  healing432Hz,
  miracleTone528Hz,
  tibetanBowls,
  rainOnWindow,
  oceanWaves,
  forestBirds,
  
  // Nervous System Reset
  rainPiano432Hz,
  deepSleepDelta,
  softPianoRain,
  healingNightSounds,
}

extension RelaxationMusicTypeExtension on RelaxationMusicType {
  /// The persisted identifier (`deepSleepDelta`), not the display name.
  ///
  /// `name` below shadows `dart:core`'s `EnumName.name` — a local extension on
  /// `RelaxationMusicType` is more specific than one on `Enum` — so `track.name`
  /// gives you "Deep Rest", never the identifier. Callers that need the audio
  /// lookup key were reaching for `toString().split('.').last` instead, once in
  /// the service and about to be a second time in the screen. This is that key,
  /// named for what it is.
  String get assetKey => EnumName(this).name;

  String get name {
    switch (this) {
      case RelaxationMusicType.binauralBeatsAlpha:
        return 'Focus Ambience';
      case RelaxationMusicType.lofiHipHop:
        return 'Lo-fi Hip Hop';
      case RelaxationMusicType.ambientInstrumental:
        return 'Ambient Instrumental';
      case RelaxationMusicType.gammaFocus40Hz:
        return 'Bright Focus';
      case RelaxationMusicType.healing432Hz:
        return 'Calm Piano';
      case RelaxationMusicType.miracleTone528Hz:
        return 'Ambient Reflection';
      case RelaxationMusicType.tibetanBowls:
        return 'Tibetan Singing Bowls';
      case RelaxationMusicType.rainOnWindow:
        return 'Rain on Window';
      case RelaxationMusicType.oceanWaves:
        return 'Ocean Waves';
      case RelaxationMusicType.forestBirds:
        return 'Forest Birds';
      case RelaxationMusicType.rainPiano432Hz:
        return 'Rain & Piano';
      case RelaxationMusicType.deepSleepDelta:
        return 'Deep Sleep';
      case RelaxationMusicType.softPianoRain:
        return 'Soft Piano with Rain';
      case RelaxationMusicType.healingNightSounds:
        return 'Night Sounds';
    }
  }

  String get emoji {
    switch (this) {
      case RelaxationMusicType.binauralBeatsAlpha:
        return '🎧';
      case RelaxationMusicType.lofiHipHop:
        return '🎵';
      case RelaxationMusicType.ambientInstrumental:
        return '🎹';
      case RelaxationMusicType.gammaFocus40Hz:
        return '⚡';
      case RelaxationMusicType.healing432Hz:
        return '✨';
      case RelaxationMusicType.miracleTone528Hz:
        return '💫';
      case RelaxationMusicType.tibetanBowls:
        return '🔔';
      case RelaxationMusicType.rainOnWindow:
        return '🌧️';
      case RelaxationMusicType.oceanWaves:
        return '🌊';
      case RelaxationMusicType.forestBirds:
        return '🐦';
      case RelaxationMusicType.rainPiano432Hz:
        return '🌧️🎹';
      case RelaxationMusicType.deepSleepDelta:
        return '🌙';
      case RelaxationMusicType.softPianoRain:
        return '🎶';
      case RelaxationMusicType.healingNightSounds:
        return '🌌';
    }
  }

  String get description {
    switch (this) {
      case RelaxationMusicType.binauralBeatsAlpha:
        return 'Steady, wordless ambience for staying with a task';
      case RelaxationMusicType.lofiHipHop:
        return 'Steady rhythm, minimal distraction for studying';
      case RelaxationMusicType.ambientInstrumental:
        return 'Brian Eno style ambient for deep concentration';
      case RelaxationMusicType.gammaFocus40Hz:
        return 'Brighter, more energetic ambience for daytime work';
      case RelaxationMusicType.healing432Hz:
        return 'Slow solo piano, designed to help you unwind';
      case RelaxationMusicType.miracleTone528Hz:
        return 'Sparse, reflective tones for winding down';
      case RelaxationMusicType.tibetanBowls:
        return 'Sustained metallic tones, often used in meditation';
      case RelaxationMusicType.rainOnWindow:
        return 'Gentle rain sounds for calming the mind';
      case RelaxationMusicType.oceanWaves:
        return 'Rhythmic ocean waves for deep relaxation';
      case RelaxationMusicType.forestBirds:
        return 'Natural forest ambiance with birdsong';
      case RelaxationMusicType.rainPiano432Hz:
        return 'Rainfall layered under soft piano';
      case RelaxationMusicType.deepSleepDelta:
        return 'Very slow, low ambience for falling asleep';
      case RelaxationMusicType.softPianoRain:
        return 'Gentle piano melodies with rain background';
      case RelaxationMusicType.healingNightSounds:
        return 'Crickets and still night air';
    }
  }

  Color get color {
    switch (this) {
      case RelaxationMusicType.binauralBeatsAlpha:
        return const Color(0xFF6366F1);
      case RelaxationMusicType.lofiHipHop:
        return const Color(0xFFF59E0B);
      case RelaxationMusicType.ambientInstrumental:
        return const Color(0xFF8B5CF6);
      case RelaxationMusicType.gammaFocus40Hz:
        return const Color(0xFFEC4899);
      case RelaxationMusicType.healing432Hz:
        return const Color(0xFF10B981);
      case RelaxationMusicType.miracleTone528Hz:
        return const Color(0xFF14B8A6);
      case RelaxationMusicType.tibetanBowls:
        return const Color(0xFFF97316);
      case RelaxationMusicType.rainOnWindow:
        return const Color(0xFF0EA5E9);
      case RelaxationMusicType.oceanWaves:
        return const Color(0xFF06B6D4);
      case RelaxationMusicType.forestBirds:
        return const Color(0xFF22C55E);
      case RelaxationMusicType.rainPiano432Hz:
        return const Color(0xFF7C3AED);
      case RelaxationMusicType.deepSleepDelta:
        return const Color(0xFF4F46E5);
      case RelaxationMusicType.softPianoRain:
        return const Color(0xFF6366F1);
      case RelaxationMusicType.healingNightSounds:
        return const Color(0xFF1E3A8A);
    }
  }

  IconData get icon {
    switch (this) {
      case RelaxationMusicType.binauralBeatsAlpha:
        return Symbols.headphones_rounded;
      case RelaxationMusicType.lofiHipHop:
        return Symbols.music_note_rounded;
      case RelaxationMusicType.ambientInstrumental:
        return Symbols.piano_rounded;
      case RelaxationMusicType.gammaFocus40Hz:
        return Symbols.bolt_rounded;
      case RelaxationMusicType.healing432Hz:
        return Symbols.auto_awesome_rounded;
      case RelaxationMusicType.miracleTone528Hz:
        return Symbols.stars_rounded;
      case RelaxationMusicType.tibetanBowls:
        return Symbols.self_improvement_rounded;
      case RelaxationMusicType.rainOnWindow:
        return Symbols.water_drop_rounded;
      case RelaxationMusicType.oceanWaves:
        return Symbols.waves_rounded;
      case RelaxationMusicType.forestBirds:
        return Symbols.forest_rounded;
      case RelaxationMusicType.rainPiano432Hz:
        return Symbols.nightlight_rounded;
      case RelaxationMusicType.deepSleepDelta:
        return Symbols.bedtime_rounded;
      case RelaxationMusicType.softPianoRain:
        return Symbols.music_note_rounded;
      case RelaxationMusicType.healingNightSounds:
        return Symbols.dark_mode_rounded;
    }
  }

  RelaxationCategory get category {
    switch (this) {
      case RelaxationMusicType.binauralBeatsAlpha:
      case RelaxationMusicType.lofiHipHop:
      case RelaxationMusicType.ambientInstrumental:
      case RelaxationMusicType.gammaFocus40Hz:
        return RelaxationCategory.deepFocus;
      case RelaxationMusicType.healing432Hz:
      case RelaxationMusicType.miracleTone528Hz:
      case RelaxationMusicType.tibetanBowls:
      case RelaxationMusicType.rainOnWindow:
      case RelaxationMusicType.oceanWaves:
      case RelaxationMusicType.forestBirds:
        return RelaxationCategory.stressRelief;
      case RelaxationMusicType.rainPiano432Hz:
      case RelaxationMusicType.deepSleepDelta:
      case RelaxationMusicType.softPianoRain:
      case RelaxationMusicType.healingNightSounds:
        return RelaxationCategory.nervousSystemReset;
    }
  }
}

class RelaxationSession {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetMinutes;
  final int actualMinutes;
  final bool wasCompleted;
  final bool wasAbandoned;
  final RelaxationMusicType musicType;
  final RelaxationCategory category;

  RelaxationSession({
    required this.id,
    required this.startedAt,
    this.completedAt,
    required this.targetMinutes,
    this.actualMinutes = 0,
    this.wasCompleted = false,
    this.wasAbandoned = false,
    required this.musicType,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'targetMinutes': targetMinutes,
        'actualMinutes': actualMinutes,
        'wasCompleted': wasCompleted,
        'wasAbandoned': wasAbandoned,
        'musicType': musicType.index,
        'category': category.index,
      };

  factory RelaxationSession.fromJson(Map<String, dynamic> json) => RelaxationSession(
        id: json['id'] ?? '',
        startedAt: DateTime.parse(json['startedAt']),
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
        targetMinutes: json['targetMinutes'] ?? 0,
        actualMinutes: json['actualMinutes'] ?? 0,
        wasCompleted: json['wasCompleted'] ?? false,
        wasAbandoned: json['wasAbandoned'] ?? false,
        musicType: EnumJson.at(RelaxationMusicType.values, json['musicType'],
            RelaxationMusicType.values.first),
        category: EnumJson.at(RelaxationCategory.values, json['category'],
            RelaxationCategory.values.first),
      );

  RelaxationSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? completedAt,
    int? targetMinutes,
    int? actualMinutes,
    bool? wasCompleted,
    bool? wasAbandoned,
    RelaxationMusicType? musicType,
    RelaxationCategory? category,
  }) {
    return RelaxationSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
      musicType: musicType ?? this.musicType,
      category: category ?? this.category,
    );
  }
}

class RelaxationStats {
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final int abandonedSessions;
  final Map<RelaxationCategory, int> minutesByCategory;
  final Map<RelaxationMusicType, int> usageByTrack;

  const RelaxationStats({
    this.totalMinutes = 0,
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.abandonedSessions = 0,
    this.minutesByCategory = const {},
    this.usageByTrack = const {},
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => totalSessions > 0 ? completedSessions / totalSessions : 0.0;

  Map<String, dynamic> toJson() => {
        'totalMinutes': totalMinutes,
        'totalSessions': totalSessions,
        'completedSessions': completedSessions,
        'abandonedSessions': abandonedSessions,
        'minutesByCategory': minutesByCategory.map((k, v) => MapEntry(k.index.toString(), v)),
        'usageByTrack': usageByTrack.map((k, v) => MapEntry(k.index.toString(), v)),
      };

  factory RelaxationStats.fromJson(Map<String, dynamic> json) {
    Map<RelaxationCategory, int> minutesByCategory = {};
    if (json['minutesByCategory'] != null) {
      (json['minutesByCategory'] as Map).forEach((key, value) {
        final k = EnumJson.key(RelaxationCategory.values, key);
        if (k != null && value is int) minutesByCategory[k] = value;
      });
    }

    Map<RelaxationMusicType, int> usageByTrack = {};
    if (json['usageByTrack'] != null) {
      (json['usageByTrack'] as Map).forEach((key, value) {
        final k = EnumJson.key(RelaxationMusicType.values, key);
        if (k != null && value is int) usageByTrack[k] = value;
      });
    }

    return RelaxationStats(
      totalMinutes: json['totalMinutes'] ?? 0,
      totalSessions: json['totalSessions'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      abandonedSessions: json['abandonedSessions'] ?? 0,
      minutesByCategory: minutesByCategory,
      usageByTrack: usageByTrack,
    );
  }

  RelaxationStats copyWith({
    int? totalMinutes,
    int? totalSessions,
    int? completedSessions,
    int? abandonedSessions,
    Map<RelaxationCategory, int>? minutesByCategory,
    Map<RelaxationMusicType, int>? usageByTrack,
  }) {
    return RelaxationStats(
      totalMinutes: totalMinutes ?? this.totalMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      abandonedSessions: abandonedSessions ?? this.abandonedSessions,
      minutesByCategory: minutesByCategory ?? this.minutesByCategory,
      usageByTrack: usageByTrack ?? this.usageByTrack,
    );
  }
}
