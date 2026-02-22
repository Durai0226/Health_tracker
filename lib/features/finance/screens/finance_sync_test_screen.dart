import 'package:flutter/material.dart';
import '../services/finance_sync_test.dart';
import '../services/finance_sync_manager.dart';
import '../services/finance_cloud_service.dart';

class FinanceSyncTestScreen extends StatefulWidget {
  const FinanceSyncTestScreen({super.key});

  @override
  State<FinanceSyncTestScreen> createState() => _FinanceSyncTestScreenState();
}

class _FinanceSyncTestScreenState extends State<FinanceSyncTestScreen> {
  bool _isRunning = false;
  Map<String, bool> _testResults = {};
  List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Sync Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance Sync Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatusRow('User Authenticated', FinanceCloudService.isUserAuthenticated),
                    _buildStatusRow('Sync Manager Initialized', FinanceSyncManager.isInitialized),
                    _buildStatusRow('Currently Syncing', FinanceSyncManager.isSyncing),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runSmokeTest,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Quick Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runComprehensiveTest,
                    icon: const Icon(Icons.assignment),
                    label: const Text('Full Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Sync Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _syncToCloud,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sync to Cloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _syncFromCloud,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Sync from Cloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Test Results
            if (_testResults.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Results',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._testResults.entries.map((entry) => _buildTestResultRow(entry.key, entry.value)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Logs
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Debug Logs',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _clearLogs,
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear Logs',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _logs.isEmpty ? 'No logs yet...' : _logs.join('\n'),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildTestResultRow(String testName, bool? result) {
    if (result == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.skip_next, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(_formatTestName(testName)),
            const Spacer(),
            const Text('SKIPPED', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            result ? Icons.check_circle : Icons.error,
            color: result ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(_formatTestName(testName)),
          const Spacer(),
          Text(
            result ? 'PASS' : 'FAIL',
            style: TextStyle(
              color: result ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTestName(String name) {
    return name.replaceAll('_', ' ').split(' ').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    // Ensure the latest log is visible
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Auto-scroll to bottom could be added here if needed
      }
    });
  }

  Future<void> _runSmokeTest() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
    });
    
    _addLog('Starting smoke test...');
    
    try {
      final success = await FinanceSyncTest.runSmokeTest();
      setState(() {
        _testResults['smoke_test'] = success;
      });
      
      _addLog(success ? 'Smoke test completed successfully' : 'Smoke test failed');
    } catch (e) {
      _addLog('Smoke test error: $e');
      setState(() {
        _testResults['smoke_test'] = false;
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runComprehensiveTest() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
    });
    
    _addLog('Starting comprehensive test suite...');
    
    try {
      final results = await FinanceSyncTest.runComprehensiveTest();
      setState(() {
        _testResults = results;
      });
      
      final passed = results.values.where((r) => r == true).length;
      final total = results.values.where((r) => r != null).length;
      _addLog('Comprehensive test completed: $passed/$total tests passed');
    } catch (e) {
      _addLog('Comprehensive test error: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _syncToCloud() async {
    setState(() {
      _isRunning = true;
    });
    
    _addLog('Starting sync to cloud...');
    
    try {
      final success = await FinanceSyncManager.syncToCloud(showProgress: true);
      _addLog(success ? 'Sync to cloud completed successfully' : 'Sync to cloud failed');
    } catch (e) {
      _addLog('Sync to cloud error: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _syncFromCloud() async {
    setState(() {
      _isRunning = true;
    });
    
    _addLog('Starting sync from cloud...');
    
    try {
      final success = await FinanceSyncManager.syncFromCloud(showProgress: true);
      _addLog(success ? 'Sync from cloud completed successfully' : 'Sync from cloud failed');
    } catch (e) {
      _addLog('Sync from cloud error: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }
}
