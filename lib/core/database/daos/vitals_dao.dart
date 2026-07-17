import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/vitals_tables.dart';

part 'vitals_dao.g.dart';

@DriftAccessor(tables: [BloodPressureReadings, GlucoseReadings])
class VitalsDao extends DatabaseAccessor<AppDatabase> with _$VitalsDaoMixin {
  VitalsDao(AppDatabase db) : super(db);

  // ============ BLOOD PRESSURE ============

  Future<List<BloodPressureReading>> getAllBp() async {
    return await (select(bloodPressureReadings)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<BloodPressureReading>> getBpForRange(
      DateTime from, DateTime to) async {
    return await (select(bloodPressureReadings)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<BloodPressureReading>> watchBp() {
    return (select(bloodPressureReadings)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertBp(BloodPressureReadingsCompanion row) async {
    await into(bloodPressureReadings).insertOnConflictUpdate(row);
  }

  Future<void> deleteBp(String id) async {
    await (delete(bloodPressureReadings)..where((t) => t.id.equals(id))).go();
  }

  // ============ BLOOD GLUCOSE ============

  Future<List<GlucoseReading>> getAllGlucose() async {
    return await (select(glucoseReadings)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<GlucoseReading>> getGlucoseForRange(
      DateTime from, DateTime to) async {
    return await (select(glucoseReadings)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<GlucoseReading>> watchGlucose() {
    return (select(glucoseReadings)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertGlucose(GlucoseReadingsCompanion row) async {
    await into(glucoseReadings).insertOnConflictUpdate(row);
  }

  Future<void> deleteGlucose(String id) async {
    await (delete(glucoseReadings)..where((t) => t.id.equals(id))).go();
  }
}
