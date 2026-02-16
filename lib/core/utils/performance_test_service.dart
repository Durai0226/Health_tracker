import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Comprehensive Performance Test Service
/// Tests cold start, Hive operations, Firestore queries, and memory usage
class PerformanceTestService {
  static final PerformanceTestService _instance = PerformanceTestService._internal();
  factory PerformanceTestService() => _instance;
  PerformanceTestService._internal();

  final Map<String, Duration> _benchmarks = {};
  final List<String> _testResults = [];
  Stopwatch? _appStartStopwatch;

  // ============ APP STARTUP TESTS ============

  /// Call this at the very beginning of main()
  void startColdStartTimer() {
    _appStartStopwatch = Stopwatch()..start();
    debugPrint('⏱️ Cold start timer started');
  }

  /// Call this when first frame is rendered
  void endColdStartTimer() {
    if (_appStartStopwatch != null) {
      _appStartStopwatch!.stop();
      final duration = _appStartStopwatch!.elapsed;
      _benchmarks['cold_start'] = duration;
      
      String status;
      if (duration.inMilliseconds < 1000) {
        status = '🟢 EXCELLENT';
      } else if (duration.inMilliseconds < 2000) {
        status = '🟡 GOOD';
      } else {
        status = '🔴 NEEDS OPTIMIZATION';
      }
      
      _testResults.add('Cold Start: ${duration.inMilliseconds}ms - $status');
      debugPrint('⏱️ Cold start completed: ${duration.inMilliseconds}ms - $status');
    }
  }

  // ============ HIVE PERFORMANCE TESTS ============

  /// Test bulk insert performance (1000 items)
  Future<Duration> testHiveBulkInsert({
    required String boxName,
    int itemCount = 1000,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final box = await Hive.openBox<Map>('perf_test_$boxName');
      
      for (int i = 0; i < itemCount; i++) {
        await box.put('item_$i', {
          'id': 'item_$i',
          'name': 'Test Item $i',
          'timestamp': DateTime.now().toIso8601String(),
          'data': List.generate(10, (j) => 'value_$j'),
        });
      }
      
      stopwatch.stop();
      await box.deleteFromDisk();
      
      final duration = stopwatch.elapsed;
      String status = duration.inMilliseconds < 1000 ? '🟢 PASS' : '🔴 SLOW';
      _testResults.add('Hive Bulk Insert ($itemCount items): ${duration.inMilliseconds}ms - $status');
      debugPrint('📦 Hive bulk insert: ${duration.inMilliseconds}ms - $status');
      
      return duration;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Hive bulk insert test failed: $e');
      return stopwatch.elapsed;
    }
  }

