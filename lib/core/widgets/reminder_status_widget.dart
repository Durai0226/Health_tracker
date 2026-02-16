import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/notification_service.dart';

class ReminderStatusWidget extends StatefulWidget {
  const ReminderStatusWidget({super.key});

  @override
  State<ReminderStatusWidget> createState() => _ReminderStatusWidgetState();
}

class _ReminderStatusWidgetState extends State<ReminderStatusWidget> {
  bool _isChecking = true;
  bool _permissionsGranted = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    
    final notificationService = NotificationService();
    final permissionsGranted = await notificationService.checkPermissions();
    final pendingCount = await notificationService.getPendingNotificationCount();
    
    setState(() {
      _permissionsGranted = permissionsGranted;
      _pendingCount = pendingCount;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Checking reminders...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _permissionsGranted
            ? LinearGradient(
                colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
              )
            : LinearGradient(
                colors: [AppColors.warning, AppColors.warning.withOpacity(0.8)],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_permissionsGranted ? AppColors.success : AppColors.warning)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _permissionsGranted
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _permissionsGranted
                      ? 'Reminders Active'
                      : 'Reminders Disabled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _permissionsGranted
                      ? '$_pendingCount scheduled reminders'
                      : 'Enable notifications in settings',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!_permissionsGranted)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
        ],
      ),
    );
  }
}
