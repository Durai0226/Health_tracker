
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:hive/hive.dart';
import 'storage_service.dart';
import '../../features/reminders/models/reminder_model.dart';
import 'notification_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<QuerySnapshot>? _reminderSubscription;

  void init() {
    // Defer listener setup to avoid blocking startup
    Future.delayed(const Duration(milliseconds: 500), () {
      _listenToReminders();
      
      // Listen for auth changes to restart listeners if user switches
      firebase_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _listenToReminders();
        } else {
          _cancelSubscriptions();
        }
      });
    });
  }

  void _listenToReminders() {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cancel existing subscription if any
    _reminderSubscription?.cancel();

    debugPrint('Starting cloud sync listener for user: ${user.uid}');

    _reminderSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          _handleReminderUpdate(change.doc);
        } else if (change.type == DocumentChangeType.removed) {
          _handleReminderDelete(change.doc.id);
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to reminder changes: $e');
    });
  }

  Future<void> _handleReminderUpdate(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Ensure data has ID
      if (!data.containsKey('id')) {
        data['id'] = doc.id;
      }
      
      final cloudReminder = Reminder.fromJson(data);
      
      // Check local version
      // We need to check if local version exists and compare modification times
      // To strictly follow "Last Write Wins", we should compare `updatedAt`.
      
      final box = Hive.box<Reminder>('reminders');
      final localReminder = box.get(cloudReminder.id);

      if (localReminder == null) {
        // New from cloud
        debugPrint('Sync: Added new reminder from cloud: ${cloudReminder.title}');
        await StorageService.saveSyncedReminder(cloudReminder);
        _scheduleNotification(cloudReminder);
      } else {
        // Exists locally. Compare generic equality or specific timestamp if available.
        // If we just wrote to cloud, we might get an echo. 
        // We can check `isSynced` flag or timestamp.
        
        // Simple timestamp check:
        // If cloud `updatedAt` is AFTER local `updatedAt`, update local.
        // Add 2 second buffer to avoid race conditions/echoes
        if (cloudReminder.updatedAt.isAfter(localReminder.updatedAt.add(const Duration(seconds: 2)))) {
           debugPrint('Sync: Updating local reminder from cloud: ${cloudReminder.title}');
           await StorageService.saveSyncedReminder(cloudReminder);
           
           // Reschedule notification
           // Cancel old one first to be safe
           await NotificationService().cancelNotification(cloudReminder.id.hashCode);
           if (!cloudReminder.isCompleted && cloudReminder.scheduledTime.isAfter(DateTime.now())) {
              _scheduleNotification(cloudReminder);
           }
        }
      }
    } catch (e) {
      debugPrint('Sync Error handling update: $e');
    }
  }

  Future<void> _handleReminderDelete(String id) async {
    try {
      final box = Hive.box<Reminder>('reminders');
      if (box.containsKey(id)) {
        debugPrint('Sync: Removing local reminder (deleted in cloud): $id');
        await StorageService.deleteSyncedReminder(id);
        await NotificationService().cancelNotification(id.hashCode);
      }
    } catch (e) {
      debugPrint('Sync Error handling delete: $e');
    }
  }

  Future<void> _scheduleNotification(Reminder reminder) async {
    if (reminder.isCompleted) return;
    
    await NotificationService().scheduleGenericReminder(
      id: reminder.id.hashCode,
      title: reminder.title,
      body: reminder.body,
      scheduledTime: reminder.scheduledTime,
      repeatType: reminder.repeatType,
      customDays: reminder.customDays,
      snoozeDuration: reminder.snoozeDuration,
      sound: reminder.sound,
    );
  }

  void _cancelSubscriptions() {
    _reminderSubscription?.cancel();
    debugPrint('Cancelled cloud sync listeners');
  }
}