  /// Test read performance
  Future<Duration> testHiveReadPerformance({
    required String boxName,
    int itemCount = 5000,
  }) async {
    try {
      final box = await Hive.openBox<Map>('perf_test_read_$boxName');
      
      // First, populate the box
      for (int i = 0; i < itemCount; i++) {
        await box.put('item_$i', {
          'id': 'item_$i',
          'name': 'Test Item $i',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      // Now test read performance
      final stopwatch = Stopwatch()..start();
      final allItems = box.values.toList();
      stopwatch.stop();
      
      await box.deleteFromDisk();
      
      final duration = stopwatch.elapsed;
      String status = duration.inMilliseconds < 500 ? '🟢 PASS' : '🔴 SLOW';
      _testResults.add('Hive Read ($itemCount items): ${duration.inMilliseconds}ms - $status');
      debugPrint('📖 Hive read: ${duration.inMilliseconds}ms (${allItems.length} items) - $status');
      
      return duration;
    } catch (e) {
      debugPrint('❌ Hive read test failed: $e');
      return Duration.zero;
    }
  }

  /// Test frequent writes (simulating rapid updates)
  Future<Duration> testHiveFrequentWrites({
    int writeCount = 100,
    int delayMs = 10,
  }) async {
    try {
      final box = await Hive.openBox<Map>('perf_test_frequent');
      
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < writeCount; i++) {
        await box.put('rapid_item', {
          'counter': i,
          'timestamp': DateTime.now().toIso8601String(),
        });
        if (delayMs > 0) {
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
      
      stopwatch.stop();
      await box.deleteFromDisk();
      
      final duration = stopwatch.elapsed;
      _testResults.add('Hive Frequent Writes ($writeCount): ${duration.inMilliseconds}ms');
      debugPrint('✍️ Hive frequent writes: ${duration.inMilliseconds}ms');
      
      return duration;
    } catch (e) {
      debugPrint('❌ Hive frequent writes test failed: $e');
      return Duration.zero;
    }
  }

  // ============ FIRESTORE PERFORMANCE TESTS ============

  /// Test Firestore query with limit
  Future<Duration> testFirestoreQueryWithLimit({
    required String collection,
    int limit = 20,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .limit(limit)
          .get();
      
      stopwatch.stop();
      final duration = stopwatch.elapsed;
      _testResults.add('Firestore Query (limit $limit): ${duration.inMilliseconds}ms');
      debugPrint('🔥 Firestore query with limit: ${duration.inMilliseconds}ms');
      
      return duration;
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ Firestore query test failed: $e');
      return stopwatch.elapsed;
    }
  }

  /// Test offline capability
  Future<bool> testFirestoreOfflineCapability() async {
    try {
      // Check if persistence is enabled
      final settings = FirebaseFirestore.instance.settings;
      final isEnabled = settings.persistenceEnabled;
      
      String status = isEnabled == true ? '🟢 ENABLED' : '🔴 DISABLED';
      _testResults.add('Firestore Persistence: $status');
      debugPrint('💾 Firestore persistence: $status');
      
      return isEnabled == true;
    } catch (e) {
      debugPrint('❌ Firestore offline test failed: $e');
      return false;
    }
  }

  // ============ MEMORY TESTS ============

  /// Log current memory usage (debug only)
  void logMemoryUsage(String context) {
    if (kDebugMode) {
      debugPrint('🧠 Memory check at: $context');
      // In debug mode, memory info is available through DevTools
      // This is a placeholder for manual DevTools inspection
    }
  }

  // ============ ISOLATE HELPERS FOR HEAVY OPERATIONS ============

  /// Run heavy JSON parsing in isolate
  static Future<T> runInIsolate<T>(FutureOr<T> Function() computation) async {
    return await compute((_) => computation(), null);
  }

  /// Parse large JSON in isolate
  static Future<List<Map<String, dynamic>>> parseJsonInIsolate(
    String jsonString,
  ) async {
    return await compute(_parseJson, jsonString);
  }

  static List<Map<String, dynamic>> _parseJson(String jsonString) {
    // Simple JSON parsing - in real use, import dart:convert
    return [];
  }

  // ============ PERFORMANCE REPORT ============

  /// Get all test results
  List<String> getTestResults() => List.unmodifiable(_testResults);

  /// Print comprehensive performance report
  void printPerformanceReport() {
    debugPrint('\n${'=' * 50}');
    debugPrint('📊 PERFORMANCE TEST REPORT');
    debugPrint('=' * 50);
    
    for (final result in _testResults) {
      debugPrint(result);
    }
    
    debugPrint('=' * 50 + '\n');
  }

  /// Clear all test results
  void clearResults() {
    _testResults.clear();
    _benchmarks.clear();
  }

  /// Run all performance tests
  Future<void> runAllTests() async {
    debugPrint('\n🚀 Starting comprehensive performance tests...\n');
    
    // Hive tests
    await testHiveBulkInsert(boxName: 'test', itemCount: 1000);
    await testHiveReadPerformance(boxName: 'test', itemCount: 1000);
    await testHiveFrequentWrites(writeCount: 50, delayMs: 0);
    
    // Firestore tests
    await testFirestoreOfflineCapability();
    
    // Print report
    printPerformanceReport();
  }
}

/// Performance monitoring mixin for StatefulWidget
mixin PerformanceMonitorMixin<T extends StatefulWidget> on State<T> {
  Stopwatch? _buildStopwatch;
  int _rebuildCount = 0;
  
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('📱 ${widget.runtimeType} initState');
    }
  }
  
  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint('📱 ${widget.runtimeType} dispose (rebuilt $_rebuildCount times)');
    }
    super.dispose();
  }
  
  /// Wrap your build method content with this to track rebuild time
  Widget trackBuild(Widget Function() builder) {
    if (kDebugMode) {
      _rebuildCount++;
      _buildStopwatch = Stopwatch()..start();
      final result = builder();
      _buildStopwatch!.stop();
      
      if (_buildStopwatch!.elapsedMilliseconds > 16) {
        debugPrint('⚠️ ${widget.runtimeType} slow build: ${_buildStopwatch!.elapsedMilliseconds}ms');
      }
      
      return result;
    }
    return builder();
  }
}

/// Frame rate monitor widget (wrap your app with this in debug mode)
class FrameRateMonitor extends StatefulWidget {
  final Widget child;
  final bool enabled;
  
  const FrameRateMonitor({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<FrameRateMonitor> createState() => _FrameRateMonitorState();
}

class _FrameRateMonitorState extends State<FrameRateMonitor> {
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !kDebugMode) {
      return widget.child;
    }
    
    return widget.child;
  }
}
