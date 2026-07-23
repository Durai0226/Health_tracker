import 'package:drift/drift.dart' show Value;
import 'package:tablet_remainder/core/database/app_database.dart' as db;

/// What the person is using cycle tracking for. The index maps 1:1 to the
/// persisted `trackingModeIndex`, so order is load-bearing.
enum TrackingMode { tracking, ttc, pregnancy }

extension TrackingModeX on TrackingMode {
  String get label {
    switch (this) {
      case TrackingMode.tracking:
        return 'Tracking';
      case TrackingMode.ttc:
        return 'Trying to conceive';
      case TrackingMode.pregnancy:
        return 'Pregnancy';
    }
  }

  String get shortLabel {
    switch (this) {
      case TrackingMode.tracking:
        return 'Track';
      case TrackingMode.ttc:
        return 'TTC';
      case TrackingMode.pregnancy:
        return 'Pregnancy';
    }
  }

  static TrackingMode fromIndex(int i) {
    if (i < 0 || i >= TrackingMode.values.length) return TrackingMode.tracking;
    return TrackingMode.values[i];
  }
}

/// Single-row user preferences for the period feature.
class PeriodSettings {
  final TrackingMode trackingMode;
  final int typicalCycleLength;
  final int typicalPeriodLength;
  final int lutealPhaseLength;
  final DateTime? pregnancyStartDate;
  final bool birthControlEnabled;
  final bool cloudSyncEnabled;

  const PeriodSettings({
    this.trackingMode = TrackingMode.tracking,
    this.typicalCycleLength = 28,
    this.typicalPeriodLength = 5,
    this.lutealPhaseLength = 14,
    this.pregnancyStartDate,
    this.birthControlEnabled = false,
    this.cloudSyncEnabled = false,
  });

  static const PeriodSettings defaults = PeriodSettings();

  PeriodSettings copyWith({
    TrackingMode? trackingMode,
    int? typicalCycleLength,
    int? typicalPeriodLength,
    int? lutealPhaseLength,
    DateTime? pregnancyStartDate,
    bool? birthControlEnabled,
    bool? cloudSyncEnabled,
    bool clearPregnancyStart = false,
  }) {
    return PeriodSettings(
      trackingMode: trackingMode ?? this.trackingMode,
      typicalCycleLength: typicalCycleLength ?? this.typicalCycleLength,
      typicalPeriodLength: typicalPeriodLength ?? this.typicalPeriodLength,
      lutealPhaseLength: lutealPhaseLength ?? this.lutealPhaseLength,
      pregnancyStartDate: clearPregnancyStart
          ? null
          : (pregnancyStartDate ?? this.pregnancyStartDate),
      birthControlEnabled: birthControlEnabled ?? this.birthControlEnabled,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    );
  }

  factory PeriodSettings.fromRow(db.PeriodSettingsRow r) => PeriodSettings(
        trackingMode: TrackingModeX.fromIndex(r.trackingModeIndex),
        typicalCycleLength: r.typicalCycleLength,
        typicalPeriodLength: r.typicalPeriodLength,
        lutealPhaseLength: r.lutealPhaseLength,
        pregnancyStartDate: r.pregnancyStartDate,
        birthControlEnabled: r.birthControlEnabled,
        cloudSyncEnabled: r.cloudSyncEnabled,
      );

  db.PeriodSettingsTableCompanion toCompanion() {
    return db.PeriodSettingsTableCompanion(
      id: const Value('settings'),
      trackingModeIndex: Value(trackingMode.index),
      typicalCycleLength: Value(typicalCycleLength),
      typicalPeriodLength: Value(typicalPeriodLength),
      lutealPhaseLength: Value(lutealPhaseLength),
      pregnancyStartDate: pregnancyStartDate == null
          ? const Value.absent()
          : Value(pregnancyStartDate),
      birthControlEnabled: Value(birthControlEnabled),
      cloudSyncEnabled: Value(cloudSyncEnabled),
      updatedAt: Value(DateTime.now()),
    );
  }
}
