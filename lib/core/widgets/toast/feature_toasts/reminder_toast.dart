import 'package:flutter/material.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Feature-specific toast notifications for the Reminders feature
class ReminderToast {
  ReminderToast._();

  /// Show toast when a reminder triggers in foreground
  static String triggered(
    BuildContext context, {
    required String title,
    String? body,
    VoidCallback? onSnooze,
    VoidCallback? onDismiss,
    int snoozeMinutes = 5,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.general,
      title: '⏰ $title',
      message: body,
      showParticles: false,
      duration: const Duration(seconds: 8),
      action: onSnooze != null
          ? ToastAction(
              label: 'Snooze ${snoozeMinutes}m',
              onPressed: onSnooze,
            )
          : null,
    );
  }

  /// Show toast when reminder is snoozed
  static String snoozed(
    BuildContext context, {
    required int minutes,
  }) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.general,
      title: '⏰ Snoozed',
      message: 'Reminder will trigger again in $minutes minutes',
      duration: const Duration(seconds: 3),
    );
  }

  /// Show toast when reminder is marked complete
  static String completed(
    BuildContext context, {
    String? reminderTitle,
  }) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.general,
      title: '✓ Reminder Completed',
      message: reminderTitle ?? 'Task marked as done',
      showParticles: true,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show toast when a new reminder is created
  static String created(
    BuildContext context, {
    required String title,
    required DateTime scheduledTime,
  }) {
    final timeStr = _formatTime(scheduledTime);
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.general,
      title: '🔔 Reminder Set',
      message: '$title scheduled for $timeStr',
      duration: const Duration(seconds: 4),
    );
  }

  /// Show toast when a reminder is updated
  static String updated(
    BuildContext context, {
    String? title,
  }) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.general,
      title: '✓ Reminder Updated',
      message: title ?? 'Your changes have been saved',
      duration: const Duration(seconds: 3),
    );
  }

  /// Show toast when a reminder is deleted
  static String deleted(
    BuildContext context, {
    String? title,
    VoidCallback? onUndo,
  }) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.general,
      title: '🗑️ Reminder Deleted',
      message: title ?? 'Reminder has been removed',
      duration: const Duration(seconds: 4),
      action: onUndo != null
          ? ToastAction(
              label: 'Undo',
              onPressed: onUndo,
            )
          : null,
    );
  }

  /// Show toast for upcoming reminder notification
  static String upcoming(
    BuildContext context, {
    required String title,
    required int minutesUntil,
  }) {
    final timeStr = minutesUntil == 1 ? '1 minute' : '$minutesUntil minutes';
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.general,
      title: '📅 Upcoming Reminder',
      message: '$title in $timeStr',
      duration: const Duration(seconds: 5),
    );
  }

  /// Show toast for missed reminder
  static String missed(
    BuildContext context, {
    required String title,
    VoidCallback? onMarkComplete,
    VoidCallback? onReschedule,
  }) {
    return ToastService.show(
      context,
      type: ToastType.warning,
      feature: ToastFeature.general,
      title: '⚠️ Missed Reminder',
      message: title,
      duration: const Duration(seconds: 6),
      action: onMarkComplete != null
          ? ToastAction(
              label: 'Complete',
              onPressed: onMarkComplete,
            )
          : null,
    );
  }

  /// Show toast for synced reminders
  static String synced(
    BuildContext context, {
    int count = 0,
  }) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.general,
      title: '☁️ Reminders Synced',
      message: count > 0 ? '$count reminders synced to cloud' : 'All reminders synced',
      duration: const Duration(seconds: 3),
    );
  }

  /// Show error toast for reminder operations
  static String error(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.general,
      title: '❌ Reminder Error',
      message: message,
      duration: const Duration(seconds: 5),
      action: onRetry != null
          ? ToastAction(
              label: 'Retry',
              onPressed: onRetry,
            )
          : null,
    );
  }

  /// Show toast for permission issues
  static String permissionRequired(
    BuildContext context, {
    VoidCallback? onOpenSettings,
  }) {
    return ToastService.show(
      context,
      type: ToastType.warning,
      feature: ToastFeature.general,
      title: '🔔 Permission Required',
      message: 'Enable notifications to receive reminders',
      duration: const Duration(seconds: 6),
      action: onOpenSettings != null
          ? ToastAction(
              label: 'Settings',
              onPressed: onOpenSettings,
            )
          : null,
    );
  }

  /// Show toast for category created
  static String categoryCreated(
    BuildContext context, {
    required String categoryName,
  }) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.general,
      title: '📁 Category Created',
      message: categoryName,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show toast for category deleted
  static String categoryDeleted(
    BuildContext context, {
    required String categoryName,
  }) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.general,
      title: '🗑️ Category Deleted',
      message: categoryName,
      duration: const Duration(seconds: 3),
    );
  }

  /// Format DateTime for display
  static String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$hour12:$minute $period';

    if (reminderDate == today) {
      return 'Today at $timeStr';
    } else if (reminderDate == tomorrow) {
      return 'Tomorrow at $timeStr';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day} at $timeStr';
    }
  }
}
