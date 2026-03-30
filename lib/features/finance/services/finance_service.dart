import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_models.dart';

/// Main Finance Service - handles all business logic and data operations
class FinanceService {
  static const String _accountsKey = 'finance_accounts_v3';
  static const String _categoriesKey = 'finance_categories_v3';
  static const String _transactionsKey = 'finance_transactions_v3';
  static const String _budgetsKey = 'finance_budgets_v3';
  static const String _billsKey = 'finance_bills_v3';
  static const String _investmentsKey = 'finance_investments_v3';
  static const String _settingsKey = 'finance_settings_v3';
  static const String _savingsGoalsKey = 'finance_savings_goals_v3';

  static SharedPreferences? _prefs;
  static bool _isInitialized = false;

  // In-memory cache
  static List<FinanceAccount> _accounts = [];
  static List<FinanceCategory> _categories = [];
  static List<FinanceTransaction> _transactions = [];
  static List<FinanceBudget> _budgets = [];
  static List<FinanceBill> _bills = [];
  static List<FinanceInvestment> _investments = [];
  static List<FinanceSavingsGoal> _savingsGoals = [];
  static Map<String, dynamic> _settings = {};

  /// Initialize the service
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadAllData();
      _isInitialized = true;
      debugPrint('✓ FinanceService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FinanceService: $e');
      rethrow;
    }
  }

  static Future<void> _loadAllData() async {
    await Future.wait([
      _loadAccounts(),
      _loadCategories(),
      _loadTransactions(),
      _loadBudgets(),
      _loadBills(),
      _loadInvestments(),
      _loadSavingsGoals(),
      _loadSettings(),
    ]);
  }

  // ==================== ACCOUNTS ====================

  static Future<void> _loadAccounts() async {
    final data = _prefs?.getString(_accountsKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _accounts = json.map((e) => FinanceAccount.fromJson(e)).toList();
    } else {
      // Initialize with default accounts
      _accounts = FinanceAccount.getDefaultAccounts();
      await _saveAccounts();
    }
  }

  static Future<void> _saveAccounts() async {
    final data = jsonEncode(_accounts.map((e) => e.toJson()).toList());
    await _prefs?.setString(_accountsKey, data);
  }

  static List<FinanceAccount> getAccounts({bool includeArchived = false}) {
    if (includeArchived) return List.from(_accounts);
    return _accounts.where((a) => !a.isArchived).toList();
  }

  static FinanceAccount? getAccount(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addAccount(FinanceAccount account) async {
    _accounts.add(account);
    await _saveAccounts();
  }

  static Future<void> updateAccount(FinanceAccount account) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
      await _saveAccounts();
    }
  }

  static Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _saveAccounts();
  }

  static double getTotalBalance() {
    return _accounts
        .where((a) => a.includeInTotal && !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.balance);
  }

  // ==================== CATEGORIES ====================

  static Future<void> _loadCategories() async {
    final data = _prefs?.getString(_categoriesKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _categories = json.map((e) => FinanceCategory.fromJson(e)).toList();
    } else {
      // Initialize with default categories
      _categories = FinanceCategory.getDefaultCategories();
      await _saveCategories();
    }
  }

  static Future<void> _saveCategories() async {
    final data = jsonEncode(_categories.map((e) => e.toJson()).toList());
    await _prefs?.setString(_categoriesKey, data);
  }

  static List<FinanceCategory> getCategories({bool? isIncome}) {
    if (isIncome == null) return List.from(_categories);
    return _categories.where((c) => c.isIncome == isIncome).toList();
  }

  static FinanceCategory? getCategory(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addCategory(FinanceCategory category) async {
    _categories.add(category);
    await _saveCategories();
  }

  static Future<void> updateCategory(FinanceCategory category) async {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      await _saveCategories();
    }
  }

  static Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    await _saveCategories();
  }

  // ==================== TRANSACTIONS ====================

  static Future<void> _loadTransactions() async {
    final data = _prefs?.getString(_transactionsKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _transactions = json.map((e) => FinanceTransaction.fromJson(e)).toList();
    }
  }

  static Future<void> _saveTransactions() async {
    final data = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await _prefs?.setString(_transactionsKey, data);
  }

  static List<FinanceTransaction> getTransactions({
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    var result = List<FinanceTransaction>.from(_transactions);

    if (type != null) {
      result = result.where((t) => t.type == type).toList();
    }
    if (categoryId != null) {
      result = result.where((t) => t.categoryId == categoryId).toList();
    }
    if (accountId != null) {
      result = result.where((t) => t.accountId == accountId || t.toAccountId == accountId).toList();
    }
    if (startDate != null) {
      result = result.where((t) => t.date.isAfter(startDate.subtract(const Duration(days: 1)))).toList();
    }
    if (endDate != null) {
      result = result.where((t) => t.date.isBefore(endDate.add(const Duration(days: 1)))).toList();
    }

    result.sort((a, b) => b.date.compareTo(a.date));

    if (limit != null) {
      result = result.take(limit).toList();
    }

    return result;
  }

  static FinanceTransaction? getTransaction(String id) {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addTransaction(FinanceTransaction transaction) async {
    _transactions.add(transaction);
    
    // Update account balance
    await _updateAccountBalance(transaction);
    
    // Update budget spent
    await _updateBudgetSpent(transaction);
    
    await _saveTransactions();
  }

  static Future<void> _updateAccountBalance(FinanceTransaction transaction) async {
    final account = getAccount(transaction.accountId);
    if (account == null) return;

    double newBalance = account.balance;
    if (transaction.type == TransactionType.income) {
      newBalance += transaction.amount;
    } else if (transaction.type == TransactionType.expense) {
      newBalance -= transaction.amount;
    } else if (transaction.type == TransactionType.transfer) {
      newBalance -= transaction.amount;
      // Update target account
      if (transaction.toAccountId != null) {
        final toAccount = getAccount(transaction.toAccountId!);
        if (toAccount != null) {
          await updateAccount(toAccount.copyWith(balance: toAccount.balance + transaction.amount));
        }
      }
    }

    await updateAccount(account.copyWith(balance: newBalance));
  }

  static Future<void> _updateBudgetSpent(FinanceTransaction transaction) async {
    if (transaction.type != TransactionType.expense) return;

    for (var budget in _budgets) {
      if (budget.categoryIds.contains(transaction.categoryId) && !budget.isArchived) {
        final updatedBudget = budget.copyWith(spent: budget.spent + transaction.amount);
        await updateBudget(updatedBudget);
      }
    }
  }

  static Future<void> updateTransaction(FinanceTransaction transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      await _saveTransactions();
    }
  }

  static Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _saveTransactions();
  }

  static double getTotalIncome({DateTime? startDate, DateTime? endDate}) {
    return getTransactions(type: TransactionType.income, startDate: startDate, endDate: endDate)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double getTotalExpense({DateTime? startDate, DateTime? endDate}) {
    return getTransactions(type: TransactionType.expense, startDate: startDate, endDate: endDate)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // ==================== BUDGETS ====================

  static Future<void> _loadBudgets() async {
    final data = _prefs?.getString(_budgetsKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _budgets = json.map((e) => FinanceBudget.fromJson(e)).toList();
    }
  }

  static Future<void> _saveBudgets() async {
    final data = jsonEncode(_budgets.map((e) => e.toJson()).toList());
    await _prefs?.setString(_budgetsKey, data);
  }

  static List<FinanceBudget> getBudgets({bool includeArchived = false}) {
    if (includeArchived) return List.from(_budgets);
    return _budgets.where((b) => !b.isArchived).toList();
  }

  static FinanceBudget? getBudget(String id) {
    try {
      return _budgets.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addBudget(FinanceBudget budget) async {
    _budgets.add(budget);
    await _saveBudgets();
  }

  static Future<void> updateBudget(FinanceBudget budget) async {
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index != -1) {
      _budgets[index] = budget;
      await _saveBudgets();
    }
  }

  static Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
    await _saveBudgets();
  }

  // ==================== BILLS ====================

  static Future<void> _loadBills() async {
    final data = _prefs?.getString(_billsKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _bills = json.map((e) => FinanceBill.fromJson(e)).toList();
    }
  }

  static Future<void> _saveBills() async {
    final data = jsonEncode(_bills.map((e) => e.toJson()).toList());
    await _prefs?.setString(_billsKey, data);
  }

  static List<FinanceBill> getBills({
    BillStatus? status,
    bool includeArchived = false,
  }) {
    var result = List<FinanceBill>.from(_bills);
    
    if (!includeArchived) {
      result = result.where((b) => !b.isArchived).toList();
    }
    if (status != null) {
      result = result.where((b) => b.status == status).toList();
    }

    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  static List<FinanceBill> getUpcomingBills({int days = 30}) {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    return _bills
        .where((b) => !b.isArchived && 
                      b.status == BillStatus.upcoming &&
                      b.dueDate.isAfter(now) &&
                      b.dueDate.isBefore(endDate))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  static List<FinanceBill> getOverdueBills() {
    final now = DateTime.now();
    return _bills
        .where((b) => !b.isArchived && 
                      b.status != BillStatus.paid &&
                      b.dueDate.isBefore(now))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  static FinanceBill? getBill(String id) {
    try {
      return _bills.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addBill(FinanceBill bill) async {
    _bills.add(bill);
    await _saveBills();
  }

  static Future<void> updateBill(FinanceBill bill) async {
    final index = _bills.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      _bills[index] = bill;
      await _saveBills();
    }
  }

  static Future<void> markBillAsPaid(String billId, {String? accountId, double? amount}) async {
    final bill = getBill(billId);
    if (bill == null) return;

    final paidBill = bill.markAsPaid(accountId: accountId, amount: amount);
    await updateBill(paidBill);

    // Create expense transaction for the bill
    final transaction = FinanceTransaction.create(
      amount: amount ?? bill.amount,
      type: TransactionType.expense,
      categoryId: bill.categoryId ?? '',
      accountId: accountId ?? bill.accountId ?? '',
      note: 'Bill payment: ${bill.name}',
    );
    await addTransaction(transaction);

    // Generate next instance if recurring
    if (bill.isRecurring) {
      final nextBill = bill.generateNextInstance();
      await addBill(nextBill);
    }
  }

  static Future<void> deleteBill(String id) async {
    _bills.removeWhere((b) => b.id == id);
    await _saveBills();
  }

  // ==================== INVESTMENTS ====================

  static Future<void> _loadInvestments() async {
    final data = _prefs?.getString(_investmentsKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _investments = json.map((e) => FinanceInvestment.fromJson(e)).toList();
    }
  }

  static Future<void> _saveInvestments() async {
    final data = jsonEncode(_investments.map((e) => e.toJson()).toList());
    await _prefs?.setString(_investmentsKey, data);
  }

  static List<FinanceInvestment> getInvestments({InvestmentType? type, bool activeOnly = true}) {
    var result = List<FinanceInvestment>.from(_investments);
    
    if (activeOnly) {
      result = result.where((i) => i.isActive).toList();
    }
    if (type != null) {
      result = result.where((i) => i.type == type).toList();
    }

    return result;
  }

  static FinanceInvestment? getInvestment(String id) {
    try {
      return _investments.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addInvestment(FinanceInvestment investment) async {
    _investments.add(investment);
    await _saveInvestments();
  }

  static Future<void> updateInvestment(FinanceInvestment investment) async {
    final index = _investments.indexWhere((i) => i.id == investment.id);
    if (index != -1) {
      _investments[index] = investment;
      await _saveInvestments();
    }
  }

  static Future<void> deleteInvestment(String id) async {
    _investments.removeWhere((i) => i.id == id);
    await _saveInvestments();
  }

  static double getTotalInvestmentValue() {
    return _investments
        .where((i) => i.isActive)
        .fold(0.0, (sum, i) => sum + i.currentValue);
  }

  static double getTotalInvestmentReturn() {
    return _investments
        .where((i) => i.isActive)
        .fold(0.0, (sum, i) => sum + i.totalReturn);
  }

  // ==================== SETTINGS ====================

  static Future<void> _loadSettings() async {
    final data = _prefs?.getString(_settingsKey);
    if (data != null) {
      _settings = jsonDecode(data);
    } else {
      _settings = {
        'currency': 'INR',
        'currencySymbol': '₹',
        'firstDayOfWeek': 1, // Monday
        'showCents': true,
      };
      await _saveSettings();
    }
  }

  static Future<void> _saveSettings() async {
    final data = jsonEncode(_settings);
    await _prefs?.setString(_settingsKey, data);
  }

  static String get currency => _settings['currency'] ?? 'INR';
  static String get currencySymbol => _settings['currencySymbol'] ?? '₹';

  static String formatCurrency(double amount) {
    final symbol = currencySymbol;
    final formatted = amount.abs().toStringAsFixed(2);
    final parts = formatted.split('.');
    
    // Add thousand separators
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    
    final result = '$symbol$intPart.${parts[1]}';
    return amount < 0 ? '-$result' : result;
  }

  // ==================== ANALYTICS ====================

  static Map<String, double> getExpensesByCategory({DateTime? startDate, DateTime? endDate}) {
    final expenses = getTransactions(type: TransactionType.expense, startDate: startDate, endDate: endDate);
    final Map<String, double> result = {};
    
    for (final expense in expenses) {
      final categoryName = getCategory(expense.categoryId)?.name ?? 'Other';
      result[categoryName] = (result[categoryName] ?? 0) + expense.amount;
    }
    
    return result;
  }

  static Map<String, double> getIncomeByCategory({DateTime? startDate, DateTime? endDate}) {
    final incomes = getTransactions(type: TransactionType.income, startDate: startDate, endDate: endDate);
    final Map<String, double> result = {};
    
    for (final income in incomes) {
      final categoryName = getCategory(income.categoryId)?.name ?? 'Other';
      result[categoryName] = (result[categoryName] ?? 0) + income.amount;
    }
    
    return result;
  }

  static List<Map<String, dynamic>> getDailyTransactionSummary({int days = 30}) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final transactions = getTransactions(startDate: startDate);
    
    final Map<String, Map<String, double>> dailyData = {};
    
    for (var i = 0; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyData[dateKey] = {'income': 0, 'expense': 0};
    }
    
    for (final t in transactions) {
      final dateKey = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      if (dailyData.containsKey(dateKey)) {
        if (t.type == TransactionType.income) {
          dailyData[dateKey]!['income'] = dailyData[dateKey]!['income']! + t.amount;
        } else if (t.type == TransactionType.expense) {
          dailyData[dateKey]!['expense'] = dailyData[dateKey]!['expense']! + t.amount;
        }
      }
    }
    
    return dailyData.entries.map((e) => {
      'date': e.key,
      'income': e.value['income'],
      'expense': e.value['expense'],
    }).toList();
  }

  // ==================== SAVINGS GOALS ====================

  static Future<void> _loadSavingsGoals() async {
    final data = _prefs?.getString(_savingsGoalsKey);
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _savingsGoals = json.map((e) => FinanceSavingsGoal.fromJson(e)).toList();
    }
  }

  static Future<void> _saveSavingsGoals() async {
    final data = jsonEncode(_savingsGoals.map((e) => e.toJson()).toList());
    await _prefs?.setString(_savingsGoalsKey, data);
  }

  static List<FinanceSavingsGoal> getSavingsGoals({bool includeArchived = false, bool includeCompleted = true}) {
    var goals = List<FinanceSavingsGoal>.from(_savingsGoals);
    if (!includeArchived) {
      goals = goals.where((g) => !g.isArchived).toList();
    }
    if (!includeCompleted) {
      goals = goals.where((g) => !g.isCompleted).toList();
    }
    return goals;
  }

  static FinanceSavingsGoal? getSavingsGoal(String id) {
    try {
      return _savingsGoals.firstWhere((g) => g.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> addSavingsGoal(FinanceSavingsGoal goal) async {
    _savingsGoals.add(goal);
    await _saveSavingsGoals();
  }

  static Future<void> updateSavingsGoal(FinanceSavingsGoal goal) async {
    final index = _savingsGoals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _savingsGoals[index] = goal;
      await _saveSavingsGoals();
    }
  }

  static Future<void> deleteSavingsGoal(String id) async {
    _savingsGoals.removeWhere((g) => g.id == id);
    await _saveSavingsGoals();
  }

  static Future<void> addContributionToGoal(String goalId, double amount) async {
    final index = _savingsGoals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _savingsGoals[index] = _savingsGoals[index].addContribution(amount);
      await _saveSavingsGoals();
    }
  }

  static double getTotalSavingsProgress() {
    final activeGoals = getSavingsGoals(includeArchived: false);
    if (activeGoals.isEmpty) return 0;
    final totalTarget = activeGoals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final totalCurrent = activeGoals.fold(0.0, (sum, g) => sum + g.currentAmount);
    return totalTarget > 0 ? (totalCurrent / totalTarget * 100) : 0;
  }

  static double getTotalSavingsAmount() {
    return getSavingsGoals(includeArchived: false)
        .fold(0.0, (sum, g) => sum + g.currentAmount);
  }
}
