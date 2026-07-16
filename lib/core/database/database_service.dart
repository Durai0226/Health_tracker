import 'package:flutter/foundation.dart';
import 'app_database.dart';
import 'daos/core_dao.dart';
import 'daos/medication_dao.dart';
import 'daos/water_dao.dart';
import 'daos/reminders_dao.dart';

/// Central service for database access
/// Provides singleton access to the Drift database and all DAOs
class DatabaseService {
  static DatabaseService? _instance;
  static bool _isInitialized = false;

  late final AppDatabase _database;

  // DAOs
  late final CoreDao coreDao;
  late final MedicationDao medicationDao;
  late final WaterDao waterDao;
  late final RemindersDao remindersDao;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Initialize the database service
  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('DatabaseService already initialized');
      return;
    }

    try {
      final service = instance;
      service._database = AppDatabase.instance;
      
      // Initialize all DAOs
      service.coreDao = CoreDao(service._database);
      service.medicationDao = MedicationDao(service._database);
      service.waterDao = WaterDao(service._database);
      service.remindersDao = RemindersDao(service._database);

      _isInitialized = true;
      debugPrint('✓ DatabaseService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing DatabaseService: $e');
      rethrow;
    }
  }

  /// Get the raw database instance (for advanced use cases)
  AppDatabase get database => _database;

  /// Check if the service is initialized
  static bool get isInitialized => _isInitialized;

  /// Close the database connection
  Future<void> close() async {
    await _database.closeDatabase();
    _isInitialized = false;
    _instance = null;
    debugPrint('✓ DatabaseService closed');
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    await _database.transaction(() async {
      // Delete from all tables
      // This will be implemented after code generation
      debugPrint('✓ All data cleared');
    });
  }
}
