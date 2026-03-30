import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Transaction detail screen
class TransactionDetailScreen extends StatelessWidget {
  final FinanceTransaction transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final category = FinanceService.getCategory(transaction.categoryId);
    final account = FinanceService.getAccount(transaction.accountId);
    final isIncome = transaction.type == TransactionType.income;

    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: FinanceTheme.textPrimary),
        ),
        title: Text('Transaction Details', style: FinanceTheme.headingM),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list, color: FinanceTheme.textPrimary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(FinanceTheme.spacingM),
        child: Column(
          children: [
            // Category icon and amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FinanceTheme.spacingXL),
              decoration: BoxDecoration(
                color: FinanceTheme.surface,
                borderRadius: FinanceTheme.borderRadiusL,
                boxShadow: FinanceTheme.shadowSoft,
              ),
              child: Column(
                children: [
                  // Category icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: (category?.color ?? Colors.grey).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category?.icon ?? Icons.category,
                      color: category?.color ?? Colors.grey,
                      size: 32,
                    ),
                  ),
                  
                  const SizedBox(height: FinanceTheme.spacingM),
                  
                  // Transaction type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isIncome ? FinanceTheme.income : FinanceTheme.expense)
                          .withValues(alpha: 0.15),
                      borderRadius: FinanceTheme.borderRadiusS,
                    ),
                    child: Text(
                      transaction.type.label,
                      style: FinanceTheme.labelM.copyWith(
                        color: isIncome ? FinanceTheme.income : FinanceTheme.expense,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: FinanceTheme.spacingS),
                  
                  // Amount
                  Text(
                    '${isIncome ? '+' : '-'} ${FinanceService.formatCurrency(transaction.amount)}',
                    style: FinanceTheme.headingXL.copyWith(
                      color: isIncome ? FinanceTheme.income : FinanceTheme.expense,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: FinanceTheme.spacingL),
            
            // Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FinanceTheme.spacingM),
              decoration: BoxDecoration(
                color: FinanceTheme.surface,
                borderRadius: FinanceTheme.borderRadiusL,
                boxShadow: FinanceTheme.shadowSoft,
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Account Credited',
                    value: account?.name ?? 'Unknown',
                  ),
                  const Divider(),
                  _DetailRow(
                    label: 'Status',
                    value: transaction.type.label,
                  ),
                  const Divider(),
                  _DetailRow(
                    label: 'Category',
                    value: category?.name ?? 'Unknown',
                  ),
                  const Divider(),
                  _DetailRow(
                    label: 'Time',
                    value: _formatTime(transaction.date),
                  ),
                  const Divider(),
                  _DetailRow(
                    label: 'Date',
                    value: _formatDate(transaction.date),
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                    const Divider(),
                    _DetailRow(
                      label: 'Notes',
                      value: transaction.note!,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: FinanceTheme.spacingL),
            
            // Download receipt button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Download Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FinanceTheme.primary,
                  side: const BorderSide(color: FinanceTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: FinanceTheme.spacingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FinanceTheme.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: FinanceTheme.bodyM.copyWith(color: FinanceTheme.textSecondary)),
          Text(value, style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
