import 'package:drift/drift.dart';

/// Menstrual cycle tracking tables.
///
/// New table names (the old dropped-v2 tables were `period_data`/`cycle_logs`/
/// `symptom_logs`/`period_reminders_table`). Every row carries the universal
/// sync fields: `updatedAt` (LWW), `deletedAt` (tombstone), `schemaVer`
/// (per-row forward-compat), `synced` (local dirty flag), and a `dataJson`
/// overflow column so the schema can evolve without a migration each time.

/// One detected/derived menstrual cycle (start → next start).
@DataClassName('MenstrualCycleRow')
class MenstrualCycles extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get cycleLengthDays => integer().nullable()();
  IntColumn get periodLengthDays => integer().nullable()();
  BoolColumn get isPredicted => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One logged calendar day. Symptoms are stored as a JSON string[] of symptom
/// ids in `symptomIdsJson` (single-user tracker → no cross-symptom queries
/// needed beyond per-day aggregation).
@DataClassName('PeriodDayRow')
@TableIndex(name: 'idx_period_days_date', columns: {#date})
class PeriodDays extends Table {
  TextColumn get id => text()(); // yyyy-MM-dd
  DateTimeColumn get date => dateTime()();
  TextColumn get cycleId => text().nullable()();
  IntColumn get flowIndex => integer().withDefault(const Constant(0))();
  IntColumn get mood => integer().nullable()(); // 1..5
  IntColumn get energy => integer().nullable()(); // 1..5
  RealColumn get bbtCelsius => real().nullable()(); // manual BBT
  BoolColumn get intercourse => boolean().nullable()();
  TextColumn get symptomIdsJson => text().nullable()(); // JSON string[]
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row settings (`id = 'settings'`). `cloudSyncEnabled` is the
/// privacy-first opt-in gating whether sensitive cycle data leaves the device.
@DataClassName('PeriodSettingsRow')
class PeriodSettingsTable extends Table {
  TextColumn get id => text()(); // 'settings'
  IntColumn get trackingModeIndex =>
      integer().withDefault(const Constant(0))(); // TrackingMode.index
  IntColumn get typicalCycleLength =>
      integer().withDefault(const Constant(28))();
  IntColumn get typicalPeriodLength =>
      integer().withDefault(const Constant(5))();
  IntColumn get lutealPhaseLength =>
      integer().withDefault(const Constant(14))();
  DateTimeColumn get pregnancyStartDate => dateTime().nullable()();
  BoolColumn get birthControlEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get cloudSyncEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
