import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'connection/connection.dart';

import 'tables/core_tables.dart';
import 'tables/medication_tables.dart';
import 'tables/water_tables.dart';
import 'tables/reminders_tables.dart';
import 'tables/vitals_tables.dart';
import 'tables/period_tables.dart';
import 'tables/steps_tables.dart';
import 'tables/sleep_tables.dart';
import 'tables/diary_tables.dart';
import 'tables/biometrics_tables.dart';
import 'tables/focus_tables.dart';

import 'daos/core_dao.dart';
import 'daos/medication_dao.dart';
import 'daos/water_dao.dart';
import 'daos/reminders_dao.dart';
import 'daos/vitals_dao.dart';
import 'daos/period_dao.dart';
import 'daos/steps_dao.dart';
import 'daos/sleep_dao.dart';
import 'daos/diary_dao.dart';
import 'daos/biometrics_dao.dart';
import 'daos/focus_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Core tables
    UserSettingsTable,
    ActionLogs,
    AppPreferences,
    
    // Medication tables
    EnhancedMedicines,
    MedicineLogs,
    MedicineSchedules,
    Doctors,
    Pharmacies,
    Appointments,
    DependentProfiles,
    TreatmentCourses,
    
    // Water tables
    DailyWaterDataTable,
    EnhancedWaterLogs,
    BeverageTypes,
    WaterContainers,
    HydrationProfiles,
    WaterAchievements,

    // Reminders tables
    Reminders,
    ReminderCategories,
    ReminderOccurrences,

    // Vitals tables (blood pressure, blood glucose, weight, mood)
    BloodPressureReadings,
    GlucoseReadings,
    WeightReadings,
    MoodEntries,

    // Period / menstrual cycle tables
    MenstrualCycles,
    PeriodDays,
    PeriodSettingsTable,

    // Steps tables (+ shared health profile)
    StepDailyData,
    StepManualEntries,
    HealthProfiles,

    // Sleep tables
    SleepSessions,

    // Diary / journal
    DiaryEntries,

    // Wearable biometrics (daily aggregates), workouts, and the registry of
    // apps/devices actually contributing data.
    BiometricDailyData,
    WorkoutSessions,
    HealthSources,

    // Focus
    FocusSessions,

  ],
  daos: [
    CoreDao,
    MedicationDao,
    WaterDao,
    RemindersDao,
    VitalsDao,
    PeriodDao,
    StepsDao,
    SleepDao,
    DiaryDao,
    BiometricsDao,
    FocusDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Test-only constructor: runs the full schema (incl. the FTS5 migration) on
  /// a caller-supplied executor (e.g. an in-memory database).
  @visibleForTesting
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 19;


  /// Tables dropped in v2 — the exam-prep, finance, fitness, notes, and
  /// period-tracking features were removed. Kept-feature data is untouched.
  static const List<String> _droppedTables = [
    // finance
    'bills', 'bill_payments', 'bill_categories', 'bill_templates',
    'bill_activities', 'category_keyword_maps', 'bill_settings_table',
    'finance_settings',
    // notes
    'notes', 'folders', 'tags',
    // fitness
    'fitness_reminders', 'fitness_activities',
    // period
    'period_data', 'period_reminders_table', 'symptom_logs', 'cycle_logs',
    // js learning
    'js_levels', 'js_topics', 'js_lessons', 'js_quizzes', 'js_challenges',
    'js_topic_progress', 'js_user_stats', 'js_daily_activity',
    'js_quiz_attempts', 'js_bookmarks', 'js_lesson_notes',
  ];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        debugPrint('✓ Drift database created');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        debugPrint('Drift database upgrading from $from to $to');
        if (from < 2) {
          for (final table in _droppedTables) {
            await customStatement('DROP TABLE IF EXISTS $table');
          }
          debugPrint('✓ Dropped removed-feature tables');
        }
        if (from < 3) {
          // Persist the user-entered medicine strength string in its own column
          // (was previously lost and reconstructed as a bogus "1.0pill(s)").
          await m.addColumn(enhancedMedicines, enhancedMedicines.strengthText);
          debugPrint('✓ Added enhancedMedicines.strengthText');
        }
        if (from < 4) {
          // Blood-pressure + blood-glucose vitals trackers.
          await m.createTable(bloodPressureReadings);
          await m.createTable(glucoseReadings);
          debugPrint('✓ Created vitals tables (BP + glucose)');
        }
        if (from < 5) {
          // Period / steps / sleep trackers.
          await m.createTable(menstrualCycles);
          await m.createTable(periodDays);
          await m.createTable(periodSettingsTable);
          await m.createTable(stepDailyData);
          await m.createTable(stepManualEntries);
          await m.createTable(healthProfiles);
          await m.createTable(sleepSessions);
          debugPrint('✓ Created period + steps + sleep tables');
        }
        // v6 created the RAG knowledge base + assistant-memory tables and v7
        // rebuilt the FTS index. Both features were removed in v8, so those
        // steps are intentionally gone: an install coming from <6 never needs
        // tables that v8 immediately drops.
        if (from < 9) {
          // Remove dose-log rows that a pre-v9 bug could duplicate.
          //
          // `reconcileMissedDoses` used to write `<medId>_missed_<slot>` while
          // take/skip write the canonical `<medId>_<slot>`. Different primary
          // keys, so the upsert could not collapse them and a slot could end up
          // with BOTH a missed row and a taken/skipped row. The read paths now
          // rank by status so this is already harmless — this step is the
          // tidy-up, and it deletes ONLY a `_missed_` row whose own slot also
          // has a real user action. A missed row with no counterpart is real
          // history and is kept.
          final before = await customSelect(
                  'SELECT COUNT(*) AS c FROM medicine_logs WHERE id LIKE ?',
                  variables: [Variable.withString('%_missed_%')])
              .getSingle();
          await customStatement(
            "DELETE FROM medicine_logs WHERE id LIKE '%\\_missed\\_%' ESCAPE '\\' "
            'AND EXISTS (SELECT 1 FROM medicine_logs m2 '
            '            WHERE m2.medicine_id = medicine_logs.medicine_id '
            '              AND m2.scheduled_time = medicine_logs.scheduled_time '
            '              AND m2.id <> medicine_logs.id '
            '              AND (m2.is_taken = 1 OR m2.is_skipped = 1))',
          );
          final after = await customSelect(
                  'SELECT COUNT(*) AS c FROM medicine_logs WHERE id LIKE ?',
                  variables: [Variable.withString('%_missed_%')])
              .getSingle();
          debugPrint('✓ Superseded missed-dose rows: '
              '${before.read<int>('c')} → ${after.read<int>('c')}');
        }
        if (from < 8) {
          // Drop the removed AI feature's storage. `knowledge_fts` is a raw FTS5
          // virtual table (created by customStatement, not the Drift DSL), so it
          // needs a raw DROP; the other two are ordinary tables.
          await customStatement('DROP TABLE IF EXISTS knowledge_fts');
          await customStatement('DROP TABLE IF EXISTS knowledge_chunks');
          await customStatement('DROP TABLE IF EXISTS assistant_memories');
          debugPrint('✓ Dropped removed assistant knowledge + memory tables');
        }
        if (from < 10) {
          // Weight + mood trackers.
          await m.createTable(weightReadings);
          await m.createTable(moodEntries);
          debugPrint('✓ Created weight + mood tables');
        }
        if (from < 11) {
          // Administration-route field on medicines.
          await m.addColumn(enhancedMedicines, enhancedMedicines.routeIndex);
          // Diary / journal entries.
          await m.createTable(diaryEntries);
          // Pre-logged (travel/pillbox) dose status.
          await m.addColumn(medicineLogs, medicineLogs.isPreLogged);
          debugPrint('✓ Added route field, diary table, and pre-logged dose status');
        }
        if (from < 12) {
          // The schema had NO indexes at all — every table declared only a
          // primary key. MedicineLogs is queried by medicineId and by
          // scheduledTime constantly (adherence, streaks, per-medicine history,
          // exports) and grows forever with no pruning, so those were full
          // scans that degrade linearly with use. Same for the vitals tables,
          // which are always ordered by takenAt, and enhancedWaterLogs, which
          // is looked up per day by dailyDataId.
          //
          // Drift emits the CREATE INDEX statements from the @TableIndex
          // annotations; createAll() is safe on an existing DB because every
          // generated statement is IF NOT EXISTS.
          await m.createAll();
          debugPrint('✓ Created query indexes (v12)');
        }
        if (from < 13) {
          // Universal sync fields on the four vitals tables. They shipped with
          // only `synced` (mood not even that) — no `updatedAt`, no
          // `deletedAt` — which is exactly why they are absent from
          // HealthCloudSyncService and why docs/bug-hunt.md lists this as
          // Outstanding.
          //
          // `addColumn` cannot add `updatedAt`: SQLite rejects
          // ADD COLUMN NOT NULL without a CONSTANT default, and
          // CURRENT_TIMESTAMP is explicitly disallowed. `alterTable` recreates
          // the table from the current Dart schema and copies the rows across.
          //
          // EVERY newly added column must be listed in `newColumns`, not just
          // the non-defaulted one. Drift copies unlisted columns by name from
          // the old table; a column that does not exist there yet comes across
          // as NULL and trips the generated CHECK (`synced IN (0, 1)`) — which
          // is exactly what mood_entries did, since it shipped without even a
          // `synced` column.
          //
          // `columnTransformer` then back-fills `updatedAt` from `createdAt`.
          // That is the truthful value — nothing has been edited since it was
          // written — and it matters: stamping DateTime.now() would tell the
          // LWW reconciler that every historical reading changed at migration
          // time.
          await m.alterTable(TableMigration(
            bloodPressureReadings,
            newColumns: [
              bloodPressureReadings.updatedAt,
              bloodPressureReadings.deletedAt,
              bloodPressureReadings.schemaVer,
              bloodPressureReadings.dataJson,
            ],
            columnTransformer: {
              bloodPressureReadings.updatedAt: bloodPressureReadings.createdAt,
            },
          ));
          await m.alterTable(TableMigration(
            glucoseReadings,
            newColumns: [
              glucoseReadings.updatedAt,
              glucoseReadings.deletedAt,
              glucoseReadings.schemaVer,
              glucoseReadings.dataJson,
            ],
            columnTransformer: {
              glucoseReadings.updatedAt: glucoseReadings.createdAt,
            },
          ));
          await m.alterTable(TableMigration(
            weightReadings,
            newColumns: [
              weightReadings.updatedAt,
              weightReadings.deletedAt,
              weightReadings.schemaVer,
              weightReadings.dataJson,
            ],
            columnTransformer: {
              weightReadings.updatedAt: weightReadings.createdAt,
            },
          ));
          await m.alterTable(TableMigration(
            moodEntries,
            newColumns: [
              moodEntries.updatedAt,
              moodEntries.deletedAt,
              moodEntries.schemaVer,
              moodEntries.dataJson,
              moodEntries.synced, // mood never had this column at all
            ],
            columnTransformer: {moodEntries.updatedAt: moodEntries.createdAt},
          ));
          // Recreating a table drops its indexes. Same trick v12 used: Drift
          // emits every @TableIndex as CREATE INDEX IF NOT EXISTS, so
          // createAll() is safe on an existing DB and restores
          // idx_bp_taken_at / idx_glucose_taken_at / idx_weight_taken_at /
          // idx_mood_taken_at.
          await m.createAll();
          debugPrint('✓ Retrofitted sync fields onto vitals tables (v13)');
        }
        if (from < 14) {
          // Wearable biometrics: one aggregated row per day, event-keyed
          // workouts, and the registry of apps/devices behind the
          // Connected-devices screen. Pure additions — nothing existing is
          // touched, so no table rebuild here.
          await m.createTable(biometricDailyData);
          await m.createTable(workoutSessions);
          await m.createTable(healthSources);
          debugPrint('✓ Created biometrics + workout + source tables (v14)');
        }
        if (from < 15) {
          // Focus sessions get a real table. `createTable` ONLY — deliberately
          // the whole of this step.
          //
          // The rows themselves are moved across in Dart, from
          // `FocusService.init()`, and not here. Reading `AppPreferences` from
          // inside a MigrationStrategy would mean touching CleanStorageService
          // before its cache is loaded, and a failure at this point has no UI to
          // report itself — which is exactly the lesson the v13 `alterTable`
          // step recorded the hard way. `createTable`-only is also the shape v4,
          // v5, v10 and v14 all used without incident.
          await m.createTable(focusSessions);
          debugPrint('✓ Created focus session table (v15)');
        }
        if (from < 16) {
          // Reminders get a stored, reserved notification id instead of one
          // derived from `id.hashCode` at each call site — which was unreserved
          // and could collide with the fixed blocks other features own.
          //
          // `addColumn` only, nullable, no backfill: filling it needs the
          // allocator (which reads the table) and would mean doing Dart work
          // inside a MigrationStrategy, the trap the v13 `alterTable` step
          // recorded the hard way. Existing rows fall back to the legacy
          // derivation until their next save, so their already-armed alarms stay
          // cancellable in the meantime.
          //
          // Guarded, and any future addColumn step must be too: the v12 and v13
          // steps above call `createAll()`, which creates every table at its
          // CURRENT definition. So a database upgrading from below 13 arrives
          // here with `notification_id` already present, and a bare ALTER TABLE
          // fails with "duplicate column name" — taking the whole migration down
          // with it, on exactly the oldest installs.
          final hasColumn = await customSelect("PRAGMA table_info('reminders')")
              .get()
              .then((rows) =>
                  rows.any((r) => r.read<String>('name') == 'notification_id'));
          if (hasColumn) {
            debugPrint(
                '• reminders.notificationId already present (createAll in an '
                'earlier step) — skipping (v16)');
          } else {
            await m.addColumn(reminders, reminders.notificationId);
            debugPrint('✓ Added reminders.notificationId (v16)');
          }
        }
        if (from < 17) {
          // One row per occurrence of a generic reminder. `isCompleted` is a
          // single mutable boolean that roll-forward overwrote, so these
          // reminders destroyed their own history — and adherence, streaks, a
          // digest and adaptive timing all need that history to exist.
          //
          // `createTable` only, the same shape v4, v5, v10, v14 and v15 used
          // without incident. Nothing is backfilled: there is no history to
          // recover, which is the entire point.
          //
          // Unlike v16 this needs no existence guard — `createTable` is a
          // CREATE TABLE IF NOT EXISTS in drift, so the `createAll()` in the
          // v12/v13 steps having already made it is harmless.
          await m.createTable(reminderOccurrences);
          debugPrint('✓ Created reminder occurrences table (v17)');
        }
        if (from < 18) {
          // Richer repeats: an RFC 5545 rule string, an end date, an occurrence
          // limit, and a pause flag. Before this the six-value `repeatType` was
          // the whole vocabulary, a repeating reminder ran forever, and deleting
          // it was the only way to stop it — which also destroyed its history.
          //
          // Guarded for the same reason v16 is: the v12/v13 steps call
          // `createAll()`, so a database upgrading from below 13 already has
          // these columns and a bare ALTER TABLE would fail with "duplicate
          // column name", taking the migration down on the oldest installs.
          final existing = await customSelect("PRAGMA table_info('reminders')")
              .get()
              .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
          for (final column in <String, GeneratedColumn<Object>>{
            'recurrence_rule': reminders.recurrenceRule,
            'ends_at': reminders.endsAt,
            'occurrence_limit': reminders.occurrenceLimit,
            'is_paused': reminders.isPaused,
          }.entries) {
            if (existing.contains(column.key)) continue;
            await m.addColumn(reminders, column.value);
          }
          debugPrint('✓ Added reminders recurrence columns (v18)');
        }
        if (from < 19) {
          // How insistent a reminder is, per reminder. Escalation used to be
          // all-or-nothing and decided by whichever code path happened to
          // schedule it, so a vitamin could ring like a heart medication and a
          // heart medication could arrive as a silent notification.
          //
          // Guarded, same reason as v16 and v18 — `createAll()` in the v12/v13
          // steps means an old database already has the column.
          final cols = await customSelect("PRAGMA table_info('reminders')")
              .get()
              .then((rows) => rows.map((r) => r.read<String>('name')).toSet());
          if (!cols.contains('escalation')) {
            await m.addColumn(reminders, reminders.escalation);
          }
          debugPrint('✓ Added reminders.escalation (v19)');
        }
      },
    );
  }

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase();
    return _instance!;
  }

  /// Test-only: point the singleton at an in-memory database so services that
  /// read `AppDatabase.instance` operate on a hermetic DB.
  @visibleForTesting
  static void setInstanceForTesting(AppDatabase db) {
    _instance = db;
  }

  Future<void> closeDatabase() async {
    await close();
    _instance = null;
  }
}
