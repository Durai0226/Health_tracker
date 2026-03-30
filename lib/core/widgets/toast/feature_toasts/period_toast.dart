import 'package:flutter/material.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Period tracking feature-specific toast notifications
class PeriodToast {
  PeriodToast._();

  /// Show period logged toast
  static String periodLogged(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.period,
      title: '📅 Period Logged',
      message: 'Your cycle data has been recorded',
    );
  }

  /// Show period started toast
  static String periodStarted(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.period,
      title: '🌸 Period Started',
      message: 'A new cycle has begun',
    );
  }

  /// Show period ended toast
  static String periodEnded(BuildContext context, {required int daysLength}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.period,
      title: '✓ Period Ended',
      message: 'This cycle lasted $daysLength days',
    );
  }

  /// Show symptom logged toast
  static String symptomLogged(BuildContext context, {int? symptomCount}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.period,
      title: 'Symptoms Logged',
      message: symptomCount != null 
          ? '$symptomCount symptoms recorded'
          : 'Your symptoms have been saved',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show period prediction toast
  static String periodPrediction(BuildContext context, {required int daysUntil}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.period,
      title: '📊 Period Prediction',
      message: daysUntil == 0 
          ? 'Your period may start today'
          : daysUntil == 1 
              ? 'Your period may start tomorrow'
              : 'Your period may start in $daysUntil days',
    );
  }

  /// Show period reminder toast
  static String periodReminder(BuildContext context, {required int daysUntil}) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.period,
      title: '🌸 Period Coming Up',
      message: daysUntil == 1 
          ? 'Expected to start tomorrow'
          : 'Expected in $daysUntil days',
    );
  }

  /// Show fertile window toast
  static String fertileWindow(BuildContext context, {required bool isStart}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.period,
      title: isStart ? '🌺 Fertile Window Started' : '🌺 Fertile Window Ended',
      message: isStart 
          ? 'You are now in your fertile phase'
          : 'Your fertile window has ended',
    );
  }

  /// Show ovulation day toast
  static String ovulationDay(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.period,
      title: '🥚 Ovulation Day',
      message: 'Today is your predicted ovulation day',
      customIcon: Icons.favorite_rounded,
    );
  }

  /// Show medication reminder toast
  static String medicationReminder(BuildContext context, {
    required String medicationName,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.period,
      title: '💊 Medication Reminder',
      message: 'Time to take $medicationName',
      action: action,
    );
  }

  /// Show data backed up toast
  static String dataBackedUp(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.period,
      title: '☁️ Data Backed Up',
      message: 'Your cycle data is safely stored',
    );
  }

  /// Show cycle insights toast
  static String cycleInsights(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.period,
      title: '📊 New Insights Available',
      message: 'Check your cycle patterns and trends',
      customIcon: Icons.insights_rounded,
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.period,
      title: 'Error',
      message: message,
    );
  }
}
