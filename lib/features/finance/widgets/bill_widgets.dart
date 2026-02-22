import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../services/bill_storage_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

class BillCard extends StatelessWidget {
  final Bill bill;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onSnooze;

  const BillCard({
    super.key,
    required this.bill,
    this.onTap,
    this.onMarkPaid,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final category = BillStorageService.getCategory(bill.categoryId ?? '');
    final statusColor = Color(bill.status.colorValue);

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onMarkPaid?.call();
          return false;
        } else {
          onSnooze?.call();
          return false;
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Mark Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Snooze', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.snooze, color: Colors.white),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: CommonCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (category?.color ?? bill.color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        category?.icon ?? bill.icon,
                        color: category?.color ?? bill.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  bill.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              BillStatusBadge(status: bill.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDueDate(bill),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: bill.isOverdue
                                      ? Colors.red
                                      : AppColors.getTextSecondary(context),
                                ),
                              ),
                              if (bill.recurrence != BillRecurrence.oneTime) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.repeat,
                                  size: 14,
                                  color: AppColors.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  bill.recurrence.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ],
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
                          '₹${NumberFormat('#,##,###').format(bill.amount)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        if (bill.isPartiallyPaid)
                          Text(
                            'Paid: ₹${NumberFormat('#,##,###').format(bill.paidAmount)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (bill.isPartiallyPaid)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: bill.paidAmount / bill.amount,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(Colors.green[400]),
                      minHeight: 4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDueDate(Bill bill) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
    final diff = due.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < -1) return '${-diff} days overdue';
    if (diff <= 7) return 'In $diff days';

    return DateFormat('MMM d, yyyy').format(bill.dueDate);
  }
}

class BillStatusBadge extends StatelessWidget {
  final BillStatus status;
  final bool compact;

  const BillStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(status.colorValue);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Text(
              status.icon,
              style: TextStyle(fontSize: compact ? 10 : 12),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class BillSummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback? onTap;

  const BillSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GradientCard(
        colors: [color, color.withValues(alpha: 0.8)],
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count bills',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpcomingBillsPreview extends StatelessWidget {
  final List<Bill> bills;
  final VoidCallback? onSeeAll;

  const UpcomingBillsPreview({
    super.key,
    required this.bills,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return CommonCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.green[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Upcoming Bills',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All caught up! Add a new bill to track.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Bills',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...bills.take(3).map((bill) => BillCard(bill: bill)),
      ],
    );
  }
}

class OverdueBanner extends StatelessWidget {
  final List<Bill> overdueBills;
  final VoidCallback? onTap;

  const OverdueBanner({
    super.key,
    required this.overdueBills,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (overdueBills.isEmpty) return const SizedBox.shrink();

    final total = overdueBills.fold(0.0, (sum, b) => sum + b.remainingAmount);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[400]!, Colors.red[600]!],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${overdueBills.length} Overdue Bill${overdueBills.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total: ₹${NumberFormat('#,##,###').format(total)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class DueTodayBanner extends StatelessWidget {
  final List<Bill> dueTodayBills;
  final VoidCallback? onTap;

  const DueTodayBanner({
    super.key,
    required this.dueTodayBills,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dueTodayBills.isEmpty) return const SizedBox.shrink();

    final total = dueTodayBills.fold(0.0, (sum, b) => sum + b.remainingAmount);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[400]!, Colors.orange[600]!],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.today,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dueTodayBills.length} Bill${dueTodayBills.length > 1 ? 's' : ''} Due Today',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total: ₹${NumberFormat('#,##,###').format(total)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class BillCategoryChip extends StatelessWidget {
  final BillCategory category;
  final bool isSelected;
  final VoidCallback? onTap;

  const BillCategoryChip({
    super.key,
    required this.category,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? category.color : AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? category.color : category.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 18,
              color: isSelected ? Colors.white : category.color,
            ),
            const SizedBox(width: 8),
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentHistoryItem extends StatelessWidget {
  final BillPayment payment;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PaymentHistoryItem({
    super.key,
    required this.payment,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${NumberFormat('#,##,###').format(payment.amount)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a').format(payment.paidAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                if (payment.note != null && payment.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      payment.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppColors.getTextSecondary(context),
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class ReminderItem extends StatelessWidget {
  final BillReminder reminder;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReminderItem({
    super.key,
    required this.reminder,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.notifications_outlined,
            color: reminder.isEnabled ? AppColors.primary : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reminder.displayText,
              style: TextStyle(
                color: reminder.isEnabled
                    ? AppColors.getTextPrimary(context)
                    : AppColors.getTextSecondary(context),
                decoration: reminder.isEnabled ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          Switch(
            value: reminder.isEnabled,
            onChanged: (_) => onToggle?.call(),
            activeColor: AppColors.primary,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
              color: Colors.grey,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

class CashFlowWarning extends StatelessWidget {
  final double balance;
  final double upcoming;

  const CashFlowWarning({
    super.key,
    required this.balance,
    required this.upcoming,
  });

  @override
  Widget build(BuildContext context) {
    final deficit = upcoming - balance;
    if (deficit <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Balance Warning',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You may need ₹${NumberFormat('#,##,###').format(deficit)} more for upcoming bills',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
