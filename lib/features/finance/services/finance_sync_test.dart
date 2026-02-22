import 'package:flutter/foundation.dart';
import '../models/finance_category.dart';
import '../models/finance_account.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import 'finance_storage_service.dart';
import 'bill_storage_service.dart';
import 'finance_sync_manager.dart';
import 'finance_cloud_service.dart';

class FinanceSyncTest {
  static Future<Map<String, bool>> runComprehensiveTest() async {
    final results = <String, bool>{};
    
    debugPrint('🧪 Starting comprehensive finance sync tests...');
    
    try {
      // Test 1: Service Initialization
      results['service_initialization'] = await _testServiceInitialization();
      
      // Test 2: Local Data Storage
      results['local_data_storage'] = await _testLocalDataStorage();
      
      // Test 3: Cloud Authentication Check
      results['cloud_authentication'] = await _testCloudAuthentication();
      
      // Test 4: Cloud Data Sync (if authenticated)
      if (results['cloud_authentication'] == true) {
        results['cloud_data_sync'] = await _testCloudDataSync();
      } else {
        results['cloud_data_sync'] = null; // Skipped due to no auth
      }
      
      // Test 5: Data Integrity
      results['data_integrity'] = await _testDataIntegrity();
      
      // Test 6: Error Handling
      results['error_handling'] = await _testErrorHandling();
      
      _printTestResults(results);
      return results;
    } catch (e) {
      debugPrint('❌ Test suite failed with error: $e');
      results['test_suite'] = false;
      return results;
    }
  }

  static Future<bool> _testServiceInitialization() async {
    debugPrint('🔧 Testing service initialization...');
    
    try {
      // Test FinanceSyncManager initialization
      final managerInit = await FinanceSyncManager.initialize();
      if (!managerInit) {
        debugPrint('❌ FinanceSyncManager initialization failed');
        return false;
      }
      
      // Check if services are properly initialized
      if (!FinanceStorageService.isInitialized) {
        debugPrint('❌ FinanceStorageService not initialized');
        return false;
      }
      
      if (!BillStorageService.isInitialized) {
        debugPrint('❌ BillStorageService not initialized');
        return false;
      }
      
      debugPrint('✅ Service initialization test passed');
      return true;
    } catch (e) {
      debugPrint('❌ Service initialization test failed: $e');
      return false;
    }
  }

  static Future<bool> _testLocalDataStorage() async {
    debugPrint('💾 Testing local data storage...');
    
    try {
      // Test Category Storage
      final testCategory = FinanceCategory(
        id: 'test_category_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Category',
        isIncome: false,
        sortOrder: 999,
      );
      
      await FinanceStorageService.addCategory(testCategory);
      final retrievedCategory = FinanceStorageService.getCategory(testCategory.id);
      
      if (retrievedCategory == null || retrievedCategory.name != testCategory.name) {
        debugPrint('❌ Category storage/retrieval failed');
        return false;
      }
      
      // Test Account Storage
      final testAccount = FinanceAccount(
        id: 'test_account_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Account',
        balance: 1000.0,
        accountType: AccountType.checking,
        sortOrder: 999,
      );
      
      await FinanceStorageService.addAccount(testAccount);
      final retrievedAccount = FinanceStorageService.getAccount(testAccount.id);
      
      if (retrievedAccount == null || retrievedAccount.balance != testAccount.balance) {
        debugPrint('❌ Account storage/retrieval failed');
        return false;
      }
      
      // Test Transaction Storage
      final testTransaction = FinanceTransaction(
        id: 'test_transaction_${DateTime.now().millisecondsSinceEpoch}',
        amount: 100.0,
        type: TransactionType.expense,
        categoryId: testCategory.id,
        accountId: testAccount.id,
        description: 'Test Transaction',
        date: DateTime.now(),
      );
      
      await FinanceStorageService.addTransaction(testTransaction);
      final allTransactions = FinanceStorageService.getAllTransactions();
      final retrievedTransaction = allTransactions
          .where((t) => t.id == testTransaction.id)
          .firstOrNull;
      
      if (retrievedTransaction == null || retrievedTransaction.amount != testTransaction.amount) {
        debugPrint('❌ Transaction storage/retrieval failed');
        return false;
      }
      
      // Test Bill Storage
      final testBill = Bill(
        id: 'test_bill_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Bill',
        amount: 200.0,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        recurrence: BillRecurrence.monthly,
        categoryId: testCategory.id,
        accountId: testAccount.id,
      );
      
      await BillStorageService.saveBill(testBill);
      final retrievedBill = BillStorageService.getBill(testBill.id);
      
      if (retrievedBill == null || retrievedBill.amount != testBill.amount) {
        debugPrint('❌ Bill storage/retrieval failed');
        return false;
      }
      
      debugPrint('✅ Local data storage test passed');
      return true;
    } catch (e) {
      debugPrint('❌ Local data storage test failed: $e');
      return false;
    }
  }

