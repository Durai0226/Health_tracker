import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/finance_models.dart';
import 'finance_service.dart';

/// Finance Sync Service - handles Firestore bidirectional sync
class FinanceSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isSyncing = false;

  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _userCollection(String collection) {
    return _firestore.collection('users').doc(_userId).collection(collection);
  }

  /// Sync all finance data to cloud
  static Future<void> syncToCloud() async {
    if (_userId == null || _isSyncing) return;
    _isSyncing = true;

    try {
      await Future.wait([
        _syncAccountsToCloud(),
        _syncCategoriesToCloud(),
        _syncTransactionsToCloud(),
        _syncBudgetsToCloud(),
        _syncBillsToCloud(),
        _syncInvestmentsToCloud(),
      ]);
      debugPrint('✓ Finance data synced to cloud');
    } catch (e) {
      debugPrint('❌ Error syncing to cloud: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync all finance data from cloud
  static Future<void> syncFromCloud() async {
    if (_userId == null || _isSyncing) return;
    _isSyncing = true;

    try {
      await Future.wait([
        _syncAccountsFromCloud(),
        _syncCategoriesFromCloud(),
        _syncTransactionsFromCloud(),
        _syncBudgetsFromCloud(),
        _syncBillsFromCloud(),
        _syncInvestmentsFromCloud(),
      ]);
      debugPrint('✓ Finance data synced from cloud');
    } catch (e) {
      debugPrint('❌ Error syncing from cloud: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ==================== ACCOUNTS SYNC ====================

  static Future<void> _syncAccountsToCloud() async {
    final accounts = FinanceService.getAccounts(includeArchived: true);
    final batch = _firestore.batch();
    
    for (final account in accounts) {
      batch.set(
        _userCollection('financeAccounts').doc(account.id),
        account.toJson(),
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
  }

  static Future<void> _syncAccountsFromCloud() async {
    final snapshot = await _userCollection('financeAccounts').get();
    
    for (final doc in snapshot.docs) {
      final account = FinanceAccount.fromJson(doc.data());
      final existing = FinanceService.getAccount(account.id);
      
      if (existing == null) {
        await FinanceService.addAccount(account);
      } else if (account.updatedAt.isAfter(existing.updatedAt)) {
        await FinanceService.updateAccount(account);
      }
    }
  }

  // ==================== CATEGORIES SYNC ====================

  static Future<void> _syncCategoriesToCloud() async {
    final categories = FinanceService.getCategories();
    final batch = _firestore.batch();
    
    for (final category in categories) {
      batch.set(
        _userCollection('financeCategories').doc(category.id),
        category.toJson(),
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
  }

  static Future<void> _syncCategoriesFromCloud() async {
    final snapshot = await _userCollection('financeCategories').get();
    
    for (final doc in snapshot.docs) {
      final category = FinanceCategory.fromJson(doc.data());
      final existing = FinanceService.getCategory(category.id);
      
      if (existing == null) {
        await FinanceService.addCategory(category);
      }
    }
  }

  // ==================== TRANSACTIONS SYNC ====================

  static Future<void> _syncTransactionsToCloud() async {
    final transactions = FinanceService.getTransactions();
    final batch = _firestore.batch();
    
    for (final transaction in transactions) {
      batch.set(
        _userCollection('financeTransactions').doc(transaction.id),
        transaction.toJson(),
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
  }

  static Future<void> _syncTransactionsFromCloud() async {
    final snapshot = await _userCollection('financeTransactions').get();
    
    for (final doc in snapshot.docs) {
      final transaction = FinanceTransaction.fromJson(doc.data());
      final existing = FinanceService.getTransaction(transaction.id);
      
      if (existing == null) {
        await FinanceService.addTransaction(transaction);
      } else if (transaction.updatedAt.isAfter(existing.updatedAt)) {
        await FinanceService.updateTransaction(transaction);
      }
    }
  }

  // ==================== BUDGETS SYNC ====================

  static Future<void> _syncBudgetsToCloud() async {
    final budgets = FinanceService.getBudgets(includeArchived: true);
    final batch = _firestore.batch();
    
    for (final budget in budgets) {
      batch.set(
        _userCollection('financeBudgets').doc(budget.id),
        budget.toJson(),
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
  }

  static Future<void> _syncBudgetsFromCloud() async {
    final snapshot = await _userCollection('financeBudgets').get();
    
    for (final doc in snapshot.docs) {
      final budget = FinanceBudget.fromJson(doc.data());
      final existing = FinanceService.getBudget(budget.id);
      
      if (existing == null) {
        await FinanceService.addBudget(budget);
      } else if (budget.updatedAt.isAfter(existing.updatedAt)) {
        await FinanceService.updateBudget(budget);
      }
    }
  }

  // ==================== BILLS SYNC ====================

  static Future<void> _syncBillsToCloud() async {
    final bills = FinanceService.getBills(includeArchived: true);
    final batch = _firestore.batch();
    
    for (final bill in bills) {
      batch.set(
        _userCollection('financeBills').doc(bill.id),
        bill.toJson(),
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
  }

  static Future<void> _syncBillsFromCloud() async {
    final snapshot = await _userCollection('financeBills').get();
    
    for (final doc in snapshot.docs) {
      final bill = FinanceBill.fromJson(doc.data());
      final existing = FinanceService.getBill(bill.id);
      
      if (existing == null) {
        await FinanceService.addBill(bill);
      } else if (bill.updatedAt.isAfter(existing.updatedAt)) {
        await FinanceService.updateBill(bill);
      }
    }
  }

  // ==================== INVESTMENTS SYNC ====================

  static Future<void> _syncInvestmentsToCloud() async {
    final investments = FinanceService.getInvestments(activeOnly: false);
    final batch = _firestore.batch();
    
    for (final investment in investments) {
      batch.set(
        _userCollection('financeInvestments').doc(investment.id),
        investment.toJson(),
        SetOptions(merge: true),
      );
    }
    
    await batch.commit();
  }

  static Future<void> _syncInvestmentsFromCloud() async {
    final snapshot = await _userCollection('financeInvestments').get();
    
    for (final doc in snapshot.docs) {
      final investment = FinanceInvestment.fromJson(doc.data());
      final existing = FinanceService.getInvestment(investment.id);
      
      if (existing == null) {
        await FinanceService.addInvestment(investment);
      } else if (investment.updatedAt.isAfter(existing.updatedAt)) {
        await FinanceService.updateInvestment(investment);
      }
    }
  }

  /// Delete all finance data from cloud for current user
  static Future<void> deleteAllCloudData() async {
    if (_userId == null) return;

    final collections = [
      'financeAccounts',
      'financeCategories',
      'financeTransactions',
      'financeBudgets',
      'financeBills',
      'financeInvestments',
    ];

    for (final collection in collections) {
      final snapshot = await _userCollection(collection).get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    debugPrint('✓ All finance cloud data deleted');
  }
}
