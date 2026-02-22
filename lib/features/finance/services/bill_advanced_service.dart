import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../models/bill_template.dart';
import '../services/bill_storage_service.dart';
import '../services/finance_storage_service.dart';

class BillAdvancedService {
  static const String _templatesBoxName = 'finance_bill_templates_v1';
  static const String _activitiesBoxName = 'finance_bill_activities_v1';
  static const String _keywordsBoxName = 'finance_bill_keywords_v1';
  static const String _settingsBoxName = 'finance_bill_settings_v2';

  static Box<BillTemplate>? _templatesBox;
  static Box<BillActivity>? _activitiesBox;
  static Box<CategoryKeywordMap>? _keywordsBox;
  static Box<BillSettings>? _settingsBox;

  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;
    debugPrint('🚀 Starting BillAdvancedService initialization...');

    try {
      _safeRegisterAdapter(BillTemplateAdapter());
      _safeRegisterAdapter(BillActivityAdapter());
      _safeRegisterAdapter(CategoryKeywordMapAdapter());
      _safeRegisterAdapter(BillSettingsAdapter());
      _safeRegisterAdapter(BillPriorityAdapter());
      _safeRegisterAdapter(AdvancedRecurrenceTypeAdapter());
      _safeRegisterAdapter(BillActivityTypeAdapter());

      _templatesBox = await Hive.openBox<BillTemplate>(_templatesBoxName);
      _activitiesBox = await Hive.openBox<BillActivity>(_activitiesBoxName);
      _keywordsBox = await Hive.openBox<CategoryKeywordMap>(_keywordsBoxName);
      _settingsBox = await Hive.openBox<BillSettings>(_settingsBoxName);

      await _initDefaultSettings();

      _isInitialized = true;
      _isInitializing = false;
      debugPrint('✓ BillAdvancedService initialized successfully');
    } catch (e) {
      _isInitializing = false;
      debugPrint('❌ Error initializing BillAdvancedService: $e');
      rethrow;
    }
  }

  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  static Future<void> _initDefaultSettings() async {
    if (_settingsBox == null || _settingsBox!.isEmpty) {
      await _settingsBox?.put('default', BillSettings());
    }
  }

  static BillSettings getSettings() {
    return _settingsBox?.get('default') ?? BillSettings();
  }

  static Future<void> updateSettings(BillSettings settings) async {
    await _settingsBox?.put('default', settings);
  }

  // ==================== TEMPLATE MANAGEMENT ====================

  static List<BillTemplate> getAllTemplates() {
    return _templatesBox?.values.where((t) => t.isActive).toList() ?? [];
  }

  static Future<BillTemplate> createTemplate(BillTemplate template) async {
    await _templatesBox?.put(template.id, template);
    await logActivity(
      billId: template.id,
      type: BillActivityType.created,
      description: 'Template created: ${template.name}',
    );
    return template;
  }

  static Future<void> updateTemplate(BillTemplate template) async {
    await _templatesBox?.put(template.id, template.copyWith());
  }

  static Future<void> deactivateTemplate(String templateId) async {
    final template = _templatesBox?.get(templateId);
    if (template != null) {
      await _templatesBox?.put(templateId, template.copyWith(isActive: false));
    }
  }

  static Future<List<Bill>> generateDueInstances() async {
    final templates = getAllTemplates();
    final generatedBills = <Bill>[];

    for (final template in templates) {
      if (template.shouldGenerateInstance) {
        final existingInstance = BillStorageService.getActiveBills()
            .where((b) => b.templateId == template.id && 
                   b.dueDate.year == template.nextDueDate.year &&
                   b.dueDate.month == template.nextDueDate.month &&
                   b.dueDate.day == template.nextDueDate.day)
            .firstOrNull;

        if (existingInstance == null) {
          final instance = template.generateInstance();
          await BillStorageService.saveBill(instance);
          generatedBills.add(instance);

          final nextDueDate = template.calculateNextDueDate();
          await updateTemplate(template.copyWith(
            nextDueDate: nextDueDate,
            lastInstanceGeneratedAt: DateTime.now(),
          ));

          await logActivity(
            billId: instance.id,
            type: BillActivityType.instanceGenerated,
            description: 'Instance generated from template: ${template.name}',
          );
        }
      }
    }

    return generatedBills;
  }

  // ==================== FORECASTED BALANCE PROJECTION ====================

  static Map<String, dynamic> getProjectedBalance({int days = 30}) {
    final accounts = FinanceStorageService.getAllAccounts();
    final currentBalance = accounts.fold<double>(0, (sum, a) => sum + a.balance);
    
    final upcomingBills = BillStorageService.getUpcomingBills(days: days);
    final upcomingTotal = upcomingBills.fold<double>(0, (sum, b) => sum + b.remainingAmount);
    
    final projectedBalance = currentBalance - upcomingTotal;
    final isNegative = projectedBalance < 0;

    final billsByAccount = <String, double>{};
    for (final bill in upcomingBills) {
      if (bill.accountId != null) {
        billsByAccount[bill.accountId!] = 
            (billsByAccount[bill.accountId!] ?? 0) + bill.remainingAmount;
      }
    }

    final accountWarnings = <Map<String, dynamic>>[];
    for (final account in accounts) {
      final deduction = billsByAccount[account.id] ?? 0;
      if (deduction > account.balance) {
        accountWarnings.add({
          'accountId': account.id,
          'accountName': account.name,
          'balance': account.balance,
          'deduction': deduction,
          'shortfall': deduction - account.balance,
        });
      }
    }

    return {
      'currentBalance': currentBalance,
      'upcomingBillsTotal': upcomingTotal,
      'projectedBalance': projectedBalance,
      'isNegative': isNegative,
      'upcomingBillsCount': upcomingBills.length,
      'accountWarnings': accountWarnings,
      'days': days,
    };
  }

  // ==================== ACCOUNT-LEVEL BILL ALLOCATION ====================

  static Map<String, dynamic>? checkAccountAllocation(Bill bill) {
    if (bill.accountId == null) return null;

    final accounts = FinanceStorageService.getAllAccounts();
    final account = accounts.where((a) => a.id == bill.accountId).firstOrNull;
    
    if (account == null) return null;

    final isInsufficient = account.balance < bill.remainingAmount;
    
    return {
      'accountId': account.id,
      'accountName': account.name,
      'balance': account.balance,
      'billAmount': bill.remainingAmount,
      'isInsufficient': isInsufficient,
      'shortfall': isInsufficient ? bill.remainingAmount - account.balance : 0,
    };
  }

  // ==================== SMART AUTO-CATEGORY ====================

  static String? suggestCategory(String billName) {
    final keywords = _keywordsBox?.values.toList() ?? [];
    if (keywords.isEmpty) return null;

    final nameLower = billName.toLowerCase();
    final words = nameLower.split(RegExp(r'\s+'));

    CategoryKeywordMap? bestMatch;
    int bestScore = 0;

    for (final keyword in keywords) {
      for (final word in words) {
        if (word.contains(keyword.keyword.toLowerCase()) || 
            keyword.keyword.toLowerCase().contains(word)) {
          if (keyword.frequency > bestScore) {
            bestScore = keyword.frequency;
            bestMatch = keyword;
          }
        }
      }
    }

    return bestMatch?.categoryId;
  }

  static Future<void> learnCategoryAssignment(String billName, String categoryId) async {
    final words = billName.toLowerCase().split(RegExp(r'\s+'));
    
    for (final word in words) {
      if (word.length < 3) continue;

      final existing = _keywordsBox?.values
          .where((k) => k.keyword.toLowerCase() == word && k.categoryId == categoryId)
          .firstOrNull;

      if (existing != null) {
        await _keywordsBox?.put(existing.id, existing.incrementFrequency());
      } else {
        final newKeyword = CategoryKeywordMap(
          keyword: word,
          categoryId: categoryId,
        );
        await _keywordsBox?.put(newKeyword.id, newKeyword);
      }
    }
  }

  // ==================== BULK ACTIONS ====================

  static Future<int> bulkMarkAsPaid(List<String> billIds) async {
    int count = 0;
    for (final id in billIds) {
      try {
        await BillStorageService.markBillAsPaid(id);
        await logActivity(
          billId: id,
          type: BillActivityType.paid,
          description: 'Marked as paid (bulk action)',
        );
        count++;
      } catch (e) {
        debugPrint('Error marking bill $id as paid: $e');
      }
    }
    return count;
  }

  static Future<int> bulkArchive(List<String> billIds) async {
    int count = 0;
    for (final id in billIds) {
      try {
        await BillStorageService.archiveBill(id);
        await logActivity(
          billId: id,
          type: BillActivityType.archived,
          description: 'Archived (bulk action)',
        );
        count++;
      } catch (e) {
        debugPrint('Error archiving bill $id: $e');
      }
    }
    return count;
  }

  static Future<int> bulkDelete(List<String> billIds) async {
    int count = 0;
    for (final id in billIds) {
      try {
        await BillStorageService.deleteBill(id);
        await logActivity(
          billId: id,
          type: BillActivityType.deleted,
          description: 'Deleted (bulk action)',
        );
        count++;
      } catch (e) {
        debugPrint('Error deleting bill $id: $e');
      }
    }
    return count;
  }

  // ==================== BILL ATTACHMENTS ====================

  static Future<String?> uploadAttachment(String billId, File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref('bill_attachments/$billId/$fileName');
      
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      final bill = BillStorageService.getBill(billId);
      if (bill != null) {
        final updatedUrls = List<String>.from(bill.attachmentUrls)..add(url);
        await BillStorageService.updateBill(bill.copyWith(attachmentUrls: updatedUrls));
      }

      return url;
    } catch (e) {
      debugPrint('Error uploading attachment: $e');
      return null;
    }
  }

  static Future<bool> deleteAttachment(String billId, String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();

      final bill = BillStorageService.getBill(billId);
      if (bill != null) {
        final updatedUrls = List<String>.from(bill.attachmentUrls)..remove(url);
        await BillStorageService.updateBill(bill.copyWith(attachmentUrls: updatedUrls));
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting attachment: $e');
      return false;
    }
  }

  // ==================== REMINDER ESCALATION ====================

  static Future<void> processEscalationReminders() async {
    final settings = getSettings();
    if (!settings.enableEscalationReminders) return;

    final overdueBills = BillStorageService.getOverdueBills();

    for (final bill in overdueBills) {
      if (bill.escalationRemindersSent >= settings.maxEscalationReminders) continue;

      final lastSent = bill.lastReminderSentAt;
      final shouldSend = lastSent == null || 
          DateTime.now().difference(lastSent).inDays >= 1;

      if (shouldSend) {
        await BillStorageService.updateBill(bill.copyWith(
          escalationRemindersSent: bill.escalationRemindersSent + 1,
          lastReminderSentAt: DateTime.now(),
        ));

        await logActivity(
          billId: bill.id,
          type: BillActivityType.reminderSent,
          description: 'Escalation reminder ${bill.escalationRemindersSent + 1} sent',
        );
      }
    }
  }

  // ==================== SMART RECURRING DETECTION ====================

  static List<Map<String, dynamic>> detectRecurringPatterns() {
    final bills = BillStorageService.getAllBills();
    final suggestions = <Map<String, dynamic>>[];

    final billsByName = <String, List<Bill>>{};
    for (final bill in bills) {
      if (bill.recurrence == BillRecurrence.oneTime && !bill.isDeleted) {
        final normalizedName = bill.name.toLowerCase().trim();
        billsByName.putIfAbsent(normalizedName, () => []).add(bill);
      }
    }

    for (final entry in billsByName.entries) {
      if (entry.value.length >= 2) {
        final sorted = entry.value..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        
        if (sorted.length >= 2) {
          final intervals = <int>[];
          for (int i = 1; i < sorted.length; i++) {
            intervals.add(sorted[i].dueDate.difference(sorted[i-1].dueDate).inDays);
          }

          final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
          
          BillRecurrence? suggestedRecurrence;
          if (avgInterval >= 28 && avgInterval <= 32) {
            suggestedRecurrence = BillRecurrence.monthly;
          } else if (avgInterval >= 6 && avgInterval <= 8) {
            suggestedRecurrence = BillRecurrence.weekly;
          } else if (avgInterval >= 360 && avgInterval <= 370) {
            suggestedRecurrence = BillRecurrence.yearly;
          }

          if (suggestedRecurrence != null) {
            suggestions.add({
              'name': entry.key,
              'bills': entry.value,
              'suggestedRecurrence': suggestedRecurrence,
              'averageInterval': avgInterval,
              'instanceCount': entry.value.length,
            });
          }
        }
      }
    }

    return suggestions;
  }

  // ==================== BIOMETRIC LOCK ====================

  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Bills',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  static Future<bool> requiresAuthentication() async {
    final settings = getSettings();
    return settings.requireBiometricLock && await isBiometricAvailable();
  }

  // ==================== SMART INSIGHTS ====================

  static Map<String, dynamic> getSmartInsights() {
    final bills = BillStorageService.getAllBills().where((b) => !b.isDeleted).toList();
    final payments = <BillPayment>[];
    for (final bill in bills) {
      payments.addAll(BillStorageService.getPaymentsForBill(bill.id));
    }

    final now = DateTime.now();
    final thisMonth = bills.where((b) => 
        b.dueDate.year == now.year && b.dueDate.month == now.month).toList();
    final lastMonth = bills.where((b) => 
        b.dueDate.year == (now.month == 1 ? now.year - 1 : now.year) && 
        b.dueDate.month == (now.month == 1 ? 12 : now.month - 1)).toList();

    final thisMonthTotal = thisMonth.fold<double>(0, (sum, b) => sum + b.amount);
    final lastMonthTotal = lastMonth.fold<double>(0, (sum, b) => sum + b.amount);
    final monthlyChange = lastMonthTotal > 0 
        ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal * 100) 
        : 0.0;

    final monthlyTotals = <int, double>{};
    for (final bill in bills) {
      final key = bill.dueDate.year * 12 + bill.dueDate.month;
      monthlyTotals[key] = (monthlyTotals[key] ?? 0) + bill.amount;
    }
    final avgMonthlyTotal = monthlyTotals.isNotEmpty 
        ? monthlyTotals.values.reduce((a, b) => a + b) / monthlyTotals.length 
        : 0.0;

    int? mostExpensiveMonth;
    double maxTotal = 0;
    for (final entry in monthlyTotals.entries) {
      if (entry.value > maxTotal) {
        maxTotal = entry.value;
        mostExpensiveMonth = entry.key % 12;
        if (mostExpensiveMonth == 0) mostExpensiveMonth = 12;
      }
    }

    final paidBills = bills.where((b) => b.status == BillStatus.paid).toList();
    final onTimePaid = paidBills.where((b) {
      final paymentDate = payments
          .where((p) => p.billId == b.id)
          .map((p) => p.paidAt)
          .fold<DateTime?>(null, (prev, curr) => 
              prev == null || curr.isBefore(prev) ? curr : prev);
      return paymentDate != null && !paymentDate.isAfter(b.dueDate);
    }).length;
    final onTimePercentage = paidBills.isNotEmpty 
        ? (onTimePaid / paidBills.length * 100) 
        : 100.0;

    final categoryTotals = <String, double>{};
    for (final bill in bills) {
      final catId = bill.categoryId ?? 'other';
      categoryTotals[catId] = (categoryTotals[catId] ?? 0) + bill.amount;
    }
    final topCategory = categoryTotals.entries
        .fold<MapEntry<String, double>?>(null, (prev, curr) => 
            prev == null || curr.value > prev.value ? curr : prev);

    return {
      'averageMonthlyTotal': avgMonthlyTotal,
      'thisMonthTotal': thisMonthTotal,
      'lastMonthTotal': lastMonthTotal,
      'monthlyChangePercent': monthlyChange,
      'mostExpensiveMonth': mostExpensiveMonth,
      'mostExpensiveMonthTotal': maxTotal,
      'onTimePaymentPercent': onTimePercentage,
      'totalBillsCount': bills.length,
      'topCategoryId': topCategory?.key,
      'topCategoryTotal': topCategory?.value ?? 0,
      'unpaidCount': bills.where((b) => !b.isFullyPaid && !b.isArchived).length,
      'overdueCount': bills.where((b) => b.isOverdue).length,
    };
  }

  // ==================== BADGE COUNT ====================

  static int getUnpaidBadgeCount() {
    final bills = BillStorageService.getActiveBills();
    return bills.where((b) => !b.isFullyPaid).length;
  }

  static int getOverdueBadgeCount() {
    return BillStorageService.getOverdueBills().length;
  }

  static Map<String, int> getBadgeCounts() {
    final bills = BillStorageService.getActiveBills();
    return {
      'unpaid': bills.where((b) => !b.isFullyPaid).length,
      'overdue': bills.where((b) => b.isOverdue).length,
      'dueToday': bills.where((b) => b.isDueToday).length,
    };
  }

  // ==================== EXPORT PDF ====================

  static Future<File?> exportAnalyticsPdf() async {
    try {
      final pdf = pw.Document();
      final insights = getSmartInsights();
      final bills = BillStorageService.getActiveBills();
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Bill Analytics Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text('Generated: ${DateFormat('MMM d, yyyy HH:mm').format(now)}'),
            pw.SizedBox(height: 20),

            pw.Header(level: 1, child: pw.Text('Summary')),
            pw.Bullet(text: 'Average Monthly Total: ₹${(insights['averageMonthlyTotal'] as double).toStringAsFixed(2)}'),
            pw.Bullet(text: 'This Month Total: ₹${(insights['thisMonthTotal'] as double).toStringAsFixed(2)}'),
            pw.Bullet(text: 'Monthly Change: ${(insights['monthlyChangePercent'] as double).toStringAsFixed(1)}%'),
            pw.Bullet(text: 'On-Time Payment Rate: ${(insights['onTimePaymentPercent'] as double).toStringAsFixed(1)}%'),
            pw.SizedBox(height: 20),

            pw.Header(level: 1, child: pw.Text('Current Status')),
            pw.Bullet(text: 'Total Bills: ${insights['totalBillsCount']}'),
            pw.Bullet(text: 'Unpaid: ${insights['unpaidCount']}'),
            pw.Bullet(text: 'Overdue: ${insights['overdueCount']}'),
            pw.SizedBox(height: 20),

            pw.Header(level: 1, child: pw.Text('Upcoming Bills')),
            pw.Table.fromTextArray(
              headers: ['Name', 'Amount', 'Due Date', 'Status'],
              data: bills.take(20).map((b) => [
                b.name,
                '₹${b.amount.toStringAsFixed(2)}',
                DateFormat('MMM d').format(b.dueDate),
                b.status.displayName,
              ]).toList(),
            ),
          ],
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/bill_analytics_${now.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      return null;
    }
  }

  // ==================== ACTIVITY LOG ====================

  static Future<void> logActivity({
    required String billId,
    required BillActivityType type,
    String? description,
    double? amount,
    Map<String, dynamic>? metadata,
  }) async {
    final activity = BillActivity(
      billId: billId,
      activityType: type,
      description: description,
      amount: amount,
      metadata: metadata,
    );
    await _activitiesBox?.put(activity.id, activity);
  }

  static List<BillActivity> getActivitiesForBill(String billId) {
    final activities = _activitiesBox?.values
        .where((a) => a.billId == billId)
        .toList() ?? [];
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities;
  }

  static List<BillActivity> getRecentActivities({int limit = 50}) {
    final activities = _activitiesBox?.values.toList() ?? [];
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(limit).toList();
  }

  // ==================== CLOUD CONFLICT RESOLUTION ====================

  static Bill resolveConflict(Bill local, Bill remote) {
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return remote;
    }
    return local;
  }

  // ==================== NOTIFICATION DEDUPLICATION ====================

  static bool shouldScheduleNotification(Bill bill, DateTime scheduledTime) {
    if (bill.lastScheduledAt == null) return true;

    final diff = scheduledTime.difference(bill.lastScheduledAt!).inMinutes.abs();
    return diff > 5;
  }

  static Future<void> markNotificationScheduled(String billId, DateTime scheduledTime) async {
    final bill = BillStorageService.getBill(billId);
    if (bill != null) {
      await BillStorageService.updateBill(bill.copyWith(
        lastScheduledAt: scheduledTime,
      ));
    }
  }

  // ==================== PERFORMANCE OPTIMIZATION ====================

  static List<Bill> getOptimizedUnpaidBills({int? limit}) {
    final bills = BillStorageService.getActiveBills()
        .where((b) => !b.isFullyPaid && !b.isDeleted)
        .toList();

    bills.sort((a, b) {
      final priorityCompare = a.priority.sortOrder.compareTo(b.priority.sortOrder);
      if (priorityCompare != 0) return priorityCompare;
      return a.dueDate.compareTo(b.dueDate);
    });

    if (limit != null) {
      return bills.take(limit).toList();
    }
    return bills;
  }

  static List<Bill> queryBillsOptimized({
    bool? isPaid,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    String? categoryId,
    BillPriority? priority,
    int? limit,
  }) {
    var bills = BillStorageService.getActiveBills().where((b) => !b.isDeleted);

    if (isPaid != null) {
      bills = bills.where((b) => b.isFullyPaid == isPaid);
    }
    if (dueDateFrom != null) {
      bills = bills.where((b) => !b.dueDate.isBefore(dueDateFrom));
    }
    if (dueDateTo != null) {
      bills = bills.where((b) => !b.dueDate.isAfter(dueDateTo));
    }
    if (categoryId != null) {
      bills = bills.where((b) => b.categoryId == categoryId);
    }
    if (priority != null) {
      bills = bills.where((b) => b.priority == priority);
    }

    final result = bills.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (limit != null) {
      return result.take(limit).toList();
    }
    return result;
  }
}
