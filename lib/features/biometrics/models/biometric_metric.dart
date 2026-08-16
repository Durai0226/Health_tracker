/// Which HRV statistic a stored value is.
///
/// NOT interchangeable. HealthKit only exposes SDNN
/// (`HEART_RATE_VARIABILITY_SDNN`), Health Connect only RMSSD
/// (`HEART_RATE_VARIABILITY_RMSSD`), and for the same recording SDNN runs
/// materially higher — nightly RMSSD sits around 20–100 ms, SDNN around
/// 30–180 ms. A chart MUST filter to one metric before plotting, or a
/// cross-platform backup restore invents a step change that never happened.
///
/// Persisted as `.index`, so the order is part of the schema.
enum HrvMetric { rmssd, sdnn }

/// Whether a stored skin temperature is a delta from the wearer's baseline
/// (Health Connect `SkinTemperatureRecord`) or an absolute reading
/// (HealthKit `AppleSleepingWristTemperature`). Same non-comparability problem
/// as [HrvMetric]. Persisted as `.index`.
enum SkinTempMetric { deltaFromBaseline, absolute }

/// Where a day's biometrics came from. Persisted as `.index`, mirroring
/// `SleepSource` — and, like it, `manual` is last so the default (2) is the
/// safe "not from a device" value.
enum BiometricSource { healthKit, healthConnect, manual }

/// Stable keys for the per-metric maps (`BiometricDailyData.sourceByMetricJson`
/// and `HealthSources.metricsJson`).
///
/// Strings, not enum indices: these cross a JSON boundary and are cloud-synced,
/// so reordering an enum must not silently reinterpret stored data.
abstract final class BiometricMetricKey {
  static const String hr = 'hr';
  static const String restingHr = 'restingHr';
  static const String hrv = 'hrv';
  static const String spo2 = 'spo2';
  static const String respiratoryRate = 'respiratoryRate';
  static const String bodyTemp = 'bodyTemp';
  static const String skinTemp = 'skinTemp';
  static const String workout = 'workout';

  static const List<String> values = <String>[
    hr,
    restingHr,
    hrv,
    spo2,
    respiratoryRate,
    bodyTemp,
    skinTemp,
    workout,
  ];

  /// Human label for the Connected-devices screen's metric chips.
  static String label(String key) => switch (key) {
        hr => 'Heart rate',
        restingHr => 'Resting HR',
        hrv => 'HRV',
        spo2 => 'Blood oxygen',
        respiratoryRate => 'Breathing rate',
        bodyTemp => 'Body temp',
        skinTemp => 'Skin temp',
        workout => 'Workouts',
        _ => key,
      };
}
