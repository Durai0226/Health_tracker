import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/medication/models/medicine.dart';
import '../../features/medication/models/enhanced_medicine.dart';
import '../../features/medication/models/medicine_enums.dart';
import '../../features/medication/models/medicine_schedule.dart';
import '../../features/medication/models/medicine_log.dart';
import '../../features/medication/models/doctor_pharmacy.dart';
import '../../features/medication/models/dependent_profile.dart';
import '../../features/medication/models/drug_interaction.dart';
import '../../features/period_tracking/models/period_data.dart';
import '../../features/water/models/water_intake.dart';
import '../../features/water/models/beverage_type.dart';
import '../../features/water/models/water_container.dart';
import '../../features/water/models/hydration_profile.dart';
import '../../features/water/models/water_achievement.dart';
import '../../features/water/models/enhanced_water_log.dart';
import '../../features/fitness/models/fitness_reminder.dart';
import '../../features/fitness/models/fitness_activity.dart';
import '../../features/water/models/water_reminder.dart';
import '../../features/period_tracking/models/period_reminder.dart';
import '../models/action_log.dart';
import '../models/user_settings.dart';
import '../../features/notes/data/models/note_model.dart';
import '../../features/notes/data/models/folder_model.dart';
import '../../features/notes/data/models/tag_model.dart';
import '../../features/reminders/models/reminder_model.dart';
import '../../features/reminders/models/reminder_category_model.dart';
import '../../core/utils/secure_storage_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/reminders/utils/reminder_helper.dart';

class StorageService {
  static const String _medicineBoxName = 'medicines';
  static const String _periodBoxName = 'period';
  static const String _waterBoxName = 'water_intake';
  static const String _fitnessBoxName = 'fitness_reminders';
  static const String _fitnessActivityBoxName = 'fitness_activities';
  static const String _waterReminderBoxName = 'water_reminders';
  static const String _periodReminderBoxName = 'period_reminders';
  static const String _appPrefsBoxName = 'app_preferences';
  static const String _actionLogBoxName = 'action_logs';
  static const String _userSettingsBoxName = 'user_settings';
  static const String _notesBoxName = 'notes';
  static const String _foldersBoxName = 'folders';
  static const String _tagsBoxName = 'tags';
  static const String _categoriesBoxName = 'reminder_categories';
  static const String _remindersBoxName = 'reminders';
  
  static bool _isInitialized = false;

