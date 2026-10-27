import 'package:drift/drift.dart';
import '../../utils/reminder_slot_spacing.dart';
import '../app_database.dart';
import '../tables/reminders_tables.dart';

part 'reminders_dao.g.dart';

/// First id of the block reserved for generic user reminders.
///
/// Every other notification family in this app owns a fixed, disjoint block
/// (910000-910002 bedtime/step/wake, 918400-918499 focus, 920000-920999
/// caregiver, 930000+ window nudges, 960000-960099 water, 990001-990004 period,
/// 100000-101439 medicine slots with 200000-201439 as their snooze twins).
/// Generic reminders were the one family with no block at all: their ids were
/// `uuid.hashCode & 0x7FFFFFFF`, which can land anywhere — including on top of
/// any of the above. `notification_id_ranges_test.dart` pinned every family
/// except this one.
const int genericReminderIdBase = 970000;

/// How many ids the generic-reminder block spans. Each reminder takes a whole
/// week of them (see `ReminderSlotSpacing`), so it holds this many divided by
/// eight — 125.
///
/// Deliberately well clear of 979999 so the `+1..+7` weekday sub-ids the
/// scheduler derives (`base + weekday`) cannot walk out of the block, and the
/// block itself stays clear of the 990001 period ids above it.
const int genericReminderIdCapacity = 1000;

/// Mirror of `background_alarm_service.dart`'s `snoozeIdOffset`, duplicated only
/// so this file stays free of service imports (a DAO must not reach into the
/// notification layer). `notification_id_ranges_test.dart` asserts they agree.
const int snoozeIdOffsetForIdRanges = 100000;

/// Offset from a reminder's id to its follow-up alarm's id.
///
/// 2000 keeps follow-ups (972000-972999) clear of both the allocatable block
/// (970000-970999) and the `+1..+7` weekday sub-ids the scheduler derives
/// (up to 971006), while staying inside the reserved 970000-979999 range.
const int genericReminderFollowUpOffset = 2000;

/// The `+100000` snooze twin of a generic reminder id, which must also stay clear
/// of every other family's block.
const int genericReminderSnoozeIdBase =
    genericReminderIdBase + snoozeIdOffsetForIdRanges;

@DriftAccessor(tables: [Reminders, ReminderCategories, ReminderOccurrences])
class RemindersDao extends DatabaseAccessor<AppDatabase> with _$RemindersDaoMixin {
  RemindersDao(AppDatabase db) : super(db);

  // ============ OCCURRENCES ============

  /// Deterministic id for one occurrence, so recording an outcome is an
  /// idempotent upsert. Same shape as
  /// `MedicineCleanStorageService.doseLogId` — two "done" taps, or a background
  /// action drained twice, must not produce two rows.
  static String occurrenceId(String reminderId, DateTime scheduledFor) =>
      '${reminderId}_${scheduledFor.millisecondsSinceEpoch}';

  /// Record what happened to one occurrence. Upserts on [occurrenceId].
  Future<void> recordOccurrence(ReminderOccurrencesCompanion row) =>
      into(reminderOccurrences).insertOnConflictUpdate(row);

  /// Create an occurrence row ONLY if one does not already exist.
  ///
  /// Distinct from [recordOccurrence] because the due-occurrence backfill must
  /// never overwrite what the user already told us. Upserting a fresh `pending`
  /// row over a `done` one would silently erase a tick — turning the adherence
  /// record it is meant to build into the thing that corrupts it.
  ///
  /// Returns true when a row was created.
  /// `insertReturningOrNull`, not `insert(mode: insertOrIgnore)`: the latter
  /// returns a rowid, which is non-zero even when the conflicting row was
  /// ignored, so it cannot answer "did I create one?". Returning null on a
  /// conflict is the only reliable signal, and callers count on it to report
  /// how many occurrences they actually derived.
  Future<bool> recordOccurrenceIfAbsent(
          ReminderOccurrencesCompanion row) async =>
      await into(reminderOccurrences)
          .insertReturningOrNull(row, mode: InsertMode.insertOrIgnore) !=
      null;

  Future<ReminderOccurrence?> getOccurrence(
          String reminderId, DateTime scheduledFor) =>
      (select(reminderOccurrences)
            ..where((t) => t.id.equals(occurrenceId(reminderId, scheduledFor))))
          .getSingleOrNull();

  /// Every occurrence of one reminder, oldest first.
  Future<List<ReminderOccurrence>> occurrencesFor(String reminderId) =>
      (select(reminderOccurrences)
            ..where((t) => t.reminderId.equals(reminderId))
            ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]))
          .get();

  /// Every occurrence due in `[from, to)`, across all reminders.
  ///
  /// Half-open on purpose: a day window is `[00:00, next 00:00)`, and an
  /// inclusive end would count midnight twice when windows are chained.
  Future<List<ReminderOccurrence>> occurrencesBetween(
          DateTime from, DateTime to) =>
      (select(reminderOccurrences)
            ..where((t) =>
                t.scheduledFor.isBiggerOrEqualValue(from) &
                t.scheduledFor.isSmallerThanValue(to))
            ..orderBy([(t) => OrderingTerm.asc(t.scheduledFor)]))
          .get();

  /// Occurrences still unresolved whose time has passed — the input to the
  /// missed-dose sweep. Without this the denominator is missing and a user who
  /// never opens the app shows perfect adherence forever.
  Future<List<ReminderOccurrence>> pendingBefore(DateTime cutoff) =>
      (select(reminderOccurrences)
            ..where((t) =>
                t.outcome.equals('pending') &
                t.scheduledFor.isSmallerThanValue(cutoff)))
          .get();

  Stream<List<ReminderOccurrence>> watchOccurrencesFor(String reminderId) =>
      (select(reminderOccurrences)
            ..where((t) => t.reminderId.equals(reminderId))
            ..orderBy([(t) => OrderingTerm.desc(t.scheduledFor)]))
          .watch();

  /// Drop a reminder's history. Only for a real delete — never as cleanup,
  /// because these rows ARE the adherence record.
  Future<void> deleteOccurrencesFor(String reminderId) =>
      (delete(reminderOccurrences)..where((t) => t.reminderId.equals(reminderId)))
          .go();

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

  /// Claim the lowest free notification id in the reserved generic-reminder
  /// block, or `null` when the block is full.
  ///
  /// "Free" means a whole [ReminderSlotSpacing.span] of ids: a reminder that
  /// repeats on chosen days is armed under `slot + 1 … slot + 7` as well, so the
  /// next reminder's slot has to sit a week of ids clear of it. Handing them out
  /// one apart let a weekday reminder's Tuesday land on its neighbour's slot, and
  /// whichever was armed second replaced the first. The block holds
  /// `genericReminderIdCapacity ~/ span` reminders; past that the caller keeps
  /// the legacy derivation.
  ///
  /// Lowest-free rather than max+1 so deleting a reminder actually frees its
  /// slot; with max+1 a user who churns reminders would march off the end of the
  /// block and start colliding with the family above it.
  ///
  /// Racy in principle — read-then-write with no transaction — but reminders are
  /// only ever created from a UI tap on the main isolate, so there is no second
  /// writer. Stated here so a future background creator does not assume
  /// otherwise.
  Future<int?> allocateNotificationId() async {
    final rows =
        await (selectOnly(reminders)..addColumns([reminders.notificationId]))
            .map((r) => r.read(reminders.notificationId))
            .get();
    return ReminderSlotSpacing.lowestFree(
      rows.whereType<int>(),
      base: genericReminderIdBase,
      capacity: genericReminderIdCapacity,
    );
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
