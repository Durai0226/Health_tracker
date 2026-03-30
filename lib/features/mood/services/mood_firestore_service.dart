import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/mood_entry.dart';
import '../models/mood_type.dart';
import '../models/mood_streak.dart';
import '../models/mood_insight.dart';

/// Firestore service for mood tracking data
/// Schema:
/// users/{userId}/mood_entries/{entryId}
/// users/{userId}/mood_settings (document)
/// users/{userId}/mood_streak (document)
class MoodFirestoreService {
  static final MoodFirestoreService _instance = MoodFirestoreService._internal();
  factory MoodFirestoreService() => _instance;
  MoodFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local cache keys
  static const String _entriesCacheKey = 'mood_entries_cache';
  static const String _streakCacheKey = 'mood_streak_cache';
  static const String _settingsCacheKey = 'mood_settings_cache';
  static const String _lastSyncKey = 'mood_last_sync';

  String? get _userId => _auth.currentUser?.uid;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _entriesCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('mood_entries');
  }

  DocumentReference<Map<String, dynamic>> get _streakDoc {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('mood_data').doc('streak');
  }

  DocumentReference<Map<String, dynamic>> get _settingsDoc {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('mood_data').doc('settings');
  }

  // ============================================
  // MOOD ENTRIES - CRUD Operations
  // ============================================

  /// Add a new mood entry
  Future<MoodEntry> addEntry(MoodEntry entry) async {
    try {
      final entryWithUser = entry.copyWith(userId: _userId);
      
      // Save to Firestore
      if (_userId != null) {
        final docRef = await _entriesCollection.add(entryWithUser.toFirestore());
        final savedEntry = entryWithUser.copyWith(id: docRef.id);
        
        // Update streak
        await _updateStreak();
        
        // Cache locally
        await _cacheEntry(savedEntry);
        
        debugPrint('✓ Mood entry saved to Firestore: ${docRef.id}');
        return savedEntry;
      } else {
        // Save locally only
        await _cacheEntry(entryWithUser);
        debugPrint('✓ Mood entry saved locally (offline)');
        return entryWithUser;
      }
    } catch (e) {
      debugPrint('❌ Error adding mood entry: $e');
      // Fallback to local storage
      await _cacheEntry(entry);
      return entry;
    }
  }

  /// Update an existing mood entry
  Future<void> updateEntry(MoodEntry entry) async {
    try {
      if (_userId != null) {
        await _entriesCollection.doc(entry.id).update(entry.toFirestore());
        debugPrint('✓ Mood entry updated: ${entry.id}');
      }
      await _cacheEntry(entry);
    } catch (e) {
      debugPrint('❌ Error updating mood entry: $e');
      await _cacheEntry(entry);
    }
  }

  /// Delete a mood entry
  Future<void> deleteEntry(String entryId) async {
    try {
      if (_userId != null) {
        await _entriesCollection.doc(entryId).delete();
        debugPrint('✓ Mood entry deleted: $entryId');
      }
      await _removeCachedEntry(entryId);
    } catch (e) {
      debugPrint('❌ Error deleting mood entry: $e');
      await _removeCachedEntry(entryId);
    }
  }

  /// Get all mood entries
  Future<List<MoodEntry>> getAllEntries() async {
    try {
      if (_userId != null) {
        final snapshot = await _entriesCollection
            .orderBy('timestamp', descending: true)
            .get();
        
        final entries = snapshot.docs
            .map((doc) => MoodEntry.fromFirestore(doc))
            .toList();
        
        // Cache for offline use
        await _cacheEntries(entries);
        
        return entries;
      }
      return _getCachedEntries();
    } catch (e) {
      debugPrint('❌ Error getting entries, using cache: $e');
      return _getCachedEntries();
    }
  }

  /// Get entries for a specific date range
  Future<List<MoodEntry>> getEntriesInRange(DateTime start, DateTime end) async {
    try {
      if (_userId != null) {
        final snapshot = await _entriesCollection
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .orderBy('timestamp', descending: true)
            .get();
        
        return snapshot.docs
            .map((doc) => MoodEntry.fromFirestore(doc))
            .toList();
      }
      
      // Filter cached entries
      final allEntries = await _getCachedEntries();
      return allEntries.where((e) => 
        e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
      ).toList();
    } catch (e) {
      debugPrint('❌ Error getting entries in range: $e');
      final allEntries = await _getCachedEntries();
      return allEntries.where((e) => 
        e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
      ).toList();
    }
  }

  /// Get entries for today
  Future<List<MoodEntry>> getTodayEntries() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getEntriesInRange(startOfDay, endOfDay);
  }

  /// Get entries for this week
  Future<List<MoodEntry>> getWeekEntries() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return getEntriesInRange(start, now);
  }

  /// Get entries for this month
  Future<List<MoodEntry>> getMonthEntries() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return getEntriesInRange(start, now);
  }

  /// Get entries for a specific month
  Future<List<MoodEntry>> getEntriesForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return getEntriesInRange(start, end);
  }

  // ============================================
  // STREAK Management
  // ============================================

  /// Get current streak data
  Future<MoodStreak> getStreak() async {
    try {
      if (_userId != null) {
        final doc = await _streakDoc.get();
        if (doc.exists) {
          final streak = MoodStreak.fromJson(doc.data()!);
          await _cacheStreak(streak);
          return streak;
        }
      }
      return _getCachedStreak();
    } catch (e) {
      debugPrint('❌ Error getting streak: $e');
      return _getCachedStreak();
    }
  }

  /// Update streak after new entry
  Future<void> _updateStreak() async {
    try {
      final currentStreak = await getStreak();
      final updatedStreak = currentStreak.recordEntry();
      
      if (_userId != null) {
        await _streakDoc.set(updatedStreak.toJson());
      }
      await _cacheStreak(updatedStreak);
      
      debugPrint('✓ Streak updated: ${updatedStreak.currentStreak} days');
    } catch (e) {
      debugPrint('❌ Error updating streak: $e');
    }
  }

  // ============================================
  // INSIGHTS & ANALYTICS
  // ============================================

  /// Get weekly insights
  Future<MoodInsight> getWeeklyInsight() async {
    final entries = await getWeekEntries();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return MoodInsight.fromEntries(
      entries,
      startDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      endDate: now,
    );
  }

  /// Get monthly insights
  Future<MoodInsight> getMonthlyInsight() async {
    final entries = await getMonthEntries();
    final now = DateTime.now();
    return MoodInsight.fromEntries(
      entries,
      startDate: DateTime(now.year, now.month, 1),
      endDate: now,
    );
  }

  /// Get insights for custom date range
  Future<MoodInsight> getInsightForRange(DateTime start, DateTime end) async {
    final entries = await getEntriesInRange(start, end);
    return MoodInsight.fromEntries(entries, startDate: start, endDate: end);
  }

  /// Get daily mood summaries for calendar
  Future<Map<String, DailyMoodSummary>> getDailySummaries(int year, int month) async {
    final entries = await getEntriesForMonth(year, month);
    final summaries = <String, DailyMoodSummary>{};
    
    // Group by date
    final groupedEntries = <String, List<MoodEntry>>{};
    for (final entry in entries) {
      groupedEntries[entry.dateKey] ??= [];
      groupedEntries[entry.dateKey]!.add(entry);
    }
    
    // Create summaries
    groupedEntries.forEach((dateKey, dayEntries) {
      final date = DateTime.parse(dateKey);
      summaries[dateKey] = DailyMoodSummary.fromEntries(date, dayEntries);
    });
    
    return summaries;
  }

  /// Get dominant mood (for adaptive theme)
  Future<MoodType?> getDominantMood({int days = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final entries = await getEntriesInRange(start, now);
    
    if (entries.isEmpty) return null;
    
    final moodCounts = <MoodType, int>{};
    for (final entry in entries) {
      moodCounts[entry.mood] = (moodCounts[entry.mood] ?? 0) + 1;
    }
    
    MoodType? dominant;
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        dominant = mood;
      }
    });
    
    return dominant;
  }

  // ============================================
  // SETTINGS
  // ============================================

  /// Get mood settings
  Future<MoodSettings> getSettings() async {
    try {
      if (_userId != null) {
        final doc = await _settingsDoc.get();
        if (doc.exists) {
          final settings = MoodSettings.fromJson(doc.data()!);
          await _cacheSettings(settings);
          return settings;
        }
      }
      return _getCachedSettings();
    } catch (e) {
      debugPrint('❌ Error getting settings: $e');
      return _getCachedSettings();
    }
  }

  /// Save mood settings
  Future<void> saveSettings(MoodSettings settings) async {
    try {
      if (_userId != null) {
        await _settingsDoc.set(settings.toJson());
      }
      await _cacheSettings(settings);
      debugPrint('✓ Mood settings saved');
    } catch (e) {
      debugPrint('❌ Error saving settings: $e');
      await _cacheSettings(settings);
    }
  }

  // ============================================
  // LOCAL CACHE Methods
  // ============================================

  Future<void> _cacheEntry(MoodEntry entry) async {
    final entries = await _getCachedEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.insert(0, entry);
    }
    await _cacheEntries(entries);
  }

  Future<void> _removeCachedEntry(String entryId) async {
    final entries = await _getCachedEntries();
    entries.removeWhere((e) => e.id == entryId);
    await _cacheEntries(entries);
  }

  Future<void> _cacheEntries(List<MoodEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = entries.map((e) => e.toJson()).toList();
      await prefs.setString(_entriesCacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('❌ Error caching entries: $e');
    }
  }

  Future<List<MoodEntry>> _getCachedEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_entriesCacheKey);
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList
            .map((json) => MoodEntry.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error reading cached entries: $e');
    }
    return [];
  }

  Future<void> _cacheStreak(MoodStreak streak) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_streakCacheKey, jsonEncode(streak.toJson()));
    } catch (e) {
      debugPrint('❌ Error caching streak: $e');
    }
  }

  Future<MoodStreak> _getCachedStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_streakCacheKey);
      if (jsonString != null) {
        return MoodStreak.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('❌ Error reading cached streak: $e');
    }
    return MoodStreak();
  }

  Future<void> _cacheSettings(MoodSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsCacheKey, jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('❌ Error caching settings: $e');
    }
  }

  Future<MoodSettings> _getCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsCacheKey);
      if (jsonString != null) {
        return MoodSettings.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('❌ Error reading cached settings: $e');
    }
    return MoodSettings();
  }

  // ============================================
  // SYNC
  // ============================================

  /// Sync local data with Firestore
  Future<void> syncData() async {
    if (_userId == null) return;
    
    try {
      // Get all local entries
      final localEntries = await _getCachedEntries();
      
      // Get all remote entries
      final remoteEntries = await getAllEntries();
      
      // Merge (simple strategy: remote wins for conflicts)
      final mergedMap = <String, MoodEntry>{};
      
      for (final entry in localEntries) {
        mergedMap[entry.id] = entry;
      }
      
      for (final entry in remoteEntries) {
        // Remote wins if exists
        mergedMap[entry.id] = entry;
      }
      
      final merged = mergedMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      await _cacheEntries(merged);
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
      debugPrint('✓ Mood data synced: ${merged.length} entries');
    } catch (e) {
      debugPrint('❌ Error syncing mood data: $e');
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _userId != null;

  /// Listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

/// Mood notification settings
class MoodSettings {
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final bool morningCheckInEnabled;
  final int morningCheckInHour;
  final bool afternoonCheckInEnabled;
  final int afternoonCheckInHour;
  final bool eveningCheckInEnabled;
  final int eveningCheckInHour;
  final bool streakNotificationsEnabled;
  final bool smartRemindersEnabled;
  final bool moodTrendAlertsEnabled;

  MoodSettings({
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 9,
    this.dailyReminderMinute = 0,
    this.morningCheckInEnabled = false,
    this.morningCheckInHour = 8,
    this.afternoonCheckInEnabled = false,
    this.afternoonCheckInHour = 14,
    this.eveningCheckInEnabled = false,
    this.eveningCheckInHour = 20,
    this.streakNotificationsEnabled = true,
    this.smartRemindersEnabled = true,
    this.moodTrendAlertsEnabled = true,
  });

  MoodSettings copyWith({
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? morningCheckInEnabled,
    int? morningCheckInHour,
    bool? afternoonCheckInEnabled,
    int? afternoonCheckInHour,
    bool? eveningCheckInEnabled,
    int? eveningCheckInHour,
    bool? streakNotificationsEnabled,
    bool? smartRemindersEnabled,
    bool? moodTrendAlertsEnabled,
  }) {
    return MoodSettings(
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      morningCheckInEnabled: morningCheckInEnabled ?? this.morningCheckInEnabled,
      morningCheckInHour: morningCheckInHour ?? this.morningCheckInHour,
      afternoonCheckInEnabled: afternoonCheckInEnabled ?? this.afternoonCheckInEnabled,
      afternoonCheckInHour: afternoonCheckInHour ?? this.afternoonCheckInHour,
      eveningCheckInEnabled: eveningCheckInEnabled ?? this.eveningCheckInEnabled,
      eveningCheckInHour: eveningCheckInHour ?? this.eveningCheckInHour,
      streakNotificationsEnabled: streakNotificationsEnabled ?? this.streakNotificationsEnabled,
      smartRemindersEnabled: smartRemindersEnabled ?? this.smartRemindersEnabled,
      moodTrendAlertsEnabled: moodTrendAlertsEnabled ?? this.moodTrendAlertsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderHour': dailyReminderHour,
      'dailyReminderMinute': dailyReminderMinute,
      'morningCheckInEnabled': morningCheckInEnabled,
      'morningCheckInHour': morningCheckInHour,
      'afternoonCheckInEnabled': afternoonCheckInEnabled,
      'afternoonCheckInHour': afternoonCheckInHour,
      'eveningCheckInEnabled': eveningCheckInEnabled,
      'eveningCheckInHour': eveningCheckInHour,
      'streakNotificationsEnabled': streakNotificationsEnabled,
      'smartRemindersEnabled': smartRemindersEnabled,
      'moodTrendAlertsEnabled': moodTrendAlertsEnabled,
    };
  }

  factory MoodSettings.fromJson(Map<String, dynamic> json) {
    return MoodSettings(
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? true,
      dailyReminderHour: json['dailyReminderHour'] as int? ?? 9,
      dailyReminderMinute: json['dailyReminderMinute'] as int? ?? 0,
      morningCheckInEnabled: json['morningCheckInEnabled'] as bool? ?? false,
      morningCheckInHour: json['morningCheckInHour'] as int? ?? 8,
      afternoonCheckInEnabled: json['afternoonCheckInEnabled'] as bool? ?? false,
      afternoonCheckInHour: json['afternoonCheckInHour'] as int? ?? 14,
      eveningCheckInEnabled: json['eveningCheckInEnabled'] as bool? ?? false,
      eveningCheckInHour: json['eveningCheckInHour'] as int? ?? 20,
      streakNotificationsEnabled: json['streakNotificationsEnabled'] as bool? ?? true,
      smartRemindersEnabled: json['smartRemindersEnabled'] as bool? ?? true,
      moodTrendAlertsEnabled: json['moodTrendAlertsEnabled'] as bool? ?? true,
    );
  }
}
