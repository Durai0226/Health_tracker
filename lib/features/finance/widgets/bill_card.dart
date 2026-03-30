import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Bill card widget for displaying upcoming/overdue bills
class BillCard extends StatelessWidget {
  final FinanceBill bill;
  final VoidCallback? onTap;
  final VoidCallback? onPay;

  const BillCard({
    super.key,
    required this.bill,
    this.onTap,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = bill.isOverdue;
    final statusColor = isOverdue ? FinanceTheme.expense : FinanceTheme.primary;

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
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bill.color.withValues(alpha: 0.15),
                borderRadius: FinanceTheme.borderRadiusM,
              ),
              child: Icon(
                bill.icon,
                color: bill.color,
                size: 24,
              ),
            ),
            
            const SizedBox(width: FinanceTheme.spacingM),
            
            // Bill details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: FinanceTheme.bodyM.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDueDate(),
                        style: FinanceTheme.bodyS.copyWith(
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Pay button
            if (!bill.isPaid)
              TextButton(
                onPressed: onPay,
                style: TextButton.styleFrom(
                  backgroundColor: FinanceTheme.primary.withValues(alpha: 0.1),
                  foregroundColor: FinanceTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FinanceTheme.spacingM,
                    vertical: FinanceTheme.spacingS,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: FinanceTheme.borderRadiusS,
                  ),
                ),
                child: const Text('Pay'),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: FinanceTheme.spacingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FinanceTheme.income.withValues(alpha: 0.15),
                  borderRadius: FinanceTheme.borderRadiusS,
                ),
                child: Text(
                  'Paid',
                  style: FinanceTheme.labelS.copyWith(
                    color: FinanceTheme.income,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDueDate() {
    final days = bill.daysUntilDue;
    if (days < 0) {
      return '${-days} days overdue';
    } else if (days == 0) {
      return 'Due today';
    } else if (days == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $days days';
    }
  }
}

/// Compact bill list item
class BillListTile extends StatelessWidget {
  final FinanceBill bill;
  final VoidCallback? onTap;
  final VoidCallback? onPay;

  const BillListTile({
    super.key,
    required this.bill,
    this.onTap,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bill.color.withValues(alpha: 0.15),
          borderRadius: FinanceTheme.borderRadiusS,
        ),
        child: Icon(
          bill.icon,
          color: bill.color,
          size: 20,
        ),
      ),
      title: Text(
        bill.name,
        style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatDate(bill.dueDate),
        style: FinanceTheme.bodyS,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FinanceService.formatCurrency(bill.amount),
            style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w600),
          ),
          if (!bill.isPaid) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onPay,
              icon: const Icon(Icons.check_circle_outline),
              color: FinanceTheme.income,
              iconSize: 24,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
