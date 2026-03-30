import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'connection/connection.dart';

import 'tables/core_tables.dart';
import 'tables/medication_tables.dart';
import 'tables/water_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/notes_tables.dart';
import 'tables/reminders_tables.dart';
import 'tables/fitness_tables.dart';
import 'tables/period_tables.dart';
import 'tables/js_learning_tables.dart';

import 'daos/core_dao.dart';
import 'daos/medication_dao.dart';
import 'daos/water_dao.dart';
import 'daos/finance_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/reminders_dao.dart';
import 'daos/fitness_dao.dart';
import 'daos/period_dao.dart';
import 'daos/js_learning_dao.dart';

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
    
    // Finance tables
    Bills,
    BillPayments,
    BillCategories,
    BillTemplates,
    BillActivities,
    CategoryKeywordMaps,
    BillSettingsTable,
    FinanceSettings,
    
    // Notes tables
    Notes,
    Folders,
    Tags,
    
    // Reminders tables
    Reminders,
    ReminderCategories,
    
    // Fitness tables
    FitnessReminders,
    FitnessActivities,
    
    // Period tracking tables
    PeriodData,
    PeriodRemindersTable,
    SymptomLogs,
    CycleLogs,
    
    // JS Learning tables
    JsLevels,
    JsTopics,
    JsLessons,
    JsQuizzes,
    JsChallenges,
    JsTopicProgress,
    JsUserStats,
    JsDailyActivity,
    JsQuizAttempts,
    JsBookmarks,
    JsLessonNotes,
  ],
  daos: [
    CoreDao,
    MedicationDao,
    WaterDao,
    FinanceDao,
    NotesDao,
    RemindersDao,
    FitnessDao,
    PeriodDao,
    JsLearningDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        debugPrint('✓ Drift database created');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        debugPrint('Drift database upgrading from $from to $to');
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
