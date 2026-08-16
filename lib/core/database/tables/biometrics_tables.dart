import 'package:drift/drift.dart';

/// Wearable biometrics, aggregated to ONE row per calendar day.
///
/// ## Why daily, and not one row per sample
///
/// A worn watch writes roughly one heart-rate sample a minute — ~1,400 a day,
/// ~500k a year. Four independent things break if those are stored raw:
///
/// * Nothing in the app consumes intraday heart rate. Every screen and every
///   engine in `lib/core/health/` works on daily or nightly figures.
/// * `BackupService` uploads the whole export to the user's Drive.
/// * `HealthCloudSyncService._sync` reads with `.limit(1000)` and writes ONE
///   Firestore document per row — a raw table blows the cap on day one and
///   costs thousands of writes per sync.
/// * `HealthDataService._readPoints` has no pagination, and `health` 13.x
///   routes any read over 100 points through a `compute()` isolate.
///
/// Intraday shape is kept the way Steps already keeps it: a JSON bucket array
/// on the daily row (`hourlyHrJson`, cf. `StepDailyData.hourlyJson`). Memory is
/// bounded by the READ strategy rather than the schema — BiometricsService
/// reads one day at a time, aggregates, and drops the list.
///
/// ## Two different windows live on the same row
///
/// * Calendar day `[00:00, 24:00)` — heart rate, SpO2, respiratory rate, body
///   temperature.
/// * Night `[prev 18:00, 18:00)` — HRV, skin temperature, and a derived
///   resting heart rate.
///
/// Both come from `lib/core/health/health_windows.dart`, which is the same
/// helper `SleepService` buckets by, so "last night" cannot mean two different
/// things in two features.
///
/// ## Every split metric records WHICH statistic it is
///
/// HealthKit exposes HRV as SDNN; Health Connect exposes RMSSD. They are
/// different statistics over different ranges (nightly RMSSD ≈ 20–100 ms, SDNN
/// ≈ 30–180 ms). Android skin temperature is a DELTA from the wearer's
/// baseline; Apple's sleeping wrist temperature is ABSOLUTE °C. Charting either
/// pair as one series — which a cross-platform backup restore would produce —
/// fabricates a trend out of a unit change. Hence `hrvMetricIndex` and
/// `skinTempMetricIndex`: readers MUST filter on them before plotting.
@DataClassName('BiometricDayRow')
@TableIndex(name: 'idx_biometrics_date', columns: {#date})
class BiometricDailyData extends Table {
  TextColumn get id => text()(); // yyyy-MM-dd
  DateTimeColumn get date => dateTime()();

  // ---- Heart rate (bpm), calendar day ----
  IntColumn get restingHr => integer().nullable()();

  /// True when [restingHr] was DERIVED (the 5th percentile of night-window
  /// heart rate) rather than read from a RESTING_HEART_RATE record. The UI must
  /// label it "estimated" — the same honesty rule the sleep and steps screens
  /// already follow for inferred figures.
  BoolColumn get restingHrDerived =>
      boolean().withDefault(const Constant(false))();
  IntColumn get hrMin => integer().nullable()();
  IntColumn get hrAvg => integer().nullable()();
  IntColumn get hrMax => integer().nullable()();
  IntColumn get hrSampleCount => integer().withDefault(const Constant(0))();

  /// JSON `List<int?>` of length 24 — hourly mean bpm, null for an hour with no
  /// sample. A null COLUMN means "never aggregated"; a zero-filled array would
  /// claim a measured zero, which is the fabricated-chart-data defect.
  TextColumn get hourlyHrJson => text().nullable()();

  // ---- HRV (ms), NIGHT window ----
  RealColumn get hrvNightlyMs => real().nullable()();

  /// `HrvMetric.index` — 0 = rmssd (Health Connect), 1 = sdnn (HealthKit).
  IntColumn get hrvMetricIndex => integer().nullable()();
  IntColumn get hrvSampleCount => integer().withDefault(const Constant(0))();

  // ---- Blood oxygen (%, 0..100), calendar day ----
  RealColumn get spo2Min => real().nullable()();
  RealColumn get spo2Avg => real().nullable()();
  IntColumn get spo2SampleCount => integer().withDefault(const Constant(0))();

  // ---- Respiratory rate (breaths/min), calendar day ----
  RealColumn get respiratoryRateMin => real().nullable()();
  RealColumn get respiratoryRateAvg => real().nullable()();
  RealColumn get respiratoryRateMax => real().nullable()();
  IntColumn get respiratoryRateSampleCount =>
      integer().withDefault(const Constant(0))();

  // ---- Temperature (°C) ----
  /// BODY_TEMPERATURE — absolute, and the same type on both platforms.
  RealColumn get bodyTempAvgC => real().nullable()();

  /// SKIN_TEMPERATURE (Android) / SLEEP_WRIST_TEMPERATURE (iOS), night window.
  RealColumn get skinTempC => real().nullable()();

  /// `SkinTempMetric.index` — 0 = deltaFromBaseline (Android), 1 = absolute
  /// (iOS). Without this the two platforms' numbers are not comparable.
  IntColumn get skinTempMetricIndex => integer().nullable()();

  // ---- Cardio fitness ----
  /// `package:health` 13.3.2 exposes NO VO2MAX type on either platform —
  /// verified against its `dataTypeKeysAndroid` / `dataTypeKeysIOS` — even
  /// though HealthKit and Health Connect both store one. Reserved as a nullable
  /// column so a future plugin bump needs no migration. **No importer writes
  /// it today**; `health_data_types_test.dart` fails when that changes.
  RealColumn get vo2Max => real().nullable()();

  // ---- attribution ----
  /// The source that won most of this day's metrics (→ `HealthSources.id`).
  /// Lets the UI say "from Galaxy Watch5" in one line.
  TextColumn get primarySourceId => text().nullable()();

  /// JSON `{metricKey: sourceId}` — the per-metric winner. A day can legitimately
  /// draw heart rate from a watch and SpO2 from a ring.
  TextColumn get sourceByMetricJson => text().nullable()();
  IntColumn get sourceIndex =>
      integer().withDefault(const Constant(2))(); // BiometricSource.index
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  // ---- universal sync fields (see period_tables.dart) ----
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One exercise session. Event-keyed — several per day, each with its own span
/// — so this follows the `SleepSessions` shape, not `StepDailyData`'s.
@DataClassName('WorkoutSessionRow')
@TableIndex(name: 'idx_workout_started', columns: {#startedAt})
@TableIndex(name: 'idx_workout_date_key', columns: {#dateKey})
class WorkoutSessions extends Table {
  TextColumn get id => text()(); // hw_<startMillis>_<activityType>
  TextColumn get dateKey => text()(); // yyyy-MM-dd of startedAt, local
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationMinutes => integer()();

  /// `HealthWorkoutActivityType.name` as a RAW STRING, never `.index`.
  ///
  /// It is a third-party enum whose ordinals shift between plugin releases
  /// (12.2.0 alone inserted CARDIO_DANCE mid-list), so persisting the index
  /// would silently reinterpret every historical row on the next `health` bump.
  /// Our OWN enums — StepSource, SleepSource, BiometricSource — stay
  /// index-persisted, because we control those.
  TextColumn get activityType => text()();

  IntColumn get energyKcal => integer().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get steps => integer().nullable()();

  /// Filled only when the same day's heart-rate pass ran, by intersecting
  /// already-fetched HR samples with this workout's window — never a second
  /// plugin read. The plugin's `WorkoutSummary` carries no heart rate.
  IntColumn get avgHr => integer().nullable()();
  IntColumn get maxHr => integer().nullable()();

  TextColumn get sourceId => text().nullable()(); // → HealthSources.id
  IntColumn get sourceIndex => integer().withDefault(const Constant(2))();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()(); // platform uuid lives here

  @override
  Set<Column> get primaryKey => {id};
}

/// Registry of the apps and wearables that actually contribute data, so a
/// "Connected devices" screen can name them and the user can pick a winner.
///
/// ## Why the key is (platform, sourceId, sourceName) and NOT sourceDeviceId
///
/// `HealthDataPoint.sourceDeviceId` is unusable. The plugin fills it from
/// `Health().deviceId` — and since v12.0.0 removed the singleton, that
/// expression builds a FRESH, unconfigured instance whose `_deviceId` is null,
/// so `deviceId` returns the literal string `'unknown'` (health_plugin.dart:62,
/// health_data_point.dart:159). Even when populated it comes from
/// `androidInfo.id` / `iosInfo.identifierForVendor` — **this phone**, never the
/// watch. `deviceModel` is documented iOS-only, always null on the platform
/// that ships first.
///
/// ## Privacy
///
/// `sourceName` is user-supplied on both platforms and routinely contains a
/// person's name ("Durai's Apple Watch"). It is stored in a FIELD; the primary
/// key is a truncated hash so the value never becomes a Firestore document id.
@DataClassName('HealthSourceRow')
@TableIndex(name: 'idx_health_source_last_seen', columns: {#lastSeenAt})
class HealthSources extends Table {
  /// `src_<first 16 hex of sha1("<platform>:<sourceId>:<sourceName>")>`.
  TextColumn get id => text()();
  TextColumn get sourceId => text()(); // bundle id / package name
  TextColumn get sourceName => text()(); // "Galaxy Watch5", "Oura"
  TextColumn get deviceModel => text().nullable()(); // iOS-only, health ≥12.2
  IntColumn get platformIndex => integer()(); // HealthPlatformType.index

  /// JSON `{metricKey: {"lastSeenMs": int, "points": int}}`.
  TextColumn get metricsJson =>
      text().withDefault(const Constant('{}'))();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  /// User override from the Connected-devices screen. 0 = no preference;
  /// higher wins, and beats every automatic signal.
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// User switched this source off — excluded from aggregation entirely.
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
