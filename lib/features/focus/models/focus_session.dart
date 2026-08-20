import 'focus_plant.dart';
import '../../../core/utils/enum_json.dart';
import 'ambient_sound.dart';

/// How a focus session runs.
/// - [single]: one continuous timer (default — preserves the plant/coin loop).
/// - [pomodoro]: alternating work / break intervals for a number of rounds.
/// How a session is timed.
///
/// **APPEND ONLY — never insert.** The mode is persisted by `.index`, both in the
/// `focusMode` preference and inside the `focusActiveSession` crash-recovery
/// snapshot. `EnumJson.at` clamps an unknown ordinal to a default, so appending
/// is safe; inserting silently reinterprets every stored value.
enum FocusMode {
  single,
  pomodoro,

  /// Count UP until the user stops — the Flowtime technique.
  ///
  /// The right fit for this app specifically, because the completion model here
  /// is already "you decide when it is over": `abandonSession` is literally a
  /// Give Up button, and the crash-recovery path refuses to guess intent. Flow
  /// mode is that stance expressed as a timer rather than as an escape hatch.
  ///
  /// The evidence for it, kept here and out of the UI: flow takes 15–20 minutes
  /// to reach, so a 25-minute countdown can cut it short; a 2025 DeskTime
  /// analysis found top performers averaged ~75 minutes of work to ~33 of rest;
  /// and analytical work optimises around 25–45 minutes while divergent work runs
  /// 90–120. A fixed 25 is a default, not a finding.
  flow,
}

extension FocusModeExtension on FocusMode {
  String get label {
    switch (this) {
      case FocusMode.single:
        return 'Single';
      case FocusMode.pomodoro:
        return 'Pomodoro';
      case FocusMode.flow:
        return 'Flow';
    }
  }
}

enum FocusActivityType {
  work,
  study,
  reading,
  meditation,
  creative,
  exercise,
  coding,
  writing,
  other,
}

extension FocusActivityTypeExtension on FocusActivityType {
  String get name {
    switch (this) {
      case FocusActivityType.work:
        return 'Work';
      case FocusActivityType.study:
        return 'Study';
      case FocusActivityType.reading:
        return 'Reading';
      case FocusActivityType.meditation:
        return 'Meditation';
      case FocusActivityType.creative:
        return 'Creative';
      case FocusActivityType.exercise:
        return 'Exercise';
      case FocusActivityType.coding:
        return 'Coding';
      case FocusActivityType.writing:
        return 'Writing';
      case FocusActivityType.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case FocusActivityType.work:
        return '💼';
      case FocusActivityType.study:
        return '📚';
      case FocusActivityType.reading:
        return '📖';
      case FocusActivityType.meditation:
        return '🧘';
      case FocusActivityType.creative:
        return '🎨';
      case FocusActivityType.exercise:
        return '💪';
      case FocusActivityType.coding:
        return '💻';
      case FocusActivityType.writing:
        return '✍️';
      case FocusActivityType.other:
        return '⭐';
    }
  }
}

class FocusSession {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetMinutes;
  final int actualMinutes;
  final bool wasCompleted;
  final bool wasAbandoned;
  final FocusActivityType activityType;
  final PlantType plantType;
  final AmbientSoundType? soundUsed;
  final String? note;
  final List<String> tagIds;

  /// How the session felt, self-reported: 0 = went well, 1 = mixed,
  /// 2 = struggled. Null when the user did not say.
  ///
  /// **Lower is better, matching the existing mood index (0 = Great … 4 =
  /// Terrible)** that `CorrelationEngine._moodMeaningfulDelta` is written
  /// against. A second, opposite scale convention in the same app is how sign
  /// errors ship — a correlation would come out backwards and read as a finding.
  ///
  /// Worth collecting specifically because this is a health app: a subjective
  /// focus-quality rating is a far more defensible correlation input than
  /// minutes. "Sessions after a short night feel harder" is the user's own
  /// report, not the app's inference about their brain.
  final int? quality;

