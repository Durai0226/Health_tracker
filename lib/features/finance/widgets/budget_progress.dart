import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Budget progress card widget
class BudgetProgressCard extends StatelessWidget {
  final FinanceBudget budget;
  final VoidCallback? onTap;

  const BudgetProgressCard({
    super.key,
    required this.budget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = budget.percentUsed / 100;
    final isOverBudget = budget.isOverBudget;
    final progressColor = isOverBudget 
        ? FinanceTheme.expense 
        : budget.isNearLimit 
            ? FinanceTheme.warning 
            : FinanceTheme.income;

    return InkWell(
      onTap: onTap,
      borderRadius: FinanceTheme.borderRadiusM,
      child: Container(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        decoration: BoxDecoration(
          color: FinanceTheme.surface,
          borderRadius: FinanceTheme.borderRadiusM,
          boxShadow: FinanceTheme.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budget.name,
                  style: FinanceTheme.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.15),
                    borderRadius: FinanceTheme.borderRadiusS,
                  ),
                  child: Text(
                    '${budget.percentUsed.toStringAsFixed(0)}%',
                    style: FinanceTheme.labelS.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: FinanceTheme.spacingM),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: FinanceTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 8,
              ),
            ),
            
            const SizedBox(height: FinanceTheme.spacingS),
            
            // Amount details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${FinanceService.formatCurrency(budget.spent)} spent',
                  style: FinanceTheme.bodyS,
                ),
                Text(
                  '${FinanceService.formatCurrency(budget.remaining)} left',
                  style: FinanceTheme.bodyS.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact budget list item
class BudgetListTile extends StatelessWidget {
  final FinanceBudget budget;
  final VoidCallback? onTap;

  const BudgetListTile({
    super.key,
    required this.budget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = budget.percentUsed / 100;
    final progressColor = budget.isOverBudget 
        ? FinanceTheme.expense 
        : budget.isNearLimit 
            ? FinanceTheme.warning 
            : budget.color;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: budget.color.withValues(alpha: 0.15),
          borderRadius: FinanceTheme.borderRadiusS,
        ),
        child: Center(
          child: Text(
            budget.name.substring(0, 1).toUpperCase(),
            style: FinanceTheme.headingS.copyWith(
              color: budget.color,
            ),
          ),
        ),
      ),
      title: Text(
        budget.name,
        style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: FinanceTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${FinanceService.formatCurrency(budget.remaining)} of ${FinanceService.formatCurrency(budget.limit)}',
            style: FinanceTheme.bodyS,
          ),
        ],
      ),
      trailing: Text(
        '${budget.percentUsed.toStringAsFixed(0)}%',
        style: FinanceTheme.bodyM.copyWith(
          color: progressColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Empty budget state
class EmptyBudgetState extends StatelessWidget {
  final VoidCallback? onCreate;

  const EmptyBudgetState({
    super.key,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FinanceTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FinanceTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 40,
                color: FinanceTheme.primary,
              ),
            ),
            const SizedBox(height: FinanceTheme.spacingL),
            Text(
              "You don't have a budget.",
              style: FinanceTheme.headingS,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FinanceTheme.spacingS),
            Text(
              "Let's make one so you be in control.",
              style: FinanceTheme.bodyM.copyWith(
                color: FinanceTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FinanceTheme.spacingL),
            ElevatedButton(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: FinanceTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: FinanceTheme.spacingXL,
                  vertical: FinanceTheme.spacingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: FinanceTheme.borderRadiusM,
                ),
              ),
              child: const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }
}
