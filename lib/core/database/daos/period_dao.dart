import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/period_tables.dart';

part 'period_dao.g.dart';

@DriftAccessor(tables: [PeriodData, PeriodRemindersTable, SymptomLogs, CycleLogs])
class PeriodDao extends DatabaseAccessor<AppDatabase> with _$PeriodDaoMixin {
  PeriodDao(AppDatabase db) : super(db);

  // ============ PERIOD DATA ============

  Future<PeriodDataData?> getPeriodData() async {
    return await (select(periodData)
      ..where((t) => t.id.equals('current')))
      .getSingleOrNull();
  }

  Future<void> savePeriodData(PeriodDataCompanion data) async {
    await into(periodData).insertOnConflictUpdate(data);
  }

  Future<void> clearPeriodData() async {
    await (delete(periodData)..where((t) => t.id.equals('current'))).go();
  }

  Stream<PeriodDataData?> watchPeriodData() {
    return (select(periodData)
      ..where((t) => t.id.equals('current')))
      .watchSingleOrNull();
  }

  // ============ PERIOD REMINDERS ============

  Future<PeriodRemindersTableData?> getPeriodReminder() async {
    return await (select(periodRemindersTable)
      ..where((t) => t.id.equals('period_reminder')))
      .getSingleOrNull();
  }

  Future<void> savePeriodReminder(PeriodRemindersTableCompanion reminder) async {
    await into(periodRemindersTable).insertOnConflictUpdate(reminder);
  }

  Future<void> deletePeriodReminder() async {
    await (delete(periodRemindersTable)..where((t) => t.id.equals('period_reminder'))).go();
  }

  // ============ SYMPTOM LOGS ============

  Future<List<SymptomLog>> getAllSymptomLogs() async {
    return await (select(symptomLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .get();
  }

  Future<SymptomLog?> getSymptomLogForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return await (select(symptomLogs)
      ..where((t) => t.date.isBiggerOrEqualValue(startOfDay) &
                     t.date.isSmallerThanValue(endOfDay)))
      .getSingleOrNull();
  }

  Future<void> saveSymptomLog(SymptomLogsCompanion log) async {
    await into(symptomLogs).insertOnConflictUpdate(log);
  }

  Future<void> deleteSymptomLog(String id) async {
    await (delete(symptomLogs)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<SymptomLog>> watchSymptomLogs() {
    return (select(symptomLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch();
  }

  // ============ CYCLE LOGS ============

  Future<List<CycleLog>> getAllCycleLogs() async {
    return await (select(cycleLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
      .get();
  }

  Future<CycleLog?> getCurrentCycle() async {
    return await (select(cycleLogs)
      ..where((t) => t.isComplete.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
      .getSingleOrNull();
  }

  Future<void> saveCycleLog(CycleLogsCompanion log) async {
    await into(cycleLogs).insertOnConflictUpdate(log);
  }

  Future<void> deleteCycleLog(String id) async {
    await (delete(cycleLogs)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<CycleLog>> watchCycleLogs() {
    return (select(cycleLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
      .watch();
  }
}
