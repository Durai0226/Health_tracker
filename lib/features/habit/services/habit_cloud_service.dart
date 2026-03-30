import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Cloud sync service for habit data via Firestore
/// Only syncs for authenticated (non-anonymous) users
class HabitCloudService {
  static final HabitCloudService _instance = HabitCloudService._internal();
  factory HabitCloudService() => _instance;
  HabitCloudService._internal();

  FirebaseFirestore? _firestore;
  String? _userId;
  bool _isEnabled = false;

  // Collection references
  CollectionReference<Map<String, dynamic>>? _habitsRef;
  CollectionReference<Map<String, dynamic>>? _logsRef;
  CollectionReference<Map<String, dynamic>>? _challengesRef;
  CollectionReference<Map<String, dynamic>>? _friendsRef;
  CollectionReference<Map<String, dynamic>>? _profileRef;

  /// Initialize cloud sync for a user
  Future<void> init({
    required String oderId,
    required bool isAuthenticated,
  }) async {
    if (!isAuthenticated) {
      _isEnabled = false;
      debugPrint('⚠ HabitCloudService: Disabled for anonymous user');
      return;
    }

    try {
      _firestore = FirebaseFirestore.instance;
      _userId = oderId;
      _isEnabled = true;

      // Set up collection references
      final userDoc = _firestore!.collection('users').doc(oderId);
      _habitsRef = userDoc.collection('habits');
      _logsRef = userDoc.collection('habitLogs');
      _challengesRef = _firestore!.collection('habitChallenges');
      _friendsRef = userDoc.collection('habitFriends');
      _profileRef = _firestore!.collection('habitProfiles');

      debugPrint('✓ HabitCloudService initialized for user: $oderId');
    } catch (e) {
      debugPrint('✗ HabitCloudService init error: $e');
      _isEnabled = false;
    }
  }

  bool get isEnabled => _isEnabled;

  // ==========================================
  // HABITS SYNC
  // ==========================================

  /// Sync habit to cloud
  Future<void> syncHabit(Habit habit) async {
    if (!_isEnabled || _habitsRef == null) return;

    try {
      await _habitsRef!.doc(habit.id).set(habit.toJson());
    } catch (e) {
      debugPrint('Error syncing habit: $e');
    }
  }

