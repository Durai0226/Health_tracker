import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import 'bill_storage_service.dart';

class BillReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? _deviceId;
  static const String _notificationChannelId = 'bill_reminders';
  static const String _notificationChannelName = 'Bill Reminders';
  static const String _lastScheduledKey = 'bill_reminders_last_scheduled';

  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz_data.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _createNotificationChannel();
      await _getDeviceId();

      _isInitialized = true;
      debugPrint('✓ BillReminderService initialized');

      await rescheduleAllReminders();
    } catch (e) {
      debugPrint('❌ Error initializing BillReminderService: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    const channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Reminders for upcoming bills and payments',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        _deviceId = android.id;
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        _deviceId = ios.identifierForVendor;
      }
    } catch (e) {
      debugPrint('⚠️ Could not get device ID: $e');
      _deviceId = 'unknown';
    }
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    debugPrint('📱 Notification tapped: $payload');

    if (response.actionId == 'mark_paid') {
      _handleMarkAsPaid(payload);
    } else if (response.actionId == 'snooze_1h') {
      _handleSnooze(payload, hours: 1);
    } else if (response.actionId == 'snooze_tomorrow') {
      _handleSnooze(payload, hours: 24);
    }
  }

  static Future<void> _handleMarkAsPaid(String billId) async {
    try {
      await BillStorageService.markBillAsPaid(billId);
      await cancelRemindersForBill(billId);
      debugPrint('✓ Bill marked as paid from notification');
    } catch (e) {
      debugPrint('❌ Error marking bill as paid: $e');
    }
  }

  static Future<void> _handleSnooze(String billId, {required int hours}) async {
    try {
      final bill = BillStorageService.getBill(billId);
      if (bill == null) return;

      final snoozeTime = DateTime.now().add(Duration(hours: hours));
      await _scheduleSnoozeReminder(bill, snoozeTime);
      debugPrint('✓ Bill reminder snoozed for $hours hours');
    } catch (e) {
      debugPrint('❌ Error snoozing reminder: $e');
    }
  }

  static Future<void> _scheduleSnoozeReminder(Bill bill, DateTime snoozeTime) async {
    final notificationId = _generateNotificationId(bill.id, 'snooze');

    await _notifications.zonedSchedule(
      notificationId,
      '⏰ Snoozed: ${bill.name}',
      '₹${bill.remainingAmount.toStringAsFixed(0)} due ${_formatDueDate(bill.dueDate)}',
      tz.TZDateTime.from(snoozeTime, tz.local),
      _getNotificationDetails(bill),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: bill.id,
    );
  }

  static Future<void> scheduleRemindersForBill(Bill bill) async {
    if (!_isInitialized || !bill.remindersEnabled) return;

    await cancelRemindersForBill(bill.id);

    if (bill.status == BillStatus.paid ||
        bill.status == BillStatus.cancelled ||
        bill.isDeleted) {
      return;
    }

    final updatedNotificationIds = <int>[];

    for (int i = 0; i < bill.reminders.length; i++) {
      final reminder = bill.reminders[i];
      if (!reminder.isEnabled) continue;

      final scheduledTime = _calculateReminderTime(bill, reminder);
      if (scheduledTime == null || scheduledTime.isBefore(DateTime.now())) {
        continue;
      }

      final notificationId = _generateNotificationId(bill.id, i.toString());

      try {
        await _notifications.zonedSchedule(
          notificationId,
          _getReminderTitle(bill, reminder),
          _getReminderBody(bill, reminder),
          tz.TZDateTime.from(scheduledTime, tz.local),
          _getNotificationDetails(bill),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: bill.id,
        );

        reminder.notificationId = notificationId;
        reminder.scheduledTime = scheduledTime;
        updatedNotificationIds.add(notificationId);

        debugPrint('📅 Scheduled reminder for ${bill.name} at $scheduledTime');
      } catch (e) {
        debugPrint('❌ Error scheduling reminder: $e');
      }
    }

    if (updatedNotificationIds.isNotEmpty) {
      final updatedBill = bill.copyWith(
        notificationIds: updatedNotificationIds,
        deviceId: _deviceId,
      );
      await BillStorageService.saveBill(updatedBill);
    }
  }

  static DateTime? _calculateReminderTime(Bill bill, BillReminder reminder) {
    DateTime reminderDate;

    switch (reminder.type) {
      case ReminderType.daysBefore:
        reminderDate = bill.dueDate.subtract(Duration(days: reminder.daysBefore));
        break;
      case ReminderType.sameDay:
        reminderDate = bill.dueDate;
        break;
      case ReminderType.exactTime:
        reminderDate = bill.dueDate;
        break;
    }

    return DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      reminder.hour,
      reminder.minute,
    );
  }

  static String _getReminderTitle(Bill bill, BillReminder reminder) {
    if (reminder.daysBefore == 0 || reminder.type == ReminderType.sameDay) {
      return '⚠️ Bill Due Today: ${bill.name}';
    } else if (reminder.daysBefore == 1) {
      return '📅 Bill Due Tomorrow: ${bill.name}';
    } else {
      return '📅 Upcoming Bill: ${bill.name}';
    }
  }

  static String _getReminderBody(Bill bill, BillReminder reminder) {
    final amount = '₹${bill.remainingAmount.toStringAsFixed(0)}';

    if (reminder.daysBefore == 0 || reminder.type == ReminderType.sameDay) {
      return '$amount is due today. Tap to mark as paid.';
    } else if (reminder.daysBefore == 1) {
      return '$amount is due tomorrow.';
    } else {
      return '$amount due in ${reminder.daysBefore} days (${_formatDueDate(bill.dueDate)})';
    }
  }

  static String _formatDueDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  static NotificationDetails _getNotificationDetails(Bill bill) {
    final androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: 'Bill payment reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: bill.color,
      category: AndroidNotificationCategory.reminder,
      actions: [
        const AndroidNotificationAction(
          'mark_paid',
          'Mark as Paid',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          'snooze_1h',
          'Snooze 1h',
        ),
        const AndroidNotificationAction(
          'snooze_tomorrow',
          'Tomorrow',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  static Future<void> cancelRemindersForBill(String billId) async {
    final bill = BillStorageService.getBill(billId);
    if (bill == null) return;

    for (final notificationId in bill.notificationIds) {
      await _notifications.cancel(notificationId);
    }

    for (int i = 0; i < bill.reminders.length; i++) {
      final id = _generateNotificationId(billId, i.toString());
      await _notifications.cancel(id);
    }

    final snoozeId = _generateNotificationId(billId, 'snooze');
    await _notifications.cancel(snoozeId);

    debugPrint('✓ Cancelled all reminders for bill: ${bill.name}');
  }

  static Future<void> rescheduleAllReminders() async {
    if (!_isInitialized) return;

    debugPrint('🔄 Rescheduling all bill reminders...');

    await _notifications.cancelAll();

    final bills = BillStorageService.getActiveBills();
    int scheduled = 0;

    for (final bill in bills) {
      if (bill.remindersEnabled &&
          bill.status != BillStatus.paid &&
          bill.reminders.isNotEmpty) {
        await scheduleRemindersForBill(bill);
        scheduled++;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScheduledKey, DateTime.now().toIso8601String());

    debugPrint('✓ Rescheduled reminders for $scheduled bills');
  }

  static Future<void> showOverdueNotification(Bill bill) async {
    if (!_isInitialized) return;

    final notificationId = _generateNotificationId(bill.id, 'overdue');

    await _notifications.show(
      notificationId,
      '🔴 Overdue: ${bill.name}',
      '₹${bill.remainingAmount.toStringAsFixed(0)} was due on ${_formatDueDate(bill.dueDate)}',
      _getNotificationDetails(bill),
      payload: bill.id,
    );
  }

  static Future<void> checkAndNotifyOverdue() async {
    final overdueBills = BillStorageService.getOverdueBills();

    for (final bill in overdueBills) {
      if (bill.daysOverdue == 1) {
        await showOverdueNotification(bill);
      }
    }
  }

  static int _generateNotificationId(String billId, String suffix) {
    final hash = '${billId}_$suffix'.hashCode;
    return hash.abs() % 2147483647;
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('✓ All bill notifications cancelled');
  }

  static BillReminder createDefaultReminder() {
    return BillReminder(
      type: ReminderType.daysBefore,
      daysBefore: BillStorageService.defaultReminderDays,
      hour: BillStorageService.defaultReminderHour,
      minute: BillStorageService.defaultReminderMinute,
    );
  }

  static List<BillReminder> createDefaultReminders() {
    return [
      BillReminder(
        type: ReminderType.daysBefore,
        daysBefore: 3,
        hour: BillStorageService.defaultReminderHour,
        minute: BillStorageService.defaultReminderMinute,
      ),
      BillReminder(
        type: ReminderType.daysBefore,
        daysBefore: 1,
        hour: BillStorageService.defaultReminderHour,
        minute: BillStorageService.defaultReminderMinute,
      ),
      BillReminder(
        type: ReminderType.sameDay,
        daysBefore: 0,
        hour: 9,
        minute: 0,
      ),
    ];
  }
}
