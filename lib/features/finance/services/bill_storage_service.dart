import 'package:flutter/foundation.dart';
import '../../../core/services/clean_storage_service.dart';
import '../models/finance_models.dart';

/// Bill Storage Service - wrapper for CleanStorageService bill methods
/// Provides backward compatibility with existing code
class BillStorageService {
  static final BillStorageService _instance = BillStorageService._internal();
  factory BillStorageService() => _instance;
  BillStorageService._internal();

  bool _isInitialized = false;

  /// Initialize the bill storage service
  Future<void> init() async {
    if (_isInitialized) return;
    await CleanStorageService.init();
    _isInitialized = true;
    debugPrint('BillStorageService initialized');
  }

  /// Get all bills
  Future<List<FinanceBill>> getAllBills() async {
    return CleanStorageService.getAllBills();
  }

  /// Get bills as models
  List<FinanceBill> getBillsAsModels() {
    return CleanStorageService.getBillsAsModels();
  }

  /// Save a bill
  Future<void> saveBill(FinanceBill bill) async {
    await CleanStorageService.saveBillFromModel(bill);
  }

  /// Get bill by ID
  FinanceBill? getBill(String id) {
    return CleanStorageService.getBillAsModel(id);
  }

  /// Duplicate a bill
  Future<void> duplicateBill(FinanceBill bill) async {
    await CleanStorageService.duplicateBill(bill);
  }
}
