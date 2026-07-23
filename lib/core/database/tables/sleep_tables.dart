import 'package:drift/drift.dart';

/// Sleep-tracking table. Universal sync fields on every row (see
/// period_tables.dart). Stage minutes are nullable — present only when measured
/// by HealthKit/Health Connect; manual logs record duration + a quality index.
@DataClassName('SleepSessionRow')
class SleepSessions extends Table {
  TextColumn get id => text()();
  TextColumn get dateKey => text()(); // the night's wake-up date, yyyy-MM-dd
  DateTimeColumn get bedtime => dateTime()();
  DateTimeColumn get wakeTime => dateTime()();
  IntColumn get inBedMinutes => integer()();
  IntColumn get asleepMinutes => integer()();
  IntColumn get awakeMinutes => integer().withDefault(const Constant(0))();
  IntColumn get lightMinutes => integer().nullable()();
  IntColumn get deepMinutes => integer().nullable()();
  IntColumn get remMinutes => integer().nullable()();
  IntColumn get sleepScore => integer().withDefault(const Constant(0))();
  RealColumn get efficiency => real().withDefault(const Constant(0))();
  IntColumn get qualityIndex => integer().nullable()(); // 1..5 (manual)
  IntColumn get sourceIndex =>
      integer().withDefault(const Constant(2))(); // SleepSource.index (manual)
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
