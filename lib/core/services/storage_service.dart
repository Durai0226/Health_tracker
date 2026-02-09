
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/medication/models/medicine.dart';
import '../../features/period_tracking/models/period_data.dart';
import '../../features/health_check/models/health_check.dart';
import '../../features/water/models/water_intake.dart';
import '../../features/fitness/models/fitness_reminder.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const String _medicineBoxName = 'medicines';
  static const String _periodBoxName = 'period';
  static const String _healthCheckBoxName = 'health_checks';
  static const String _waterBoxName = 'water_intake';
  static const String _fitnessBoxName = 'fitness_reminders';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MedicineAdapter());
    Hive.registerAdapter(PeriodDataAdapter());
    Hive.registerAdapter(HealthCheckAdapter());
    Hive.registerAdapter(WaterIntakeAdapter());
    Hive.registerAdapter(WaterLogAdapter());
    Hive.registerAdapter(FitnessReminderAdapter());
    await Hive.openBox<Medicine>(_medicineBoxName);
    await Hive.openBox<PeriodData>(_periodBoxName);
    await Hive.openBox<HealthCheck>(_healthCheckBoxName);
    await Hive.openBox<WaterIntake>(_waterBoxName);
    await Hive.openBox<FitnessReminder>(_fitnessBoxName);
  }

  // Medicine Methods
  static Box<Medicine> get _medicineBox => Hive.box<Medicine>(_medicineBoxName);

  static List<Medicine> getAllMedicines() {
    return _medicineBox.values.toList();
  }

  static Future<void> addMedicine(Medicine medicine) async {
    await _medicineBox.put(medicine.id, medicine);
  }

  static Future<void> deleteMedicine(String id) async {
    await _medicineBox.delete(id);
  }

  static Future<void> updateMedicine(Medicine medicine) async {
    await _medicineBox.put(medicine.id, medicine);
  }

  static ValueListenable<Box<Medicine>> get listenable => _medicineBox.listenable();

  // Period Methods
  static Box<PeriodData> get _periodBox => Hive.box<PeriodData>(_periodBoxName);

  static Future<void> savePeriodData(PeriodData data) async {
    await _periodBox.put('current', data);
  }

  static PeriodData? getPeriodData() {
    return _periodBox.get('current');
  }

  static Future<void> clearPeriodData() async {
    await _periodBox.delete('current');
  }

  static bool get isPeriodTrackingEnabled => _periodBox.containsKey('current');

  // Health Check Methods
  static Box<HealthCheck> get _healthCheckBox => Hive.box<HealthCheck>(_healthCheckBoxName);

  static List<HealthCheck> getAllHealthChecks() {
    return _healthCheckBox.values.toList();
  }

  static Future<void> addHealthCheck(HealthCheck check) async {
    await _healthCheckBox.put(check.id, check);
  }

  static Future<void> deleteHealthCheck(String id) async {
    await _healthCheckBox.delete(id);
  }

  static Future<void> updateHealthCheck(HealthCheck check) async {
    await _healthCheckBox.put(check.id, check);
  }

  static ValueListenable<Box<HealthCheck>> get healthCheckListenable => _healthCheckBox.listenable();

  // Water Intake Methods
  static Box<WaterIntake> get _waterBox => Hive.box<WaterIntake>(_waterBoxName);

  static WaterIntake? getTodayWaterIntake() {
    final today = DateTime.now();
    final key = '${today.year}-${today.month}-${today.day}';
    return _waterBox.get(key);
  }

  static Future<void> saveWaterIntake(WaterIntake water) async {
    final key = '${water.date.year}-${water.date.month}-${water.date.day}';
    await _waterBox.put(key, water);
  }

  static Future<void> addWaterLog(int amountMl) async {
    final today = DateTime.now();
    final key = '${today.year}-${today.month}-${today.day}';
    var water = _waterBox.get(key);
    
    if (water == null) {
      water = WaterIntake(
        id: key,
        date: today,
        currentIntakeMl: amountMl,
        logs: [WaterLog(time: today, amountMl: amountMl)],
      );
    } else {
      final newLogs = [...water.logs, WaterLog(time: today, amountMl: amountMl)];
      water = water.copyWith(
        currentIntakeMl: water.currentIntakeMl + amountMl,
        logs: newLogs,
      );
    }
    await _waterBox.put(key, water);
  }

  static ValueListenable<Box<WaterIntake>> get waterListenable => _waterBox.listenable();

  // Fitness Reminder Methods
  static Box<FitnessReminder> get _fitnessBox => Hive.box<FitnessReminder>(_fitnessBoxName);

  static List<FitnessReminder> getAllFitnessReminders() {
    return _fitnessBox.values.toList();
  }

  static Future<void> addFitnessReminder(FitnessReminder reminder) async {
    await _fitnessBox.put(reminder.id, reminder);
  }

  static Future<void> deleteFitnessReminder(String id) async {
    await _fitnessBox.delete(id);
  }

  static Future<void> updateFitnessReminder(FitnessReminder reminder) async {
    await _fitnessBox.put(reminder.id, reminder);
  }

  static ValueListenable<Box<FitnessReminder>> get fitnessListenable => _fitnessBox.listenable();
}
