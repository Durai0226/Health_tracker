import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'connection/connection.dart';

import 'tables/core_tables.dart';
import 'tables/medication_tables.dart';
import 'tables/water_tables.dart';
import 'tables/reminders_tables.dart';

import 'daos/core_dao.dart';
import 'daos/medication_dao.dart';
import 'daos/water_dao.dart';
import 'daos/reminders_dao.dart';

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
  ],
  daos: [
    CoreDao,
    MedicationDao,
    WaterDao,
    RemindersDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

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
      },
    );
  }

  static AppDatabase? _instance;
  
  static AppDatabase get instance {
    _instance ??= AppDatabase();
    return _instance!;
  }

  Future<void> closeDatabase() async {
    await close();
    _instance = null;
  }
}