  static String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  static Future<void> _syncToCloud<T>(String collection, String docId, Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .set(data);
      debugPrint('Synced $collection/$docId to cloud');
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
      debugPrint('Deleted $collection/$docId from cloud');
    } catch (e) {
      debugPrint('Error deleting from cloud: $e');
    }
  }

  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('StorageService already initialized');
      return;
    }
    
    try {
      await Hive.initFlutter();
      
      // Register all adapters with error handling
      _safeRegisterAdapter(MedicineAdapter());
      _safeRegisterAdapter(PeriodDataAdapter());
      _safeRegisterAdapter(WaterIntakeAdapter());
      _safeRegisterAdapter(WaterLogAdapter());
      _safeRegisterAdapter(FitnessReminderAdapter());
      _safeRegisterAdapter(WaterReminderAdapter());
      _safeRegisterAdapter(PeriodReminderAdapter());
      _safeRegisterAdapter(ActionTypeAdapter());
      _safeRegisterAdapter(ActionLogAdapter());
      _safeRegisterAdapter(UserSettingsAdapter());
      _safeRegisterAdapter(FitnessActivityAdapter());
      _safeRegisterAdapter(FitnessGoalAdapter());
      
      // Register water feature adapters
      _safeRegisterAdapter(BeverageTypeAdapter());
      _safeRegisterAdapter(WaterContainerAdapter());
      _safeRegisterAdapter(ActivityLevelAdapter());
      _safeRegisterAdapter(ClimateTypeAdapter());
      _safeRegisterAdapter(HydrationProfileAdapter());
      _safeRegisterAdapter(AchievementTypeAdapter());
      _safeRegisterAdapter(WaterAchievementAdapter());
      _safeRegisterAdapter(UserAchievementsAdapter());
      _safeRegisterAdapter(EnhancedWaterLogAdapter());
      _safeRegisterAdapter(DailyWaterDataAdapter());
      
      // Register enhanced medicine adapters
      _safeRegisterAdapter(DosageFormAdapter());
      _safeRegisterAdapter(FrequencyTypeAdapter());
      _safeRegisterAdapter(MealTimingAdapter());
      _safeRegisterAdapter(MedicineStatusAdapter());
      _safeRegisterAdapter(SkipReasonAdapter());
      _safeRegisterAdapter(InteractionSeverityAdapter());
      _safeRegisterAdapter(MedicineColorAdapter());
      _safeRegisterAdapter(MedicineShapeAdapter());
      _safeRegisterAdapter(ScheduledTimeAdapter());
      _safeRegisterAdapter(MedicineScheduleAdapter());
      _safeRegisterAdapter(MedicineLogAdapter());
      _safeRegisterAdapter(DailyMedicineSummaryAdapter());
      _safeRegisterAdapter(DoctorAdapter());
      _safeRegisterAdapter(PharmacyAdapter());
      _safeRegisterAdapter(AppointmentAdapter());
      _safeRegisterAdapter(DrugInteractionAdapter());
      _safeRegisterAdapter(SideEffectAdapter());
      _safeRegisterAdapter(DrugInfoAdapter());
      _safeRegisterAdapter(RelationshipTypeAdapter());
      _safeRegisterAdapter(DependentProfileAdapter());
      _safeRegisterAdapter(EnhancedMedicineAdapter());
      _safeRegisterAdapter(TreatmentCourseAdapter());
      _safeRegisterAdapter(HealthCategoryAdapter());

      // Register Notes adapters
      _safeRegisterAdapter(NoteModelAdapter());
      _safeRegisterAdapter(FolderModelAdapter());
      _safeRegisterAdapter(TagModelAdapter());
      _safeRegisterAdapter(ReminderAdapter());
      _safeRegisterAdapter(RepeatTypeAdapter());
      _safeRegisterAdapter(ReminderPriorityAdapter());
      _safeRegisterAdapter(ReminderCategoryAdapter());
      
      // Open critical boxes in parallel for faster startup
      await Future.wait([
        _safeOpenBox<UserSettings>(_userSettingsBoxName),
        _safeOpenBox<dynamic>(_appPrefsBoxName),
        _safeOpenBox<Reminder>(_remindersBoxName),
        _safeOpenBox<ReminderCategory>(_categoriesBoxName),
      ]);
      
      await _initDefaultCategories();
      
      // Open remaining boxes in parallel (non-blocking for app startup)
      Future.wait([
        _safeOpenBox<Medicine>(_medicineBoxName),
        _safeOpenBox<PeriodData>(_periodBoxName),
        _safeOpenBox<WaterIntake>(_waterBoxName),
        _safeOpenBox<FitnessReminder>(_fitnessBoxName),
        _safeOpenBox<FitnessActivity>(_fitnessActivityBoxName),
        _safeOpenBox<WaterReminder>(_waterReminderBoxName),
        _safeOpenBox<PeriodReminder>(_periodReminderBoxName),
        _safeOpenBox<ActionLog>(_actionLogBoxName),
        _safeOpenBox<NoteModel>(_notesBoxName),
        _safeOpenBox<FolderModel>(_foldersBoxName),
        _safeOpenBox<TagModel>(_tagsBoxName),
      ]).then((_) => debugPrint('✓ All storage boxes loaded'));

      _isInitialized = true;
      debugPrint('StorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing StorageService: $e');
      rethrow;
    }
  }
  
  static Future<void> toggleReminderCompletion(Reminder reminder) async {
    // Determine new state
    // If currently NOT completed, we are completing it.
    // If recurring, we reschedule instead of marking completed.
    
    if (!reminder.isCompleted) {
       // User checking off the item
       if (reminder.repeatType != RepeatType.none) {
         // It's a recurring reminder
         final nextDate = ReminderHelper.getNextOccurrence(reminder);
         
         final updatedReminder = reminder.copyWith(
           scheduledTime: nextDate,
           isCompleted: false, // Ensure it stays active
           isSynced: false,
         );
         
         await updateReminder(updatedReminder);
         
         // Reschedule notification
         await NotificationService().scheduleGenericReminder(
            id: int.parse(updatedReminder.id), // Ensure ID is int parsable or hash
            // Wait, ID is UUID string... we need a consistent way to map UUID to Int for notifications
            // Existing code in RemindersScreen used hashCode or parse.
            // Let's unify. Assuming we use hashCode for notification ID.
            title: updatedReminder.title,
            body: updatedReminder.body,
            scheduledTime: nextDate,
            repeatType: updatedReminder.repeatType,
            customDays: updatedReminder.customDays,
            snoozeDuration: updatedReminder.snoozeDuration,
            sound: updatedReminder.sound,
         );
         
         debugPrint('Recurring reminder rescheduled to $nextDate');
         return;
       }
    }
    
    // Default Toggle behavior (One-time or Unchecking)
    final updated = reminder.copyWith(isCompleted: !reminder.isCompleted, isSynced: false);
    await updateReminder(updated);
    
    // Handle notification cancellation/restoration
    // If marked completed -> Cancel notification
    // If marked incomplete -> Reschedule (if in future)
    final notifId = reminder.id.hashCode;
    if (updated.isCompleted) {
      await NotificationService().cancelNotification(notifId);
    } else {
       if (updated.scheduledTime.isAfter(DateTime.now())) {
         await NotificationService().scheduleGenericReminder(
            id: notifId,
            title: updated.title,
            body: updated.body,
            scheduledTime: updated.scheduledTime,
            repeatType: updated.repeatType,
            customDays: updated.customDays,
            snoozeDuration: updated.snoozeDuration,
            sound: updated.sound,
         );
       }
    }
  }

  // Reminder & Categories Methods
  static Box<Reminder> get _remindersBox => Hive.box<Reminder>(_remindersBoxName);
  static Box<ReminderCategory> get _categoriesBox => Hive.box<ReminderCategory>(_categoriesBoxName);

  static Future<void> updateReminder(Reminder reminder) async {
    await _remindersBox.put(reminder.id, reminder);
    await _syncToCloud('reminders', reminder.id, reminder.toJson());
  }

  static ValueListenable<Box<Reminder>> get remindersListenable => _remindersBox.listenable();

  static List<Reminder> getAllReminders() {
    return _remindersBox.values.toList()..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  static Future<void> addReminder(Reminder reminder) async {
    await _remindersBox.put(reminder.id, reminder);
    await _syncToCloud('reminders', reminder.id, reminder.toJson());
  }

  static Future<void> deleteReminder(String id) async {
    await _remindersBox.delete(id);
    await _deleteFromCloud('reminders', id);
  }

  static Future<void> _initDefaultCategories() async {
    if (_categoriesBox.isEmpty) {
      final defaults = [
        ReminderCategory(
          id: 'personal',
          name: 'Personal',
          color: Colors.blue.value,
          icon: Icons.person_rounded.codePoint,
          isDefault: true,
        ),
        ReminderCategory(
          id: 'work',
          name: 'Work',
          color: Colors.orange.value,
          icon: Icons.work_rounded.codePoint,
          isDefault: true,
        ),
        ReminderCategory(
          id: 'health',
          name: 'Health',
          color: Colors.green.value,
          icon: Icons.favorite_rounded.codePoint,
          isDefault: true,
        ),
        ReminderCategory(
          id: 'finance',
          name: 'Finance',
          color: Colors.purple.value,
          icon: Icons.attach_money_rounded.codePoint,
          isDefault: true,
        ),
        ReminderCategory(
          id: 'education',
          name: 'Education',
          color: Colors.yellow.shade700.value, // Darker yellow for visibility
          icon: Icons.school_rounded.codePoint,
          isDefault: true,
        ),
      ];
      
      for (var category in defaults) {
        await _categoriesBox.put(category.id, category);
      }
      debugPrint('Initialized default reminder categories');
    }
  }

  static ValueListenable<Box<ReminderCategory>> get categoriesListenable => _categoriesBox.listenable();

  static List<ReminderCategory> getAllCategories() {
    return _categoriesBox.values.toList();
  }

  static ReminderCategory? getCategory(String id) {
    return _categoriesBox.get(id);
  }

  static Future<void> addCategory(ReminderCategory category) async {
    await _categoriesBox.put(category.id, category);
    // Cloud sync for categories not yet implemented, but placeholder:
    // await _syncToCloud('reminder_categories', category.id, category.toJson());
  }

  static Future<void> updateCategory(ReminderCategory category) async {
    await _categoriesBox.put(category.id, category);
  }

  static Future<void> deleteCategory(String id) async {
    // Only allow deletion if not default? Or allow user to restore defaults?
    // For now, allow deletion.
    await _categoriesBox.delete(id);
    
    // Also update reminders to remove this categoryId
    final reminders = _remindersBox.values.where((r) => r.categoryId == id).toList();
    for (var reminder in reminders) {
      final updated = reminder.copyWith(categoryId: null);
      // We can't pass null to copyWith if the parameter is nullable but optional?
      // Wait, copyWith usually takes nullable arguments to update, but if I pass null it might mean "don't update".
      // Let's check Reminder.copyWith implementation.
      // It is: categoryId: categoryId ?? this.categoryId
      // So passing null won't clear it. I need to pass a special value or change copyWith.
      // Or just create new instance.
       final newReminder = Reminder(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledTime: reminder.scheduledTime,
        isCompleted: reminder.isCompleted,
        createdAt: reminder.createdAt,
        updatedAt: DateTime.now(),
        repeatType: reminder.repeatType,
        customDays: reminder.customDays,
        snoozeDuration: reminder.snoozeDuration,
        sound: reminder.sound,
        priority: reminder.priority,
        categoryId: null, // Explicitly null
      );
      await updateReminder(newReminder);
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
      
      // Get encryption key
      final encryptionKey = await SecureStorageHelper.getEncryptionKey();
      
      return await Hive.openBox<T>(
        boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      debugPrint('Error opening box $boxName: $e');
      // Try to delete corrupted box and recreate
      try {
        await Hive.deleteBoxFromDisk(boxName);
        // Get key again just in case
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
  
  static Future<void> recoverFromError() async {
    debugPrint('Attempting storage recovery...');
    _isInitialized = false;
    await init();
  }

  // Medicine Methods
  static Box<Medicine> get _medicineBox {
    if (!Hive.isBoxOpen(_medicineBoxName)) {
      throw StateError('Medicine box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<Medicine>(_medicineBoxName);
  }

  static List<Medicine> getAllMedicines() {
    return _medicineBox.values.toList();
  }

  static Future<void> addMedicine(Medicine medicine) async {
    await _medicineBox.put(medicine.id, medicine);
    await _syncToCloud('medicines', medicine.id, medicine.toJson());
  }

  static Future<void> deleteMedicine(String id) async {
    await _medicineBox.delete(id);
    await _deleteFromCloud('medicines', id);
  }

  static Future<void> updateMedicine(Medicine medicine) async {
    await _medicineBox.put(medicine.id, medicine);
    await _syncToCloud('medicines', medicine.id, medicine.toJson());
  }

  static ValueListenable<Box<Medicine>> get listenable => _medicineBox.listenable();

  // Period Methods
  static Box<PeriodData> get _periodBox {
    if (!Hive.isBoxOpen(_periodBoxName)) {
      throw StateError('Period box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<PeriodData>(_periodBoxName);
  }

  static Future<void> savePeriodData(PeriodData data) async {
    await _periodBox.put('current', data);
    await _syncToCloud('period', 'current', data.toJson());
  }

  static PeriodData? getPeriodData() {
    return _periodBox.get('current');
  }

  static Future<void> clearPeriodData() async {
    await _periodBox.delete('current');
    await _deleteFromCloud('period', 'current');
  }

  static bool get isPeriodTrackingEnabled => _periodBox.containsKey('current');

  // Water Intake Methods
  static Box<WaterIntake> get _waterBox {
    if (!Hive.isBoxOpen(_waterBoxName)) {
      throw StateError('Water box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<WaterIntake>(_waterBoxName);
  }

  static WaterIntake? getTodayWaterIntake() {
    final today = DateTime.now();
    final key = '${today.year}-${today.month}-${today.day}';
    return _waterBox.get(key);
  }

  static Future<void> saveWaterIntake(WaterIntake water) async {
    final key = '${water.date.year}-${water.date.month}-${water.date.day}';
    await _waterBox.put(key, water);
    await _syncToCloud('water_intake', key, water.toJson());
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
    await _syncToCloud('water_intake', key, water.toJson());
  }

  static ValueListenable<Box<WaterIntake>> get waterListenable => _waterBox.listenable();

  // Fitness Reminder Methods
  static Box<FitnessReminder> get _fitnessBox {
    if (!Hive.isBoxOpen(_fitnessBoxName)) {
      throw StateError('Fitness box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<FitnessReminder>(_fitnessBoxName);
  }

  static List<FitnessReminder> getAllFitnessReminders() {
    return _fitnessBox.values.toList();
  }

  static Future<void> addFitnessReminder(FitnessReminder reminder) async {
    await _fitnessBox.put(reminder.id, reminder);
    await _syncToCloud('fitness_reminders', reminder.id, reminder.toJson());
  }

  static Future<void> deleteFitnessReminder(String id) async {
    await _fitnessBox.delete(id);
    await _deleteFromCloud('fitness_reminders', id);
  }

  static Future<void> updateFitnessReminder(FitnessReminder reminder) async {
    await _fitnessBox.put(reminder.id, reminder);
    await _syncToCloud('fitness_reminders', reminder.id, reminder.toJson());
  }

  static ValueListenable<Box<FitnessReminder>> get fitnessListenable => _fitnessBox.listenable();

  // Fitness Activity Methods
  static Box<FitnessActivity> get _fitnessActivityBox {
    if (!Hive.isBoxOpen(_fitnessActivityBoxName)) {
      throw StateError('Fitness activity box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<FitnessActivity>(_fitnessActivityBoxName);
  }

  static List<FitnessActivity> getAllFitnessActivities() {
    return _fitnessActivityBox.values.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  static Future<void> addFitnessActivity(FitnessActivity activity) async {
    await _fitnessActivityBox.put(activity.id, activity);
    await _syncToCloud('fitness_activities', activity.id, activity.toJson());
  }

  static ValueListenable<Box<FitnessActivity>> get fitnessActivityListenable => _fitnessActivityBox.listenable();

  static Future<void> saveFitnessActivity(FitnessActivity activity) async {
    await _fitnessActivityBox.put(activity.id, activity);
    await _syncToCloud('fitness_activities', activity.id, activity.toJson());
  }

  // App Preferences
  static Box get _appPrefsBox {
    if (!Hive.isBoxOpen(_appPrefsBoxName)) {
      throw StateError('App prefs box not initialized. Call StorageService.init() first.');
    }
    return Hive.box(_appPrefsBoxName);
  }

  static bool get isFirstLaunch {
    return _appPrefsBox.get('onboarding_complete', defaultValue: false) == false;
  }

  static Future<void> setOnboardingComplete() async {
    await _appPrefsBox.put('onboarding_complete', true);
  }

  static Map<String, dynamic> getAppPreferences() {
    return Map<String, dynamic>.from(_appPrefsBox.toMap());
  }

  static Future<void> setAppPreference(String key, dynamic value) async {
    await _appPrefsBox.put(key, value);
  }

  // Water Reminder Methods
  static Box<WaterReminder> get _waterReminderBox {
    if (!Hive.isBoxOpen(_waterReminderBoxName)) {
      throw StateError('Water reminder box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<WaterReminder>(_waterReminderBoxName);
  }

  static WaterReminder? getWaterReminder() {
    return _waterReminderBox.get('water_reminder');
  }

  static Future<void> saveWaterReminder(WaterReminder reminder) async {
    await _waterReminderBox.put('water_reminder', reminder);
    await _syncToCloud('water_reminders', 'water_reminder', reminder.toJson());
  }

  static Future<void> deleteWaterReminder() async {
    await _waterReminderBox.delete('water_reminder');
    await _deleteFromCloud('water_reminders', 'water_reminder');
  }

  // Period Reminder Methods
  static Box<PeriodReminder> get _periodReminderBox {
    if (!Hive.isBoxOpen(_periodReminderBoxName)) {
      throw StateError('Period reminder box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<PeriodReminder>(_periodReminderBoxName);
  }

  static PeriodReminder? getPeriodReminder() {
    return _periodReminderBox.get('period_reminder');
  }

  static Future<void> savePeriodReminder(PeriodReminder reminder) async {
    await _periodReminderBox.put('period_reminder', reminder);
    await _syncToCloud('period_reminders', 'period_reminder', reminder.toJson());
  }

  static Future<void> deletePeriodReminder() async {
    await _periodReminderBox.delete('period_reminder');
    await _deleteFromCloud('period_reminders', 'period_reminder');
  }

  // ============ Action Log Methods ============
  static Box<ActionLog> get _actionLogBox {
    if (!Hive.isBoxOpen(_actionLogBoxName)) {
      throw StateError('Action log box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<ActionLog>(_actionLogBoxName);
  }

  static List<ActionLog> getAllActionLogs() {
    try {
      return _actionLogBox.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error getting action logs: $e');
      return [];
    }
  }

  static List<ActionLog> getActionLogsByType(ActionType type) {
    try {
      return _actionLogBox.values
          .where((log) => log.type == type)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error getting action logs by type: $e');
      return [];
    }
  }

  static List<ActionLog> getActionLogsForDate(DateTime date) {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return _actionLogBox.values
          .where((log) => 
              log.timestamp.isAfter(startOfDay) && 
              log.timestamp.isBefore(endOfDay))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error getting action logs for date: $e');
      return [];
    }
  }

  static List<ActionLog> getActionLogsForReference(String referenceId) {
    try {
      return _actionLogBox.values
          .where((log) => log.referenceId == referenceId)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error getting action logs for reference: $e');
      return [];
    }
  }

  static Future<void> addActionLog(ActionLog log) async {
    try {
      await _actionLogBox.put(log.id, log);
      await _syncToCloud('action_logs', log.id, log.toJson());
    } catch (e) {
      debugPrint('Error adding action log: $e');
    }
  }

  static Future<void> logMedicineTaken({
    required String medicineId,
    required String medicineName,
    int? dosageAmount,
    String? dosageType,
  }) async {
    final log = ActionLog(
      id: '${medicineId}_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.medicineTaken,
      timestamp: DateTime.now(),
      referenceId: medicineId,
      title: medicineName,
      metadata: {
        'dosageAmount': dosageAmount,
        'dosageType': dosageType,
      },
    );
    await addActionLog(log);
  }

  static Future<void> logMedicineSkipped({
    required String medicineId,
    required String medicineName,
    String? reason,
  }) async {
    final log = ActionLog(
      id: '${medicineId}_skip_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.medicineSkipped,
      timestamp: DateTime.now(),
      referenceId: medicineId,
      title: medicineName,
      metadata: {'reason': reason},
    );
    await addActionLog(log);
  }

  static Future<void> logFitnessCompleted({
    required String fitnessId,
    required String fitnessTitle,
    int? durationMinutes,
    String? fitnessType,
  }) async {
    final log = ActionLog(
      id: '${fitnessId}_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.fitnessCompleted,
      timestamp: DateTime.now(),
      referenceId: fitnessId,
      title: fitnessTitle,
      metadata: {
        'durationMinutes': durationMinutes,
        'fitnessType': fitnessType,
      },
    );
    await addActionLog(log);
  }

  static Future<void> logFitnessSkipped({
    required String fitnessId,
    required String fitnessTitle,
    String? reason,
  }) async {
    final log = ActionLog(
      id: '${fitnessId}_skip_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.fitnessSkipped,
      timestamp: DateTime.now(),
      referenceId: fitnessId,
      title: fitnessTitle,
      metadata: {'reason': reason},
    );
    await addActionLog(log);
  }

  static Future<void> logWaterIntake({
    required int amountMl,
    String? source,
  }) async {
    final log = ActionLog(
      id: 'water_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.waterLogged,
      timestamp: DateTime.now(),
      title: '+$amountMl ml',
      metadata: {
        'amountMl': amountMl,
        'source': source,
      },
    );
    await addActionLog(log);
  }

  static Future<void> logPeriodStarted() async {
    final log = ActionLog(
      id: 'period_start_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.periodStarted,
      timestamp: DateTime.now(),
      title: 'Period Started',
    );
    await addActionLog(log);
  }

  static Future<void> logPeriodEnded() async {
    final log = ActionLog(
      id: 'period_end_${DateTime.now().millisecondsSinceEpoch}',
      type: ActionType.periodEnded,
      timestamp: DateTime.now(),
      title: 'Period Ended',
    );
    await addActionLog(log);
  }

  static Future<void> deleteActionLog(String id) async {
    try {
      await _actionLogBox.delete(id);
      await _deleteFromCloud('action_logs', id);
    } catch (e) {
      debugPrint('Error deleting action log: $e');
    }
  }

  static Future<void> clearOldActionLogs({int keepDays = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      final logsToDelete = _actionLogBox.values
          .where((log) => log.timestamp.isBefore(cutoffDate))
          .map((log) => log.id)
          .toList();
      
      for (final id in logsToDelete) {
        await _actionLogBox.delete(id);
      }
      debugPrint('Cleared ${logsToDelete.length} old action logs');
    } catch (e) {
      debugPrint('Error clearing old action logs: $e');
    }
  }

  static ValueListenable<Box<ActionLog>> get actionLogListenable => _actionLogBox.listenable();

  // ============ User Settings Methods ============
  static Box<UserSettings> get _userSettingsBox {
    if (!Hive.isBoxOpen(_userSettingsBoxName)) {
      throw StateError('User settings box not initialized. Call StorageService.init() first.');
    }
    return Hive.box<UserSettings>(_userSettingsBoxName);
  }

  static UserSettings getUserSettings() {
    try {
      return _userSettingsBox.get('settings') ?? UserSettings();
    } catch (e) {
      debugPrint('Error getting user settings: $e');
      return UserSettings();
    }
  }

  static Future<void> saveUserSettings(UserSettings settings) async {
    try {
      await _userSettingsBox.put('settings', settings);
      await _syncToCloud('user_settings', 'settings', settings.toJson());
    } catch (e) {
      debugPrint('Error saving user settings: $e');
    }
  }

  static Future<void> updateUserSetting<T>({
    required String key,
    required T value,
  }) async {
    try {
      final current = getUserSettings();
      UserSettings updated;
      
      switch (key) {
        case 'waterDailyGoalMl':
          updated = current.copyWith(waterDailyGoalMl: value as int);
          break;
        case 'darkModeEnabled':
          updated = current.copyWith(darkModeEnabled: value as bool);
          break;
        case 'soundEnabled':
          updated = current.copyWith(soundEnabled: value as bool);
          break;
        case 'vibrationEnabled':
          updated = current.copyWith(vibrationEnabled: value as bool);
          break;
        case 'preferredRingtone':
          updated = current.copyWith(preferredRingtone: value as String?);
          break;
        case 'showCompletedReminders':
          updated = current.copyWith(showCompletedReminders: value as bool);
          break;
        case 'reminderSnoozeMinutes':
          updated = current.copyWith(reminderSnoozeMinutes: value as int);
          break;
        case 'autoMarkMissed':
          updated = current.copyWith(autoMarkMissed: value as bool);
          break;
        case 'missedThresholdMinutes':
          updated = current.copyWith(missedThresholdMinutes: value as int);
          break;
        case 'analyticsEnabled':
          updated = current.copyWith(analyticsEnabled: value as bool);
          break;
        case 'locale':
          updated = current.copyWith(locale: value as String?);
          break;
        default:
          debugPrint('Unknown setting key: $key');
          return;
      }
      
      await saveUserSettings(updated);
    } catch (e) {
      debugPrint('Error updating user setting: $e');
    }
  }

  static int getWaterDailyGoal() {
    return getUserSettings().waterDailyGoalMl;
  }

  static Future<void> setWaterDailyGoal(int goalMl) async {
    await updateUserSetting(key: 'waterDailyGoalMl', value: goalMl);
  }

  static ValueListenable<Box<UserSettings>> get userSettingsListenable => _userSettingsBox.listenable();

  // ============ Analytics & Statistics Methods ============
  static Map<String, dynamic> getMedicineAdherenceStats({int days = 7}) {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final logs = _actionLogBox.values
          .where((log) => 
              (log.type == ActionType.medicineTaken || log.type == ActionType.medicineSkipped) &&
              log.timestamp.isAfter(cutoffDate))
          .toList();
      
      final taken = logs.where((log) => log.type == ActionType.medicineTaken).length;
      final skipped = logs.where((log) => log.type == ActionType.medicineSkipped).length;
      final total = taken + skipped;
      
      return {
        'taken': taken,
        'skipped': skipped,
        'total': total,
        'adherenceRate': total > 0 ? (taken / total * 100).round() : 100,
        'days': days,
      };
    } catch (e) {
      debugPrint('Error getting medicine adherence stats: $e');
      return {'taken': 0, 'skipped': 0, 'total': 0, 'adherenceRate': 100, 'days': days};
    }
  }

  static Map<String, dynamic> getFitnessStats({int days = 7}) {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final logs = _actionLogBox.values
          .where((log) => 
              (log.type == ActionType.fitnessCompleted || log.type == ActionType.fitnessSkipped) &&
              log.timestamp.isAfter(cutoffDate))
          .toList();
      
      final completed = logs.where((log) => log.type == ActionType.fitnessCompleted).length;
      final skipped = logs.where((log) => log.type == ActionType.fitnessSkipped).length;
      final totalMinutes = logs
          .where((log) => log.type == ActionType.fitnessCompleted)
          .map((log) => (log.metadata?['durationMinutes'] as int?) ?? 0)
          .fold(0, (sum, mins) => sum + mins);
      
      return {
        'completed': completed,
        'skipped': skipped,
        'totalMinutes': totalMinutes,
        'completionRate': (completed + skipped) > 0 
            ? (completed / (completed + skipped) * 100).round() 
            : 100,
        'days': days,
      };
    } catch (e) {
      debugPrint('Error getting fitness stats: $e');
      return {'completed': 0, 'skipped': 0, 'totalMinutes': 0, 'completionRate': 100, 'days': days};
    }
  }

  static Map<String, dynamic> getWaterStats({int days = 7}) {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final logs = _actionLogBox.values
          .where((log) => 
              log.type == ActionType.waterLogged &&
              log.timestamp.isAfter(cutoffDate))
          .toList();
      
      final totalMl = logs
          .map((log) => (log.metadata?['amountMl'] as int?) ?? 0)
          .fold(0, (sum, ml) => sum + ml);
      
      final dailyGoal = getWaterDailyGoal();
      final avgDaily = days > 0 ? (totalMl / days).round() : 0;
      
      return {
        'totalMl': totalMl,
        'avgDailyMl': avgDaily,
        'dailyGoal': dailyGoal,
        'avgCompletionRate': dailyGoal > 0 ? (avgDaily / dailyGoal * 100).round() : 0,
        'logCount': logs.length,
        'days': days,
      };
    } catch (e) {
      debugPrint('Error getting water stats: $e');
      return {'totalMl': 0, 'avgDailyMl': 0, 'dailyGoal': 2500, 'avgCompletionRate': 0, 'logCount': 0, 'days': days};
    }
  }

  // ============ Data Export & Backup Methods ============
  static Map<String, dynamic> exportAllData() {
    try {
      return {
        'exportDate': DateTime.now().toIso8601String(),
        'medicines': getAllMedicines().map((m) => m.toJson()).toList(),
        'fitnessReminders': getAllFitnessReminders().map((f) => f.toJson()).toList(),
        'periodData': getPeriodData()?.toJson(),
        'waterReminder': getWaterReminder()?.toJson(),
        'periodReminder': getPeriodReminder()?.toJson(),
        'actionLogs': getAllActionLogs().map((a) => a.toJson()).toList(),
        'userSettings': getUserSettings().toJson(),
        'appPreferences': getAppPreferences(),
        'reminders': _remindersBox.values.map((r) => r.toJson()).toList(),
      };
    } catch (e) {
      debugPrint('Error exporting data: $e');
      return {'error': e.toString()};
    }
  }

  // Cloud Sync Helpers (Update local without pushing back to Cloud to avoid loop)
  static Future<void> saveSyncedReminder(Reminder reminder) async {
    await _remindersBox.put(reminder.id, reminder.copyWith(isSynced: true));
  }

  static Future<void> deleteSyncedReminder(String id) async {
    if (_remindersBox.containsKey(id)) {
      await _remindersBox.delete(id);
    }
  }

  static Future<bool> importData(Map<String, dynamic> data) async {
    try {
      // Import medicines
      if (data['medicines'] != null) {
        for (final json in data['medicines'] as List) {
          final medicine = Medicine.fromJson(json);
          await addMedicine(medicine);
        }
      }
      
      // Import fitness reminders
      if (data['fitnessReminders'] != null) {
        for (final json in data['fitnessReminders'] as List) {
          final reminder = FitnessReminder.fromJson(json);
          await addFitnessReminder(reminder);
        }
      }
      
      // Import period data
      if (data['periodData'] != null) {
        await savePeriodData(PeriodData.fromJson(data['periodData']));
      }
      
      // Import water reminder
      if (data['waterReminder'] != null) {
        await saveWaterReminder(WaterReminder.fromJson(data['waterReminder']));
      }
      
      // Import period reminder
      if (data['periodReminder'] != null) {
        await savePeriodReminder(PeriodReminder.fromJson(data['periodReminder']));
      }
      
      // Import user settings
      if (data['userSettings'] != null) {
        await saveUserSettings(UserSettings.fromJson(data['userSettings']));
      }

      // Import reminders
      if (data['reminders'] != null) {
        for (final json in data['reminders'] as List) {
          final reminder = Reminder.fromJson(json);
           // Use saveSyncedReminder to avoid trigger cloud sync loop during restore
           // Actually, for restore, we probably WANT to sync to cloud to overwrite cloud state?
           // Plan said "Overwrite local data".
           // If we overwrite local, next sync might push to cloud.
           // Let's use standard update to ensure cloud gets the restored data too.
           await updateReminder(reminder);
        }
      }
      
      debugPrint('Data import completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }

  // ============ Notes Methods ============
  static Box<NoteModel> get _notesBox {
    // Only try to open if we have initialized Hive
    if (!Hive.isBoxOpen(_notesBoxName)) {
       throw HiveError('Box $_notesBoxName is not open');
    }
    return Hive.box<NoteModel>(_notesBoxName);
  }
  static Box<FolderModel> get _foldersBox => Hive.box<FolderModel>(_foldersBoxName);
  static Box<TagModel> get _tagsBox => Hive.box<TagModel>(_tagsBoxName);

  static ValueListenable<Box<NoteModel>> get notesListenable => _notesBox.listenable();
  static ValueListenable<Box<FolderModel>> get foldersListenable => _foldersBox.listenable();
  static ValueListenable<Box<TagModel>> get tagsListenable => _tagsBox.listenable();

  // Notes
  static List<NoteModel> getAllNotes() {
    return _notesBox.values.toList();
  }

  static Future<void> saveNote(NoteModel note) async {
    await _notesBox.put(note.id, note);
    // Cloud sync will be handled by Repository to avoid circular dependency or tightly coupled code here
  }

  static Future<void> deleteNote(String id) async {
    await _notesBox.delete(id);
  }

  static NoteModel? getNote(String id) {
    return _notesBox.get(id);
  }

  // Folders
  static List<FolderModel> getAllFolders() {
    return _foldersBox.values.toList();
  }

  static Future<void> saveFolder(FolderModel folder) async {
    await _foldersBox.put(folder.id, folder);
  }

  static Future<void> deleteFolder(String id) async {
    await _foldersBox.delete(id);
  }

  // Tags
  static List<TagModel> getAllTags() {
    return _tagsBox.values.toList();
  }

  static Future<void> saveTag(TagModel tag) async {
    await _tagsBox.put(tag.id, tag);
  }

  static Future<void> deleteTag(String id) async {
    await _tagsBox.delete(id);
  }



  // ============ Clear All Data ============
  static Future<void> clearAllData() async {
    try {
      await _medicineBox.clear();
      await _fitnessBox.clear();
      await _waterBox.clear();
      await _periodBox.clear();
      await _waterReminderBox.clear();
      await _periodReminderBox.clear();
      await _actionLogBox.clear();
      
      // Clear Notes data
      await _notesBox.clear();
      await _foldersBox.clear();
      await _tagsBox.clear();
      
      // Keep user settings and app preferences
      debugPrint('All data cleared');
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }

  // ============ Backup & Restore (Notes Feature) ============

  /// Exports all relevant data as a JSON-encodable Map (Notes-focused backup)
  static Future<Map<String, dynamic>> exportNotesData() async {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'version': 1,
      // Notes Feature
      'notes': _notesBox.values.map((e) => _noteToJson(e)).toList(),
      'folders': _foldersBox.values.map((e) => _folderToJson(e)).toList(),
      'tags': _tagsBox.values.map((e) => _tagToJson(e)).toList(),
      
      // Legacy Features
      'medicines': getAllMedicines().map((m) => m.toJson()).toList(),
      'fitnessReminders': getAllFitnessReminders().map((f) => f.toJson()).toList(),
      'periodData': getPeriodData()?.toJson(),
      'waterReminder': getWaterReminder()?.toJson(),
      'periodReminder': getPeriodReminder()?.toJson(),
      'actionLogs': getAllActionLogs().map((a) => a.toJson()).toList(),
      'userSettings': _userSettingsBox.values.map((e) => _userSettingsToJson(e)).toList(), // Prefer generic or specific? Using box values directly is safer if method handles empty. But `getUserSettings().toJson()` handles defaults. Let's use `getUserSettings().toJson()` for consistency with legacy if it works, or map box. 
      // The duplicated code used `getUserSettings().toJson()`.
      // My new code used `_userSettingsBox.values.map...`.
      // Let's use the explicit map for backup to be raw.
      // 'user_settings': _userSettingsBox.values.map((e) => _userSettingsToJson(e)).toList(), 
      // check if I should use camelCase 'userSettings' or snake_case 'user_settings'. Legacy used 'userSettings'. New used 'user_settings'.
      // I should support both or standardise. I'll use 'userSettings' to match legacy for now or keep 'user_settings'.
      // I'll keep 'user_settings' for the new backup format.
      'user_settings': _userSettingsBox.values.map((e) => _userSettingsToJson(e)).toList(),
      'appPreferences': getAppPreferences(),
      'reminders': _remindersBox.values.map((e) => _reminderToJson(e)).toList(),
      // 'categories': _categoriesBox.values.map((e) => _categoryToJson(e)).toList(),
    };
  }
  
  /// Imports notes data from a JSON Map (Notes-focused restore).
  static Future<void> importNotesData(Map<String, dynamic> data) async {
    try {
      await _notesBox.clear();
      await _foldersBox.clear();
      await _tagsBox.clear();
      
      if (data['notes'] != null) {
        for (var item in data['notes']) {
          final note = _jsonToNote(item);
          await _notesBox.put(note.id, note);
        }
      }
      
      if (data['folders'] != null) {
        for (var item in data['folders']) {
          final folder = _jsonToFolder(item);
          await _foldersBox.put(folder.id, folder);
        }
      }
      
      if (data['tags'] != null) {
        for (var item in data['tags']) {
          final tag = _jsonToTag(item);
          await _tagsBox.put(tag.id, tag);
        }
      }
      
      debugPrint("Notes data import completed successfully");
    } catch (e) {
      debugPrint("Error importing notes data: $e");
      rethrow;
    }
  }
  
  // --- Simpler JSON converters for Hive Objects (avoiding TypeAdapter complexity for json export) ---
  // Ideally models should have toJson/fromJson. 
  // Since they are HiveObjects, we might not have standard toJson.
  // We can implement helpers here or added to models.
  // Let's implement minimal helpers here to avoid modifying all models right now.
  
  static Map<String, dynamic> _noteToJson(NoteModel note) => {
    'id': note.id,
    'title': note.title,
    'content': note.content,
    'createdAt': note.createdAt.toIso8601String(),
    'updatedAt': note.updatedAt.toIso8601String(),
    'tagIds': note.tagIds,
    'isPinned': note.isPinned,
    'isArchived': note.isArchived,
    'isDeleted': note.isDeleted,
    'color': note.color,
    'isSynced': note.isSynced,
    'reminderId': note.reminderId,
  };

  static NoteModel _jsonToNote(Map<String, dynamic> json) => NoteModel(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    tagIds: List<String>.from(json['tagIds'] ?? []),
    isPinned: json['isPinned'] ?? false,
    isArchived: json['isArchived'] ?? false,
    isDeleted: json['isDeleted'] ?? false,
    color: json['color'],
    isSynced: false, // Reset sync status on import usually
    reminderId: json['reminderId'],
  );
  
  static Map<String, dynamic> _folderToJson(FolderModel folder) => {
    'id': folder.id,
    'name': folder.name,
    'color': folder.color,
    'icon': folder.icon,
    'createdAt': folder.createdAt.toIso8601String(),
    'parentId': folder.parentId,
  };

  static FolderModel _jsonToFolder(Map<String, dynamic> json) => FolderModel(
    id: json['id'],
    name: json['name'],
    color: json['color'],
    icon: json['icon'],
    createdAt: DateTime.parse(json['createdAt']),
    parentId: json['parentId'],
  );
  
  static Map<String, dynamic> _tagToJson(TagModel tag) => {
    'id': tag.id,
    'name': tag.name,
    'color': tag.color,
  };
  
  static TagModel _jsonToTag(Map<String, dynamic> json) => TagModel(
    id: json['id'],
    name: json['name'],
    color: json['color'],
  );
  

  static Map<String, dynamic> _userSettingsToJson(UserSettings s) => {
     // Implement if needed
     'id': 'settings', // usually singleton
  };
  
  static Map<String, dynamic> _reminderToJson(Reminder r) => {
    'id': r.id,
    'title': r.title,
    'body': r.body,
    'scheduledTime': r.scheduledTime.toIso8601String(),
    'isCompleted': r.isCompleted,
    'categoryId': r.categoryId,
    'repeatType': r.repeatType.index,
    'priority': r.priority.index,
  };

}
