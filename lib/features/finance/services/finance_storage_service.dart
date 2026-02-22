import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/finance_enums.dart';
import '../models/finance_category.dart';
import '../models/finance_account.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'finance_cloud_service.dart';

class FinanceStorageService {
  static const String _transactionsBoxName = 'finance_transactions_v2';
  static const String _accountsBoxName = 'finance_accounts_v2';
  static const String _categoriesBoxName = 'finance_categories_v2';
  static const String _budgetsBoxName = 'finance_budgets_v2';

  static bool _isInitialized = false;
  static bool _isInitializing = false;

  static bool get isInitialized => _isInitialized;

  static String? get _currentUserId {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        return user.uid;
      }
    } catch (_) {}
    return null;
  }

  static void resetForTesting() {
    _isInitialized = false;
    _isInitializing = false;
  }

  static Future<void> _syncToCloud(String collection, String docId, Map<String, dynamic> data) async {
    final userId = _currentUserId;
    if (userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .set({
            ...data,
            'syncedAt': FieldValue.serverTimestamp(),
            'version': 1,
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
      // Retry mechanism
      await Future.delayed(const Duration(seconds: 2));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(collection)
            .doc(docId)
            .set({
              ...data,
              'syncedAt': FieldValue.serverTimestamp(),
              'version': 1,
            }, SetOptions(merge: true));
      } catch (retryError) {
        debugPrint('Retry failed for syncing to cloud: $retryError');
      }
    }
  }

  static Future<void> _deleteFromCloud(String collection, String docId) async {
    final userId = _currentUserId;
    if (userId == null || !FinanceCloudService.isUserAuthenticated) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting from cloud: $e');
      // Retry mechanism
      await Future.delayed(const Duration(seconds: 2));
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection(collection)
            .doc(docId)
            .delete();
      } catch (retryError) {
        debugPrint('Retry failed for deleting from cloud: $retryError');
      }
    }
  }

  static Future<void> init() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      int attempts = 0;
      while (_isInitializing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_isInitialized) return;
    }

    _isInitializing = true;
    debugPrint('🚀 Starting FinanceStorageService initialization...');

    try {
      // Register adapters
      _safeRegisterAdapter(TransactionTypeAdapter());
      _safeRegisterAdapter(AccountTypeAdapter());
      _safeRegisterAdapter(RecurrenceTypeAdapter());
      _safeRegisterAdapter(BudgetPeriodAdapter());
      _safeRegisterAdapter(FinanceCategoryAdapter());
      _safeRegisterAdapter(FinanceAccountAdapter());
      _safeRegisterAdapter(FinanceTransactionAdapter());
      _safeRegisterAdapter(BudgetAdapter());

      // Open boxes
      await _safeOpenBox<FinanceTransaction>(_transactionsBoxName);
      await _safeOpenBox<FinanceAccount>(_accountsBoxName);
      await _safeOpenBox<FinanceCategory>(_categoriesBoxName);
      await _safeOpenBox<Budget>(_budgetsBoxName);

      // Initialize defaults
      await _initDefaultCategories();
      await _initDefaultAccount();
      
      // Perform initial cloud sync if user is authenticated
      if (FinanceCloudService.isUserAuthenticated) {
        debugPrint('🔄 Performing initial cloud sync...');
        await FinanceCloudService.syncFinanceDataFromCloud();
      }

      _isInitialized = true;
      _isInitializing = false;
      debugPrint('✓ FinanceStorageService initialized');
    } catch (e, stackTrace) {
      _isInitializing = false;
      debugPrint('❌ Error initializing FinanceStorageService: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
    try {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter(adapter);
      }
    } catch (e) {
      debugPrint('Adapter registration error: $e');
    }
  }

  static Future<Box<T>> _safeOpenBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<T>(boxName);
      }
      final encryptionKey = await SecureStorageHelper.getEncryptionKey();
      return await Hive.openBox<T>(
        boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      debugPrint('Error opening box $boxName: $e');
      try {
        await Hive.deleteBoxFromDisk(boxName);
        final encryptionKey = await SecureStorageHelper.getEncryptionKey();
        return await Hive.openBox<T>(
          boxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        );
      } catch (deleteError) {
        rethrow;
      }
    }
  }

  // ============ Category Methods ============
  static Box<FinanceCategory> get _categoriesBox =>
      Hive.box<FinanceCategory>(_categoriesBoxName);

  static Future<void> _initDefaultCategories() async {
    if (_categoriesBox.isEmpty) {
      final defaults = FinanceCategory.getDefaultCategories();
      for (var category in defaults) {
        await _categoriesBox.put(category.id, category);
      }
      debugPrint('✓ Initialized default finance categories');
    }
  }

  static List<FinanceCategory> getAllCategories() {
    return _categoriesBox.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static List<FinanceCategory> getExpenseCategories() {
    return getAllCategories().where((c) => !c.isIncome).toList();
  }

  static List<FinanceCategory> getIncomeCategories() {
    return getAllCategories().where((c) => c.isIncome).toList();
  }

  static FinanceCategory? getCategory(String id) {
    return _categoriesBox.get(id);
  }

  static Future<void> addCategory(FinanceCategory category) async {
    await _categoriesBox.put(category.id, category);
    await _syncToCloud('finance_categories', category.id, category.toJson());
  }

  static Future<void> updateCategory(FinanceCategory category) async {
    await _categoriesBox.put(category.id, category);
    await _syncToCloud('finance_categories', category.id, category.toJson());
  }

  static Future<void> deleteCategory(String id) async {
    final category = _categoriesBox.get(id);
    if (category?.isDefault == true) {
      throw Exception('Cannot delete default category');
    }
    await _categoriesBox.delete(id);
    await _deleteFromCloud('finance_categories', id);
  }

  static ValueListenable<Box<FinanceCategory>> get categoriesListenable =>
      _categoriesBox.listenable();

  // ============ Account Methods ============
  static Box<FinanceAccount> get _accountsBox =>
      Hive.box<FinanceAccount>(_accountsBoxName);

  static Future<void> _initDefaultAccount() async {
    if (_accountsBox.isEmpty) {
      final defaultAccount = FinanceAccount.createDefault();
      await _accountsBox.put(defaultAccount.id, defaultAccount);
      debugPrint('✓ Initialized default finance account');
    }
  }

  static List<FinanceAccount> getAllAccounts() {
    return _accountsBox.values.where((a) => !a.isArchived).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static FinanceAccount? getAccount(String id) {
    return _accountsBox.get(id);
  }

  static Future<void> addAccount(FinanceAccount account) async {
    await _accountsBox.put(account.id, account);
    await _syncToCloud('finance_accounts', account.id, account.toJson());
  }

  static Future<void> updateAccount(FinanceAccount account) async {
    await _accountsBox.put(account.id, account);
    await _syncToCloud('finance_accounts', account.id, account.toJson());
  }

  static Future<void> deleteAccount(String id) async {
    await _accountsBox.delete(id);
    await _deleteFromCloud('finance_accounts', id);
  }

  static Future<void> updateAccountBalance(String accountId, double newBalance) async {
    final account = _accountsBox.get(accountId);
    if (account != null) {
      await updateAccount(account.copyWith(balance: newBalance));
    }
  }

  static double getTotalBalance() {
    return getAllAccounts()
        .where((a) => a.includeInTotal && !a.isLiability)
        .fold(0.0, (sum, a) => sum + a.balance);
  }

  static double getTotalLiabilities() {
    return getAllAccounts()
        .where((a) => a.includeInTotal && a.isLiability)
        .fold(0.0, (sum, a) => sum + a.balance.abs());
  }

  static double getNetWorth() {
    return getTotalBalance() - getTotalLiabilities();
  }

  static ValueListenable<Box<FinanceAccount>> get accountsListenable =>
      _accountsBox.listenable();

  // ============ Transaction Methods ============
  static Box<FinanceTransaction> get _transactionsBox =>
      Hive.box<FinanceTransaction>(_transactionsBoxName);

  static List<FinanceTransaction> getAllTransactions() {
    return _transactionsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static List<FinanceTransaction> getTransactionsForPeriod(DateTime start, DateTime end) {
    return getAllTransactions()
        .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
        .toList();
  }

  static List<FinanceTransaction> getTransactionsForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    return getTransactionsForPeriod(start, end);
  }

  static List<FinanceTransaction> getTransactionsForAccount(String accountId) {
    return getAllTransactions()
        .where((t) => t.accountId == accountId || t.toAccountId == accountId)
        .toList();
  }

  static List<FinanceTransaction> getRecentTransactions({int limit = 10}) {
    final all = getAllTransactions();
    return all.take(limit).toList();
  }

  static Future<void> addTransaction(FinanceTransaction transaction) async {
    await _transactionsBox.put(transaction.id, transaction);
    await _updateAccountBalanceForTransaction(transaction, isAdd: true);

    if (transaction.type == TransactionType.expense) {
      await _updateBudgetSpent(transaction.categoryId, transaction.amount);
    }

    await _syncToCloud('finance_transactions', transaction.id, transaction.toJson());
  }

  static Future<void> updateTransaction(FinanceTransaction transaction) async {
    final oldTransaction = _transactionsBox.get(transaction.id);
    if (oldTransaction != null) {
      await _updateAccountBalanceForTransaction(oldTransaction, isAdd: false);
    }

    await _transactionsBox.put(transaction.id, transaction);
    await _updateAccountBalanceForTransaction(transaction, isAdd: true);
    await _syncToCloud('finance_transactions', transaction.id, transaction.toJson());
  }

  static Future<void> deleteTransaction(String id) async {
    final transaction = _transactionsBox.get(id);
    if (transaction != null) {
      await _updateAccountBalanceForTransaction(transaction, isAdd: false);
    }
    await _transactionsBox.delete(id);
    await _deleteFromCloud('finance_transactions', id);
  }

  static Future<void> _updateAccountBalanceForTransaction(
    FinanceTransaction transaction,
    {required bool isAdd}
  ) async {
    final multiplier = isAdd ? 1.0 : -1.0;
    final account = _accountsBox.get(transaction.accountId);

    if (account != null) {
      double balanceChange = 0;
      switch (transaction.type) {
        case TransactionType.income:
          balanceChange = transaction.amount * multiplier;
          break;
        case TransactionType.expense:
          balanceChange = -transaction.amount * multiplier;
          break;
        case TransactionType.transfer:
          balanceChange = -transaction.amount * multiplier;
          break;
      }
      await updateAccountBalance(account.id, account.balance + balanceChange);
    }

    if (transaction.type == TransactionType.transfer && transaction.toAccountId != null) {
      final toAccount = _accountsBox.get(transaction.toAccountId!);
      if (toAccount != null) {
        final change = transaction.amount * multiplier;
        await updateAccountBalance(toAccount.id, toAccount.balance + change);
      }
    }
  }

  static ValueListenable<Box<FinanceTransaction>> get transactionsListenable =>
      _transactionsBox.listenable();

  // ============ Budget Methods ============
  static Box<Budget> get _budgetsBox => Hive.box<Budget>(_budgetsBoxName);

  static List<Budget> getAllBudgets() {
    return _budgetsBox.values.where((b) => !b.isArchived).toList();
  }

  static Budget? getBudget(String id) {
    return _budgetsBox.get(id);
  }

  static Future<void> addBudget(Budget budget) async {
    await _budgetsBox.put(budget.id, budget);
    await _syncToCloud('finance_budgets', budget.id, budget.toJson());
  }

  static Future<void> updateBudget(Budget budget) async {
    await _budgetsBox.put(budget.id, budget);
    await _syncToCloud('finance_budgets', budget.id, budget.toJson());
  }

  static Future<void> deleteBudget(String id) async {
    await _budgetsBox.delete(id);
    await _deleteFromCloud('finance_budgets', id);
  }

  static Future<void> _updateBudgetSpent(String categoryId, double amount) async {
    final budgets = getAllBudgets()
        .where((b) => b.categoryIds.contains(categoryId))
        .toList();

    for (var budget in budgets) {
      final updated = budget.copyWith(spent: budget.spent + amount);
      await updateBudget(updated);
    }
  }

  static ValueListenable<Box<Budget>> get budgetsListenable =>
      _budgetsBox.listenable();

  // ============ Analytics Methods ============
  static Map<String, double> getSpendingByCategory({DateTime? start, DateTime? end}) {
    var transactions = getAllTransactions()
        .where((t) => t.type == TransactionType.expense);

    if (start != null && end != null) {
      transactions = transactions.where((t) =>
          t.date.isAfter(start) && t.date.isBefore(end));
    }

    final map = <String, double>{};
    for (var t in transactions) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
    }
    return map;
  }

  static double getTotalExpenses({DateTime? start, DateTime? end}) {
    var transactions = getAllTransactions()
        .where((t) => t.type == TransactionType.expense);

    if (start != null && end != null) {
      transactions = transactions.where((t) =>
          t.date.isAfter(start) && t.date.isBefore(end));
    }

    return transactions.fold(0.0, (sum, t) => sum + t.amount);
  }

  static double getTotalIncome({DateTime? start, DateTime? end}) {
    var transactions = getAllTransactions()
        .where((t) => t.type == TransactionType.income);

    if (start != null && end != null) {
      transactions = transactions.where((t) =>
          t.date.isAfter(start) && t.date.isBefore(end));
    }

    return transactions.fold(0.0, (sum, t) => sum + t.amount);
  }

  static double getThisMonthExpenses() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getTotalExpenses(start: start, end: end);
  }

  static double getThisMonthIncome() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getTotalIncome(start: start, end: end);
  }

  // ============ Cloud Sync Methods ============
  static Future<bool> syncToCloud() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated for cloud sync');
      return false;
    }
    return await FinanceCloudService.syncFinanceDataToCloud();
  }

  static Future<bool> syncFromCloud() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated for cloud sync');
      return false;
    }
    return await FinanceCloudService.syncFinanceDataFromCloud();
  }

  static Future<bool> performFullSync() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated for cloud sync');
      return false;
    }
    return await FinanceCloudService.performFullSync();
  }
}