  /// Distractions the user tapped during the session, as (id, seconds elapsed).
  ///
  /// Self-reported, and that is the point rather than a limitation. The app
  /// cannot see app switches and deliberately does not try — but the ACT of
  /// logging is itself the interposed pause that the friction research credits,
  /// and the timestamps buy something a usage-stats report cannot: not "you were
  /// distracted 14% of the time" but "Instagram pulled at you nine times across
  /// twelve sessions, mostly in the first ten minutes".
  ///
  /// Never scored. Taps ÷ minutes would turn a self-awareness tool into a thing
  /// you can be bad at, and would punish the honest logger.
  final List<DistractionTap> distractions;

  FocusSession({
    required this.id,
    required this.startedAt,
    this.completedAt,
    required this.targetMinutes,
    this.actualMinutes = 0,
    this.wasCompleted = false,
    this.wasAbandoned = false,
    required this.activityType,
    required this.plantType,
    this.soundUsed,
    this.note,
    this.tagIds = const [],
    this.quality,
    this.distractions = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'targetMinutes': targetMinutes,
        'actualMinutes': actualMinutes,
        'wasCompleted': wasCompleted,
        'wasAbandoned': wasAbandoned,
        'activityType': activityType.index,
        'plantType': plantType.index,
        'soundUsed': soundUsed?.index,
        'note': note,
        'tagIds': tagIds,
        'quality': quality,
        'distractions': distractions.map((d) => d.toJson()).toList(),
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] ?? '',
        // A session with no parseable start is not recoverable data, but it must
        // not take the rest of the history down with it.
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
        targetMinutes: json['targetMinutes'] ?? 0,
        actualMinutes: json['actualMinutes'] ?? 0,
        wasCompleted: json['wasCompleted'] ?? false,
        wasAbandoned: json['wasAbandoned'] ?? false,
        activityType: EnumJson.at(FocusActivityType.values, json['activityType'],
            FocusActivityType.work),
        plantType:
            EnumJson.at(PlantType.values, json['plantType'], PlantType.seedling),
        soundUsed: json['soundUsed'] == null
            ? null
            : EnumJson.at(AmbientSoundType.values, json['soundUsed'],
                AmbientSoundType.none),
        note: json['note'],
        // Backward-compatible: older persisted sessions have no tagIds → [].
        tagIds: json['tagIds'] is List
            ? List<String>.from(json['tagIds'].map((e) => e.toString()))
            : const [],
        // Same pattern for both new fields. A record written before they existed
        // must load, not throw — the alternative is one old session taking the
        // whole history down with it.
        quality: json['quality'] is int ? json['quality'] as int : null,
        distractions: json['distractions'] is List
            ? (json['distractions'] as List)
                .whereType<Map>()
                .map((e) => DistractionTap.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );

  FocusSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? completedAt,
    int? targetMinutes,
    int? actualMinutes,
    bool? wasCompleted,
    bool? wasAbandoned,
    FocusActivityType? activityType,
    PlantType? plantType,
    AmbientSoundType? soundUsed,
    String? note,
    List<String>? tagIds,
    int? quality,
    List<DistractionTap>? distractions,
  }) {
    return FocusSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      wasCompleted: wasCompleted ?? this.wasCompleted,
      wasAbandoned: wasAbandoned ?? this.wasAbandoned,
      activityType: activityType ?? this.activityType,
      plantType: plantType ?? this.plantType,
      soundUsed: soundUsed ?? this.soundUsed,
      note: note ?? this.note,
      tagIds: tagIds ?? this.tagIds,
      quality: quality ?? this.quality,
      distractions: distractions ?? this.distractions,
    );
  }
}

/// One tap on the user's own distraction list, during a session.
class DistractionTap {
  /// The `AllowedApp.id` that was tapped.
  final String appId;

  /// Seconds into the session. Kept rather than a wall-clock time because the
  /// useful question is "how far in did this happen", which is comparable across
  /// sessions of different lengths and at different times of day.
  final int atSecond;

