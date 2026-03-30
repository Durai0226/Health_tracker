import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../services/finance_service.dart';

/// Main balance card widget - displays total balance with income/expense summary
class BalanceCard extends StatelessWidget {
  final VoidCallback? onAddAccount;
  final VoidCallback? onTap;

  const BalanceCard({
    super.key,
    this.onAddAccount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalBalance = FinanceService.getTotalBalance();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final totalIncome = FinanceService.getTotalIncome(startDate: startOfMonth);
    final totalExpense = FinanceService.getTotalExpense(startDate: startOfMonth);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(FinanceTheme.spacingL),
        decoration: BoxDecoration(
          gradient: FinanceTheme.cardGradient,
          borderRadius: FinanceTheme.borderRadiusXL,
          boxShadow: FinanceTheme.shadowStrong,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Accounts & Cards',
                      style: FinanceTheme.labelM.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Available Balance',
                          style: FinanceTheme.bodyS.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
                // Add account button
                if (onAddAccount != null)
                  GestureDetector(
                    onTap: onAddAccount,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: FinanceTheme.spacingM),
            
            // Balance amount
            Text(
              FinanceService.formatCurrency(totalBalance),
              style: FinanceTheme.currency.copyWith(
                fontSize: 32,
              ),
            ),
            
            const SizedBox(height: FinanceTheme.spacingL),
            
            // Income and Expense row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Income',
                    amount: totalIncome,
                    icon: Icons.arrow_downward,
                    iconColor: FinanceTheme.income,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white24,
                ),
                Expanded(
                  child: _buildStatItem(
                    label: 'Expense',
                    amount: totalExpense,
                    icon: Icons.arrow_upward,
                    iconColor: FinanceTheme.expense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required double amount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FinanceTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: FinanceTheme.labelS.copyWith(
                  color: Colors.white70,
                ),
              ),
              Text(
                FinanceService.formatCurrency(amount),
                style: FinanceTheme.bodyM.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
