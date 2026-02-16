import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/cycle_log.dart';
import '../models/symptom_log.dart';
import '../models/period_settings.dart';
import '../../../core/utils/secure_storage_helper.dart';

class PeriodStorageService {
  static const String _cycleLogBoxName = 'cycle_logs';
  static const String _symptomLogBoxName = 'symptom_logs';
  static const String _periodSettingsBoxName = 'period_settings';

  static bool _isInitialized = false;

  static String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  static Future<void> _syncToCloud(String collection, String docId, Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .set(data);
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
    }
  }

  static Future<void> _deleteFromCloud(String collection, String docId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting from cloud: $e');
    }
  }

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Register adapters
      _safeRegisterAdapter(FlowIntensityAdapter());
      _safeRegisterAdapter(CyclePhaseAdapter());
      _safeRegisterAdapter(CycleLogAdapter());
      _safeRegisterAdapter(DailyLogAdapter());
      _safeRegisterAdapter(SymptomTypeAdapter());
      _safeRegisterAdapter(SymptomSeverityAdapter());
      _safeRegisterAdapter(MoodTypeAdapter());
      _safeRegisterAdapter(EnergyLevelAdapter());
      _safeRegisterAdapter(SleepQualityAdapter());
      _safeRegisterAdapter(SymptomLogAdapter());
      _safeRegisterAdapter(SymptomEntryAdapter());
      _safeRegisterAdapter(PeriodSettingsAdapter());

      // Open boxes
      await _safeOpenBox<CycleLog>(_cycleLogBoxName);
      await _safeOpenBox<SymptomLog>(_symptomLogBoxName);
      await _safeOpenBox<PeriodSettings>(_periodSettingsBoxName);

      _isInitialized = true;
      debugPrint('PeriodStorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing PeriodStorageService: $e');
    }
  }

  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
    try {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter(adapter);
      }
    } catch (e) {
      debugPrint('Error registering adapter ${adapter.runtimeType}: $e');
    }
  }

  static Future<Box<T>> _safeOpenBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<T>(boxName);
      }
      final encryptionKey = await SecureStorageHelper.getEncryptionKey();
      return await Hive.openBox<T>(
        boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      debugPrint('Error opening box $boxName: $e');
      try {
        await Hive.deleteBoxFromDisk(boxName);
        final encryptionKey = await SecureStorageHelper.getEncryptionKey();
        return await Hive.openBox<T>(
          boxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        );
      } catch (deleteError) {
        debugPrint('Error recovering box $boxName: $deleteError');
        rethrow;
      }
    }
  }

  // ============ Cycle Log Methods ============
  static Box<CycleLog> get _cycleLogBox => Hive.box<CycleLog>(_cycleLogBoxName);

  static List<CycleLog> getAllCycles() {
    try {
      final cycles = _cycleLogBox.values.toList();
      cycles.sort((a, b) => b.startDate.compareTo(a.startDate));
      return cycles;
    } catch (e) {
      debugPrint('Error getting cycles: $e');
      return [];
    }
  }

  static CycleLog? getCurrentCycle() {
    try {
      final cycles = getAllCycles();
      if (cycles.isEmpty) return null;
      return cycles.firstWhere(
        (c) => !c.isComplete,
        orElse: () => cycles.first,
      );
    } catch (e) {
      debugPrint('Error getting current cycle: $e');
      return null;
    }
  }

  static Future<void> addCycle(CycleLog cycle) async {
    try {
      await _cycleLogBox.put(cycle.id, cycle);
      await _syncToCloud('cycle_logs', cycle.id, cycle.toJson());
    } catch (e) {
      debugPrint('Error adding cycle: $e');
    }
  }

  static Future<void> updateCycle(CycleLog cycle) async {
    try {
      await _cycleLogBox.put(cycle.id, cycle);
      await _syncToCloud('cycle_logs', cycle.id, cycle.toJson());
    } catch (e) {
      debugPrint('Error updating cycle: $e');
    }
  }

  static Future<void> deleteCycle(String id) async {
    try {
      await _cycleLogBox.delete(id);
      await _deleteFromCloud('cycle_logs', id);
    } catch (e) {
      debugPrint('Error deleting cycle: $e');
    }
  }

  static Future<CycleLog> startNewCycle(DateTime startDate, {int? cycleLength, int? periodDuration}) async {
    // Complete any existing open cycles
    final openCycles = getAllCycles().where((c) => !c.isComplete).toList();
    for (final cycle in openCycles) {
      final completedCycle = cycle.copyWith(
        isComplete: true,
        endDate: startDate.subtract(const Duration(days: 1)),
      );
      await updateCycle(completedCycle);
    }

    // Get settings for defaults
    final settings = getSettings();
    
    final cycle = CycleLog(
      id: 'cycle_${startDate.millisecondsSinceEpoch}',
      startDate: startDate,
      cycleLength: cycleLength ?? settings.defaultCycleLength,
      periodDuration: periodDuration ?? settings.defaultPeriodDuration,
    );
    await addCycle(cycle);
    return cycle;
  }

  static Future<void> endCurrentPeriod(DateTime endDate) async {
    final current = getCurrentCycle();
    if (current == null) return;

    final periodDuration = endDate.difference(current.startDate).inDays + 1;
    final updated = current.copyWith(
      periodDuration: periodDuration,
    );
    await updateCycle(updated);
  }

  static ValueListenable<Box<CycleLog>> get cycleLogListenable => _cycleLogBox.listenable();

  // ============ Symptom Log Methods ============
  static Box<SymptomLog> get _symptomLogBox => Hive.box<SymptomLog>(_symptomLogBoxName);

  static List<SymptomLog> getAllSymptomLogs() {
    try {
      final logs = _symptomLogBox.values.toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      return logs;
    } catch (e) {
      debugPrint('Error getting symptom logs: $e');
      return [];
    }
  }

  static SymptomLog? getSymptomLogForDate(DateTime date) {
    try {
      final key = '${date.year}-${date.month}-${date.day}';
      return _symptomLogBox.get(key);
    } catch (e) {
      debugPrint('Error getting symptom log for date: $e');
      return null;
    }
  }

  static List<SymptomLog> getSymptomLogsForDateRange(DateTime start, DateTime end) {
    try {
      return _symptomLogBox.values.where((log) {
        return log.date.isAfter(start.subtract(const Duration(days: 1))) &&
               log.date.isBefore(end.add(const Duration(days: 1)));
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('Error getting symptom logs for range: $e');
      return [];
    }
  }

  static Future<void> saveSymptomLog(SymptomLog log) async {
    try {
      final key = '${log.date.year}-${log.date.month}-${log.date.day}';
      await _symptomLogBox.put(key, log);
      await _syncToCloud('symptom_logs', key, log.toJson());
    } catch (e) {
      debugPrint('Error saving symptom log: $e');
    }
  }

  static Future<void> deleteSymptomLog(DateTime date) async {
    try {
      final key = '${date.year}-${date.month}-${date.day}';
      await _symptomLogBox.delete(key);
      await _deleteFromCloud('symptom_logs', key);
    } catch (e) {
      debugPrint('Error deleting symptom log: $e');
    }
  }

  static ValueListenable<Box<SymptomLog>> get symptomLogListenable => _symptomLogBox.listenable();

  // ============ Settings Methods ============
  static Box<PeriodSettings> get _settingsBox => Hive.box<PeriodSettings>(_periodSettingsBoxName);

  static PeriodSettings getSettings() {
    try {
      return _settingsBox.get('settings') ?? PeriodSettings();
    } catch (e) {
      debugPrint('Error getting period settings: $e');
      return PeriodSettings();
    }
  }

  static Future<void> saveSettings(PeriodSettings settings) async {
    try {
      await _settingsBox.put('settings', settings);
      await _syncToCloud('period_settings', 'settings', settings.toJson());
    } catch (e) {
      debugPrint('Error saving period settings: $e');
    }
  }

  // ============ Statistics Methods ============
  static Map<String, dynamic> getCycleStatistics() {
    final cycles = getAllCycles().where((c) => c.isComplete).toList();
    
    if (cycles.isEmpty) {
      return {
        'totalCycles': 0,
        'averageCycleLength': 28,
        'averagePeriodDuration': 5,
        'shortestCycle': 0,
        'longestCycle': 0,
        'cycleVariation': 0,
      };
    }

    final lengths = cycles.map((c) => c.actualCycleLength).toList();
    final durations = cycles.map((c) => c.periodDuration).toList();

    return {
      'totalCycles': cycles.length,
      'averageCycleLength': (lengths.reduce((a, b) => a + b) / lengths.length).round(),
      'averagePeriodDuration': (durations.reduce((a, b) => a + b) / durations.length).round(),
      'shortestCycle': lengths.reduce((a, b) => a < b ? a : b),
      'longestCycle': lengths.reduce((a, b) => a > b ? a : b),
      'cycleVariation': lengths.reduce((a, b) => a > b ? a : b) - lengths.reduce((a, b) => a < b ? a : b),
    };
  }

  static Map<SymptomType, int> getSymptomFrequency({int? lastNCycles}) {
    final logs = getAllSymptomLogs();
    final Map<SymptomType, int> frequency = {};

    for (final log in logs) {
      for (final symptom in log.symptoms) {
        frequency[symptom.type] = (frequency[symptom.type] ?? 0) + 1;
      }
    }

    return frequency;
  }

  static Map<MoodType, int> getMoodFrequency({int? lastNCycles}) {
    final logs = getAllSymptomLogs();
    final Map<MoodType, int> frequency = {};

    for (final log in logs) {
      for (final mood in log.moods) {
        frequency[mood] = (frequency[mood] ?? 0) + 1;
      }
    }

    return frequency;
  }

  // ============ Export & Import ============
  static Map<String, dynamic> exportData() {
    return {
      'cycles': getAllCycles().map((c) => c.toJson()).toList(),
      'symptomLogs': getAllSymptomLogs().map((l) => l.toJson()).toList(),
      'settings': getSettings().toJson(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    try {
      if (data['cycles'] != null) {
        for (final json in data['cycles'] as List) {
          await addCycle(CycleLog.fromJson(json));
        }
      }
      if (data['symptomLogs'] != null) {
        for (final json in data['symptomLogs'] as List) {
          await saveSymptomLog(SymptomLog.fromJson(json));
        }
      }
      if (data['settings'] != null) {
        await saveSettings(PeriodSettings.fromJson(data['settings']));
      }
    } catch (e) {
      debugPrint('Error importing data: $e');
    }
  }

  static Future<void> clearAllData() async {
    try {
      await _cycleLogBox.clear();
      await _symptomLogBox.clear();
      // Keep settings
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }
}
