// DEPRECATED: Legacy storage service - Use CleanStorageService instead
// This file provides basic stubs to prevent compilation errors during migration

import 'package:flutter/foundation.dart';
import '../../features/reminders/models/reminder_model.dart' as ReminderModel;
import '../models/user_settings.dart';
import 'clean_storage_service.dart';

/// @deprecated Use CleanStorageService instead
class StorageService {
  
  /// @deprecated Use CleanStorageService.init() instead
  static Future<void> init() async {
    debugPrint('⚠️ StorageService.init() is deprecated. Use CleanStorageService.init() instead.');
    await CleanStorageService.init();
  }
  
  /// @deprecated Use CleanStorageService.isFirstLaunch instead
  static bool get isFirstLaunch => CleanStorageService.isFirstLaunch;
  
  /// @deprecated Use CleanStorageService.setFirstLaunchComplete() instead
  static Future<void> setFirstLaunchComplete() async {
    await CleanStorageService.setFirstLaunchComplete();
  }
  
  /// @deprecated Use CleanStorageService.getUserSettings() instead
  static UserSettings getUserSettings() {
    return CleanStorageService.getUserSettings();
  }
  
  /// @deprecated Use CleanStorageService.saveUserSettings() instead
  static Future<void> saveUserSettings(UserSettings settings) async {
    await CleanStorageService.saveUserSettings(settings);
  }
  
  /// @deprecated Use CleanStorageService.getAllReminders() instead
  static Future<List<ReminderModel.Reminder>> getAllReminders() async {
    return await CleanStorageService.getAllReminders();
  }
  
  /// @deprecated Use CleanStorageService.saveReminder() instead
  static Future<void> saveReminder(ReminderModel.Reminder reminder) async {
    await CleanStorageService.saveReminder(reminder);
  }
  
  /// @deprecated Use CleanStorageService methods instead
  static Future<void> updateReminder(ReminderModel.Reminder reminder) async {
    debugPrint('⚠️ StorageService.updateReminder() is deprecated.');
  }
  
  /// @deprecated Use CleanStorageService methods instead
  static Future<void> deleteReminder(String id) async {
    debugPrint('⚠️ StorageService.deleteReminder() is deprecated.');
  }
  
  /// @deprecated Use CleanStorageService methods instead
  static Future<void> toggleReminderCompletion(ReminderModel.Reminder reminder) async {
    debugPrint('⚠️ StorageService.toggleReminderCompletion() is deprecated.');
  }
  
  /// @deprecated Use CleanStorageService.exportAllData() instead
  static Map<String, dynamic> exportAllData() {
    return CleanStorageService.exportAllData();
  }
  
  /// @deprecated Use CleanStorageService.clearAllData() instead
  static Future<void> clearAllData() async {
    await CleanStorageService.clearAllData();
  }
  
  /// @deprecated Use CleanStorageService.importData() instead
  static Future<void> importData(Map<String, dynamic> data) async {
    await CleanStorageService.importData(data);
  }
  
  /// @deprecated Use CleanStorageService.close() instead
  static Future<void> close() async {
    await CleanStorageService.close();
  }
}
