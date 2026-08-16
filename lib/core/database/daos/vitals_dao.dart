import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/vitals_tables.dart';

part 'vitals_dao.g.dart';

/// Blood pressure, glucose, weight and mood.
///
/// ## Soft deletes (schema v13)
///
/// Deletes here used to be real `DELETE`s. That left nothing behind to say
/// "the user removed this", so once these tables became cloud-synced the next
/// sync would see the id present in Firestore and absent locally, read that as
/// "missing on this device", and download the reading straight back. Same bug
/// `SleepDao.deleteSession` already documents.
///
/// So every delete stamps a tombstone instead, and **every read filters
/// `deletedAt.isNull()`**. `get*ForRangeIncludingDeleted` is the one deliberate
/// exception, for the syncer that has to see tombstones to propagate them.
@DriftAccessor(
    tables: [BloodPressureReadings, GlucoseReadings, WeightReadings, MoodEntries])
class VitalsDao extends DatabaseAccessor<AppDatabase> with _$VitalsDaoMixin {
  VitalsDao(AppDatabase db) : super(db);

  /// `updatedAt` is bumped so the deletion wins the last-write-wins compare,
  /// and `synced` is cleared so the row is re-uploaded as a tombstone.
  static DateTime get _now => DateTime.now();

  // ============ BLOOD PRESSURE ============

  Future<List<BloodPressureReading>> getAllBp() async {
    return await (select(bloodPressureReadings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<BloodPressureReading>> getBpForRange(
      DateTime from, DateTime to) async {
    return await (select(bloodPressureReadings)
          ..where((t) =>
              t.takenAt.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  /// Cloud-sync only — tombstones included, so a deletion can propagate.
  Future<List<BloodPressureReading>> getBpForRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(bloodPressureReadings)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<BloodPressureReading>> watchBp() {
    return (select(bloodPressureReadings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertBp(BloodPressureReadingsCompanion row) async {
    await into(bloodPressureReadings).insertOnConflictUpdate(row);
  }

  Future<void> deleteBp(String id) async {
    final now = _now;
    await (update(bloodPressureReadings)..where((t) => t.id.equals(id))).write(
      BloodPressureReadingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ BLOOD GLUCOSE ============

  Future<List<GlucoseReading>> getAllGlucose() async {
    return await (select(glucoseReadings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<GlucoseReading>> getGlucoseForRange(
      DateTime from, DateTime to) async {
    return await (select(glucoseReadings)
          ..where((t) =>
              t.takenAt.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<GlucoseReading>> getGlucoseForRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(glucoseReadings)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<GlucoseReading>> watchGlucose() {
    return (select(glucoseReadings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertGlucose(GlucoseReadingsCompanion row) async {
    await into(glucoseReadings).insertOnConflictUpdate(row);
  }

  Future<void> deleteGlucose(String id) async {
    final now = _now;
    await (update(glucoseReadings)..where((t) => t.id.equals(id))).write(
      GlucoseReadingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ WEIGHT ============

  Future<List<WeightReading>> getAllWeight() async {
    return await (select(weightReadings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<WeightReading>> getWeightForRange(
      DateTime from, DateTime to) async {
    return await (select(weightReadings)
          ..where((t) =>
              t.takenAt.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<WeightReading>> getWeightForRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(weightReadings)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<WeightReading>> watchWeight() {
    return (select(weightReadings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertWeight(WeightReadingsCompanion row) async {
    await into(weightReadings).insertOnConflictUpdate(row);
  }

  Future<void> deleteWeight(String id) async {
    final now = _now;
    await (update(weightReadings)..where((t) => t.id.equals(id))).write(
      WeightReadingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }

  // ============ MOOD ============

  Future<List<MoodEntry>> getAllMood() async {
    return await (select(moodEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<MoodEntry>> getMoodForRange(DateTime from, DateTime to) async {
    return await (select(moodEntries)
          ..where((t) =>
              t.takenAt.isBetweenValues(from, to) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Future<List<MoodEntry>> getMoodForRangeIncludingDeleted(
      DateTime from, DateTime to) {
    return (select(moodEntries)
          ..where((t) => t.takenAt.isBetweenValues(from, to))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  Stream<List<MoodEntry>> watchMood() {
    return (select(moodEntries)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .watch();
  }

  Future<void> upsertMood(MoodEntriesCompanion row) async {
    await into(moodEntries).insertOnConflictUpdate(row);
  }

  Future<void> deleteMood(String id) async {
    final now = _now;
    await (update(moodEntries)..where((t) => t.id.equals(id))).write(
      MoodEntriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );
  }
}
