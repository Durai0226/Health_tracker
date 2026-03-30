import 'package:flutter/material.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Medication/Nunito feature-specific toast notifications
class NunitoToast {
  NunitoToast._();

  /// Show medication taken toast
  static String medicationTaken(BuildContext context, {required String medicineName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.medication,
      title: '💊 Medication Taken',
      message: '$medicineName marked as taken',
      customIcon: Icons.check_circle_rounded,
    );
  }

  /// Show dose skipped toast
  static String doseSkipped(BuildContext context, {required String medicineName, String? reason}) {
    return ToastService.show(
      context,
      type: ToastType.warning,
      feature: ToastFeature.medication,
      title: 'Dose Skipped',
      message: reason ?? '$medicineName skipped',
      customIcon: Icons.skip_next_rounded,
    );
  }

  /// Show medication reminder toast
  static String reminder(BuildContext context, {
    required String medicineName,
    String? dosage,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.medication,
      title: '⏰ Time for $medicineName',
      message: dosage != null ? 'Dosage: $dosage' : 'Don\'t forget to take your medication',
      action: action ?? ToastAction(
        label: 'Take Now',
        onPressed: () {},
      ),
      duration: const Duration(seconds: 8),
    );
  }

  /// Show medication added toast
  static String medicationAdded(BuildContext context, {required String medicineName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.medication,
      title: 'Medication Added',
      message: '$medicineName has been added to your list',
    );
  }

  /// Show medication updated toast
  static String medicationUpdated(BuildContext context, {required String medicineName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.medication,
      title: 'Medication Updated',
      message: '$medicineName has been updated',
      duration: const Duration(seconds: 2),
    );
  }

  /// Show medication archived toast
  static String medicationArchived(BuildContext context, {
    required String medicineName,
    required VoidCallback onUndo,
  }) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.medication,
      title: 'Medication Archived',
      message: '$medicineName moved to archive',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show medication restored toast
  static String medicationRestored(BuildContext context, {required String medicineName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.medication,
      title: 'Medication Restored',
      message: '$medicineName is active again',
    );
  }

  /// Show perfect adherence toast
  static String perfectAdherence(BuildContext context, {required int days}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.medication,
      title: '🏆 Perfect Adherence!',
      message: '$days days with all medications taken on time',
      showParticles: true,
    );
  }

  /// Show doctor added toast
  static String doctorAdded(BuildContext context, {required String doctorName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.medication,
      title: 'Doctor Added',
      message: 'Dr. $doctorName added to your list',
    );
  }

  /// Show pharmacy added toast
  static String pharmacyAdded(BuildContext context, {required String pharmacyName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.medication,
      title: 'Pharmacy Added',
      message: '$pharmacyName added to your list',
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.medication,
      title: 'Error',
      message: message,
    );
  }
}
