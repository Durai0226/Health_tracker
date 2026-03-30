import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/fitness_tables.dart';

part 'fitness_dao.g.dart';

@DriftAccessor(tables: [FitnessReminders, FitnessActivities])
class FitnessDao extends DatabaseAccessor<AppDatabase> with _$FitnessDaoMixin {
  FitnessDao(AppDatabase db) : super(db);

  // ============ FITNESS REMINDERS ============

  Future<List<FitnessReminder>> getAllReminders() async {
    return await select(fitnessReminders).get();
  }

  Future<List<FitnessReminder>> getActiveReminders() async {
    return await (select(fitnessReminders)
      ..where((t) => t.isEnabled.equals(true)))
      .get();
  }

  Future<FitnessReminder?> getReminder(String id) async {
    return await (select(fitnessReminders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> addReminder(FitnessRemindersCompanion reminder) async {
    await into(fitnessReminders).insert(reminder);
  }

  Future<void> updateReminder(FitnessRemindersCompanion reminder) async {
    await (update(fitnessReminders)..where((t) => t.id.equals(reminder.id.value))).write(reminder);
  }

  Future<void> deleteReminder(String id) async {
    await (delete(fitnessReminders)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<FitnessReminder>> watchReminders() => select(fitnessReminders).watch();

  // ============ FITNESS ACTIVITIES ============

  Future<List<FitnessActivity>> getAllActivities() async {
    return await (select(fitnessActivities)
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
      .get();
  }

  Future<List<FitnessActivity>> getActivitiesForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return await (select(fitnessActivities)
      ..where((t) => t.startTime.isBiggerOrEqualValue(startOfDay) &
                     t.startTime.isSmallerThanValue(endOfDay))
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
      .get();
  }

  Future<void> addActivity(FitnessActivitiesCompanion activity) async {
    await into(fitnessActivities).insert(activity);
  }

  Future<void> updateActivity(FitnessActivitiesCompanion activity) async {
    await (update(fitnessActivities)..where((t) => t.id.equals(activity.id.value))).write(activity);
  }

  Future<void> saveActivity(FitnessActivitiesCompanion activity) async {
    await into(fitnessActivities).insertOnConflictUpdate(activity);
  }

  Future<void> deleteActivity(String id) async {
    await (delete(fitnessActivities)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<FitnessActivity>> watchActivities() {
    return (select(fitnessActivities)
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
      .watch();
  }
}
