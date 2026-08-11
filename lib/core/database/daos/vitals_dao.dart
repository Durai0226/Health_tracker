import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/vitals_tables.dart';

part 'vitals_dao.g.dart';

@DriftAccessor(
    tables: [BloodPressureReadings, GlucoseReadings, WeightReadings, MoodEntries])
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

  // ============ WEIGHT ============

  Future<List<WeightReading>> getAllWeight() async {
    return await (select(weightReadings)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<WeightReading>> getWeightForRange(
      DateTime from, DateTime to) async {
    return await (select(weightReadings)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<WeightReading>> watchWeight() {
    return (select(weightReadings)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertWeight(WeightReadingsCompanion row) async {
    await into(weightReadings).insertOnConflictUpdate(row);
  }

  Future<void> deleteWeight(String id) async {
    await (delete(weightReadings)..where((t) => t.id.equals(id))).go();
  }

  // ============ MOOD ============

  Future<List<MoodEntry>> getAllMood() async {
    return await (select(moodEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<MoodEntry>> getMoodForRange(DateTime from, DateTime to) async {
    return await (select(moodEntries)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<MoodEntry>> watchMood() {
    return (select(moodEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertMood(MoodEntriesCompanion row) async {
    await into(moodEntries).insertOnConflictUpdate(row);
  }

  Future<void> deleteMood(String id) async {
    await (delete(moodEntries)..where((t) => t.id.equals(id))).go();
  }
}
