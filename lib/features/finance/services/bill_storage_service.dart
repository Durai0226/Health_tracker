import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import 'finance_cloud_service.dart';

class BillStorageService {
  static const String _billsBoxName = 'finance_bills_v1';
  static const String _paymentsBoxName = 'finance_bill_payments_v1';
  static const String _categoriesBoxName = 'finance_bill_categories_v1';
  static const String _settingsBoxName = 'finance_bill_settings_v1';

  static bool _isInitialized = false;
  static bool _isInitializing = false;

  static bool get isInitialized => _isInitialized;

  static Box<Bill>? _billsBox;
  static Box<BillPayment>? _paymentsBox;
  static Box<BillCategory>? _categoriesBox;
  static Box<dynamic>? _settingsBox;

  static Future<void> init() async {
    if (_isInitialized) {
      debugPrint('✓ BillStorageService already initialized');
      return;
    }

    if (_isInitializing) {
      debugPrint('⏳ BillStorageService initialization in progress, waiting...');
      int attempts = 0;
      while (_isInitializing && attempts < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_isInitialized) return;
      if (_isInitializing) {
        throw Exception('BillStorageService initialization timeout');
      }
    }

    _isInitializing = true;
    debugPrint('🚀 Starting BillStorageService initialization...');

    try {
      _safeRegisterAdapter(BillStatusAdapter());
      _safeRegisterAdapter(BillRecurrenceAdapter());
      _safeRegisterAdapter(CustomRecurrenceUnitAdapter());
      _safeRegisterAdapter(ReminderTypeAdapter());
      _safeRegisterAdapter(BillPriorityAdapter());
      _safeRegisterAdapter(AdvancedRecurrenceTypeAdapter());
      _safeRegisterAdapter(BillActivityTypeAdapter());
      _safeRegisterAdapter(BillAdapter());
      _safeRegisterAdapter(BillReminderAdapter());
      _safeRegisterAdapter(BillPaymentAdapter());
      _safeRegisterAdapter(BillCategoryAdapter());
      debugPrint('✓ Bill adapters registered');

      _billsBox = await _safeOpenBox<Bill>(_billsBoxName);
      _paymentsBox = await _safeOpenBox<BillPayment>(_paymentsBoxName);
      _categoriesBox = await _safeOpenBox<BillCategory>(_categoriesBoxName);
      _settingsBox = await _safeOpenBox<dynamic>(_settingsBoxName);

      await _initDefaultCategories();
      await _initDefaultSettings();
      await _recalculateAllStatuses();

      _isInitialized = true;
      _isInitializing = false;
      debugPrint('✓ BillStorageService initialized successfully');
    } catch (e, stackTrace) {
      _isInitializing = false;
      debugPrint('❌ Error initializing BillStorageService: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
      debugPrint('  📝 Registered adapter: ${adapter.runtimeType} (typeId: ${adapter.typeId})');
    }
  }

  static Future<Box<T>> _safeOpenBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<T>(boxName);
      }
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      debugPrint('⚠️ Error opening box $boxName, attempting recovery: $e');
      await Hive.deleteBoxFromDisk(boxName);
      return await Hive.openBox<T>(boxName);
    }
  }

  static Future<void> _initDefaultCategories() async {
    if (_categoriesBox == null || _categoriesBox!.isNotEmpty) return;

    final defaults = BillCategory.defaults;
    for (final category in defaults) {
      await _categoriesBox!.put(category.id, category);
    }
    debugPrint('✓ Default bill categories initialized');
  }

  static Future<void> _initDefaultSettings() async {
    if (_settingsBox == null) return;

    if (!_settingsBox!.containsKey('defaultReminderDays')) {
      await _settingsBox!.put('defaultReminderDays', 3);
    }
    if (!_settingsBox!.containsKey('defaultReminderHour')) {
      await _settingsBox!.put('defaultReminderHour', 9);
    }
    if (!_settingsBox!.containsKey('defaultReminderMinute')) {
      await _settingsBox!.put('defaultReminderMinute', 0);
    }
    if (!_settingsBox!.containsKey('autoArchivePaidDays')) {
      await _settingsBox!.put('autoArchivePaidDays', 30);
    }
    debugPrint('✓ Default bill settings initialized');
  }

  // ==================== BILLS CRUD ====================

  static List<Bill> getAllBills() {
    if (_billsBox == null) return [];
    return _billsBox!.values.where((b) => !b.isDeleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  static List<Bill> getActiveBills() {
    return getAllBills()
        .where((b) => !b.isArchived && b.status != BillStatus.cancelled)
        .toList();
  }

  static List<Bill> getUpcomingBills({int days = 7}) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    return getActiveBills().where((b) {
      return b.dueDate.isAfter(now) &&
          b.dueDate.isBefore(endDate) &&
          b.status != BillStatus.paid;
    }).toList();
  }

  static List<Bill> getDueTodayBills() {
    return getActiveBills().where((b) => b.isDueToday && !b.isFullyPaid).toList();
  }

  static List<Bill> getOverdueBills() {
    return getActiveBills()
        .where((b) => b.status == BillStatus.overdue || b.isOverdue)
        .toList();
  }

  static List<Bill> getPaidBills({DateTime? fromDate, DateTime? toDate}) {
    var bills = getAllBills().where((b) => b.status == BillStatus.paid);
    if (fromDate != null) {
      bills = bills.where((b) => b.updatedAt.isAfter(fromDate));
    }
    if (toDate != null) {
      bills = bills.where((b) => b.updatedAt.isBefore(toDate));
    }
    return bills.toList();
  }

  static List<Bill> getArchivedBills() {
    if (_billsBox == null) return [];
    return _billsBox!.values
        .where((b) => b.isArchived && !b.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Bill? getBill(String id) {
    return _billsBox?.get(id);
  }

  static Future<void> saveBill(Bill bill) async {
    if (_billsBox == null) return;

    bill.status = bill.calculateStatus();
    await _billsBox!.put(bill.id, bill);
    await _syncBillToCloud(bill);
    debugPrint('✓ Bill saved: ${bill.name}');
  }

  static Future<void> updateBill(Bill bill) async {
    bill.status = bill.calculateStatus();
    await saveBill(bill.copyWith(updatedAt: DateTime.now()));
  }

  static Future<void> deleteBill(String id, {bool soft = true}) async {
    if (_billsBox == null) return;

    final bill = _billsBox!.get(id);
    if (bill == null) return;

    if (soft) {
      await saveBill(bill.copyWith(isDeleted: true, status: BillStatus.cancelled));
    } else {
      await _billsBox!.delete(id);
      await _deletePaymentsForBill(id);
      await _deleteBillFromCloud(id);
    }
    debugPrint('✓ Bill deleted: ${bill.name}');
  }

  static Future<Bill> duplicateBill(String id) async {
    final original = getBill(id);
    if (original == null) throw Exception('Bill not found');

    final duplicate = original.duplicate();
    await saveBill(duplicate);
    return duplicate;
  }

  static Future<void> archiveBill(String id) async {
    final bill = getBill(id);
    if (bill == null) return;

    await saveBill(bill.copyWith(isArchived: true, status: BillStatus.archived));
    debugPrint('✓ Bill archived: ${bill.name}');
  }

  static Future<void> unarchiveBill(String id) async {
    final bill = getBill(id);
    if (bill == null) return;

    final updated = bill.copyWith(isArchived: false);
    updated.status = updated.calculateStatus();
    await saveBill(updated);
    debugPrint('✓ Bill unarchived: ${bill.name}');
  }

  // ==================== PAYMENTS ====================

  static List<BillPayment> getPaymentsForBill(String billId) {
    if (_paymentsBox == null) return [];
    return _paymentsBox!.values
        .where((p) => p.billId == billId)
        .toList()
      ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
  }

  static List<BillPayment> getAllPayments({DateTime? fromDate, DateTime? toDate}) {
    if (_paymentsBox == null) return [];
    var payments = _paymentsBox!.values.toList();

    if (fromDate != null) {
      payments = payments.where((p) => p.paidAt.isAfter(fromDate)).toList();
    }
    if (toDate != null) {
      payments = payments.where((p) => p.paidAt.isBefore(toDate)).toList();
    }

    return payments..sort((a, b) => b.paidAt.compareTo(a.paidAt));
  }

  static Future<BillPayment> addPayment({
    required String billId,
    required double amount,
    String? accountId,
    String? note,
    DateTime? paidAt,
  }) async {
    final bill = getBill(billId);
    if (bill == null) throw Exception('Bill not found');

    final payment = BillPayment(
      billId: billId,
      amount: amount,
      accountId: accountId,
      note: note,
      paidAt: paidAt,
    );

    await _paymentsBox?.put(payment.id, payment);

    final newPaidAmount = bill.paidAmount + amount;
    await updateBill(bill.copyWith(paidAmount: newPaidAmount));

    if (bill.recurrence != BillRecurrence.oneTime && newPaidAmount >= bill.amount) {
      await _generateNextRecurrence(bill);
    }

    await _syncPaymentToCloud(payment);
    debugPrint('✓ Payment added: ₹$amount for ${bill.name}');

    return payment;
  }

  static Future<void> updatePayment(BillPayment payment) async {
    final oldPayment = _paymentsBox?.get(payment.id);
    if (oldPayment == null) return;

    final bill = getBill(payment.billId);
    if (bill == null) return;

    final amountDiff = payment.amount - oldPayment.amount;
    final newPaidAmount = bill.paidAmount + amountDiff;

    await _paymentsBox?.put(payment.id, payment);
    await updateBill(bill.copyWith(paidAmount: newPaidAmount));
    await _syncPaymentToCloud(payment);
  }

  static Future<void> deletePayment(String paymentId) async {
    final payment = _paymentsBox?.get(paymentId);
    if (payment == null) return;

    final bill = getBill(payment.billId);
    if (bill != null) {
      final newPaidAmount = bill.paidAmount - payment.amount;
      await updateBill(bill.copyWith(paidAmount: newPaidAmount.clamp(0, bill.amount)));
    }

    await _paymentsBox?.delete(paymentId);
    await _deletePaymentFromCloud(paymentId);
    debugPrint('✓ Payment deleted');
  }

  static Future<void> _deletePaymentsForBill(String billId) async {
    if (_paymentsBox == null) return;

    final payments = _paymentsBox!.values.where((p) => p.billId == billId).toList();
    for (final payment in payments) {
      await _paymentsBox!.delete(payment.id);
    }
  }

  static Future<void> markBillAsPaid(String billId, {String? accountId}) async {
    final bill = getBill(billId);
    if (bill == null) return;

    final remaining = bill.remainingAmount;
    if (remaining > 0) {
      await addPayment(
        billId: billId,
        amount: remaining,
        accountId: accountId,
      );
    }
  }

  // ==================== CATEGORIES ====================

  static List<BillCategory> getAllCategories() {
    if (_categoriesBox == null) return BillCategory.defaults;
    return _categoriesBox!.values.toList()
      ..sort((a, b) => a.isCustom == b.isCustom ? a.name.compareTo(b.name) : (a.isCustom ? 1 : -1));
  }

  static BillCategory? getCategory(String id) {
    return _categoriesBox?.get(id);
  }

  static Future<void> saveCategory(BillCategory category) async {
    await _categoriesBox?.put(category.id, category);
  }

  static Future<void> deleteCategory(String id) async {
    final category = getCategory(id);
    if (category != null && category.isCustom) {
      await _categoriesBox?.delete(id);
    }
  }

  // ==================== SETTINGS ====================

  static int get defaultReminderDays => _settingsBox?.get('defaultReminderDays') ?? 3;
  static int get defaultReminderHour => _settingsBox?.get('defaultReminderHour') ?? 9;
  static int get defaultReminderMinute => _settingsBox?.get('defaultReminderMinute') ?? 0;
  static int get autoArchivePaidDays => _settingsBox?.get('autoArchivePaidDays') ?? 30;

  static Future<void> setDefaultReminderDays(int days) async {
    await _settingsBox?.put('defaultReminderDays', days);
  }

  static Future<void> setDefaultReminderTime(int hour, int minute) async {
    await _settingsBox?.put('defaultReminderHour', hour);
    await _settingsBox?.put('defaultReminderMinute', minute);
  }

  static Future<void> setAutoArchivePaidDays(int days) async {
    await _settingsBox?.put('autoArchivePaidDays', days);
  }

  // ==================== ANALYTICS ====================

  static double getTotalUpcoming({int days = 30}) {
    return getUpcomingBills(days: days).fold(0.0, (sum, b) => sum + b.remainingAmount);
  }

  static double getTotalOverdue() {
    return getOverdueBills().fold(0.0, (sum, b) => sum + b.remainingAmount);
  }

  static double getMonthlyTotal({DateTime? month}) {
    final targetMonth = month ?? DateTime.now();
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);

    return getAllBills()
        .where((b) =>
            b.dueDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            b.dueDate.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  static double getYearlyTotal({int? year}) {
    final targetYear = year ?? DateTime.now().year;
    return getAllBills()
        .where((b) => b.dueDate.year == targetYear)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  static double getPaidThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return getAllPayments(fromDate: startOfMonth).fold(0.0, (sum, p) => sum + p.amount);
  }

  static double getOnTimePaymentPercentage() {
    final paidBills = getPaidBills();
    if (paidBills.isEmpty) return 100.0;

    int onTime = 0;
    for (final bill in paidBills) {
      final payments = getPaymentsForBill(bill.id);
      if (payments.isNotEmpty) {
        final firstPayment = payments.last;
        if (!firstPayment.paidAt.isAfter(bill.dueDate.add(Duration(days: bill.gracePeriodDays)))) {
          onTime++;
        }
      }
    }

    return (onTime / paidBills.length) * 100;
  }

  static Bill? getLargestBill() {
    final bills = getActiveBills();
    if (bills.isEmpty) return null;
    return bills.reduce((a, b) => a.amount > b.amount ? a : b);
  }

  static Map<String, int> getBillFrequency() {
    final frequency = <String, int>{};
    for (final bill in getAllBills()) {
      frequency[bill.name] = (frequency[bill.name] ?? 0) + 1;
    }
    return frequency;
  }

  static String? getMostFrequentBillName() {
    final frequency = getBillFrequency();
    if (frequency.isEmpty) return null;

    String? mostFrequent;
    int maxCount = 0;
    frequency.forEach((name, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = name;
      }
    });
    return mostFrequent;
  }

  static bool shouldSuggestRecurring(String billName) {
    final count = getBillFrequency()[billName] ?? 0;
    return count >= 3;
  }

  static double getCashFlowWarningThreshold(double currentBalance) {
    final upcoming7Days = getTotalUpcoming(days: 7);
    return currentBalance - upcoming7Days;
  }

  // ==================== STATUS ENGINE ====================

  static Future<void> _recalculateAllStatuses() async {
    if (_billsBox == null) return;

    final bills = _billsBox!.values.where((b) => !b.isDeleted && !b.isArchived).toList();
    for (final bill in bills) {
      final newStatus = bill.calculateStatus();
      if (bill.status != newStatus) {
        await _billsBox!.put(bill.id, bill.copyWith(status: newStatus));
      }
    }

    await _autoArchiveOldPaidBills();
    debugPrint('✓ Bill statuses recalculated');
  }

  static Future<void> _autoArchiveOldPaidBills() async {
    final days = autoArchivePaidDays;
    if (days <= 0) return;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final paidBills = getPaidBills().where((b) => b.updatedAt.isBefore(cutoff));

    for (final bill in paidBills) {
      await archiveBill(bill.id);
    }
  }

  static Future<void> _generateNextRecurrence(Bill bill) async {
    if (bill.recurrence == BillRecurrence.oneTime) return;

    final existingNext = getAllBills().where(
      (b) => b.parentBillId == bill.id && b.status != BillStatus.paid,
    );

    if (existingNext.isNotEmpty) {
      debugPrint('⏭️ Next recurrence already exists for ${bill.name}');
      return;
    }

    final nextBill = bill.createNextRecurrence();
    await saveBill(nextBill);
    debugPrint('✓ Created next recurring bill: ${nextBill.name} due ${nextBill.dueDate}');
  }

  // ==================== SEARCH & FILTER ====================

  static List<Bill> searchBills(String query) {
    if (query.isEmpty) return getActiveBills();

    final lowerQuery = query.toLowerCase();
    return getActiveBills().where((b) {
      return b.name.toLowerCase().contains(lowerQuery) ||
          (b.note?.toLowerCase().contains(lowerQuery) ?? false) ||
          b.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  static List<Bill> filterByDateRange(DateTime start, DateTime end) {
    return getActiveBills().where((b) {
      return b.dueDate.isAfter(start.subtract(const Duration(days: 1))) &&
          b.dueDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  static List<Bill> filterByCategory(String categoryId) {
    return getActiveBills().where((b) => b.categoryId == categoryId).toList();
  }

  static List<Bill> filterByStatus(BillStatus status) {
    return getActiveBills().where((b) => b.status == status).toList();
  }

  // ==================== CLOUD SYNC ====================

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> _syncBillToCloud(Bill bill) async {
    if (_userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('finance_bills')
          .doc(bill.id)
          .set({
            ...bill.toJson(),
            'syncedAt': FieldValue.serverTimestamp(),
            'version': 1,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Failed to sync bill to cloud: $e');
      // Retry mechanism
      await Future.delayed(const Duration(seconds: 2));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('finance_bills')
            .doc(bill.id)
            .set({
              ...bill.toJson(),
              'syncedAt': FieldValue.serverTimestamp(),
              'version': 1,
            }, SetOptions(merge: true));
      } catch (retryError) {
        debugPrint('⚠️ Retry failed for bill sync: $retryError');
      }
    }
  }

  static Future<void> _deleteBillFromCloud(String billId) async {
    if (_userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('finance_bills')
          .doc(billId)
          .delete();
    } catch (e) {
      debugPrint('⚠️ Failed to delete bill from cloud: $e');
      // Retry mechanism
      await Future.delayed(const Duration(seconds: 2));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('finance_bills')
            .doc(billId)
            .delete();
      } catch (retryError) {
        debugPrint('⚠️ Retry failed for bill deletion: $retryError');
      }
    }
  }

  static Future<void> _syncPaymentToCloud(BillPayment payment) async {
    if (_userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('finance_bill_payments')
          .doc(payment.id)
          .set({
            ...payment.toJson(),
            'syncedAt': FieldValue.serverTimestamp(),
            'version': 1,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Failed to sync payment to cloud: $e');
      // Retry mechanism
      await Future.delayed(const Duration(seconds: 2));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('finance_bill_payments')
            .doc(payment.id)
            .set({
              ...payment.toJson(),
              'syncedAt': FieldValue.serverTimestamp(),
              'version': 1,
            }, SetOptions(merge: true));
      } catch (retryError) {
        debugPrint('⚠️ Retry failed for payment sync: $retryError');
      }
    }
  }

  static Future<void> _deletePaymentFromCloud(String paymentId) async {
    if (_userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('finance_bill_payments')
          .doc(paymentId)
          .delete();
    } catch (e) {
      debugPrint('⚠️ Failed to delete payment from cloud: $e');
      // Retry mechanism
      await Future.delayed(const Duration(seconds: 2));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('finance_bill_payments')
            .doc(paymentId)
            .delete();
      } catch (retryError) {
        debugPrint('⚠️ Retry failed for payment deletion: $retryError');
      }
    }
  }

  static Future<void> syncFromCloud() async {
    if (_userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      final billsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('finance_bills')
          .get();

      for (final doc in billsSnapshot.docs) {
        try {
          final cloudBill = Bill.fromJson(doc.data());
          final localBill = getBill(cloudBill.id);

          if (localBill == null || cloudBill.updatedAt.isAfter(localBill.updatedAt)) {
            await _billsBox?.put(cloudBill.id, cloudBill);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing bill ${doc.id}: $e');
        }
      }

      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('finance_bill_payments')
          .get();

      for (final doc in paymentsSnapshot.docs) {
        try {
          final payment = BillPayment.fromJson(doc.data());
          final existingPayment = _paymentsBox?.values
              .where((p) => p.id == payment.id)
              .firstOrNull;
          
          if (existingPayment == null || payment.paidAt.isAfter(existingPayment.paidAt)) {
            await _paymentsBox?.put(payment.id, payment);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing payment ${doc.id}: $e');
        }
      }

      debugPrint('✓ Bills synced from cloud');
    } catch (e) {
      debugPrint('⚠️ Failed to sync from cloud: $e');
    }
  }

  static Stream<QuerySnapshot>? getBillsStream() {
    if (_userId == null || !FinanceCloudService.isUserAuthenticated) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('finance_bills')
        .where('isDeleted', isEqualTo: false)
        .orderBy('dueDate')
        .snapshots();
  }

  // ==================== EXPORT/BACKUP ====================

  static String exportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Name,Amount,Due Date,Status,Category,Paid Amount,Recurrence');

    for (final bill in getAllBills()) {
      final category = getCategory(bill.categoryId ?? '');
      buffer.writeln(
        '${bill.name},${bill.amount},${bill.dueDate.toIso8601String()},${bill.status.displayName},${category?.name ?? 'Uncategorized'},${bill.paidAmount},${bill.recurrence.displayName}',
      );
    }

    return buffer.toString();
  }

  static Map<String, dynamic> exportToJson() {
    return {
      'bills': getAllBills().map((b) => b.toJson()).toList(),
      'payments': getAllPayments().map((p) => p.toJson()).toList(),
      'categories': getAllCategories().map((c) => c.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> importFromJson(Map<String, dynamic> data) async {
    final bills = (data['bills'] as List<dynamic>?)
        ?.map((e) => Bill.fromJson(e as Map<String, dynamic>))
        .toList();

    final payments = (data['payments'] as List<dynamic>?)
        ?.map((e) => BillPayment.fromJson(e as Map<String, dynamic>))
        .toList();

    final categories = (data['categories'] as List<dynamic>?)
        ?.map((e) => BillCategory.fromJson(e as Map<String, dynamic>))
        .toList();

    if (bills != null) {
      for (final bill in bills) {
        await _billsBox?.put(bill.id, bill);
      }
    }

    if (payments != null) {
      for (final payment in payments) {
        await _paymentsBox?.put(payment.id, payment);
      }
    }

    if (categories != null) {
      for (final category in categories) {
        await _categoriesBox?.put(category.id, category);
      }
    }

    debugPrint('✓ Data imported successfully');
  }

  // ==================== CLEANUP ====================

  static Future<void> clearOldPaidBills({int olderThanDays = 365}) async {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    final oldBills = getPaidBills().where((b) => b.updatedAt.isBefore(cutoff));

    for (final bill in oldBills) {
      await deleteBill(bill.id, soft: false);
    }

    debugPrint('✓ Cleared ${oldBills.length} old paid bills');
  }

  static Future<void> resetAll() async {
    await _billsBox?.clear();
    await _paymentsBox?.clear();
    await _categoriesBox?.clear();
    await _initDefaultCategories();
    debugPrint('✓ All bill data reset');
  }

  // ==================== VALUE LISTENABLES ====================

  static ValueListenable<Box<Bill>>? get billsListenable => _billsBox?.listenable();
  static ValueListenable<Box<BillPayment>>? get paymentsListenable => _paymentsBox?.listenable();

  // ==================== CLOUD SYNC METHODS ====================

  static Future<bool> syncToCloud() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated for bills cloud sync');
      return false;
    }

    try {
      final bills = getAllBills().where((b) => !b.isDeleted);
      final payments = getAllPayments();
      
      for (final bill in bills) {
        await _syncBillToCloud(bill);
      }
      
      for (final payment in payments) {
        await _syncPaymentToCloud(payment);
      }
      
      debugPrint('✅ Bills synced to cloud successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing bills to cloud: $e');
      return false;
    }
  }

  static Future<bool> performFullSync() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated for bills sync');
      return false;
    }

    try {
      // First sync from cloud
      await syncFromCloud();
      
      // Then sync to cloud
      await syncToCloud();
      
      debugPrint('✅ Bills full sync completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error during bills full sync: $e');
      return false;
    }
  }
}
