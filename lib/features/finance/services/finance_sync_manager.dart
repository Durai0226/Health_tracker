import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_storage_service.dart';
import 'bill_storage_service.dart';
import 'finance_cloud_service.dart';

class FinanceSyncManager {
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  
  static bool get isInitialized => _isInitialized;
  static bool get isSyncing => _isSyncing;

  /// Initialize all finance services in the correct order
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    debugPrint('🚀 Initializing Finance Sync Manager...');
    
    try {
      // Initialize local storage services first
      await FinanceStorageService.init();
      await BillStorageService.init();
      
      // Set up auth state listener for automatic sync
      FirebaseAuth.instance.authStateChanges().listen(_onAuthStateChanged);
      
      _isInitialized = true;
      debugPrint('✅ Finance Sync Manager initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error initializing Finance Sync Manager: $e');
      return false;
    }
  }

  /// Handle authentication state changes
  static Future<void> _onAuthStateChanged(User? user) async {
    if (user != null && !user.isAnonymous) {
      debugPrint('👤 User authenticated - triggering sync...');
      await performInitialSync();
    } else {
      debugPrint('👤 User signed out - clearing sync status');
    }
  }

  /// Perform initial sync when user logs in
  static Future<bool> performInitialSync() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Cannot perform initial sync - user not authenticated');
      return false;
    }

    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress, skipping...');
      return false;
    }

    _isSyncing = true;
    debugPrint('🔄 Starting initial finance sync...');
    
    try {
      // First sync from cloud to get latest data
      final success = await FinanceCloudService.syncFinanceDataFromCloud();
      
      if (success) {
        debugPrint('✅ Initial sync completed successfully');
        
        // Schedule periodic sync
        _schedulePeriodicSync();
        return true;
      } else {
        debugPrint('⚠️ Initial sync completed with errors');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during initial sync: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync all finance data to cloud
  static Future<bool> syncToCloud({bool showProgress = false}) async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Cannot sync to cloud - user not authenticated');
      return false;
    }

    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress');
      return false;
    }

    _isSyncing = true;
    if (showProgress) debugPrint('📤 Syncing finance data to cloud...');

    try {
      final success = await FinanceCloudService.syncFinanceDataToCloud();
      
      if (success) {
        if (showProgress) debugPrint('✅ Finance data synced to cloud');
        return true;
      } else {
        if (showProgress) debugPrint('⚠️ Sync to cloud completed with errors');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error syncing to cloud: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync all finance data from cloud
  static Future<bool> syncFromCloud({bool showProgress = false}) async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Cannot sync from cloud - user not authenticated');
      return false;
    }

    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress');
      return false;
    }

    _isSyncing = true;
    if (showProgress) debugPrint('📥 Syncing finance data from cloud...');

    try {
      final success = await FinanceCloudService.syncFinanceDataFromCloud();
      
      if (success) {
        if (showProgress) debugPrint('✅ Finance data synced from cloud');
        return true;
      } else {
        if (showProgress) debugPrint('⚠️ Sync from cloud completed with errors');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error syncing from cloud: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Perform full bidirectional sync
  static Future<bool> performFullSync({bool showProgress = true}) async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Cannot perform full sync - user not authenticated');
      return false;
    }

    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress');
      return false;
    }

    _isSyncing = true;
    if (showProgress) debugPrint('🔄 Starting full finance sync...');

    try {
      final success = await FinanceCloudService.performFullSync();
      
      if (success) {
        if (showProgress) debugPrint('✅ Full finance sync completed');
        return true;
      } else {
        if (showProgress) debugPrint('⚠️ Full sync completed with some errors');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during full sync: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Schedule periodic background sync
  static void _schedulePeriodicSync() {
    debugPrint('⏰ Scheduling periodic sync...');
    
    // This would typically use a background task scheduler
    // For now, we'll use a simple timer approach
    Future.delayed(const Duration(minutes: 15), () async {
      if (FinanceCloudService.isUserAuthenticated && !_isSyncing) {
        await syncToCloud();
        _schedulePeriodicSync(); // Reschedule
      }
    });
  }

  /// Sync specific data when changes occur
  static Future<void> syncAfterDataChange({
    bool categories = false,
    bool accounts = false,
    bool transactions = false,
    bool budgets = false,
    bool bills = false,
    bool payments = false,
  }) async {
    if (!FinanceCloudService.isUserAuthenticated) return;

    // For now, perform a full sync
    // In production, you might want to sync only specific collections
    await syncToCloud();
  }

  /// Get sync status
  static Future<Map<String, dynamic>?> getSyncStatus() async {
    return await FinanceCloudService.getSyncStatus();
  }

  /// Force sync all data
  static Future<bool> forceSyncAll() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Cannot force sync - user not authenticated');
      return false;
    }

    debugPrint('🔄 Force syncing all finance data...');
    
    try {
      // Sync both directions
      await FinanceCloudService.syncFinanceDataFromCloud();
      await FinanceCloudService.syncFinanceDataToCloud();
      
      debugPrint('✅ Force sync completed');
      return true;
    } catch (e) {
      debugPrint('❌ Error during force sync: $e');
      return false;
    }
  }

  /// Create backup of all finance data
  static Future<bool> createBackup() async {
    if (!FinanceCloudService.isUserAuthenticated) {
      debugPrint('⚠️ Cannot create backup - user not authenticated');
      return false;
    }

    debugPrint('💾 Creating finance data backup...');
    
    try {
      final success = await FinanceCloudService.createBackup();
      
      if (success) {
        debugPrint('✅ Finance backup created');
        return true;
      } else {
        debugPrint('⚠️ Backup creation failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error creating backup: $e');
      return false;
    }
  }

  /// Check if sync is needed based on last sync time
  static Future<bool> isSyncNeeded() async {
    final status = await getSyncStatus();
    if (status == null) return true;

    final lastSync = status['lastSyncFromCloud'];
    if (lastSync == null) return true;

    // Check if more than 30 minutes since last sync
    final lastSyncTime = lastSync is Timestamp ? lastSync.toDate() : DateTime.now();
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime);
    
    return difference.inMinutes > 30;
  }

  /// Reset sync manager (for testing/debugging)
  static void reset() {
    _isInitialized = false;
    _isSyncing = false;
    debugPrint('🔄 Finance Sync Manager reset');
  }
}
