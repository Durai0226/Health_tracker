import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../models/reminder_model.dart';
import '../models/reminder_category_model.dart';

/// Cloud service for syncing reminders to Firestore
class RemindersCloudService {
  static final RemindersCloudService _instance = RemindersCloudService._internal();
  factory RemindersCloudService() => _instance;
  RemindersCloudService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Get current user ID
  String? get _userId => _authService.currentUser?.id;

  /// Get reminders collection reference
  CollectionReference<Map<String, dynamic>> get _remindersCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('reminders');
  }

  /// Get reminder categories collection reference
  CollectionReference<Map<String, dynamic>> get _categoriesCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('reminder_categories');
  }

  // ==========================================
  // REMINDER CRUD OPERATIONS
  // ==========================================

  /// Create a new reminder in Firestore
  Future<bool> createReminder(Reminder reminder) async {
    try {
      if (_userId == null) return false;

      final data = _reminderToFirestore(reminder);
      await _remindersCollection.doc(reminder.id).set(data);
      debugPrint('✓ Reminder synced to cloud: ${reminder.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to sync reminder: $e');
      return false;
    }
  }

  /// Update an existing reminder in Firestore
  Future<bool> updateReminder(Reminder reminder) async {
    try {
      if (_userId == null) return false;

      final data = _reminderToFirestore(reminder);
      await _remindersCollection.doc(reminder.id).update(data);
      debugPrint('✓ Reminder updated in cloud: ${reminder.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update reminder: $e');
      return false;
    }
  }

  /// Delete a reminder from Firestore
  Future<bool> deleteReminder(String reminderId) async {
    try {
      if (_userId == null) return false;

      await _remindersCollection.doc(reminderId).delete();
      debugPrint('✓ Reminder deleted from cloud: $reminderId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete reminder: $e');
      return false;
    }
  }

  /// Get a single reminder from Firestore
  Future<Reminder?> getReminder(String reminderId) async {
    try {
      if (_userId == null) return null;

      final doc = await _remindersCollection.doc(reminderId).get();
      if (!doc.exists) return null;

      return _reminderFromFirestore(doc.data()!);
    } catch (e) {
      debugPrint('❌ Failed to get reminder: $e');
      return null;
    }
  }

  /// Get all reminders from Firestore
  Future<List<Reminder>> getAllReminders() async {
    try {
      if (_userId == null) return [];

      final snapshot = await _remindersCollection
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => _reminderFromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get reminders: $e');
      return [];
    }
  }

  /// Get upcoming reminders (not completed, scheduled in future)
  Future<List<Reminder>> getUpcomingReminders() async {
    try {
      if (_userId == null) return [];

      final now = DateTime.now();
      final snapshot = await _remindersCollection
          .where('isCompleted', isEqualTo: false)
          .where('scheduledTime', isGreaterThan: now.toIso8601String())
          .orderBy('scheduledTime')
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => _reminderFromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get upcoming reminders: $e');
      return [];
    }
  }

  /// Stream of reminders for real-time updates
  Stream<List<Reminder>> watchReminders() {
    if (_userId == null) return Stream.value([]);

    return _remindersCollection
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _reminderFromFirestore(doc.data()))
            .toList());
  }

  /// Mark reminder as completed
  Future<bool> markReminderCompleted(String reminderId, bool completed) async {
    try {
      if (_userId == null) return false;

      await _remindersCollection.doc(reminderId).update({
        'isCompleted': completed,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('✓ Reminder marked as ${completed ? 'completed' : 'incomplete'}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update reminder status: $e');
      return false;
    }
  }

  // ==========================================
  // CATEGORY CRUD OPERATIONS
  // ==========================================

  /// Create a new category
  Future<bool> createCategory(ReminderCategory category) async {
    try {
      if (_userId == null) return false;

      final data = _categoryToFirestore(category);
      await _categoriesCollection.doc(category.id).set(data);
      debugPrint('✓ Category synced to cloud: ${category.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to sync category: $e');
      return false;
    }
  }

  /// Update a category
  Future<bool> updateCategory(ReminderCategory category) async {
    try {
      if (_userId == null) return false;

      final data = _categoryToFirestore(category);
      await _categoriesCollection.doc(category.id).update(data);
      debugPrint('✓ Category updated in cloud: ${category.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update category: $e');
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      if (_userId == null) return false;

      await _categoriesCollection.doc(categoryId).delete();
      debugPrint('✓ Category deleted from cloud: $categoryId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete category: $e');
      return false;
    }
  }

  /// Get all categories
  Future<List<ReminderCategory>> getAllCategories() async {
    try {
      if (_userId == null) return [];

      final snapshot = await _categoriesCollection.get();
      return snapshot.docs
          .map((doc) => _categoryFromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get categories: $e');
      return [];
    }
  }

  /// Stream of categories for real-time updates
  Stream<List<ReminderCategory>> watchCategories() {
    if (_userId == null) return Stream.value([]);

    return _categoriesCollection.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => _categoryFromFirestore(doc.data())).toList());
  }

  // ==========================================
  // SYNC OPERATIONS
  // ==========================================

  /// Sync all local reminders to cloud
  Future<int> syncAllReminders(List<Reminder> localReminders) async {
    try {
      if (_userId == null) return 0;

      int syncedCount = 0;
      final batch = _firestore.batch();

      for (final reminder in localReminders) {
        final ref = _remindersCollection.doc(reminder.id);
        batch.set(ref, _reminderToFirestore(reminder), SetOptions(merge: true));
        syncedCount++;
      }

      await batch.commit();
      debugPrint('✓ Synced $syncedCount reminders to cloud');
      return syncedCount;
    } catch (e) {
      debugPrint('❌ Failed to sync reminders: $e');
      return 0;
    }
  }

  /// Sync all local categories to cloud
  Future<int> syncAllCategories(List<ReminderCategory> localCategories) async {
    try {
      if (_userId == null) return 0;

      int syncedCount = 0;
      final batch = _firestore.batch();

      for (final category in localCategories) {
        final ref = _categoriesCollection.doc(category.id);
        batch.set(ref, _categoryToFirestore(category), SetOptions(merge: true));
        syncedCount++;
      }

      await batch.commit();
      debugPrint('✓ Synced $syncedCount categories to cloud');
      return syncedCount;
    } catch (e) {
      debugPrint('❌ Failed to sync categories: $e');
      return 0;
    }
  }

  // ==========================================
  // DATA CONVERSION
  // ==========================================

  /// Convert Reminder to Firestore map
  Map<String, dynamic> _reminderToFirestore(Reminder reminder) {
    return {
      'id': reminder.id,
      'title': reminder.title,
      'body': reminder.body,
      'scheduledTime': reminder.scheduledTime.toIso8601String(),
      'isCompleted': reminder.isCompleted,
      'createdAt': reminder.createdAt.toIso8601String(),
      'updatedAt': reminder.updatedAt.toIso8601String(),
      'isSynced': true,
      'repeatType': reminder.repeatType.index,
      'customDaysJson': reminder.customDays != null 
          ? reminder.customDays!.join(',') 
          : null,
      'snoozeDuration': reminder.snoozeDuration,
      'sound': reminder.sound,
      'priority': reminder.priority.index,
      'categoryId': reminder.categoryId,
      'note': reminder.note,
      'imagePath': reminder.imagePath,
      'noteId': reminder.noteId,
      'version': 1,
    };
  }

  /// Convert Firestore map to Reminder
  Reminder _reminderFromFirestore(Map<String, dynamic> data) {
    List<int>? customDays;
    if (data['customDaysJson'] != null && data['customDaysJson'].toString().isNotEmpty) {
      customDays = data['customDaysJson']
          .toString()
          .split(',')
          .map((s) => int.tryParse(s) ?? 0)
          .toList();
    }

    return Reminder(
      id: data['id'],
      title: data['title'],
      body: data['body'],
      scheduledTime: DateTime.parse(data['scheduledTime']),
      isCompleted: data['isCompleted'] ?? false,
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
      isSynced: true,
      repeatType: data['repeatType'] != null 
          ? RepeatType.values[data['repeatType']] 
          : RepeatType.none,
      customDays: customDays,
      snoozeDuration: data['snoozeDuration'],
      sound: data['sound'] ?? 'default',
      priority: data['priority'] != null 
          ? ReminderPriority.values[data['priority']] 
          : ReminderPriority.high,
      categoryId: data['categoryId'],
      note: data['note'],
      imagePath: data['imagePath'],
      noteId: data['noteId'],
    );
  }

  /// Convert ReminderCategory to Firestore map
  Map<String, dynamic> _categoryToFirestore(ReminderCategory category) {
    return {
      'id': category.id,
      'name': category.name,
      'colorValue': category.color,
      'iconCodePoint': category.icon,
      'isDefault': category.isDefault,
      'version': 1,
    };
  }

  /// Convert Firestore map to ReminderCategory
  ReminderCategory _categoryFromFirestore(Map<String, dynamic> data) {
    return ReminderCategory(
      id: data['id'],
      name: data['name'],
      color: data['colorValue'],
      icon: data['iconCodePoint'],
      isDefault: data['isDefault'] ?? false,
    );
  }
}
