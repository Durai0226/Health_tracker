import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'toast_overlay.dart';
import 'toast_theme.dart';
import 'premium_toast.dart';

/// Global toast service for showing notifications throughout the app
class ToastService {
  ToastService._();

  /// Initialize the toast service
  /// Call this in your app's initialization (e.g., in main.dart after runApp)
  static void init(BuildContext context) {
    ToastOverlay.instance.init(context);
  }

  /// Show a toast notification
  static String show(
    BuildContext context, {
    required ToastType type,
    ToastFeature feature = ToastFeature.general,
    required String title,
    String? message,
    ToastAction? action,
    Duration? duration,
    bool showParticles = false,
    bool showProgress = true,
    IconData? customIcon,
    Color? customColor,
    bool hapticFeedback = true,
  }) {
    if (hapticFeedback) {
      _triggerHaptic(type);
    }

    return ToastOverlay.instance.show(
      context: context,
      type: type,
      feature: feature,
      title: title,
      message: message,
      action: action,
      duration: duration,
      showParticles: showParticles,
      showProgress: showProgress,
      customIcon: customIcon,
      customColor: customColor,
    );
  }

  /// Show a success toast
  static String success(
    BuildContext context, {
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    Duration? duration,
  }) {
    return show(
      context,
      type: ToastType.success,
      feature: feature,
      title: title,
      message: message,
      action: action,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Show an error toast
  static String error(
    BuildContext context, {
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    Duration? duration,
  }) {
    return show(
      context,
      type: ToastType.error,
      feature: feature,
      title: title,
      message: message,
      action: action,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  /// Show a warning toast
  static String warning(
    BuildContext context, {
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    Duration? duration,
  }) {
    return show(
      context,
      type: ToastType.warning,
      feature: feature,
      title: title,
      message: message,
      action: action,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Show an info toast
  static String info(
    BuildContext context, {
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    Duration? duration,
  }) {
    return show(
      context,
      type: ToastType.info,
      feature: feature,
      title: title,
      message: message,
      action: action,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Show an achievement toast with celebration particles
  static String achievement(
    BuildContext context, {
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    Duration? duration,
  }) {
    return show(
      context,
      type: ToastType.achievement,
      feature: feature,
      title: title,
      message: message,
      showParticles: true,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  /// Show a reminder toast
  static String reminder(
    BuildContext context, {
    required String title,
    String? message,
    ToastFeature feature = ToastFeature.general,
    ToastAction? action,
    Duration? duration,
  }) {
    return show(
      context,
      type: ToastType.reminder,
      feature: feature,
      title: title,
      message: message,
      action: action,
      duration: duration ?? const Duration(seconds: 6),
    );
  }

  /// Dismiss a specific toast by ID
  static void dismiss(String id) {
    ToastOverlay.instance.dismiss(id);
  }

  /// Dismiss all active toasts
  static void dismissAll() {
    ToastOverlay.instance.dismissAll();
  }

  /// Check if any toasts are currently visible
  static bool get hasActiveToasts => ToastOverlay.instance.hasActiveToasts;

  /// Trigger appropriate haptic feedback based on toast type
  static void _triggerHaptic(ToastType type) {
    switch (type) {
      case ToastType.success:
        HapticFeedback.lightImpact();
        break;
      case ToastType.error:
        HapticFeedback.heavyImpact();
        break;
      case ToastType.warning:
        HapticFeedback.mediumImpact();
        break;
      case ToastType.info:
        HapticFeedback.selectionClick();
        break;
      case ToastType.achievement:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.lightImpact();
        });
        break;
      case ToastType.reminder:
        HapticFeedback.mediumImpact();
        break;
    }
  }
}

/// Extension methods for easy toast access from BuildContext
extension ToastServiceExtension on BuildContext {
  /// Show a success toast
  String showSuccessToast(String title, {String? message, ToastFeature? feature}) {
    return ToastService.success(
      this,
      title: title,
      message: message,
      feature: feature ?? ToastFeature.general,
    );
  }

  /// Show an error toast
  String showErrorToast(String title, {String? message, ToastFeature? feature}) {
    return ToastService.error(
      this,
      title: title,
      message: message,
      feature: feature ?? ToastFeature.general,
    );
  }

  /// Show a warning toast
  String showWarningToast(String title, {String? message, ToastFeature? feature}) {
    return ToastService.warning(
      this,
      title: title,
      message: message,
      feature: feature ?? ToastFeature.general,
    );
  }

  /// Show an info toast
  String showInfoToast(String title, {String? message, ToastFeature? feature}) {
    return ToastService.info(
      this,
      title: title,
      message: message,
      feature: feature ?? ToastFeature.general,
    );
  }

  /// Show an achievement toast
  String showAchievementToast(String title, {String? message, ToastFeature? feature}) {
    return ToastService.achievement(
      this,
      title: title,
      message: message,
      feature: feature ?? ToastFeature.general,
    );
  }

  /// Show a reminder toast
  String showReminderToast(String title, {String? message, ToastFeature? feature, ToastAction? action}) {
    return ToastService.reminder(
      this,
      title: title,
      message: message,
      feature: feature ?? ToastFeature.general,
      action: action,
    );
  }
}
