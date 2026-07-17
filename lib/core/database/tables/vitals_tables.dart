import 'package:drift/drift.dart';

/// Blood-pressure readings (mm Hg). `categoryIndex` stores the denormalized
/// AHA/ACC category (BpCategory.index) for fast filtering; it is recomputed on
/// write from the systolic/diastolic values.
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
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Blood-glucose readings. Value is stored canonically as integer mg/dL; the
/// display unit (mg/dL vs mmol/L) is a user preference applied only at render.
/// `classIndex` stores the denormalized GlucoseClass; `contextIndex` the
/// GlucoseContext that drove the classification.
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
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
