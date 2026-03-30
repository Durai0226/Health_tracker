import 'package:flutter/material.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Notes feature-specific toast notifications
class NotesToast {
  NotesToast._();

  /// Show note saved toast
  static String noteSaved(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: '📝 Note Saved',
      message: 'Your note has been saved',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show note deleted toast
  static String noteDeleted(BuildContext context, {required VoidCallback onUndo}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.notes,
      title: 'Note Deleted',
      message: 'Note has been moved to trash',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show note pinned toast
  static String notePinned(BuildContext context, {required bool isPinned}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: isPinned ? '📌 Note Pinned' : 'Note Unpinned',
      message: isPinned ? 'Note moved to top' : 'Note unpinned',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show note archived toast
  static String noteArchived(BuildContext context, {required VoidCallback onUndo}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.notes,
      title: 'Note Archived',
      message: 'Note moved to archive',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show note restored toast
  static String noteRestored(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: 'Note Restored',
      message: 'Note has been restored',
    );
  }

  /// Show reminder set toast
  static String reminderSet(BuildContext context, {required String dateTime}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: '⏰ Reminder Set',
      message: 'You\'ll be reminded on $dateTime',
    );
  }

  /// Show note reminder toast
  static String noteReminder(BuildContext context, {
    required String noteTitle,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.notes,
      title: '📝 Note Reminder',
      message: noteTitle,
      action: action ?? ToastAction(
        label: 'Open',
        onPressed: () {},
      ),
    );
  }

  /// Show tag added toast
  static String tagAdded(BuildContext context, {required String tagName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: 'Tag Added',
      message: '"$tagName" tag applied',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show notes synced toast
  static String notesSynced(BuildContext context, {int? count}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: '☁️ Notes Synced',
      message: count != null ? '$count notes synced to cloud' : 'All notes are up to date',
    );
  }

  /// Show sync error toast
  static String syncError(BuildContext context, {ToastAction? action}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.notes,
      title: 'Sync Failed',
      message: 'Could not sync notes to cloud',
      action: action ?? ToastAction(
        label: 'Retry',
        onPressed: () {},
      ),
    );
  }

  /// Show checklist item toggled toast
  static String checklistToggled(BuildContext context, {
    required int completed,
    required int total,
  }) {
    if (completed == total) {
      return ToastService.show(
        context,
        type: ToastType.achievement,
        feature: ToastFeature.notes,
        title: '✅ All Tasks Complete!',
        message: 'Great job finishing your checklist',
        showParticles: true,
      );
    }
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: 'Task Updated',
      message: '$completed of $total tasks completed',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.notes,
      title: 'Error',
      message: message,
    );
  }

  /// Show info toast
  static String info(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.notes,
      title: 'Info',
      message: message,
    );
  }

  /// Show success toast
  static String success(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: 'Success',
      message: message,
    );
  }

  /// Show note unlocked toast
  static String noteUnlocked(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: '🔓 Note Unlocked',
      message: 'Note unlocked successfully',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show note locked toast
  static String noteLocked(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.notes,
      title: '🔒 Note Protected',
      message: 'Note protected with password',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show permanently deleted toast (no undo)
  static String permanentlyDeleted(BuildContext context, {String? message}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.notes,
      title: '🗑️ Permanently Deleted',
      message: message ?? 'Notes permanently deleted',
    );
  }
}
