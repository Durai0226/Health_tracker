import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Habit tracker feature-specific toast notifications
class HabitToast {
  HabitToast._();

  /// Show habit completed toast
  static String habitCompleted(BuildContext context, {required String habitName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.habit,
      title: '✓ Habit Completed',
      message: '$habitName marked as done',
      customIcon: Symbols.check_circle_rounded,
    );
  }

  /// Show habit uncompleted toast
  static String habitUncompleted(BuildContext context, {required String habitName}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.habit,
      title: 'Habit Unmarked',
      message: '$habitName marked as not done',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show streak milestone toast
  static String streakMilestone(BuildContext context, {
    required String habitName,
    required int days,
  }) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.habit,
      title: '🔥 $days-Day Streak!',
      message: 'Keep the $habitName streak going!',
      showParticles: true,
    );
  }

  /// Show streak broken toast
  static String streakBroken(BuildContext context, {required String habitName}) {
    return ToastService.show(
      context,
      type: ToastType.warning,
      feature: ToastFeature.habit,
      title: 'Streak Reset',
      message: '$habitName streak has been reset - start fresh!',
      customIcon: Symbols.refresh_rounded,
    );
  }

  /// Show habit created toast
  static String habitCreated(BuildContext context, {required String habitName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.habit,
      title: 'Habit Created',
      message: '"$habitName" added to your habits',
    );
  }

  /// Show habit updated toast
  static String habitUpdated(BuildContext context, {required String habitName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.habit,
      title: 'Habit Updated',
      message: '"$habitName" has been updated',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show habit deleted toast
  static String habitDeleted(BuildContext context, {
    required String habitName,
    required VoidCallback onUndo,
  }) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.habit,
      title: 'Habit Deleted',
      message: '"$habitName" has been removed',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show habit reminder toast
  static String reminder(BuildContext context, {
    required String habitName,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.habit,
      title: '⏰ Habit Reminder',
      message: 'Time for: $habitName',
      action: action ?? ToastAction(
        label: 'Complete',
        onPressed: () {},
      ),
    );
  }

  /// Show all habits completed toast
  static String allHabitsCompleted(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.habit,
      title: '🎉 All Done!',
      message: 'You\'ve completed all habits for today',
      showParticles: true,
    );
  }

  /// Show building unlocked toast
  static String buildingUnlocked(BuildContext context, {required String buildingName}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.habit,
      title: '🏛️ Building Unlocked!',
      message: '$buildingName added to your city',
      showParticles: true,
    );
  }

  /// Show challenge completed toast
  static String challengeCompleted(BuildContext context, {required String challengeName}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.habit,
      title: '🏆 Challenge Complete!',
      message: 'You finished "$challengeName"',
      showParticles: true,
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.habit,
      title: 'Error',
      message: message,
    );
  }
}
