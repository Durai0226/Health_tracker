import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/finance_enums.dart';
import '../models/finance_category.dart';
import '../models/finance_account.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/bill.dart';
import '../models/bill_template.dart';
import 'finance_storage_service.dart';
import 'bill_storage_service.dart';

class FinanceCloudService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static String? get _currentUserId {
    final user = _auth.currentUser;
    return user?.uid;
  }

  static bool get isUserAuthenticated {
    final user = _auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  // ==================== SYNC TO CLOUD ====================

  static Future<bool> syncFinanceDataToCloud() async {
    if (!isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated - skipping cloud sync');
      return false;
    }

    final userId = _currentUserId!;
    debugPrint('🔄 Starting finance data sync to cloud...');

    try {
      final batch = _firestore.batch();
      
      // Sync Categories
      final categories = FinanceStorageService.getAllCategories();
      for (final category in categories) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('finance_categories')
            .doc(category.id);
        batch.set(docRef, {
          ...category.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'version': 1,
        }, SetOptions(merge: true));
      }

      // Sync Accounts
      final accounts = FinanceStorageService.getAllAccounts();
      for (final account in accounts) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('finance_accounts')
            .doc(account.id);
        batch.set(docRef, {
          ...account.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'version': 1,
        }, SetOptions(merge: true));
      }

      // Sync Transactions
      final transactions = FinanceStorageService.getAllTransactions();
      for (final transaction in transactions) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('finance_transactions')
            .doc(transaction.id);
        batch.set(docRef, {
          ...transaction.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'version': 1,
        }, SetOptions(merge: true));
      }

      // Sync Budgets
      final budgets = FinanceStorageService.getAllBudgets();
      for (final budget in budgets) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('finance_budgets')
            .doc(budget.id);
        batch.set(docRef, {
          ...budget.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'version': 1,
        }, SetOptions(merge: true));
      }

      // Sync Bills
      final bills = BillStorageService.getAllBills();
      for (final bill in bills.where((b) => !b.isDeleted)) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('finance_bills')
            .doc(bill.id);
        batch.set(docRef, {
          ...bill.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'version': 1,
        }, SetOptions(merge: true));
      }

      // Sync Bill Payments
      final payments = BillStorageService.getAllPayments();
      for (final payment in payments) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('finance_bill_payments')
            .doc(payment.id);
        batch.set(docRef, {
          ...payment.toJson(),
          'syncedAt': FieldValue.serverTimestamp(),
          'version': 1,
        }, SetOptions(merge: true));
      }

      await batch.commit();
      
      // Update sync status
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sync_status')
          .doc('finance')
          .set({
        'lastSyncToCloud': FieldValue.serverTimestamp(),
        'categoriesCount': categories.length,
        'accountsCount': accounts.length,
        'transactionsCount': transactions.length,
        'budgetsCount': budgets.length,
        'billsCount': bills.length,
        'paymentsCount': payments.length,
      }, SetOptions(merge: true));

      debugPrint('✅ Finance data synced to cloud successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing finance data to cloud: $e');
      return false;
    }
  }

  // ==================== SYNC FROM CLOUD ====================

  static Future<bool> syncFinanceDataFromCloud() async {
    if (!isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated - skipping cloud sync');
      return false;
    }

    final userId = _currentUserId!;
    debugPrint('🔄 Starting finance data sync from cloud...');

    try {
      // Sync Categories
      final categoriesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance_categories')
          .get();

      for (final doc in categoriesSnapshot.docs) {
        try {
          final cloudCategory = FinanceCategory.fromJson(doc.data());
          final localCategory = FinanceStorageService.getCategory(cloudCategory.id);
          
          if (localCategory == null || 
              (doc.data()['syncedAt'] as Timestamp?)?.toDate().isAfter(DateTime.now()) == true) {
            await FinanceStorageService.addCategory(cloudCategory);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing category ${doc.id}: $e');
        }
      }

      // Sync Accounts
      final accountsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance_accounts')
          .get();

      for (final doc in accountsSnapshot.docs) {
        try {
          final cloudAccount = FinanceAccount.fromJson(doc.data());
          final localAccount = FinanceStorageService.getAccount(cloudAccount.id);
          
          if (localAccount == null || 
              (doc.data()['syncedAt'] as Timestamp?)?.toDate().isAfter(DateTime.now()) == true) {
            await FinanceStorageService.addAccount(cloudAccount);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing account ${doc.id}: $e');
        }
      }

      // Sync Transactions
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance_transactions')
          .get();

      for (final doc in transactionsSnapshot.docs) {
        try {
          final cloudTransaction = FinanceTransaction.fromJson(doc.data());
          final existingTransactions = FinanceStorageService.getAllTransactions();
          final localTransaction = existingTransactions
              .where((t) => t.id == cloudTransaction.id)
              .firstOrNull;
          
          if (localTransaction == null) {
            await FinanceStorageService.addTransaction(cloudTransaction);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing transaction ${doc.id}: $e');
        }
      }

      // Sync Budgets
      final budgetsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance_budgets')
          .get();

      for (final doc in budgetsSnapshot.docs) {
        try {
          final cloudBudget = Budget.fromJson(doc.data());
          final localBudget = FinanceStorageService.getBudget(cloudBudget.id);
          
          if (localBudget == null || 
              (doc.data()['syncedAt'] as Timestamp?)?.toDate().isAfter(DateTime.now()) == true) {
            await FinanceStorageService.addBudget(cloudBudget);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing budget ${doc.id}: $e');
        }
      }

      // Sync Bills
      final billsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance_bills')
          .get();

      for (final doc in billsSnapshot.docs) {
        try {
          final cloudBill = Bill.fromJson(doc.data());
          final localBill = BillStorageService.getBill(cloudBill.id);
          
          if (localBill == null || 
              cloudBill.updatedAt.isAfter(localBill.updatedAt)) {
            await BillStorageService.saveBill(cloudBill);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing bill ${doc.id}: $e');
        }
      }

      // Sync Bill Payments
      final paymentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('finance_bill_payments')
          .get();

      for (final doc in paymentsSnapshot.docs) {
        try {
          final cloudPayment = BillPayment.fromJson(doc.data());
          final existingPayments = BillStorageService.getAllPayments();
          final localPayment = existingPayments
              .where((p) => p.id == cloudPayment.id)
              .firstOrNull;
          
          if (localPayment == null || 
              cloudPayment.paidAt.isAfter(localPayment.paidAt)) {
            // Need to manually add payment without triggering balance updates
            await BillStorageService.updatePayment(cloudPayment);
          }
        } catch (e) {
          debugPrint('⚠️ Error syncing payment ${doc.id}: $e');
        }
      }

      // Update sync status
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sync_status')
          .doc('finance')
          .set({
        'lastSyncFromCloud': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Finance data synced from cloud successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing finance data from cloud: $e');
      return false;
    }
  }

  // ==================== FULL SYNC ====================

  static Future<bool> performFullSync() async {
    if (!isUserAuthenticated) {
      debugPrint('⚠️ User not authenticated - cannot perform sync');
      return false;
    }

    debugPrint('🔄 Starting full finance data sync...');
    
    try {
      // First sync from cloud to get latest data
      final fromCloudSuccess = await syncFinanceDataFromCloud();
      if (!fromCloudSuccess) {
        debugPrint('⚠️ Sync from cloud failed, continuing with to-cloud sync...');
      }
      
      // Then sync to cloud to upload any local changes
      final toCloudSuccess = await syncFinanceDataToCloud();
      
      final success = fromCloudSuccess && toCloudSuccess;
      debugPrint(success 
          ? '✅ Full finance sync completed successfully'
          : '⚠️ Full finance sync completed with some errors');
      
      return success;
    } catch (e) {
      debugPrint('❌ Error during full finance sync: $e');
      return false;
    }
  }

  // ==================== REAL-TIME SYNC ====================

  static Stream<QuerySnapshot>? getFinanceDataStream(String collection) {
    if (!isUserAuthenticated) return null;

    final userId = _currentUserId!;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .snapshots();
  }

  // ==================== SYNC STATUS ====================

  static Future<Map<String, dynamic>?> getSyncStatus() async {
    if (!isUserAuthenticated) return null;

    final userId = _currentUserId!;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sync_status')
          .doc('finance')
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('❌ Error getting sync status: $e');
      return null;
    }
  }

  // ==================== DELETE FROM CLOUD ====================

  static Future<bool> deleteFinanceDataFromCloud(String collection, String docId) async {
    if (!isUserAuthenticated) return false;

    final userId = _currentUserId!;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(docId)
          .delete();
      
      debugPrint('✅ Deleted $docId from $collection in cloud');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting $docId from cloud: $e');
      return false;
    }
  }

  // ==================== BACKUP/RESTORE ====================

  static Future<bool> createBackup() async {
    if (!isUserAuthenticated) return false;

    final userId = _currentUserId!;
    try {
      final backupData = {
        'createdAt': FieldValue.serverTimestamp(),
        'version': '1.0',
        'categories': FinanceStorageService.getAllCategories().map((c) => c.toJson()).toList(),
        'accounts': FinanceStorageService.getAllAccounts().map((a) => a.toJson()).toList(),
        'transactions': FinanceStorageService.getAllTransactions().map((t) => t.toJson()).toList(),
        'budgets': FinanceStorageService.getAllBudgets().map((b) => b.toJson()).toList(),
        'bills': BillStorageService.getAllBills().map((b) => b.toJson()).toList(),
        'payments': BillStorageService.getAllPayments().map((p) => p.toJson()).toList(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('backups')
          .doc('finance_${DateTime.now().millisecondsSinceEpoch}')
          .set(backupData);

      debugPrint('✅ Finance backup created successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating backup: $e');
      return false;
    }
  }

  // ==================== CONFLICT RESOLUTION ====================

  static Future<void> resolveConflicts() async {
    // This would implement more sophisticated conflict resolution
    // For now, we use "server wins" approach via timestamps
    debugPrint('🔧 Conflict resolution using server timestamps');
  }
}
