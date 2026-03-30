import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Transaction list item widget
class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = FinanceService.getCategory(transaction.categoryId);
    final account = FinanceService.getAccount(transaction.accountId);
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    return InkWell(
      onTap: onTap,
      borderRadius: FinanceTheme.borderRadiusM,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FinanceTheme.spacingM,
          vertical: FinanceTheme.spacingS,
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (category?.color ?? Colors.grey).withValues(alpha: 0.15),
                borderRadius: FinanceTheme.borderRadiusM,
              ),
              child: Icon(
                category?.icon ?? Icons.category,
                color: category?.color ?? Colors.grey,
                size: 24,
              ),
            ),
            
            const SizedBox(width: FinanceTheme.spacingM),
            
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? 'Unknown',
                    style: FinanceTheme.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(transaction.date),
                    style: FinanceTheme.bodyS,
                  ),
                ],
              ),
            ),
            
            // Amount and account
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : isTransfer ? '' : '-'} ${FinanceService.formatCurrency(transaction.amount)}',
                  style: FinanceTheme.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isIncome 
                        ? FinanceTheme.income 
                        : isTransfer 
                            ? FinanceTheme.transfer 
                            : FinanceTheme.expense,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account?.name ?? '',
                  style: FinanceTheme.bodyS,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

/// Grouped transactions by date
class TransactionGroup extends StatelessWidget {
  final String title;
  final List<FinanceTransaction> transactions;
  final void Function(FinanceTransaction)? onTransactionTap;

  const TransactionGroup({
    super.key,
    required this.title,
    required this.transactions,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FinanceTheme.spacingM,
            vertical: FinanceTheme.spacingS,
          ),
          child: Text(
            title,
            style: FinanceTheme.labelM,
          ),
        ),
        ...transactions.map((t) => TransactionTile(
          transaction: t,
          onTap: () => onTransactionTap?.call(t),
        )),
      ],
    );
  }
}
