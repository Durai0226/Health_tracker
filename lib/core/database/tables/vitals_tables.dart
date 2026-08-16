import 'package:drift/drift.dart';

/// ## The universal sync fields on these four tables (schema v13)
///
/// `createdAt` + `synced` shipped originally; `updatedAt`, `deletedAt`,
/// `schemaVer` and `dataJson` were retrofitted later. Their absence was the
/// whole reason blood pressure, glucose, weight and mood were the only
/// trackers `HealthCloudSyncService` could not carry: its reconciler compares
/// `updatedAt` for last-write-wins and needs a tombstone to distinguish "the
/// user deleted this" from "this device has not synced yet". Without them a
/// deleted reading came straight back on the next sync.
///
/// `deletedAt` means every read path here MUST filter `deletedAt.isNull()`,
/// and every companion mapper MUST write `deletedAt: Value(null)` — see the
/// note on `VitalsStorageService.deleteBp` about Undo re-saving the same id.

/// Blood-pressure readings (mm Hg). `categoryIndex` stores the denormalized
/// AHA/ACC category (BpCategory.index) for fast filtering; it is recomputed on
/// write from the systolic/diastolic values.
@TableIndex(name: 'idx_bp_taken_at', columns: {#takenAt})
class BloodPressureReadings extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().nullable()();
  IntColumn get systolic => integer()();
  IntColumn get diastolic => integer()();
  IntColumn get pulse => integer().nullable()();
  IntColumn get armIndex => integer().nullable()(); // 0=left, 1=right
  IntColumn get positionIndex =>
      integer().nullable()(); // 0=sitting, 1=standing, 2=lying
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get tagsJson => text().nullable()(); // JSON string[]
  TextColumn get note => text().nullable()();
  IntColumn get categoryIndex =>
      integer().withDefault(const Constant(0))(); // BpCategory.index
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Blood-glucose readings. Value is stored canonically as integer mg/dL; the
/// display unit (mg/dL vs mmol/L) is a user preference applied only at render.
/// `classIndex` stores the denormalized GlucoseClass; `contextIndex` the
/// GlucoseContext that drove the classification.
@TableIndex(name: 'idx_glucose_taken_at', columns: {#takenAt})
class GlucoseReadings extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().nullable()();
  IntColumn get valueMgdl => integer()();
  IntColumn get contextIndex =>
      integer().withDefault(const Constant(4))(); // GlucoseContext.index (random)
  DateTimeColumn get takenAt => dateTime()();
  IntColumn get carbs => integer().nullable()(); // grams
  RealColumn get insulinUnits => real().nullable()();
  TextColumn get medNote => text().nullable()();
  TextColumn get tagsJson => text().nullable()(); // JSON string[]
  TextColumn get note => text().nullable()();
  IntColumn get classIndex =>
      integer().withDefault(const Constant(2))(); // GlucoseClass.index (inRange)
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Body-weight readings. Value is stored canonically as kilograms (matching
/// `DependentProfile.weight`'s convention); the display unit (kg vs lb) is a
/// user preference applied only at render, same pattern as glucose's mg/dL.
@TableIndex(name: 'idx_weight_taken_at', columns: {#takenAt})
class WeightReadings extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().nullable()();
  RealColumn get valueKg => real()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get tagsJson => text().nullable()(); // JSON string[]
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

/// Daily mood entries. `moodIndex` follows `moodRatingLabels`' convention (0 =
/// Great … 4 = Terrible), so the same rating already collected per-dose can be
/// compared against a standalone daily mood without a second scale to reconcile.
@TableIndex(name: 'idx_mood_taken_at', columns: {#takenAt})
class MoodEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().nullable()();
  IntColumn get moodIndex => integer()();
  DateTimeColumn get takenAt => dateTime()();
  TextColumn get tagsJson => text().nullable()(); // JSON string[]
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  // Mood alone shipped without even `synced` — it was never syncable at all.
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
