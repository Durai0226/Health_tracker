import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Focus/Productivity feature-specific toast notifications
class FocusToast {
  FocusToast._();

  /// Show session started toast
  static String sessionStarted(BuildContext context, {required int minutes}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.focus,
      title: '🎯 Focus Session Started',
      message: '$minutes minute session - stay focused!',
      customIcon: Symbols.play_circle_rounded,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show session completed toast
  static String sessionComplete(BuildContext context, {required int minutes}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.focus,
      title: '🎉 Session Complete!',
      message: 'Great job! You focused for $minutes minutes',
      showParticles: true,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show session paused toast
  static String sessionPaused(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.focus,
      title: 'Session Paused',
      message: 'Take a break, your progress is saved',
      customIcon: Symbols.pause_circle_rounded,
      duration: const Duration(seconds: 2),
    );
  }

  /// Show session resumed toast
  static String sessionResumed(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.focus,
      title: 'Session Resumed',
      message: 'Welcome back! Keep going',
      customIcon: Symbols.play_circle_rounded,
      duration: const Duration(seconds: 2),
    );
  }

  /// Show session abandoned toast
  static String sessionAbandoned(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.warning,
      feature: ToastFeature.focus,
      title: 'Session Ended',
      message: 'That\'s okay, try again when you\'re ready',
      customIcon: Symbols.stop_circle_rounded,
    );
  }

  /// Show plant unlocked toast
  static String plantUnlocked(BuildContext context, {required String plantName}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.focus,
      title: '🌱 New Plant Unlocked!',
      message: '$plantName is now available in your garden',
      showParticles: true,
    );
  }

  /// Show plant grown toast
  static String plantGrown(BuildContext context, {required String plantName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.focus,
      title: '🌳 Plant Grown!',
      message: '$plantName has been added to your garden',
      showParticles: true,
    );
  }

  /// Show focus streak toast
  static String streak(BuildContext context, {required int days}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.focus,
      title: '🔥 $days-Day Focus Streak!',
      message: 'Your consistency is paying off',
      showParticles: true,
    );
  }

  /// Show break reminder toast
  static String breakReminder(BuildContext context, {ToastAction? action}) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.focus,
      title: '☕ Time for a Break',
      message: 'You\'ve been focused for a while, take a short break',
      action: action,
    );
  }

  /// Show activity saved toast
  static String activitySaved(BuildContext context, {required String activityName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.focus,
      title: 'Activity Saved',
      message: '"$activityName" added to your activities',
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.focus,
      title: 'Oops!',
      message: message,
    );
  }
}
