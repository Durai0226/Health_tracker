import 'package:drift/drift.dart';

/// Focus sessions — the only health pillar that had no table.
///
/// ## Why this exists
///
/// Focus history lived as a JSON blob in an `AppPreferences` row, written with
/// `_sessions.take(100)`. So on the 101st session the oldest was destroyed on the
/// next save — roughly fifty days of history at two sessions a day, silently
/// shrinking. Two consequences, both worse than the cap itself:
///
///  * `importSessionsJson` merged a backup into memory and then `_saveData()`
///    wrote 100 of them, so **restoring a 300-session backup kept 100** and the
///    user was told the restore succeeded.
///  * `_checkAndUpdateStreak` recomputes from history, which is why
///    `longestStreak` needs a defensive `max()` — a truncating source of truth
///    was quietly eroding a derived record.
///
/// ## Shape
///
/// Modelled on `WorkoutSessions`, including the five sync columns, so a later
/// decision to sync focus needs no second migration. Our own enums are persisted
/// by `.index` because we control them — the same reasoning that keeps
/// `StepSource`/`SleepSource` index-persisted while `HealthWorkoutActivityType`
/// is stored as a raw string.
///
/// `dateKey` is denormalised for the same reason the other daily tables carry
/// one: every aggregate in this feature groups by local calendar day, and
/// deriving that from a `DateTime` in SQL means either a timezone-naive
/// expression or reading every row.
/// `FocusSessionRow`, not `FocusSession`: Drift would singularise the table name
/// straight onto the domain model in `features/focus/models/focus_session.dart`,
/// and two classes with one name across a `part`-generated file is a collision
/// nobody enjoys diagnosing. Same `*Row` convention as every other table here.
@DataClassName('FocusSessionRow')
class FocusSessions extends Table {
  TextColumn get id => text()();

  /// `yyyy-MM-dd` of [startedAt], local. Indexed for the by-day roll-ups.
  TextColumn get dateKey => text()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// What the user asked for, and what they actually got. Kept separate because
  /// the difference IS the signal: `FocusInsights.suggestedMinutes` is the median
  /// of [actualMinutes] over completed sessions, which is how the app learns the
  /// length someone finishes rather than the length they pick.
  IntColumn get targetMinutes => integer()();
  IntColumn get actualMinutes => integer().withDefault(const Constant(0))();

  /// Mutually exclusive in practice, but stored as two flags rather than one
  /// enum because that is the existing persisted shape and a day can hold both
  /// kinds. `DailyFocusStats` counts completed minutes and abandoned minutes
  /// separately, and collapsing these would lose that.
  BoolColumn get wasCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get wasAbandoned => boolean().withDefault(const Constant(false))();

  IntColumn get activityTypeIndex => integer().withDefault(const Constant(0))();
  IntColumn get plantTypeIndex => integer().withDefault(const Constant(0))();
  IntColumn get soundUsedIndex => integer().nullable()();

  /// The stated intention, capped at `FocusService.kMaxIntentionChars`.
  TextColumn get note => text().nullable()();

  /// JSON arrays rather than join tables, deliberately.
  ///
  /// Neither is ever queried BY its contents — tag statistics and the distraction
  /// tally both walk the sessions they already have in memory — so two join
  /// tables would buy nothing and cost two migrations, two DAOs and a cascade
  /// delete. If either ever needs a `WHERE tag = ?`, that is the point to
  /// normalise it, not before.
  TextColumn get tagIdsJson => text().withDefault(const Constant('[]'))();
  TextColumn get distractionsJson => text().withDefault(const Constant('[]'))();

  /// Self-reported: 0 = went well, 1 = mixed, 2 = struggled. Lower is better,
  /// matching the mood index the correlation engine is written against.
  IntColumn get quality => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get schemaVer => integer().withDefault(const Constant(1))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  TextColumn get dataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
