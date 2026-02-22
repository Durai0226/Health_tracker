import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/finance_enums.dart';
import '../services/finance_storage_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = FinanceStorageService.getCategory(transaction.categoryId);
    final isDark = AppColors.isDark(context);

    Color amountColor;
    String amountPrefix;
    switch (transaction.type) {
      case TransactionType.income:
        amountColor = const Color(0xFF22C55E);
        amountPrefix = '+';
        break;
      case TransactionType.expense:
        amountColor = const Color(0xFFEF4444);
        amountPrefix = '-';
        break;
      case TransactionType.transfer:
        amountColor = const Color(0xFF3B82F6);
        amountPrefix = '';
        break;
    }

    return Dismissible(
      key: Key(transaction.id),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete?.call(),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text('Are you sure you want to delete this transaction?'),
            actions: [
              CommonButton(
                text: 'Cancel',
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
              CommonButton(
                text: 'Delete',
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: CommonCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (category?.color ?? AppColors.primary).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  category?.icon ?? Icons.receipt_rounded,
                  color: category?.color ?? AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (transaction.note != null && transaction.note!.isNotEmpty)
                          Expanded(
                            child: Text(
                              transaction.note!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          Text(
                            DateFormat('h:mm a').format(transaction.date),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amountPrefix₹${NumberFormat('#,##,###.##').format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  if (transaction.isRecurring)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.repeat,
                            size: 10,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            transaction.recurrence.displayName,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountCard extends StatelessWidget {
  final String name;
  final String type;
  final double balance;
  final Color color;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      onTap: onTap,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      colors: [color, color.withOpacity(0.8)],
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
          const Spacer(),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            type,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${NumberFormat('#,##,###').format(balance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetProgressCard extends StatelessWidget {
  final String name;
  final double spent;
  final double limit;
  final Color color;
  final List<String> categoryNames;

  const BudgetProgressCard({
    super.key,
    required this.name,
    required this.spent,
    required this.limit,
    required this.color,
    required this.categoryNames,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = spent > limit;
    final isDark = AppColors.isDark(context);

    Color progressColor;
    if (isOverBudget) {
      progressColor = const Color(0xFFEF4444);
    } else if (progress >= 0.8) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = const Color(0xFF22C55E);
    }

    return CommonCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            categoryNames.join(', '),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: progressColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(spent)} / ₹${NumberFormat('#,##,###').format(limit)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpendingCategoryChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final double amount;
  final double percentage;

  const SpendingCategoryChip({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return CommonCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
