/// Where a day's step count came from. Persisted as its [index] in
/// `StepDailyData.sourceIndex`.
///
/// - [healthKit] / [healthConnect] / [pedometer] are hardware-measured.
/// - [manual] is user-entered (an estimate).
/// - [mixed] is a sensor total the user has topped up with a manual adjustment.
enum StepSource { healthKit, healthConnect, pedometer, manual, mixed }

extension StepSourceX on StepSource {
  /// Honest "Measured" vs "Estimated" label for the UI — sensor data is
  /// measured; anything the user typed (or a sensor total nudged by hand) is an
  /// estimate.
  String get label {
    switch (this) {
      case StepSource.healthKit:
      case StepSource.healthConnect:
      case StepSource.pedometer:
        return 'Measured';
      case StepSource.manual:
      case StepSource.mixed:
        return 'Estimated';
    }
  }

  /// Human-readable provider name.
  String get title {
    switch (this) {
      case StepSource.healthKit:
        return 'Apple Health';
      case StepSource.healthConnect:
        return 'Health Connect';
      case StepSource.pedometer:
        return 'Step sensor';
      case StepSource.manual:
        return 'Manual entry';
      case StepSource.mixed:
        return 'Sensor + manual';
    }
  }

  /// True when the total is backed by at least some hardware measurement.
  bool get isMeasured =>
      this == StepSource.healthKit ||
      this == StepSource.healthConnect ||
      this == StepSource.pedometer ||
      this == StepSource.mixed;

  /// Safe decode of a persisted `sourceIndex` (defaults to [manual]).
  static StepSource fromIndex(int? index) {
    if (index == null || index < 0 || index >= StepSource.values.length) {
      return StepSource.manual;
    }
    return StepSource.values[index];
  }
}
