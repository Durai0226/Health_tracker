import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'sleep_stage.dart';

/// One night of sleep — measured (HealthKit / Health Connect) or estimated
/// (manual). Durations are in minutes; [efficiency] is 0..1; [sleepScore] is
/// 0..100. Stage minutes are nullable — present only when measured.
class SleepSession {
  final String id;

  /// The night's wake-up date, yyyy-MM-dd (matches [db.SleepSessionRow.dateKey]).
  final String dateKey;
  final DateTime bedtime;
  final DateTime wakeTime;
  final int inBedMinutes;
  final int asleepMinutes;
  final int awakeMinutes;
  final int? lightMinutes;
  final int? deepMinutes;
  final int? remMinutes;
  final int sleepScore;
  final double efficiency; // 0..1
  final int? qualityIndex; // 1..5 (manual self-report)
  final SleepSource source;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SleepSession({
    required this.id,
    required this.dateKey,
    required this.bedtime,
    required this.wakeTime,
    required this.inBedMinutes,
    required this.asleepMinutes,
    this.awakeMinutes = 0,
    this.lightMinutes,
    this.deepMinutes,
    this.remMinutes,
    this.sleepScore = 0,
    this.efficiency = 0,
    this.qualityIndex,
    this.source = SleepSource.manual,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// True when we have a measured stage breakdown (light/deep/rem) to plot a
  /// real hypnogram; false → the timeline shows an honest asleep-vs-in-bed split.
  bool get hasStages =>
      (lightMinutes ?? 0) + (deepMinutes ?? 0) + (remMinutes ?? 0) > 0;

  bool get isMeasured => source.isMeasured;
  String get measurementLabel => source.measurementLabel;

  double get efficiencyFraction => efficiency.clamp(0.0, 1.0);
  int get efficiencyPercent => (efficiencyFraction * 100).round();

  /// "7h 32m" from the asleep duration — the headline number.
  String get durationLabel => formatMinutes(asleepMinutes);

  /// "8h 05m" from the total time in bed.
  String get inBedLabel => formatMinutes(inBedMinutes);

  /// Minutes recorded for [stage] (0 when unmeasured).
  int stageMinutes(SleepStage stage) {
    switch (stage) {
      case SleepStage.awake:
        return awakeMinutes;
      case SleepStage.light:
        return lightMinutes ?? 0;
      case SleepStage.deep:
        return deepMinutes ?? 0;
      case SleepStage.rem:
        return remMinutes ?? 0;
    }
  }

  /// "7h 32m" (or "0h 45m" / "32m") from a raw minute count.
  static String formatMinutes(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '${r}m';
    return '${h}h ${r.toString().padLeft(2, '0')}m';
  }

  factory SleepSession.fromRow(db.SleepSessionRow r) => SleepSession(
        id: r.id,
        dateKey: r.dateKey,
        bedtime: r.bedtime,
        wakeTime: r.wakeTime,
        inBedMinutes: r.inBedMinutes,
        asleepMinutes: r.asleepMinutes,
        awakeMinutes: r.awakeMinutes,
        lightMinutes: r.lightMinutes,
        deepMinutes: r.deepMinutes,
        remMinutes: r.remMinutes,
        sleepScore: r.sleepScore,
        efficiency: r.efficiency,
        qualityIndex: r.qualityIndex,
        source: SleepSourceX.fromIndex(r.sourceIndex),
        note: r.note,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  /// Drift companion for an upsert. Always stamps a fresh [updatedAt] and marks
  /// the row unsynced (mirrors the other feature services' write contract).
  db.SleepSessionsCompanion toCompanion() => db.SleepSessionsCompanion(
        id: Value(id),
        dateKey: Value(dateKey),
        bedtime: Value(bedtime),
        wakeTime: Value(wakeTime),
        inBedMinutes: Value(inBedMinutes),
        asleepMinutes: Value(asleepMinutes),
        awakeMinutes: Value(awakeMinutes),
        lightMinutes: Value(lightMinutes),
        deepMinutes: Value(deepMinutes),
        remMinutes: Value(remMinutes),
        sleepScore: Value(sleepScore),
        efficiency: Value(efficiency),
        qualityIndex: Value(qualityIndex),
        sourceIndex: Value(source.index),
        note: Value(note),
        createdAt: Value(createdAt),
        updatedAt: Value(DateTime.now()),
        synced: const Value(false),
      );

  SleepSession copyWith({
    String? id,
    String? dateKey,
    DateTime? bedtime,
    DateTime? wakeTime,
    int? inBedMinutes,
    int? asleepMinutes,
    int? awakeMinutes,
    int? lightMinutes,
    int? deepMinutes,
    int? remMinutes,
    int? sleepScore,
    double? efficiency,
    int? qualityIndex,
    SleepSource? source,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SleepSession(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      inBedMinutes: inBedMinutes ?? this.inBedMinutes,
      asleepMinutes: asleepMinutes ?? this.asleepMinutes,
      awakeMinutes: awakeMinutes ?? this.awakeMinutes,
      lightMinutes: lightMinutes ?? this.lightMinutes,
      deepMinutes: deepMinutes ?? this.deepMinutes,
      remMinutes: remMinutes ?? this.remMinutes,
      sleepScore: sleepScore ?? this.sleepScore,
      efficiency: efficiency ?? this.efficiency,
      qualityIndex: qualityIndex ?? this.qualityIndex,
      source: source ?? this.source,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// One column in the 7-night duration trend. A day with no [session] renders as
/// a muted empty bar (honest "nothing logged", not a zero).
class SleepTrendDay {
  final DateTime date;
  final SleepSession? session;

  const SleepTrendDay({required this.date, this.session});

  int get asleepMinutes => session?.asleepMinutes ?? 0;
  bool get hasData => session != null;
}
