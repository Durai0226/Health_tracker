import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/reminders_tables.dart';

part 'reminders_dao.g.dart';

@DriftAccessor(tables: [Reminders, ReminderCategories])
class RemindersDao extends DatabaseAccessor<AppDatabase> with _$RemindersDaoMixin {
  RemindersDao(AppDatabase db) : super(db);

  // ============ REMINDERS ============

  Future<List<Reminder>> getAllReminders() async {
    return await (select(reminders)
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledTime)]))
      .get();
  }

  Future<List<Reminder>> getUpcomingReminders() async {
    return await (select(reminders)
      ..where((t) => t.scheduledTime.isBiggerOrEqualValue(DateTime.now()) &
                     t.isCompleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledTime)]))
      .get();
  }

  Future<Reminder?> getReminder(String id) async {
    return await (select(reminders)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> addReminder(RemindersCompanion reminder) async {
    await into(reminders).insert(reminder);
  }

  Future<void> updateReminder(RemindersCompanion reminder) async {
    await (update(reminders)..where((t) => t.id.equals(reminder.id.value))).write(reminder);
  }

  Future<void> saveReminder(RemindersCompanion reminder) async {
    await into(reminders).insertOnConflictUpdate(reminder);
  }

  Future<void> deleteReminder(String id) async {
    await (delete(reminders)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Reminder>> watchReminders() {
    return (select(reminders)
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledTime)]))
      .watch();
  }

  // ============ CATEGORIES ============

  Future<List<ReminderCategory>> getAllCategories() async {
    return await select(reminderCategories).get();
  }

  Future<ReminderCategory?> getCategory(String id) async {
    return await (select(reminderCategories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> saveCategory(ReminderCategoriesCompanion category) async {
    await into(reminderCategories).insertOnConflictUpdate(category);
  }

  Future<void> deleteCategory(String id) async {
    await (delete(reminderCategories)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<ReminderCategory>> watchCategories() => select(reminderCategories).watch();
}
