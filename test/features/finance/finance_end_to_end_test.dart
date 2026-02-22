import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tablet_remainder/features/finance/services/finance_storage_service.dart';
import 'package:tablet_remainder/features/finance/models/transaction.dart';
import 'package:tablet_remainder/features/finance/models/finance_account.dart';
import 'package:tablet_remainder/features/finance/models/budget.dart';
import 'package:tablet_remainder/features/finance/models/savings_goal.dart';
import 'package:tablet_remainder/features/finance/models/debt.dart';
import 'package:tablet_remainder/features/finance/models/bill_reminder.dart';
import 'package:tablet_remainder/features/finance/models/finance_enums.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tablet_remainder/features/finance/models/finance_category.dart';

void main() {
  setUpAll(() async {
    // Mock Secure Storage
    FlutterSecureStorage.setMockInitialValues({});
    
    // Initialize Hive with a temp directory
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
  });

  setUp(() async {
    await FinanceStorageService.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    FinanceStorageService.resetForTesting();
  });

  group('Finance Core Features E2E Tests', () {
    test('Transaction Management - Add, Update, Delete', () async {
      final accounts = FinanceStorageService.getAllAccounts();
      expect(accounts.isNotEmpty, true, reason: 'Should have default account');

      final transaction = FinanceTransaction(
        amount: 1000,
        type: TransactionType.expense,
        categoryId: 'food_dining',
        accountId: accounts.first.id,
        note: 'Test transaction',
        date: DateTime.now(),
      );

      await FinanceStorageService.addTransaction(transaction);
      final transactions = FinanceStorageService.getAllTransactions();
      expect(transactions.length, 1);
      expect(transactions.first.amount, 1000);

      final updated = transaction.copyWith(amount: 1500);
      await FinanceStorageService.updateTransaction(updated);
      final updatedTransactions = FinanceStorageService.getAllTransactions();
      expect(updatedTransactions.first.amount, 1500);

      await FinanceStorageService.deleteTransaction(transaction.id);
      final finalTransactions = FinanceStorageService.getAllTransactions();
      expect(finalTransactions.isEmpty, true);
    });

    test('Account Management - CRUD Operations', () async {
      final account = FinanceAccount(
        name: 'Test Bank',
        type: AccountType.bank,
        balance: 5000,
        colorValue: 0xFF2196F3,
        iconCodePoint: 0xe047,
      );

      await FinanceStorageService.addAccount(account);
      final accounts = FinanceStorageService.getAllAccounts();
      expect(accounts.any((a) => a.name == 'Test Bank'), true);

      final retrieved = FinanceStorageService.getAccount(account.id);
      expect(retrieved?.balance, 5000);

      await FinanceStorageService.updateAccountBalance(account.id, 6000);
      final updated = FinanceStorageService.getAccount(account.id);
      expect(updated?.balance, 6000);

      await FinanceStorageService.deleteAccount(account.id);
      final deleted = FinanceStorageService.getAccount(account.id);
      expect(deleted, null);
    });

    test('Budget Tracking - Create and Track Spending', () async {
      final budget = Budget(
        name: 'Monthly Food Budget',
        limit: 10000,
        period: BudgetPeriod.monthly,
        categoryIds: ['food_dining'],
        startDate: DateTime.now(),
        colorValue: 0xFF4CAF50,
      );

      await FinanceStorageService.addBudget(budget);
      final budgets = FinanceStorageService.getAllBudgets();
      expect(budgets.length, 1);
      expect(budgets.first.remaining, 10000);

      final accounts = FinanceStorageService.getAllAccounts();
      final transaction = FinanceTransaction(
        amount: 2000,
        type: TransactionType.expense,
        categoryId: 'food_dining',
        accountId: accounts.first.id,
        date: DateTime.now(),
      );
      await FinanceStorageService.addTransaction(transaction);

      final updatedBudgets = FinanceStorageService.getAllBudgets();
      expect(updatedBudgets.first.spent, 2000);
      expect(updatedBudgets.first.remaining, 8000);
    });

    test('Savings Goals - Create and Add Contributions', () async {
      final goal = SavingsGoal(
        name: 'Vacation Fund',
        targetAmount: 50000,
        targetDate: DateTime.now().add(const Duration(days: 180)),
        colorValue: 0xFF9C27B0,
        iconCodePoint: 0xe558,
      );

      await FinanceStorageService.addSavingsGoal(goal);
      final goals = FinanceStorageService.getAllSavingsGoals();
      expect(goals.length, 1);
      expect(goals.first.currentAmount, 0);

      await FinanceStorageService.addContributionToGoal(goal.id, 5000, note: 'First contribution');
      final updated = FinanceStorageService.getSavingsGoal(goal.id);
      expect(updated?.currentAmount, 5000);
      expect(updated?.progress, 10);
    });

    test('Debt Management - Track Debt and Payments', () async {
      final debt = Debt(
        name: 'Car Loan',
        type: DebtType.loan,
        totalAmount: 100000,
        interestRate: 8.5,
        startDate: DateTime.now(),
        colorValue: 0xFFF44336,
      );

      await FinanceStorageService.addDebt(debt);
      final debts = FinanceStorageService.getAllDebts();
      expect(debts.length, 1);
      expect(debts.first.remainingAmount, 100000);

      await FinanceStorageService.addPaymentToDebt(debt.id, 10000, note: 'Monthly payment');
      final updated = FinanceStorageService.getDebt(debt.id);
      expect(updated?.paidAmount, 10000);
      expect(updated?.remainingAmount, 90000);
      expect(updated?.progress, 10);
    });

    test('Bill Reminders - Create and Mark as Paid', () async {
      final bill = BillReminder(
        name: 'Electricity Bill',
        amount: 2500,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        recurrence: RecurrenceType.monthly,
        colorValue: 0xFFFF9800,
        iconCodePoint: 0xe1ac,
      );

      await FinanceStorageService.addBillReminder(bill);
      final bills = FinanceStorageService.getAllBillReminders();
      expect(bills.length, 1);
      expect(bills.first.isPaid, false);

      await FinanceStorageService.markBillAsPaid(bill.id);
      final paidBills = FinanceStorageService.getAllBillReminders();
      expect(paidBills.any((b) => b.id == bill.id && b.isPaid), true);

      final nextBills = FinanceStorageService.getAllBillReminders();
      expect(nextBills.any((b) => b.id != bill.id && !b.isPaid), true, 
        reason: 'Should create next recurring bill');
    });

    test('Net Worth Calculation', () async {
      final assetAccount = FinanceAccount(
        name: 'Savings',
        type: AccountType.savings,
        balance: 50000,
        includeInTotal: true,
        colorValue: 0xFF4CAF50,
        iconCodePoint: 0xe047,
      );

      final liabilityAccount = FinanceAccount(
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: -10000,
        includeInTotal: true,
        colorValue: 0xFFF44336,
        iconCodePoint: 0xe8f4,
      );

      await FinanceStorageService.addAccount(assetAccount);
      await FinanceStorageService.addAccount(liabilityAccount);

      final totalAssets = FinanceStorageService.getTotalBalance();
      final totalLiabilities = FinanceStorageService.getTotalLiabilities();
      final netWorth = FinanceStorageService.getNetWorth();

      expect(totalAssets, greaterThan(0));
      expect(totalLiabilities, greaterThan(0));
      expect(netWorth, totalAssets - totalLiabilities);
    });

    test('Analytics - Spending by Category', () async {
      final accounts = FinanceStorageService.getAllAccounts();
      final now = DateTime.now();

      await FinanceStorageService.addTransaction(FinanceTransaction(
        amount: 1000,
        type: TransactionType.expense,
        categoryId: 'food_dining',
        accountId: accounts.first.id,
        date: now,
      ));

      await FinanceStorageService.addTransaction(FinanceTransaction(
        amount: 500,
        type: TransactionType.expense,
        categoryId: 'transport',
        accountId: accounts.first.id,
        date: now,
      ));

      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
      final spendingByCategory = FinanceStorageService.getSpendingByCategory(
        start: monthStart,
        end: monthEnd,
      );

      expect(spendingByCategory.isNotEmpty, true);
      expect(spendingByCategory['food_dining'], 1000);
      expect(spendingByCategory['transport'], 500);
    });

    test('Auto-Categorization Rules', () async {
      final rules = FinanceStorageService.getAllRules();
      expect(rules.isNotEmpty, true, reason: 'Should have default rules');

      final suggestedCategory = FinanceStorageService.applyCategoryRules('Uber ride');
      expect(suggestedCategory, isNotNull);
      expect(suggestedCategory, 'transport');
    });

    test('CSV Export/Import', () async {
      final accounts = FinanceStorageService.getAllAccounts();
      
      await FinanceStorageService.addTransaction(FinanceTransaction(
        amount: 1000,
        type: TransactionType.expense,
        categoryId: 'food_dining',
        accountId: accounts.first.id,
        note: 'Test export',
        date: DateTime.now(),
      ));

      final csv = FinanceStorageService.exportTransactionsToCsv();
      expect(csv.contains('Test export'), true);
      expect(csv.contains('food_dining'), true);

      await Hive.deleteFromDisk();
      FinanceStorageService.resetForTesting();
      await FinanceStorageService.init();

      final imported = await FinanceStorageService.importTransactionsFromCsv(
        csv,
        accounts.first.id,
      );
      expect(imported, greaterThan(0));
    });

    test('Recurring Transaction Processing', () async {
      final accounts = FinanceStorageService.getAllAccounts();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final recurringTransaction = FinanceTransaction(
        amount: 500,
        type: TransactionType.expense,
        categoryId: 'subscriptions',
        accountId: accounts.first.id,
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        nextRecurrenceDate: yesterday,
        date: yesterday.subtract(const Duration(days: 30)),
      );

      await FinanceStorageService.addTransaction(recurringTransaction);
      await FinanceStorageService.processRecurringTransactions();

      final transactions = FinanceStorageService.getAllTransactions();
      expect(transactions.length, greaterThan(1), 
        reason: 'Should create new recurring transaction');
    });
  });

  group('Finance Feature Integration Tests', () {
    test('Complete User Flow - Add Income, Set Budget, Track Expenses', () async {
      final accounts = FinanceStorageService.getAllAccounts();
      final account = accounts.first;

      await FinanceStorageService.addTransaction(FinanceTransaction(
        amount: 50000,
        type: TransactionType.income,
        categoryId: 'salary',
        accountId: account.id,
        note: 'Monthly salary',
        date: DateTime.now(),
      ));

      final budget = Budget(
        name: 'Monthly Budget',
        limit: 20000,
        period: BudgetPeriod.monthly,
        categoryIds: ['food_dining', 'transport', 'shopping'],
        startDate: DateTime.now(),
        colorValue: 0xFF2196F3,
      );
      await FinanceStorageService.addBudget(budget);

      await FinanceStorageService.addTransaction(FinanceTransaction(
        amount: 5000,
        type: TransactionType.expense,
        categoryId: 'food_dining',
        accountId: account.id,
        date: DateTime.now(),
      ));

      final updatedAccount = FinanceStorageService.getAccount(account.id);
      expect(updatedAccount!.balance, greaterThan(account.balance));

      final budgets = FinanceStorageService.getAllBudgets();
      expect(budgets.first.spent, 5000);
      expect(budgets.first.remaining, 15000);
    });
  });
}
