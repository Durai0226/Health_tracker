import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cycle_log.dart';
import '../models/symptom_log.dart';
import '../models/period_settings.dart';

/// Period tracking storage service
/// Uses SharedPreferences for local storage with Firestore sync
class PeriodCleanStorageService {
  static const String _cyclesKey = 'period_cycles';
  static const String _symptomsKey = 'period_symptoms';
  static const String _settingsKey = 'period_settings';

  static bool _isInitialized = false;
  static SharedPreferences? _prefs;
  
  // In-memory cache for faster access
  static List<CycleLog> _cyclesCache = [];
  static List<SymptomLog> _symptomsCache = [];
  static PeriodSettings? _settingsCache;

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
    _prefs = await SharedPreferences.getInstance();
    await _loadFromPrefs();
    debugPrint('✓ PeriodCleanStorageService initialized');
    _isInitialized = true;
  }

  static Future<void> _loadFromPrefs() async {
    if (_prefs == null) return;
    
    // Load cycles
    final cyclesJson = _prefs!.getString(_cyclesKey);
    if (cyclesJson != null) {
      try {
        final List<dynamic> cyclesList = jsonDecode(cyclesJson);
        _cyclesCache = cyclesList.map((e) => CycleLog.fromJson(e)).toList();
        _cyclesCache.sort((a, b) => b.startDate.compareTo(a.startDate));
      } catch (e) {
        debugPrint('Error loading cycles: $e');
        _cyclesCache = [];
      }
    }
    
    // Load symptoms
    final symptomsJson = _prefs!.getString(_symptomsKey);
    if (symptomsJson != null) {
      try {
        final List<dynamic> symptomsList = jsonDecode(symptomsJson);
        _symptomsCache = symptomsList.map((e) => SymptomLog.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading symptoms: $e');
        _symptomsCache = [];
      }
    }
    
    // Load settings
    final settingsJson = _prefs!.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        _settingsCache = PeriodSettings.fromJson(jsonDecode(settingsJson));
      } catch (e) {
        debugPrint('Error loading settings: $e');
        _settingsCache = null;
      }
    }
  }

  static Future<void> _saveCycles() async {
    if (_prefs == null) return;
    final json = jsonEncode(_cyclesCache.map((c) => c.toJson()).toList());
    await _prefs!.setString(_cyclesKey, json);
  }

  static Future<void> _saveSymptoms() async {
    if (_prefs == null) return;
    final json = jsonEncode(_symptomsCache.map((s) => s.toJson()).toList());
    await _prefs!.setString(_symptomsKey, json);
  }

  static Future<void> _saveSettings() async {
    if (_prefs == null || _settingsCache == null) return;
    final json = jsonEncode(_settingsCache!.toJson());
    await _prefs!.setString(_settingsKey, json);
  }

  // ============ Cycle Log Methods ============

  static List<CycleLog> getAllCycles() {
    return List.from(_cyclesCache);
  }

  static CycleLog? getCurrentCycle() {
    final cycles = getAllCycles();
    if (cycles.isEmpty) return null;
    return cycles.firstWhere(
      (c) => !c.isComplete,
      orElse: () => cycles.first,
    );
  }

  static Future<void> addCycle(CycleLog cycle) async {
    _cyclesCache.add(cycle);
    _cyclesCache.sort((a, b) => b.startDate.compareTo(a.startDate));
    await _saveCycles();
    await _syncToCloud('period_cycles', cycle.id, cycle.toJson());
  }

  static Future<void> updateCycle(CycleLog cycle) async {
    final index = _cyclesCache.indexWhere((c) => c.id == cycle.id);
    if (index != -1) {
      _cyclesCache[index] = cycle;
      await _saveCycles();
      await _syncToCloud('period_cycles', cycle.id, cycle.toJson());
    }
  }

  static Future<void> deleteCycle(String id) async {
    _cyclesCache.removeWhere((c) => c.id == id);
    await _saveCycles();
    await _deleteFromCloud('period_cycles', id);
  }

  static Future<CycleLog> startNewCycle(DateTime startDate, {int? cycleLength, int? periodDuration}) async {
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
    final updated = current.copyWith(periodDuration: periodDuration);
    await updateCycle(updated);
  }

  // TODO: Replace with Drift stream/listener
  // static ValueListenable<Box<CycleLog>> get cycleLogListenable => ...

  // ============ Symptom Log Methods ============
  // TODO: Replace Hive box with Drift storage
  // static Box<SymptomLog> get _symptomLogBox => ...

  static List<SymptomLog> getAllSymptomLogs() {
    return List.from(_symptomsCache);
  }

  static SymptomLog? getSymptomLogForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    try {
      return _symptomsCache.firstWhere(
        (log) => DateTime(log.date.year, log.date.month, log.date.day) == dateOnly,
      );
    } catch (_) {
      return null;
    }
  }

  static List<SymptomLog> getSymptomLogsForDateRange(DateTime start, DateTime end) {
    return getAllSymptomLogs().where((log) {
      return log.date.isAfter(start.subtract(const Duration(days: 1))) &&
             log.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  static Future<void> saveSymptomLog(SymptomLog log) async {
    final dateOnly = DateTime(log.date.year, log.date.month, log.date.day);
    _symptomsCache.removeWhere(
      (s) => DateTime(s.date.year, s.date.month, s.date.day) == dateOnly,
    );
    _symptomsCache.add(log);
    _symptomsCache.sort((a, b) => b.date.compareTo(a.date));
    await _saveSymptoms();
    await _syncToCloud('period_symptoms', log.id, log.toJson());
  }

  /// Alias for saveSymptomLog for consistency
  static Future<void> addSymptomLog(SymptomLog log) async {
    await saveSymptomLog(log);
  }

  static Future<void> deleteSymptomLog(DateTime date) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final log = _symptomsCache.firstWhere(
      (s) => DateTime(s.date.year, s.date.month, s.date.day) == dateOnly,
      orElse: () => SymptomLog(id: '', date: date, symptoms: [], moods: []),
    );
    if (log.id.isNotEmpty) {
      _symptomsCache.removeWhere((s) => s.id == log.id);
      await _saveSymptoms();
      await _deleteFromCloud('period_symptoms', log.id);
    }
  }

  // TODO: Replace with Drift stream/listener
  // static ValueListenable<Box<SymptomLog>> get symptomLogListenable => ...

  // ============ Settings Methods ============
  // TODO: Replace Hive box with Drift storage
  // static Box<PeriodSettings> get _settingsBox => ...

  static PeriodSettings getSettings() {
    return _settingsCache ?? PeriodSettings();
  }

  static Future<void> saveSettings(PeriodSettings settings) async {
    _settingsCache = settings;
    await _saveSettings();
    await _syncToCloud('period_settings', 'user_settings', settings.toJson());
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
      // Handle both simple symptoms list and symptomEntries
      for (final symptom in log.symptoms) {
        frequency[symptom] = (frequency[symptom] ?? 0) + 1;
      }
      for (final entry in log.symptomEntries) {
        frequency[entry.type] = (frequency[entry.type] ?? 0) + 1;
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
    _cyclesCache.clear();
    _symptomsCache.clear();
    _settingsCache = null;
    
    if (_prefs != null) {
      await _prefs!.remove(_cyclesKey);
      await _prefs!.remove(_symptomsKey);
      await _prefs!.remove(_settingsKey);
    }
    debugPrint('✓ Period tracking data cleared');
  }
}
