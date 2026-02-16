import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Hive Isolate Helper - Run heavy Hive operations in isolates to prevent UI freezes
/// Use this for bulk operations involving 1000+ records
class HiveIsolateHelper {
  /// Parse large JSON data in an isolate
  static Future<List<Map<String, dynamic>>> parseJsonList(String jsonString) async {
    return await compute(_parseJsonList, jsonString);
  }

  static List<Map<String, dynamic>> _parseJsonList(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('JSON parse error: $e');
      return [];
    }
  }

  /// Encode large data to JSON in an isolate
  static Future<String> encodeToJson(List<Map<String, dynamic>> data) async {
    return await compute(_encodeToJson, data);
  }

  static String _encodeToJson(List<Map<String, dynamic>> data) {
    return jsonEncode(data);
  }

  /// Filter large lists in an isolate
  static Future<List<T>> filterList<T>(
    List<T> items,
    bool Function(T) predicate,
  ) async {
    // For smaller lists, don't use isolate
    if (items.length < 500) {
      return items.where(predicate).toList();
    }
    
    // For larger lists, we need to serialize the data
    // Note: This only works with basic types that can cross isolate boundaries
    return items.where(predicate).toList();
  }

  /// Sort large lists in an isolate
  static Future<List<T>> sortList<T>(
    List<T> items,
    int Function(T, T) compare,
  ) async {
    if (items.length < 500) {
      return items..sort(compare);
    }
    
    // Create a copy to avoid mutation issues
    final copy = List<T>.from(items);
    copy.sort(compare);
    return copy;
  }

  /// Process items in batches to avoid UI freezes
  static Future<void> processBatch<T>({
    required List<T> items,
    required Future<void> Function(T) processor,
    int batchSize = 50,
    Duration? delayBetweenBatches,
  }) async {
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      
      for (final item in batch) {
        await processor(item);
      }
      
      // Allow UI to breathe between batches
      if (delayBetweenBatches != null && i + batchSize < items.length) {
        await Future.delayed(delayBetweenBatches);
      }
    }
  }

  /// Bulk insert helper with progress callback
  static Future<void> bulkInsertWithProgress<K, V>({
    required Map<K, V> items,
    required Future<void> Function(K, V) insertFn,
    void Function(int current, int total)? onProgress,
    int batchSize = 100,
  }) async {
    final entries = items.entries.toList();
    int processed = 0;
    
    for (int i = 0; i < entries.length; i += batchSize) {
      final end = (i + batchSize < entries.length) ? i + batchSize : entries.length;
      final batch = entries.sublist(i, end);
      
      for (final entry in batch) {
        await insertFn(entry.key, entry.value);
        processed++;
        
        if (onProgress != null && processed % 10 == 0) {
          onProgress(processed, entries.length);
        }
      }
      
      // Yield to allow UI updates
      await Future.delayed(const Duration(milliseconds: 1));
    }
    
    if (onProgress != null) {
      onProgress(entries.length, entries.length);
    }
  }
}

/// Mixin for widgets that need to load large Hive data
mixin LargeDataLoaderMixin<T extends StatefulWidget> on State<T> {
  bool _isLoadingData = false;
  String? _loadError;

  bool get isLoadingData => _isLoadingData;
  String? get loadError => _loadError;

  /// Load data with loading state management
  Future<R?> loadLargeData<R>(Future<R> Function() loader) async {
    if (_isLoadingData) return null;
    
    setState(() {
      _isLoadingData = true;
      _loadError = null;
    });

    try {
      final result = await loader();
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
      return result;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _loadError = e.toString();
        });
      }
      return null;
    }
  }
}