  static Future<bool> _testCloudAuthentication() async {
    debugPrint('🔐 Testing cloud authentication...');
    
    try {
      final isAuthenticated = FinanceCloudService.isUserAuthenticated;
      
      if (isAuthenticated) {
        debugPrint('✅ User is authenticated for cloud sync');
        return true;
      } else {
        debugPrint('⚠️ User is not authenticated - cloud sync will be skipped');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Cloud authentication test failed: $e');
      return false;
    }
  }

  static Future<bool> _testCloudDataSync() async {
    debugPrint('☁️ Testing cloud data sync...');
    
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Skipping cloud sync test - user not authenticated');
      return false;
    }
    
    try {
      // Test sync to cloud
      final syncToCloudSuccess = await FinanceSyncManager.syncToCloud(showProgress: true);
      if (!syncToCloudSuccess) {
        debugPrint('❌ Sync to cloud failed');
        return false;
      }
      
      // Wait a moment for cloud propagation
      await Future.delayed(const Duration(seconds: 2));
      
      // Test sync from cloud
      final syncFromCloudSuccess = await FinanceSyncManager.syncFromCloud(showProgress: true);
      if (!syncFromCloudSuccess) {
        debugPrint('❌ Sync from cloud failed');
        return false;
      }
      
      // Test full sync
      final fullSyncSuccess = await FinanceSyncManager.performFullSync();
      if (!fullSyncSuccess) {
        debugPrint('❌ Full sync failed');
        return false;
      }
      
      debugPrint('✅ Cloud data sync test passed');
      return true;
    } catch (e) {
      debugPrint('❌ Cloud data sync test failed: $e');
      return false;
    }
  }

  static Future<bool> _testDataIntegrity() async {
    debugPrint('🔍 Testing data integrity...');
    
    try {
      // Test that data counts are consistent
      final categories = FinanceStorageService.getAllCategories();
      final accounts = FinanceStorageService.getAllAccounts();
      final transactions = FinanceStorageService.getAllTransactions();
      final bills = BillStorageService.getAllBills();
      
      if (categories.isEmpty) {
        debugPrint('❌ No categories found - default categories may not have been initialized');
        return false;
      }
      
      if (accounts.isEmpty) {
        debugPrint('❌ No accounts found - default account may not have been initialized');
        return false;
      }
      
      // Test that transactions reference valid accounts and categories
      for (final transaction in transactions.take(5)) { // Check first 5
        final account = FinanceStorageService.getAccount(transaction.accountId);
        final category = FinanceStorageService.getCategory(transaction.categoryId);
        
        if (account == null) {
          debugPrint('❌ Transaction ${transaction.id} references non-existent account');
          return false;
        }
        
        if (category == null) {
          debugPrint('❌ Transaction ${transaction.id} references non-existent category');
          return false;
        }
      }
      
      // Test that bills reference valid accounts and categories
      for (final bill in bills.take(5)) { // Check first 5
        if (bill.accountId != null) {
          final account = FinanceStorageService.getAccount(bill.accountId!);
          if (account == null) {
            debugPrint('❌ Bill ${bill.id} references non-existent account');
            return false;
          }
        }
        
        if (bill.categoryId != null) {
          final category = FinanceStorageService.getCategory(bill.categoryId!);
          if (category == null) {
            debugPrint('❌ Bill ${bill.id} references non-existent category');
            return false;
          }
        }
      }
      
      debugPrint('✅ Data integrity test passed');
      debugPrint('📊 Data summary: ${categories.length} categories, ${accounts.length} accounts, ${transactions.length} transactions, ${bills.length} bills');
      return true;
    } catch (e) {
      debugPrint('❌ Data integrity test failed: $e');
      return false;
    }
  }

  static Future<bool> _testErrorHandling() async {
    debugPrint('🚨 Testing error handling...');
    
    try {
      // Test handling of non-existent data
      final nonExistentCategory = FinanceStorageService.getCategory('non_existent_id');
      if (nonExistentCategory != null) {
        debugPrint('❌ Should return null for non-existent category');
        return false;
      }
      
      final nonExistentAccount = FinanceStorageService.getAccount('non_existent_id');
      if (nonExistentAccount != null) {
        debugPrint('❌ Should return null for non-existent account');
        return false;
      }
      
      final nonExistentBill = BillStorageService.getBill('non_existent_id');
      if (nonExistentBill != null) {
        debugPrint('❌ Should return null for non-existent bill');
        return false;
      }
      
      debugPrint('✅ Error handling test passed');
      return true;
    } catch (e) {
      debugPrint('❌ Error handling test failed: $e');
      return false;
    }
  }

  static void _printTestResults(Map<String, bool> results) {
    debugPrint('\n📊 FINANCE SYNC TEST RESULTS:');
    debugPrint('================================');
    
    int passed = 0;
    int total = 0;
    
    results.forEach((testName, result) {
      if (result != null) {
        final status = result ? '✅ PASS' : '❌ FAIL';
        final formattedName = testName.replaceAll('_', ' ').toUpperCase();
        debugPrint('$formattedName: $status');
        
        if (result) passed++;
        total++;
      } else {
        final formattedName = testName.replaceAll('_', ' ').toUpperCase();
        debugPrint('$formattedName: ⏭️ SKIPPED');
      }
    });
    
    debugPrint('================================');
    debugPrint('SUMMARY: $passed/$total tests passed');
    
    if (passed == total) {
      debugPrint('🎉 All tests passed! Finance sync is working correctly.');
    } else {
      debugPrint('⚠️ Some tests failed. Please review the issues above.');
    }
  }

  /// Run quick smoke test
  static Future<bool> runSmokeTest() async {
    debugPrint('💨 Running quick smoke test...');
    
    try {
      // Test basic initialization
      if (!FinanceStorageService.isInitialized || !BillStorageService.isInitialized) {
        debugPrint('❌ Services not initialized');
        return false;
      }
      
      // Test basic data retrieval
      final categories = FinanceStorageService.getAllCategories();
      final accounts = FinanceStorageService.getAllAccounts();
      
      if (categories.isEmpty || accounts.isEmpty) {
        debugPrint('❌ Missing default data');
        return false;
      }
      
      debugPrint('✅ Smoke test passed - basic functionality working');
      return true;
    } catch (e) {
      debugPrint('❌ Smoke test failed: $e');
      return false;
    }
  }
}
