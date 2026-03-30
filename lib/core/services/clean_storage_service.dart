import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/core_dao.dart';
import '../database/daos/medication_dao.dart';
import '../database/daos/water_dao.dart';
import '../database/daos/finance_dao.dart';
import '../database/daos/notes_dao.dart';
import '../database/daos/reminders_dao.dart';
import '../database/daos/fitness_dao.dart';
import '../database/daos/period_dao.dart';
import '../models/user_settings.dart';
import '../config/env_config.dart';
import '../../features/reminders/models/reminder_model.dart' as ReminderModel;
import '../../features/reminders/models/reminder_category_model.dart' as ReminderCategoryModel;
import '../../features/finance/models/finance_models.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import '../../features/medication/models/medicine.dart';
import '../../features/period_tracking/models/period_data.dart';
import '../../features/fitness/models/fitness_reminder.dart' as FitnessReminderModel;

/// Clean Drift-based storage service - unified storage using Drift DAOs
class CleanStorageService {
  static bool _isInitialized = false;
  static AppDatabase? _database;
  
  // DAO accessors
  static AppDatabase get database {
    _database ??= AppDatabase.instance;
    return _database!;
  }
  
  static CoreDao get _coreDao => database.coreDao;
  static MedicationDao get _medicationDao => database.medicationDao;
  static WaterDao get _waterDao => database.waterDao;
  static FinanceDao get _financeDao => database.financeDao;
  static NotesDao get _notesDao => database.notesDao;
  static RemindersDao get _remindersDao => database.remindersDao;
  static FitnessDao get _fitnessDao => database.fitnessDao;
  static PeriodDao get _periodDao => database.periodDao;

  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('CleanStorageService already initialized');
      return;
    }
    
    try {
      _database = AppDatabase.instance;
      debugPrint('✓ Drift database initialized');
      await _initDefaultCategories();
      
      // Load all caches for synchronous access
      await loadAppPreferences();
      await getAllCategoriesAsync();
      await getAllMedicinesAsync();
      await getAllFitnessRemindersAsync();
      await getAllBillsAsync();
      await getAllNotesAsync();
      
      _isInitialized = true;
      debugPrint('✓ CleanStorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing CleanStorageService: $e');
    }
  }

  static Future<void> _initDefaultCategories() async {
    try {
      final db = database;
      // Check if categories already exist
      final existingCategories = await db.select(db.reminderCategories).get();
      
      if (existingCategories.isEmpty) {
        // Insert default categories
        await db.into(db.reminderCategories).insert(ReminderCategoriesCompanion.insert(
          id: 'personal',
          name: 'Personal',
          colorValue: 0xFF4CAF50,
          iconCodePoint: 0xe7fd, // Icons.person
        ));
        
        await db.into(db.reminderCategories).insert(ReminderCategoriesCompanion.insert(
          id: 'work', 
          name: 'Work',
          colorValue: 0xFF2196F3,
          iconCodePoint: 0xe89c, // Icons.work
        ));
        
        await db.into(db.reminderCategories).insert(ReminderCategoriesCompanion.insert(
          id: 'health',
          name: 'Health',
          colorValue: 0xFFFF5722,
          iconCodePoint: 0xe3f4, // Icons.health_and_safety
        ));
        
        debugPrint('✓ Default categories created');
      }
    } catch (e) {
      debugPrint('Error creating default categories: $e');
    }
  }
  
  /// Check if this is first launch
  static bool get isFirstLaunch => getAppPreference('isFirstLaunch', true) == true;
  
  static Future<void> setFirstLaunchComplete() async {
    await setAppPreference('isFirstLaunch', false);
  }

  // ============ REMINDERS (cached for sync access) ============
  static final List<ReminderModel.Reminder> _remindersCache = [];
  
  static List<ReminderModel.Reminder> getReminders() {
    return List.unmodifiable(_remindersCache);
  }

  /// Save reminder using Drift
  static Future<void> saveReminder(ReminderModel.Reminder reminder) async {
    try {
      final db = database;
      final companion = RemindersCompanion.insert(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        categoryId: Value(reminder.categoryId),
        scheduledTime: reminder.scheduledTime,
        repeatType: Value(reminder.repeatType.index),
        priority: Value(reminder.priority.index),
        isCompleted: Value(reminder.isCompleted),
        createdAt: reminder.createdAt,
        updatedAt: reminder.updatedAt,
      );
      
      await db.into(db.reminders).insert(companion);
      debugPrint('✓ Reminder saved: ${reminder.title}');
    } catch (e) {
      debugPrint('Error saving reminder: $e');
    }
  }

  /// Get all active reminders using Drift (async version that updates cache)
  static Future<List<ReminderModel.Reminder>> getAllReminders() async {
    try {
      final db = database;
      final reminderRows = await db.select(db.reminders).get();
      
      // Convert Drift rows to model objects
      final reminders = reminderRows.map((row) {
        return ReminderModel.Reminder(
          id: row.id,
          title: row.title,
          body: row.body,
          categoryId: row.categoryId,
          scheduledTime: row.scheduledTime,
          repeatType: ReminderModel.RepeatType.values[row.repeatType],
          priority: ReminderModel.ReminderPriority.values[row.priority],
          isCompleted: row.isCompleted,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }).toList();
      
      _remindersCache.clear();
      _remindersCache.addAll(reminders);
      return reminders;
    } catch (e) {
      debugPrint('Error getting reminders: $e');
      return [];
    }
  }

  /// Delete reminder using Drift
  static Future<void> deleteReminder(String reminderId) async {
    try {
      final db = database;
      await (db.delete(db.reminders)..where((tbl) => tbl.id.equals(reminderId))).go();
      debugPrint('✓ Reminder deleted: $reminderId');
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
    }
  }

  /// Get all reminder categories using Drift (cached for sync access)
  static final List<ReminderCategoryModel.ReminderCategory> _categoriesCache = [];
  
  static List<ReminderCategoryModel.ReminderCategory> getAllCategories() {
    return List.unmodifiable(_categoriesCache);
  }
  
  static Future<List<ReminderCategoryModel.ReminderCategory>> getAllCategoriesAsync() async {
    try {
      final db = database;
      final categoryRows = await db.select(db.reminderCategories).get();
      
      // Convert Drift rows to model objects
      final categories = categoryRows.map((row) {
        return ReminderCategoryModel.ReminderCategory(
          id: row.id,
          name: row.name,
          color: row.colorValue,
          icon: row.iconCodePoint,
        );
      }).toList();
      
      _categoriesCache.clear();
      _categoriesCache.addAll(categories);
      return categories;
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }
  
  static List<Bill> filterByCategory(String categoryId) {
    return _billsCache.where((b) => b.categoryId == categoryId).toList();
  }

  /// Toggle reminder completion
  static Future<void> toggleReminderCompletion(ReminderModel.Reminder reminder) async {
    try {
      final db = database;
      await (db.update(db.reminders)..where((tbl) => tbl.id.equals(reminder.id)))
          .write(RemindersCompanion(
        isCompleted: Value(!reminder.isCompleted),
        updatedAt: Value(DateTime.now()),
      ));
      debugPrint('✓ Reminder completion toggled: ${reminder.id}');
    } catch (e) {
      debugPrint('Error toggling reminder completion: $e');
    }
  }

  // ============ APP PREFERENCES (using CoreDao) ============
  static final Map<String, dynamic> _appPreferencesCache = {};
  
  static Map<String, dynamic> getAppPreferences() {
    return Map<String, dynamic>.from(_appPreferencesCache);
  }
  
  static Future<void> setAppPreference(String key, dynamic value) async {
    _appPreferencesCache[key] = value;
    try {
      if (value is bool) {
        await _coreDao.setBoolPreference(key, value);
      } else if (value is int) {
        await _coreDao.setIntPreference(key, value);
      } else {
        await _coreDao.setPreference(key, value?.toString());
      }
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }
  
  static dynamic getAppPreference(String key, [dynamic defaultValue]) {
    return _appPreferencesCache[key] ?? defaultValue;
  }
  
  static Future<void> loadAppPreferences() async {
    try {
      final prefs = await _coreDao.getAllPreferences();
      _appPreferencesCache.addAll(prefs);
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }
  
  // ============ FITNESS REMINDERS (using FitnessDao) ============
  static List<FitnessReminderModel.FitnessReminder> getAllFitnessReminders() {
    // Return cached list synchronously - use async version for fresh data
    return _fitnessRemindersModelCache;
  }
  
  static final List<FitnessReminderModel.FitnessReminder> _fitnessRemindersModelCache = [];
  
  static Future<List<FitnessReminderModel.FitnessReminder>> getAllFitnessRemindersAsync() async {
    try {
      final driftReminders = await _fitnessDao.getAllReminders();
      // Convert Drift types to model types
      final modelReminders = driftReminders.map((r) => FitnessReminderModel.FitnessReminder(
        id: r.id,
        type: r.fitnessType,
        title: r.title,
        reminderTime: r.scheduledTime,
        frequency: 'daily', // Default - repeatDaysJson would need parsing
        durationMinutes: r.durationMinutes,
        isEnabled: r.isEnabled,
      )).toList();
      _fitnessRemindersModelCache.clear();
      _fitnessRemindersModelCache.addAll(modelReminders);
      return modelReminders;
    } catch (e) {
      debugPrint('Error getting fitness reminders: $e');
      return [];
    }
  }
  
  static Future<void> addFitnessReminder(FitnessRemindersCompanion reminder) async {
    try {
      await _fitnessDao.addReminder(reminder);
      await getAllFitnessRemindersAsync(); // Refresh cache
    } catch (e) {
      debugPrint('Error adding fitness reminder: $e');
    }
  }
  
  static Future<void> saveFitnessReminder(FitnessReminderModel.FitnessReminder reminder) async {
    try {
      final companion = FitnessRemindersCompanion(
        id: Value(reminder.id),
        title: Value(reminder.title),
        fitnessType: Value(reminder.type),
        scheduledTime: Value(reminder.reminderTime),
        durationMinutes: Value(reminder.durationMinutes),
        isEnabled: Value(reminder.isEnabled),
      );
      await _fitnessDao.updateReminder(companion);
      await getAllFitnessRemindersAsync();
    } catch (e) {
      debugPrint('Error saving fitness reminder: $e');
    }
  }
  
  static Future<void> deleteFitnessReminder(String id) async {
    try {
      await _fitnessDao.deleteReminder(id);
      await getAllFitnessRemindersAsync();
    } catch (e) {
      debugPrint('Error deleting fitness reminder: $e');
    }
  }
  
  /// Add fitness reminder from model object
  static Future<void> addFitnessReminderFromModel(FitnessReminderModel.FitnessReminder reminder) async {
    try {
      final companion = FitnessRemindersCompanion.insert(
        id: reminder.id,
        title: reminder.title,
        fitnessType: Value(reminder.type),
        scheduledTime: reminder.reminderTime,
        durationMinutes: Value(reminder.durationMinutes),
        isEnabled: Value(reminder.isEnabled),
        createdAt: DateTime.now(),
      );
      await _fitnessDao.addReminder(companion);
      await getAllFitnessRemindersAsync();
    } catch (e) {
      debugPrint('Error adding fitness reminder: $e');
    }
  }
  
  // ============ MEDICINES (using MedicationDao) ============
  static final List<EnhancedMedicine> _medicinesCache = [];
  
  static List<EnhancedMedicine> getAllMedicines() {
    return List.unmodifiable(_medicinesCache);
  }
  
  static Future<List<EnhancedMedicine>> getAllMedicinesAsync() async {
    try {
      final medicines = await _medicationDao.getAllMedicines();
      _medicinesCache.clear();
      _medicinesCache.addAll(medicines);
      return medicines;
    } catch (e) {
      debugPrint('Error getting medicines: $e');
      return [];
    }
  }
  
  static Future<EnhancedMedicine?> getMedicineAsync(String id) async {
    return await _medicationDao.getMedicine(id);
  }
  
  static EnhancedMedicine? getMedicine(String id) {
    try {
      return _medicinesCache.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> addMedicine(EnhancedMedicinesCompanion medicine) async {
    try {
      await _medicationDao.addMedicine(medicine);
      await getAllMedicinesAsync();
    } catch (e) {
      debugPrint('Error adding medicine: $e');
    }
  }
  
  static Future<void> updateMedicine(EnhancedMedicinesCompanion medicine) async {
    try {
      await _medicationDao.updateMedicine(medicine);
      await getAllMedicinesAsync();
    } catch (e) {
      debugPrint('Error updating medicine: $e');
    }
  }
  
  static Future<void> deleteMedicine(String id) async {
    try {
      await _medicationDao.deleteMedicine(id);
      await getAllMedicinesAsync();
    } catch (e) {
      debugPrint('Error deleting medicine: $e');
    }
  }
  
  /// Add medicine from model object (for cloud sync compatibility)
  static Future<void> addMedicineFromModel(Medicine medicine) async {
    // Store in cache for now - full Drift integration would convert to Companion
    debugPrint('Adding medicine from model: ${medicine.name}');
  }
  
  // ============ REMINDERS (using RemindersDao) ============
  static Future<void> updateReminder(RemindersCompanion reminder) async {
    try {
      await _remindersDao.updateReminder(reminder);
    } catch (e) {
      debugPrint('Error updating reminder: $e');
    }
  }
  
  static Future<void> saveSyncedReminder(RemindersCompanion reminder) async {
    try {
      await _remindersDao.saveReminder(reminder);
    } catch (e) {
      debugPrint('Error saving synced reminder: $e');
    }
  }
  
  /// Save synced reminder from model object (for cloud sync)
  static Future<void> saveSyncedReminderFromModel(ReminderModel.Reminder reminder) async {
    try {
      final companion = RemindersCompanion.insert(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        categoryId: Value(reminder.categoryId),
        scheduledTime: reminder.scheduledTime,
        repeatType: Value(reminder.repeatType.index),
        priority: Value(reminder.priority.index),
        isCompleted: Value(reminder.isCompleted),
        createdAt: reminder.createdAt,
        updatedAt: reminder.updatedAt,
      );
      await _remindersDao.saveReminder(companion);
      await getAllReminders(); // Refresh cache
    } catch (e) {
      debugPrint('Error saving synced reminder from model: $e');
    }
  }
  
  static Future<void> deleteSyncedReminder(String id) async {
    try {
      await _remindersDao.deleteReminder(id);
    } catch (e) {
      debugPrint('Error deleting synced reminder: $e');
    }
  }
  
  // ============ PERIOD TRACKING (using PeriodDao) ============
  static PeriodDataData? _periodDataCache;
  
  static PeriodDataData? getPeriodData() => _periodDataCache;
  
  static Future<PeriodDataData?> getPeriodDataAsync() async {
    try {
      _periodDataCache = await _periodDao.getPeriodData();
      return _periodDataCache;
    } catch (e) {
      debugPrint('Error getting period data: $e');
      return null;
    }
  }
  
  static Future<void> savePeriodData(PeriodDataCompanion data) async {
    try {
      await _periodDao.savePeriodData(data);
      await getPeriodDataAsync();
    } catch (e) {
      debugPrint('Error saving period data: $e');
    }
  }
  
  /// Save period data from model object (for cloud sync compatibility)
  static Future<void> savePeriodDataFromModel(PeriodData data) async {
    debugPrint('Saving period data from model');
  }
  
  static Future<PeriodRemindersTableData?> getPeriodReminder() async {
    return await _periodDao.getPeriodReminder();
  }
  
  static Future<CycleLog?> getCurrentCycle() async {
    return await _periodDao.getCurrentCycle();
  }
  
  static Future<List<CycleLog>> getAllCycles() async {
    return await _periodDao.getAllCycleLogs();
  }
  
  static Future<SymptomLog?> getSymptomLogForDate(DateTime date) async {
    return await _periodDao.getSymptomLogForDate(date);
  }
  
  static Future<void> saveSymptomLog(SymptomLogsCompanion log) async {
    try {
      await _periodDao.saveSymptomLog(log);
    } catch (e) {
      debugPrint('Error saving symptom log: $e');
    }
  }
  
  static Future<void> startNewCycle(DateTime date) async {
    try {
      final cycleId = DateTime.now().millisecondsSinceEpoch.toString();
      await _periodDao.saveCycleLog(CycleLogsCompanion.insert(
        id: cycleId,
        startDate: date,
        createdAt: DateTime.now(),
        isComplete: const Value(false),
      ));
    } catch (e) {
      debugPrint('Error starting new cycle: $e');
    }
  }

  // ============ BILLS (using FinanceDao) ============
  static final List<Bill> _billsCache = [];
  
  static List<Bill> getActiveBills() => _billsCache.where((b) => !b.isArchived).toList();
  static List<Bill> getArchivedBills() => _billsCache.where((b) => b.isArchived).toList();
  
  static Future<List<Bill>> getAllBillsAsync() async {
    try {
      final bills = await _financeDao.getAllBills();
      _billsCache.clear();
      _billsCache.addAll(bills);
      return bills;
    } catch (e) {
      debugPrint('Error getting bills: $e');
      return [];
    }
  }
  
  static Future<Bill?> getBillAsync(String id) async {
    return await _financeDao.getBill(id);
  }
  
  static Bill? getBill(String id) {
    try {
      return _billsCache.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> saveBill(BillsCompanion bill) async {
    try {
      await _financeDao.saveBill(bill);
      await getAllBillsAsync();
    } catch (e) {
      debugPrint('Error saving bill: $e');
    }
  }
  
  static Future<void> deleteBill(String id) async {
    try {
      await _financeDao.deleteBill(id);
      await getAllBillsAsync();
    } catch (e) {
      debugPrint('Error deleting bill: $e');
    }
  }

  // Bill helper methods for dashboard
  static List<Bill> getOverdueBills() {
    final now = DateTime.now();
    return _billsCache.where((b) => !b.isArchived && b.dueDate.isBefore(now) && b.paidAmount < b.amount).toList();
  }
  
  static List<Bill> getDueTodayBills() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return _billsCache.where((b) => !b.isArchived && b.dueDate.isAfter(today) && b.dueDate.isBefore(tomorrow)).toList();
  }
  
  static List<Bill> getUpcomingBills({int days = 30}) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    return _billsCache.where((b) => !b.isArchived && b.dueDate.isAfter(now) && b.dueDate.isBefore(endDate)).toList();
  }
  
  static double getTotalUpcoming({int days = 30}) {
    return getUpcomingBills(days: days).fold(0.0, (sum, b) => sum + b.amount - b.paidAmount);
  }
  
  static double getTotalOverdue() {
    return getOverdueBills().fold(0.0, (sum, b) => sum + b.amount - b.paidAmount);
  }
  
  static double getPaidThisMonth() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _billsCache.where((b) => b.paidAmount >= b.amount && b.updatedAt.isAfter(monthStart))
        .fold(0.0, (sum, b) => sum + b.paidAmount);
  }
  
  static List<Bill> getPaidBills({DateTime? fromDate}) {
    return _billsCache.where((b) {
      if (b.paidAmount < b.amount) return false;
      if (fromDate != null && b.updatedAt.isBefore(fromDate)) return false;
      return true;
    }).toList();
  }
  
  static Future<void> markBillAsPaid(String billId) async {
    final bill = getBill(billId);
    if (bill != null) {
      await saveBill(BillsCompanion(
        id: Value(bill.id),
        name: Value(bill.name),
        amount: Value(bill.amount),
        dueDate: Value(bill.dueDate),
        status: Value(bill.status),
        paidAmount: Value(bill.amount),
        updatedAt: Value(DateTime.now()),
        createdAt: Value(bill.createdAt),
      ));
    }
  }
  
  static Future<List<BillCategory>> getAllBillCategories() async {
    return await _financeDao.getAllCategories();
  }
  
  static Future<BillCategory?> getBillCategory(String id) async {
    return await _financeDao.getCategory(id);
  }
  
  /// Add Bill from model object (for UI compatibility)
  static Future<void> saveBillFromModel(FinanceBill bill) async {
    try {
      final companion = BillsCompanion.insert(
        id: bill.id,
        name: bill.name,
        amount: bill.amount,
        dueDate: bill.dueDate,
        status: bill.status.index,
        paidAmount: Value(bill.paidAmount),
        createdAt: bill.createdAt,
        updatedAt: bill.updatedAt,
      );
      await _financeDao.addBill(companion);
      await getAllBills(); // Refresh cache
    } catch (e) {
      debugPrint('Error saving bill from model: $e');
    }
  }
  
  /// Convert Drift Bill to Model FinanceBill
  static List<FinanceBill> getBillsAsModels() {
    return _billsCache.map((driftBill) => FinanceBill(
      id: driftBill.id,
      name: driftBill.name,
      amount: driftBill.amount,
      dueDate: driftBill.dueDate,
      status: BillStatus.values[driftBill.status],
      recurrence: BillRecurrence.monthly,
      paidAmount: driftBill.paidAmount,
      colorValue: 0xFF2196F3,
      iconCodePoint: 0xe047,
      createdAt: driftBill.createdAt,
      updatedAt: driftBill.updatedAt,
    )).toList();
  }
  
  /// Duplicate bill (for UI compatibility)
  static Future<void> duplicateBill(FinanceBill originalBill) async {
    try {
      final newBill = FinanceBill(
        id: const Uuid().v4(),
        name: '${originalBill.name} (Copy)',
        amount: originalBill.amount,
        dueDate: originalBill.dueDate.add(const Duration(days: 30)),
        status: BillStatus.upcoming,
        recurrence: originalBill.recurrence,
        categoryId: originalBill.categoryId,
        accountId: originalBill.accountId,
        note: originalBill.note,
        tags: originalBill.tags,
        paidAmount: 0,
        colorValue: originalBill.colorValue,
        iconCodePoint: originalBill.iconCodePoint,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await saveBillFromModel(newBill);
    } catch (e) {
      debugPrint('Error duplicating bill: $e');
    }
  }
  
  /// Bills listenable (stub for compatibility)
  static ValueNotifier<List<FinanceBill>>? get billsListenable {
    // TODO: Implement proper ValueNotifier for reactive UI updates
    return null;
  }
  
  /// Get all bills as Future (for compatibility)
  static Future<List<FinanceBill>> getAllBills() async {
    await getAllBillsAsync(); // Refresh cache
    return getBillsAsModels();
  }
  
  /// Filter bills by date range
  static List<FinanceBill> filterByDateRange(DateTime start, DateTime end) {
    return getBillsAsModels().where((bill) {
      return bill.dueDate.isAfter(start.subtract(const Duration(days: 1))) &&
             bill.dueDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
  
  /// Get monthly total
  static double getMonthlyTotal(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    return filterByDateRange(monthStart, monthEnd)
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }
  
  /// Get yearly total
  static double getYearlyTotal(int year) {
    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);
    return filterByDateRange(yearStart, yearEnd)
        .fold(0.0, (sum, bill) => sum + bill.amount);
  }
  
  /// Get on-time payment percentage
  static double getOnTimePaymentPercentage() {
    final bills = getBillsAsModels();
    if (bills.isEmpty) return 0.0;
    
    final paidOnTime = bills.where((b) => 
      b.status == BillStatus.paid && 
      b.paidAmount >= b.amount).length;
    return (paidOnTime / bills.length) * 100;
  }
  
  /// Get largest bill
  static FinanceBill? getLargestBill() {
    final bills = getBillsAsModels();
    if (bills.isEmpty) return null;
    
    return bills.reduce((a, b) => a.amount > b.amount ? a : b);
  }
  
  /// Get bill by ID as Model (for UI compatibility)
  static FinanceBill? getBillAsModel(String id) {
    return getBillsAsModels().where((bill) => bill.id == id).firstOrNull;
  }
  
  /// Get category by ID (stub for compatibility)
  static dynamic getCategoryById(String categoryId) {
    // TODO: Implement category lookup with Drift
    debugPrint('Category lookup temporarily disabled - Drift migration needed');
    return null;
  }
  
  /// Get most frequent bill name
  static String getMostFrequentBillName() {
    final bills = getBillsAsModels();
    if (bills.isEmpty) return 'No bills';
    
    final frequency = <String, int>{};
    for (final bill in bills) {
      frequency[bill.name] = (frequency[bill.name] ?? 0) + 1;
    }
    
    var maxCount = 0;
    var mostFrequent = 'No bills';
    frequency.forEach((name, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = name;
      }
    });
    
    return mostFrequent;
  }
  
  /// Save category (stub for compatibility)
  static Future<void> saveCategory(dynamic category) async {
    // TODO: Implement category saving with Drift
    debugPrint('Category saving temporarily disabled - Drift migration needed');
  }
  
  /// Auto archive paid days (stub for compatibility)
  static int get autoArchivePaidDays => 30;
  
  /// Set default reminder days (stub for compatibility)
  static Future<void> setDefaultReminderDays(int days) async {
    // TODO: Implement settings persistence
    debugPrint('Settings persistence temporarily disabled - SharedPreferences migration needed');
  }
  
  /// Set default reminder time (stub for compatibility)
  static Future<void> setDefaultReminderTime(int hour, int minute) async {
    // TODO: Implement settings persistence
    debugPrint('Settings persistence temporarily disabled - SharedPreferences migration needed');
  }
  
  /// Set auto archive paid days (stub for compatibility)
  static Future<void> setAutoArchivePaidDays(int days) async {
    // TODO: Implement settings persistence
    debugPrint('Settings persistence temporarily disabled - SharedPreferences migration needed');
  }
  
  /// Delete category (stub for compatibility)
  static Future<void> deleteCategory(String categoryId) async {
    // TODO: Implement category deletion with Drift
    debugPrint('Category deletion temporarily disabled - Drift migration needed');
  }
  
  /// Get payments for bill (stub for compatibility)
  static List<dynamic> getPaymentsForBill(String billId) {
    // TODO: Implement payments with Drift
    debugPrint('Payments functionality temporarily disabled - Drift migration needed');
    return [];
  }
  
  /// Update bill (stub for compatibility)
  static Future<void> updateBill(FinanceBill bill) async {
    // TODO: Implement bill updates with Drift
    debugPrint('Bill updates temporarily disabled - Drift migration needed');
  }
  
  /// Archive bill (stub for compatibility)
  static Future<void> archiveBill(String billId) async {
    // TODO: Implement bill archiving with Drift
    debugPrint('Bill archiving temporarily disabled - Drift migration needed');
  }
  
  /// Unarchive bill (stub for compatibility)
  static Future<void> unarchiveBill(String billId) async {
    // TODO: Implement bill unarchiving with Drift
    debugPrint('Bill unarchiving temporarily disabled - Drift migration needed');
  }
  
  /// Add payment (stub for compatibility)
  static Future<void> addPayment(dynamic payment) async {
    // TODO: Implement payments with Drift
    debugPrint('Payment addition temporarily disabled - Drift migration needed');
  }
  
  /// Update payment (stub for compatibility)
  static Future<void> updatePayment(dynamic payment) async {
    // TODO: Implement payments with Drift
    debugPrint('Payment updates temporarily disabled - Drift migration needed');
  }
  
  /// Delete payment (stub for compatibility)
  static Future<void> deletePayment(String paymentId) async {
    // TODO: Implement payments with Drift
    debugPrint('Payment deletion temporarily disabled - Drift migration needed');
  }
  

  // ============ FINANCE ACCOUNTS (in-memory, no Drift tables yet) ============
  static final List<FinanceAccount> _accountsCache = [];
  
  static List<FinanceAccount> getAllAccounts() => List.unmodifiable(_accountsCache);
  
  static double getTotalBalance() {
    return _accountsCache.where((a) => a.includeInTotal && !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance);
  }
  
  static Future<void> addAccount(FinanceAccount account) async {
    _accountsCache.add(account);
  }
  
  static Future<void> updateAccount(FinanceAccount account) async {
    final index = _accountsCache.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      _accountsCache[index] = account;
    }
  }
  
  static Future<void> deleteAccount(String id) async {
    _accountsCache.removeWhere((a) => a.id == id);
  }

  // ============ BUDGETS (in-memory, no Drift tables yet) ============
  static final List<FinanceBudget> _budgetsCache = [];
  
  static List<FinanceBudget> getAllBudgets() => List.unmodifiable(_budgetsCache);
  
  static Future<void> addBudget(FinanceBudget budget) async {
    _budgetsCache.add(budget);
  }
  
  static Future<void> updateBudget(FinanceBudget budget) async {
    final index = _budgetsCache.indexWhere((b) => b.id == budget.id);
    if (index >= 0) {
      _budgetsCache[index] = budget;
    }
  }
  
  static Future<void> deleteBudget(String id) async {
    _budgetsCache.removeWhere((b) => b.id == id);
  }
  
  static List<FinanceCategory> getExpenseCategories() => FinanceCategory.getDefaultCategories()
      .where((c) => !c.isIncome).toList();
  
  static List<FinanceCategory> getIncomeCategories() => FinanceCategory.getDefaultCategories()
      .where((c) => c.isIncome).toList();

  // ============ TRANSACTIONS (in-memory, no Drift tables yet) ============
  static final List<FinanceTransaction> _transactionsCache = [];
  
  static List<FinanceTransaction> getAllTransactions() => List.unmodifiable(_transactionsCache);
  
  static List<FinanceTransaction> getRecentTransactions({int limit = 10}) {
    final sorted = List<FinanceTransaction>.from(_transactionsCache)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }
  
  static double getThisMonthIncome() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _transactionsCache.where((t) => t.isIncome && t.date.isAfter(monthStart))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  
  static double getThisMonthExpenses() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _transactionsCache.where((t) => !t.isIncome && t.date.isAfter(monthStart))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  
  static List<FinanceTransaction> getTransactionsForAccount(String accountId) {
    return _transactionsCache.where((t) => t.accountId == accountId).toList();
  }
  
  static Future<void> addTransaction(FinanceTransaction transaction) async {
    _transactionsCache.add(transaction);
  }
  
  static Future<void> updateTransaction(FinanceTransaction transaction) async {
    final index = _transactionsCache.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      _transactionsCache[index] = transaction;
    }
  }
  
  static Future<void> deleteTransaction(String id) async {
    _transactionsCache.removeWhere((t) => t.id == id);
  }
  
  static FinanceCategory? getCategory(String id) {
    try {
      return FinanceCategory.getDefaultCategories().firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // ============ NOTES (using NotesDao) ============
  static final List<Note> _notesCache = [];
  
  static List<Note> getAllNotes() => List.unmodifiable(_notesCache);
  
  static Future<List<Note>> getAllNotesAsync() async {
    try {
      final notes = await _notesDao.getAllNotes();
      _notesCache.clear();
      _notesCache.addAll(notes);
      return notes;
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }
  
  static Note? getNote(String id) {
    try {
      return _notesCache.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> saveNote(NotesCompanion note) async {
    try {
      await _notesDao.saveNote(note);
      await getAllNotesAsync();
    } catch (e) {
      debugPrint('Error saving note: $e');
    }
  }
  
  static Future<void> deleteNote(String id) async {
    try {
      await _notesDao.deleteNote(id);
      await getAllNotesAsync();
    } catch (e) {
      debugPrint('Error deleting note: $e');
    }
  }
  
  static Future<List<Tag>> getAllTagsAsync() async {
    return await _notesDao.getAllTags();
  }
  
  static Future<void> saveTag(TagsCompanion tag) async {
    try {
      await _notesDao.saveTag(tag);
    } catch (e) {
      debugPrint('Error saving tag: $e');
    }
  }
  
  static Future<void> deleteTag(String id) async {
    try {
      await _notesDao.deleteTag(id);
    } catch (e) {
      debugPrint('Error deleting tag: $e');
    }
  }
  
  static Future<List<Folder>> getAllFoldersAsync() async {
    return await _notesDao.getAllFolders();
  }
  
  static Future<void> saveFolder(FoldersCompanion folder) async {
    try {
      await _notesDao.saveFolder(folder);
    } catch (e) {
      debugPrint('Error saving folder: $e');
    }
  }
  
  static Future<void> deleteFolder(String id) async {
    try {
      await _notesDao.deleteFolder(id);
    } catch (e) {
      debugPrint('Error deleting folder: $e');
    }
  }

  // ============ WATER (using WaterDao) ============
  static Future<void> saveWaterReminder(dynamic reminder) async {
    debugPrint('Save water reminder: ${reminder.toString()}');
  }
  
  static Future<DailyWaterDataTableData?> getWaterReminder() async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return await _waterDao.getDailyData(dateKey);
  }

  // ============ UTILITY METHODS ============
  static bool get isInitialized => _isInitialized;
  static int get defaultReminderDays => 3;
  static int get defaultReminderHour => 9;
  static int get defaultReminderMinute => 0;
  
  static UserSettings getUserSettings() {
    return UserSettings(
      darkModeEnabled: getAppPreference('darkMode', false) == true,
      soundEnabled: getAppPreference('soundEnabled', true) == true,
      vibrationEnabled: getAppPreference('vibrationEnabled', true) == true,
      snoozeIntervalMinutes: getAppPreference('snoozeInterval', 5) as int? ?? 5,
      snoozeEnabled: getAppPreference('snoozeEnabled', true) == true,
    );
  }
  
  static Future<void> saveUserSettings(UserSettings settings) async {
    await setAppPreference('darkMode', settings.darkModeEnabled);
    await setAppPreference('soundEnabled', settings.soundEnabled);
    await setAppPreference('vibrationEnabled', settings.vibrationEnabled);
    await setAppPreference('snoozeInterval', settings.snoozeIntervalMinutes);
    await setAppPreference('snoozeEnabled', settings.snoozeEnabled);
  }
  
  static Map<String, dynamic> exportAllData() {
    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'medicines': _medicinesCache.map((m) => {'id': m.id, 'name': m.name}).toList(),
      'fitnessReminders': _fitnessRemindersModelCache.map((r) => {'id': r.id}).toList(),
      'notes': _notesCache.map((n) => {'id': n.id, 'title': n.title}).toList(),
      'bills': _billsCache.map((b) => {'id': b.id, 'name': b.name}).toList(),
    };
  }
  
  static Future<void> clearAllData() async {
    _medicinesCache.clear();
    _fitnessRemindersModelCache.clear();
    _notesCache.clear();
    _billsCache.clear();
    _periodDataCache = null;
    _appPreferencesCache.clear();
    debugPrint('✓ All cached data cleared');
  }
  
  static Future<void> importData(Map<String, dynamic> data) async {
    debugPrint('Import data: ${data.keys}');
  }
  

  /// Close the database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
      debugPrint('✓ CleanStorageService closed');
    }
  }
}