  /// Sync all habits to cloud
  Future<void> syncAllHabits(List<Habit> habits) async {
    if (!_isEnabled || _habitsRef == null) return;

    try {
      final batch = _firestore!.batch();
      for (final habit in habits) {
        batch.set(_habitsRef!.doc(habit.id), habit.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error syncing all habits: $e');
    }
  }

  /// Fetch habits from cloud
  Future<List<Habit>> fetchHabits() async {
    if (!_isEnabled || _habitsRef == null) return [];

    try {
      final snapshot = await _habitsRef!.get();
      return snapshot.docs.map((doc) => Habit.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching habits: $e');
      return [];
    }
  }

  /// Delete habit from cloud
  Future<void> deleteHabit(String habitId) async {
    if (!_isEnabled || _habitsRef == null) return;

    try {
      await _habitsRef!.doc(habitId).delete();
    } catch (e) {
      debugPrint('Error deleting habit: $e');
    }
  }

  // ==========================================
  // LOGS SYNC
  // ==========================================

  /// Sync habit log to cloud
  Future<void> syncLog(HabitLog log) async {
    if (!_isEnabled || _logsRef == null) return;

    try {
      await _logsRef!.doc(log.id).set(log.toJson());
    } catch (e) {
      debugPrint('Error syncing log: $e');
    }
  }

  /// Fetch logs for a habit
  Future<List<HabitLog>> fetchLogsForHabit(String habitId) async {
    if (!_isEnabled || _logsRef == null) return [];

    try {
      final snapshot = await _logsRef!
          .where('habitId', isEqualTo: habitId)
          .orderBy('date', descending: true)
          .limit(100)
          .get();
      return snapshot.docs.map((doc) => HabitLog.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      return [];
    }
  }

  /// Fetch logs for date range
  Future<List<HabitLog>> fetchLogsForDateRange(DateTime start, DateTime end) async {
    if (!_isEnabled || _logsRef == null) return [];

    try {
      final snapshot = await _logsRef!
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThanOrEqualTo: end.toIso8601String())
          .get();
      return snapshot.docs.map((doc) => HabitLog.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching logs for date range: $e');
      return [];
    }
  }

  // ==========================================
  // CHALLENGES SYNC
  // ==========================================

  /// Sync challenge to cloud
  Future<void> syncChallenge(HabitChallenge challenge) async {
    if (!_isEnabled || _challengesRef == null) return;

    try {
      await _challengesRef!.doc(challenge.id).set(challenge.toJson());
    } catch (e) {
      debugPrint('Error syncing challenge: $e');
    }
  }

  /// Fetch challenges for user
  Future<List<HabitChallenge>> fetchChallenges() async {
    if (!_isEnabled || _challengesRef == null || _userId == null) return [];

    try {
      // Fetch challenges where user is a participant
      final snapshot = await _challengesRef!
          .where('participants', arrayContains: {'userId': _userId})
          .get();
      return snapshot.docs
          .map((doc) => HabitChallenge.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching challenges: $e');
      return [];
    }
  }

  /// Listen to challenge updates
  Stream<List<HabitChallenge>>? watchChallenges() {
    if (!_isEnabled || _challengesRef == null || _userId == null) return null;

    try {
      return _challengesRef!
          .where('creatorId', isEqualTo: _userId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => HabitChallenge.fromJson(doc.data()))
              .toList());
    } catch (e) {
      debugPrint('Error watching challenges: $e');
      return null;
    }
  }

  // ==========================================
  // FRIENDS SYNC
  // ==========================================

  /// Sync friend to cloud
  Future<void> syncFriend(HabitFriend friend) async {
    if (!_isEnabled || _friendsRef == null) return;

    try {
      await _friendsRef!.doc(friend.oderId).set(friend.toJson());
    } catch (e) {
      debugPrint('Error syncing friend: $e');
    }
  }

  /// Fetch friends
  Future<List<HabitFriend>> fetchFriends() async {
    if (!_isEnabled || _friendsRef == null) return [];

    try {
      final snapshot = await _friendsRef!.get();
      return snapshot.docs.map((doc) => HabitFriend.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      return [];
    }
  }

  /// Search users by email
  Future<List<HabitProfile>> searchUsersByEmail(String email) async {
    if (!_isEnabled || _profileRef == null) return [];

    try {
      final snapshot = await _profileRef!
          .where('email', isEqualTo: email)
          .limit(10)
          .get();
      return snapshot.docs
          .map((doc) => HabitProfile.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // ==========================================
  // PROFILE SYNC
  // ==========================================

  /// Sync profile to cloud
  Future<void> syncProfile(HabitProfile profile) async {
    if (!_isEnabled || _profileRef == null) return;

    try {
      await _profileRef!.doc(profile.oderId).set(profile.toJson());
    } catch (e) {
      debugPrint('Error syncing profile: $e');
    }
  }

  /// Fetch profile
  Future<HabitProfile?> fetchProfile(String oderId) async {
    if (!_isEnabled || _profileRef == null) return null;

    try {
      final doc = await _profileRef!.doc(oderId).get();
      if (doc.exists && doc.data() != null) {
        return HabitProfile.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  // ==========================================
  // FULL SYNC
  // ==========================================

  /// Perform full sync (upload local data)
  Future<void> performFullSync({
    required List<Habit> habits,
    required List<HabitLog> logs,
    required HabitProfile? profile,
  }) async {
    if (!_isEnabled) return;

    try {
      // Sync habits
      await syncAllHabits(habits);

      // Sync recent logs (last 30 days)
      final recentLogs = logs.where((l) {
        final daysAgo = DateTime.now().difference(l.date).inDays;
        return daysAgo <= 30;
      }).toList();

      final batch = _firestore!.batch();
      for (final log in recentLogs) {
        batch.set(_logsRef!.doc(log.id), log.toJson());
      }
      await batch.commit();

      // Sync profile
      if (profile != null) {
        await syncProfile(profile);
      }

      debugPrint('✓ Full habit sync completed');
    } catch (e) {
      debugPrint('Error performing full sync: $e');
    }
  }
}