  const DistractionTap({required this.appId, required this.atSecond});

  Map<String, dynamic> toJson() => {'appId': appId, 'atSecond': atSecond};

  factory DistractionTap.fromJson(Map<String, dynamic> json) => DistractionTap(
        appId: json['appId']?.toString() ?? '',
        atSecond: json['atSecond'] is int ? json['atSecond'] as int : 0,
      );
}

class FocusStats {
  final int totalMinutes;
  final int totalSessions;
  final int completedSessions;
  final int abandonedSessions;
  final int currentStreak;
  final int longestStreak;
  final int totalPlants;
  final int deadPlants;
  final Map<FocusActivityType, int> minutesByActivity;
  final Map<PlantType, int> plantCounts;
  final DateTime? lastSessionDate;

  const FocusStats({
    this.totalMinutes = 0,
    this.totalSessions = 0,
    this.completedSessions = 0,
    this.abandonedSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPlants = 0,
    this.deadPlants = 0,
    this.minutesByActivity = const {},
    this.plantCounts = const {},
    this.lastSessionDate,
  });

  int get totalHours => totalMinutes ~/ 60;
  double get completionRate => totalSessions > 0 ? completedSessions / totalSessions : 0.0;
  int get alivePlants => totalPlants - deadPlants;

  Map<String, dynamic> toJson() => {
        'totalMinutes': totalMinutes,
        'totalSessions': totalSessions,
        'completedSessions': completedSessions,
        'abandonedSessions': abandonedSessions,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalPlants': totalPlants,
        'deadPlants': deadPlants,
        'minutesByActivity': minutesByActivity.map((k, v) => MapEntry(k.index.toString(), v)),
        'plantCounts': plantCounts.map((k, v) => MapEntry(k.index.toString(), v)),
        'lastSessionDate': lastSessionDate?.toIso8601String(),
      };

  factory FocusStats.fromJson(Map<String, dynamic> json) {
    Map<FocusActivityType, int> minutesByActivity = {};
    if (json['minutesByActivity'] != null) {
      (json['minutesByActivity'] as Map).forEach((key, value) {
        final k = EnumJson.key(FocusActivityType.values, key);
        if (k != null && value is int) minutesByActivity[k] = value;
      });
    }

    Map<PlantType, int> plantCounts = {};
    if (json['plantCounts'] != null) {
      (json['plantCounts'] as Map).forEach((key, value) {
        final k = EnumJson.key(PlantType.values, key);
        if (k != null && value is int) plantCounts[k] = value;
      });
    }

    return FocusStats(
      totalMinutes: json['totalMinutes'] ?? 0,
      totalSessions: json['totalSessions'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      abandonedSessions: json['abandonedSessions'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      totalPlants: json['totalPlants'] ?? 0,
      deadPlants: json['deadPlants'] ?? 0,
      minutesByActivity: minutesByActivity,
      plantCounts: plantCounts,
      lastSessionDate: json['lastSessionDate'] != null ? DateTime.parse(json['lastSessionDate']) : null,
    );
  }

  FocusStats copyWith({
    int? totalMinutes,
    int? totalSessions,
    int? completedSessions,
    int? abandonedSessions,
    int? currentStreak,
    int? longestStreak,
    int? totalPlants,
    int? deadPlants,
    Map<FocusActivityType, int>? minutesByActivity,
    Map<PlantType, int>? plantCounts,
    DateTime? lastSessionDate,
  }) {
    return FocusStats(
      totalMinutes: totalMinutes ?? this.totalMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      abandonedSessions: abandonedSessions ?? this.abandonedSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalPlants: totalPlants ?? this.totalPlants,
      deadPlants: deadPlants ?? this.deadPlants,
      minutesByActivity: minutesByActivity ?? this.minutesByActivity,
      plantCounts: plantCounts ?? this.plantCounts,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
    );
  }
}
