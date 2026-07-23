import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Water/Aqua feature-specific toast notifications
class AquaToast {
  AquaToast._();

  /// Show hydration logged toast
  static String hydrationLogged(BuildContext context, {required int amount, String? beverage}) {
    final beverageName = beverage ?? 'Water';
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.water,
      title: '💧 Hydration Logged!',
      message: '+${amount}ml of $beverageName added',
      customIcon: Symbols.water_drop_rounded,
    );
  }

  /// Show daily goal reached toast
  static String goalReached(BuildContext context, {int? totalMl}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.water,
      title: '🎯 Daily Goal Reached!',
      message: totalMl != null ? 'You\'ve consumed ${totalMl}ml today' : 'Keep up the great work!',
      showParticles: true,
      duration: const Duration(seconds: 5),
    );
  }

  /// Show streak milestone toast
  static String streakMilestone(BuildContext context, {required int days}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.water,
      title: '🔥 $days-Day Streak!',
      message: 'You\'re staying consistently hydrated',
      showParticles: true,
    );
  }

  /// Show hydration reminder toast
  static String reminder(BuildContext context, {ToastAction? action}) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.water,
      title: '💧 Time to Hydrate',
      message: 'Don\'t forget to drink some water',
      action: action ?? ToastAction(
        label: 'Log Now',
        onPressed: () {},
      ),
    );
  }

  /// Show drink deleted toast with undo
  static String drinkDeleted(BuildContext context, {required VoidCallback onUndo}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.water,
      title: 'Drink Removed',
      message: 'Entry has been deleted',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show cup saved toast
  static String cupSaved(BuildContext context, {required String cupName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.water,
      title: 'Cup Saved',
      message: '"$cupName" added to your cups',
    );
  }

  /// Show settings updated toast
  static String settingsUpdated(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.water,
      title: 'Settings Updated',
      message: 'Your hydration preferences have been saved',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.water,
      title: 'Oops!',
      message: message,
    );
  }
}
