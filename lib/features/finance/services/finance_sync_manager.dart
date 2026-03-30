import 'package:flutter/foundation.dart';
import 'finance_sync_service.dart';

/// Finance Sync Manager - wrapper for FinanceSyncService
/// Provides backward compatibility with existing code
class FinanceSyncManager {
  static final FinanceSyncManager _instance = FinanceSyncManager._internal();
  factory FinanceSyncManager() => _instance;
  FinanceSyncManager._internal();

  bool _isInitialized = false;

  /// Initialize the sync manager
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('FinanceSyncManager initialized');
  }

  /// Sync all finance data to cloud
  Future<void> syncToCloud() async {
    await FinanceSyncService.syncToCloud();
  }

  /// Sync all finance data from cloud
  Future<void> syncFromCloud() async {
    await FinanceSyncService.syncFromCloud();
  }

  /// Full bidirectional sync
  Future<void> fullSync() async {
    await syncFromCloud();
    await syncToCloud();
  }
}
