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
import 'tables/knowledge_tables.dart';
import 'tables/memory_tables.dart';

import 'daos/core_dao.dart';
import 'daos/medication_dao.dart';
import 'daos/water_dao.dart';
import 'daos/reminders_dao.dart';
import 'daos/vitals_dao.dart';
import 'daos/period_dao.dart';
import 'daos/steps_dao.dart';
import 'daos/sleep_dao.dart';
import 'daos/ai_dao.dart';

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

    // Vitals tables (blood pressure + blood glucose)
    BloodPressureReadings,
    GlucoseReadings,

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

    // AI: RAG knowledge base + user-curated memory
    KnowledgeChunks,
    AssistantMemories,
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
    AiDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// Test-only constructor: runs the full schema (incl. the FTS5 migration) on
  /// a caller-supplied executor (e.g. an in-memory database).
  @visibleForTesting
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 7;

  /// Creates the FTS5 virtual table backing the RAG knowledge base. Called from
  /// both onCreate (fresh installs) and onUpgrade — Drift's DSL can't declare
  /// FTS5, so it's raw SQL. sqlite3 ships FTS5 + bm25(). The `porter` tokenizer
  /// stems words so "sleeping"/"slept"/"hydrate"/"hydration" all retrieve their
  /// base-form chunks (v7).
  Future<void> _createKnowledgeFts() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5('
      "chunk_id UNINDEXED, title, body, topic, tokenize = 'porter unicode61')",
    );
  }

  /// Rebuilds the FTS index with the current tokenizer from the persisted
  /// `knowledge_chunks` rows (used when the tokenizer changes across versions).
  Future<void> _rebuildKnowledgeFts() async {
    await customStatement('DROP TABLE IF EXISTS knowledge_fts');
    await _createKnowledgeFts();
    await customStatement(
      'INSERT INTO knowledge_fts(chunk_id, title, body, topic) '
      'SELECT id, title, body, topic FROM knowledge_chunks',
    );
  }

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
        await _createKnowledgeFts();
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
        if (from < 6) {
          // AI: RAG knowledge base (+ FTS5) + user-curated memory.
          await m.createTable(knowledgeChunks);
          await m.createTable(assistantMemories);
          await _createKnowledgeFts();
          debugPrint('✓ Created AI knowledge + memory tables');
        }
        if (from < 7) {
          // Upgrade the KB search index to the stemming (porter) tokenizer,
          // rebuilding it from the persisted chunks (no re-seed needed).
          await _rebuildKnowledgeFts();
          debugPrint('✓ Rebuilt knowledge FTS with porter stemming');
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
