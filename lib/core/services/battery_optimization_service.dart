import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizationService {
  static final BatteryOptimizationService _instance = BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  /// Check if battery optimization is disabled (app is whitelisted)
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      debugPrint('🔋 Battery optimization status: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      debugPrint('🔋 Battery optimization request result: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error requesting battery optimization exemption: $e');
      return false;
    }
  }

  /// Show dialog explaining why battery optimization should be disabled
  Future<bool> showBatteryOptimizationDialog(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    // Check if already exempt
    if (await isIgnoringBatteryOptimizations()) {
      debugPrint('✓ Already exempt from battery optimization');
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Enable Reliable Reminders')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For medicine reminders to work reliably when the app is closed, please disable battery optimization for this app.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is critical for medication reminders!',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Enable Now'),
          ),
        ],
      ),
    );

    if (result == true) {
      return await requestDisableBatteryOptimization();
    }
    return false;
  }

  /// Check all required permissions for reliable notifications
  Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};
    
    if (Platform.isAndroid) {
      // Notification permission
      results['notifications'] = await Permission.notification.isGranted;
      
      // Battery optimization
      results['batteryOptimization'] = await Permission.ignoreBatteryOptimizations.isGranted;
      
      // Exact alarms (Android 12+)
      results['exactAlarms'] = await Permission.scheduleExactAlarm.isGranted;
    } else {
      results['notifications'] = true;
      results['batteryOptimization'] = true;
      results['exactAlarms'] = true;
    }
    
    debugPrint('📋 Permission status: $results');
    return results;
  }

  /// Request all required permissions
  Future<bool> requestAllPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return true;
    
    bool allGranted = true;
    
    // Request notification permission
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      allGranted = false;
      debugPrint('⚠️ Notification permission not granted');
    }
    
    // Request exact alarm permission
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    if (!alarmStatus.isGranted) {
      debugPrint('⚠️ Exact alarm permission not granted');
    }
    
    // Request battery optimization exemption with dialog
    final batteryResult = await showBatteryOptimizationDialog(context);
    if (!batteryResult) {
      allGranted = false;
      debugPrint('⚠️ Battery optimization not disabled');
    }
    
    return allGranted;
  }
}
