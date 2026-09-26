import 'package:drift/drift.dart';

/// Reminders Table
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  IntColumn get repeatType => integer().withDefault(const Constant(0))(); // RepeatType enum
  TextColumn get customDaysJson => text().nullable()(); // JSON array of int
  IntColumn get snoozeDuration => integer().nullable()();
  TextColumn get sound => text().withDefault(const Constant('default'))();
  IntColumn get priority => integer().withDefault(const Constant(2))(); // ReminderPriority enum
  TextColumn get categoryId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get noteId => text().nullable()();

  /// The OS notification id this reminder is armed under.
  ///
  /// Was derived at every call site as `reminder.id.hashCode & 0x7FFFFFFF` —
  /// unreserved, so it could land anywhere, including on top of the fixed blocks
  /// other features own (910000-910002 bedtime/step/wake, 918401+ focus,
  /// 960000-960099 water, 990001-990004 period). Its `+1..+7` weekday variants
  /// and `+100000` snooze twin widened the blast radius further. A collision
  /// means one reminder cancels or overwrites another's alarm, silently.
  ///
  /// Now allocated from a reserved block (see `genericReminderIdBase`) and stored,
  /// so ids are auditable, stable across a hashCode change, and re-armable after
  /// a restore. Nullable: rows written before v16 have none until their next save
  /// or the next reschedule pass, and fall back to the legacy derivation so their
  /// already-scheduled alarms stay cancellable.
  IntColumn get notificationId => integer().nullable()();

  /// An RFC 5545 `RRULE:` string, when the repeat is richer than [repeatType]
  /// can express.
  ///
  /// Dual-read with `repeatType`, not a replacement: every stored reminder has a
  /// `repeatType` and most will keep using it. Null means "use `repeatType`",
  /// which is also the fallback if this string fails to parse — a rule written
  /// by a newer build must degrade to the old schedule, not to a crash on the
  /// list.
  TextColumn get recurrenceRule => text().nullable()();

  /// Stop repeating after this instant. Null means forever, which is what every
  /// repeating reminder was before: there was no end condition at all.
  DateTimeColumn get endsAt => dateTime().nullable()();

  /// Stop after this many occurrences. Null means unlimited.
  IntColumn get occurrenceLimit => integer().nullable()();

  /// Temporarily stop firing without deleting. Deleting used to be the only way
  /// to stop a reminder, which also destroyed its history.
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();

  /// A [ReminderEscalation] name — how hard this reminder pushes when ignored.
  ///
  /// By name, not index: reordering the enum must not silently promote every
  /// existing "quiet" reminder to a full-screen alarm.
  TextColumn get escalation =>
      text().withDefault(const Constant('standard'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per *occurrence* of a reminder — the thing `Reminders.isCompleted`
/// could never be.
///
/// `isCompleted` is a single mutable boolean. Completing a repeating reminder
/// overwrote it and rolled `scheduledTime` forward, and `add_reminder_screen`
/// reset it to `false` on every save. So a generic reminder **destroyed its own
/// history**: there was no record that yesterday's 9pm reminder was ever shown,
/// let alone acted on.
///
/// Nothing "smart" is buildable on top of that. Adherence, streaks, a digest,
/// and adaptive timing all need to know what happened and when — which is why
/// this table comes before any of them. Medication already had its equivalent in
/// `MedicineLogs`; generic reminders had nothing.
///
/// The id is deterministic — `reminderId@millisecondsSinceEpoch`, the same shape
/// as `MedicineCleanStorageService.doseLogId` — so writing an outcome is an
/// idempotent upsert. Two "done" taps on the same occurrence, or a background
/// action drained twice, cannot produce two rows.
@TableIndex(name: 'idx_occ_reminder', columns: {#reminderId})
@TableIndex(name: 'idx_occ_scheduled', columns: {#scheduledFor})
class ReminderOccurrences extends Table {
  TextColumn get id => text()();

  /// The `Reminders.id` this occurrence belongs to. No FK constraint, matching
  /// `Reminders.categoryId` and `MedicineLogs.medicineId`: deleting a reminder
  /// should not silently erase the record that it once fired.
  TextColumn get reminderId => text()();

  /// The instant the occurrence was due — its identity, not when it fired.
  DateTimeColumn get scheduledFor => dateTime()();

  /// When the notification actually appeared. Null if it never did (the OS
  /// dropped it, exact alarms were denied, the device was off).
  DateTimeColumn get firedAt => dateTime().nullable()();

  /// When the user acted. Null while [outcome] is pending or missed.
  DateTimeColumn get actedAt => dateTime().nullable()();

  /// A [ReminderOutcome] name — stored by name, not index, so reordering the
  /// enum cannot silently reinterpret history.
  TextColumn get outcome =>
      text().withDefault(const Constant('pending'))();

  /// How many times this occurrence was snoozed before it was resolved. The
  /// signal behind "you always push the 9pm one back".
  IntColumn get snoozeCount => integer().withDefault(const Constant(0))();

  /// Where the action came from — `notification`, `app`, `widget`. Distinguishes
  /// a one-tap Done from the notification (the behaviour worth encouraging) from
  /// opening the app to tick it off.
  TextColumn get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reminder Categories Table
class ReminderCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
  IntColumn get iconCodePoint => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
