// Sleep-stage + provenance enums for the Sleep feature.
//
// Pure Dart (no Flutter) so they can be reused by the service, the models, and
// the widget layer without pulling in the widget tree.

/// The four stages rendered by the hypnogram / stage timeline. Ordered
/// deep → light → rem → awake for consistent legends.
enum SleepStage { awake, light, deep, rem }

extension SleepStageX on SleepStage {
  /// Human label for legends / tooltips.
  String get label {
    switch (this) {
      case SleepStage.awake:
        return 'Awake';
      case SleepStage.light:
        return 'Light';
      case SleepStage.deep:
        return 'Deep';
      case SleepStage.rem:
        return 'REM';
    }
  }
}

/// Where a session's data came from. HealthKit / Health Connect are *measured*
/// (real stage segments); a hand-entered session is *estimated*.
///
/// Index order is load-bearing: it is persisted as `SleepSessions.sourceIndex`
/// (default column value 2 → [manual]).
enum SleepSource { healthKit, healthConnect, manual }

extension SleepSourceX on SleepSource {
  /// True when the data was measured by the OS health store (not hand-entered).
  bool get isMeasured => this != SleepSource.manual;

  /// The honest provenance tag surfaced on the score ring / timeline.
  String get measurementLabel => isMeasured ? 'Measured' : 'Estimated';

  /// A short source label ("Apple Health", "Health Connect", "Manual").
  String get label {
    switch (this) {
      case SleepSource.healthKit:
        return 'Apple Health';
      case SleepSource.healthConnect:
        return 'Health Connect';
      case SleepSource.manual:
        return 'Manual';
    }
  }

  /// Safe mapping from the persisted [SleepSessions.sourceIndex].
  static SleepSource fromIndex(int index) {
    if (index >= 0 && index < SleepSource.values.length) {
      return SleepSource.values[index];
    }
    return SleepSource.manual;
  }
}
