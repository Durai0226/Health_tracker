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

import 'daos/core_dao.dart';
import 'daos/medication_dao.dart';
import 'daos/water_dao.dart';
import 'daos/reminders_dao.dart';
import 'daos/vitals_dao.dart';
import 'daos/period_dao.dart';
import 'daos/steps_dao.dart';
import 'daos/sleep_dao.dart';
import 'daos/diary_dao.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Test-only constructor: runs the full schema (incl. the FTS5 migration) on
  /// a caller-supplied executor (e.g. an in-memory database).
  @visibleForTesting
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 13;


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
