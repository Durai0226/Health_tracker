import 'package:flutter/material.dart';
import '../toast_service.dart';
import '../toast_theme.dart';
import '../premium_toast.dart';

/// Finance feature-specific toast notifications
class FinanceToast {
  FinanceToast._();

  /// Show transaction added toast
  static String transactionAdded(BuildContext context, {
    required String type,
    required double amount,
    String? currency,
  }) {
    final symbol = currency ?? '\$';
    final formattedAmount = amount.toStringAsFixed(2);
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.finance,
      title: '💰 $type Added',
      message: '$symbol$formattedAmount recorded successfully',
      customIcon: type.toLowerCase() == 'income' 
          ? Icons.arrow_downward_rounded 
          : Icons.arrow_upward_rounded,
    );
  }

  /// Show transaction deleted toast
  static String transactionDeleted(BuildContext context, {required VoidCallback onUndo}) {
    return ToastService.show(
      context,
      type: ToastType.info,
      feature: ToastFeature.finance,
      title: 'Transaction Deleted',
      message: 'Entry has been removed',
      action: ToastAction(
        label: 'Undo',
        onPressed: onUndo,
      ),
    );
  }

  /// Show budget updated toast
  static String budgetUpdated(BuildContext context, {required String category}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.finance,
      title: 'Budget Updated',
      message: '$category budget has been set',
    );
  }

  /// Show budget warning toast
  static String budgetWarning(BuildContext context, {
    required String category,
    required int percentUsed,
  }) {
    return ToastService.show(
      context,
      type: ToastType.warning,
      feature: ToastFeature.finance,
      title: '⚠️ Budget Alert',
      message: '$category is at $percentUsed% of budget',
      customIcon: Icons.warning_amber_rounded,
    );
  }

  /// Show budget exceeded toast
  static String budgetExceeded(BuildContext context, {required String category}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.finance,
      title: '🚨 Budget Exceeded',
      message: '$category has gone over budget',
      duration: const Duration(seconds: 5),
    );
  }

  /// Show savings goal reached toast
  static String savingsGoalReached(BuildContext context, {required String goalName}) {
    return ToastService.show(
      context,
      type: ToastType.achievement,
      feature: ToastFeature.finance,
      title: '🎯 Goal Reached!',
      message: 'Congratulations! "$goalName" completed',
      showParticles: true,
    );
  }

  /// Show savings goal created toast
  static String savingsGoalCreated(BuildContext context, {required String goalName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.finance,
      title: 'Goal Created',
      message: '"$goalName" has been added',
    );
  }

  /// Show bill reminder toast
  static String billReminder(BuildContext context, {
    required String billName,
    required String dueDate,
    ToastAction? action,
  }) {
    return ToastService.show(
      context,
      type: ToastType.reminder,
      feature: ToastFeature.finance,
      title: '📅 Bill Due: $billName',
      message: 'Due on $dueDate',
      action: action ?? ToastAction(
        label: 'Mark Paid',
        onPressed: () {},
      ),
    );
  }

  /// Show bill paid toast
  static String billPaid(BuildContext context, {required String billName}) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.finance,
      title: '✓ Bill Paid',
      message: '$billName marked as paid',
    );
  }

  /// Show data exported toast
  static String dataExported(BuildContext context) {
    return ToastService.show(
      context,
      type: ToastType.success,
      feature: ToastFeature.finance,
      title: 'Export Complete',
      message: 'Your financial data has been exported',
    );
  }

  /// Show error toast
  static String error(BuildContext context, {required String message}) {
    return ToastService.show(
      context,
      type: ToastType.error,
      feature: ToastFeature.finance,
      title: 'Error',
      message: message,
    );
  }
}
