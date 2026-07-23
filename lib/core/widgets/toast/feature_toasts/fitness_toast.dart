import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Fitness feature-specific toast notifications
class FitnessToast {
  FitnessToast._();

  /// Show workout completed toast
  static String workoutCompleted(BuildContext context, {
    required String workoutName,
    int? calories,
  }) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.fitness,
      title: '💪 Workout Complete!',
      message: calories != null 
          ? '$workoutName - $calories cal burned'
          : '$workoutName finished',
      showParticles: true,
    );
  }

  /// Show workout started toast
  static String workoutStarted(BuildContext context, {required String workoutName}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.fitness,
      title: '🏃 Let\'s Go!',
      message: 'Starting $workoutName',
      customIcon: Symbols.play_circle_rounded,
      duration: const Duration(seconds: 2),
    );
  }

  /// Show exercise logged toast
  static String exerciseLogged(BuildContext context, {required String exerciseName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.fitness,
      title: '✓ Exercise Logged',
      message: '$exerciseName added to your workout',
    );
  }

  /// Show personal record toast
  static String personalRecord(BuildContext context, {required String achievement}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.fitness,
      title: '🏆 New Personal Record!',
      message: achievement,
      showParticles: true,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show fitness goal reached toast
  static String goalReached(BuildContext context, {required String goalName}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.fitness,
      title: '🎯 Goal Achieved!',
      message: 'You completed "$goalName"',
      showParticles: true,
    );
  }

  /// Show streak milestone toast
  static String streakMilestone(BuildContext context, {required int days}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.fitness,
      title: '🔥 $days-Day Workout Streak!',
      message: 'You\'re on fire! Keep it up',
      showParticles: true,
    );
  }

  /// Show workout reminder toast
  static String reminder(BuildContext context, {
    String? workoutName,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.fitness,
      title: '🏋️ Time to Work Out',
      message: workoutName != null ? 'Scheduled: $workoutName' : 'Don\'t skip your workout today!',
      action: action ?? ToastAction(
        label: 'Start',
        onPressed: () {},
      ),
    );
  }

  /// Show custom workout saved toast
  static String workoutSaved(BuildContext context, {required String workoutName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.fitness,
      title: 'Workout Saved',
      message: '"$workoutName" added to your workouts',
    );
  }

  /// Show rest day reminder toast
  static String restDayReminder(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.fitness,
      title: '😴 Rest Day',
      message: 'Recovery is important - take it easy today',
      customIcon: Symbols.self_improvement_rounded,
    );
  }

  /// Show steps goal reached toast
  static String stepsGoalReached(BuildContext context, {required int steps}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.fitness,
      title: '👟 Steps Goal Reached!',
      message: 'You walked $steps steps today',
      showParticles: true,
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.fitness,
      title: 'Error',
      message: message,
    );
  }
}
