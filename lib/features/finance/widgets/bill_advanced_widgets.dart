import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../models/bill_template.dart';
import '../services/bill_advanced_service.dart';
import '../services/bill_storage_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

class ProjectedBalanceCard extends StatelessWidget {
  final VoidCallback? onTap;

  const ProjectedBalanceCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = BillAdvancedService.getProjectedBalance();
    final isNegative = data['isNegative'] as bool;
    final projectedBalance = data['projectedBalance'] as double;
    final currentBalance = data['currentBalance'] as double;
    final upcomingTotal = data['upcomingBillsTotal'] as double;

    return GestureDetector(
      onTap: onTap,
      child: CommonCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '30-Day Projection',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                if (isNegative)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                        SizedBox(width: 4),
                        Text('Warning', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      Text(
                        '₹${NumberFormat('#,##,###').format(currentBalance)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Projected',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      Text(
                        '₹${NumberFormat('#,##,###').format(projectedBalance)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isNegative ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${data['upcomingBillsCount']} upcoming bills (₹${NumberFormat('#,##,###').format(upcomingTotal)})',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountAllocationWarning extends StatelessWidget {
  final Bill bill;

  const AccountAllocationWarning({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final allocation = BillAdvancedService.checkAccountAllocation(bill);
    if (allocation == null || !(allocation['isInsufficient'] as bool)) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insufficient Balance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                Text(
                  '${allocation['accountName']} needs ₹${NumberFormat('#,##,###').format(allocation['shortfall'])} more',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
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

class SmartInsightsCard extends StatelessWidget {
  final VoidCallback? onTap;

  const SmartInsightsCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final insights = BillAdvancedService.getSmartInsights();
    final monthlyChange = insights['monthlyChangePercent'] as double;
    final onTimePercent = insights['onTimePaymentPercent'] as double;

    return GestureDetector(
      onTap: onTap,
      child: CommonCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Smart Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                Icon(Icons.insights, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInsightItem(
                    context,
                    'Avg Monthly',
                    '₹${NumberFormat('#,##,###').format(insights['averageMonthlyTotal'])}',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightItem(
                    context,
                    'Change',
                    '${monthlyChange >= 0 ? '+' : ''}${monthlyChange.toStringAsFixed(1)}%',
                    monthlyChange >= 0 ? Icons.trending_up : Icons.trending_down,
                    monthlyChange >= 0 ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInsightItem(
                    context,
                    'On-Time',
                    '${onTimePercent.toStringAsFixed(0)}%',
                    Icons.check_circle,
                    onTimePercent >= 80 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

class BillPrioritySelector extends StatelessWidget {
  final BillPriority selected;
  final ValueChanged<BillPriority> onChanged;

  const BillPrioritySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: BillPriority.values.map((priority) {
        final isSelected = selected == priority;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(priority),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color(priority.colorValue).withValues(alpha: 0.2)
                    : AppColors.getCardBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Color(priority.colorValue)
                      : Colors.grey.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    priority == BillPriority.high
                        ? Icons.priority_high
                        : priority == BillPriority.medium
                            ? Icons.remove
                            : Icons.arrow_downward,
                    color: Color(priority.colorValue),
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    priority.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Color(priority.colorValue)
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class BillBadgeCounter extends StatelessWidget {
  final Widget child;

  const BillBadgeCounter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final counts = BillAdvancedService.getBadgeCounts();
    final total = counts['overdue']! + counts['dueToday']!;

    if (total == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            decoration: BoxDecoration(
              color: counts['overdue']! > 0 ? Colors.red : Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                total > 99 ? '99+' : '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RecurringPatternSuggestion extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const RecurringPatternSuggestion({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final recurrence = suggestion['suggestedRecurrence'] as BillRecurrence;

    return CommonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make this recurring?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      '"${suggestion['name']}" appears ${suggestion['instanceCount']} times',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Suggested: ${recurrence.displayName}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Create Template'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActivityLogItem extends StatelessWidget {
  final BillActivity activity;

  const ActivityLogItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getActivityColor().withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                activity.activityType.icon,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityType.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                if (activity.description != null)
                  Text(
                    activity.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatTime(activity.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor() {
    switch (activity.activityType) {
      case BillActivityType.created:
        return Colors.blue;
      case BillActivityType.edited:
        return Colors.orange;
      case BillActivityType.paid:
        return Colors.green;
      case BillActivityType.partiallyPaid:
        return Colors.amber;
      case BillActivityType.deleted:
        return Colors.red;
      case BillActivityType.archived:
      case BillActivityType.unarchived:
        return Colors.grey;
      case BillActivityType.reminderSent:
        return Colors.purple;
      case BillActivityType.instanceGenerated:
        return Colors.teal;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}

class BulkSelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onMarkPaid;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const BulkSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onMarkPaid,
    required this.onArchive,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onCancel,
            ),
            Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              onPressed: onMarkPaid,
              tooltip: 'Mark as Paid',
            ),
            IconButton(
              icon: const Icon(Icons.archive_outlined, color: Colors.white),
              onPressed: onArchive,
              tooltip: 'Archive',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

class TagSelector extends StatelessWidget {
  final List<String> selectedTags;
  final List<String> availableTags;
  final ValueChanged<List<String>> onChanged;

  const TagSelector({
    super.key,
    required this.selectedTags,
    required this.availableTags,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final allTags = {...availableTags, ...selectedTags}.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...allTags.map((tag) {
          final isSelected = selectedTags.contains(tag);
          return GestureDetector(
            onTap: () {
              final newTags = List<String>.from(selectedTags);
              if (isSelected) {
                newTags.remove(tag);
              } else {
                newTags.add(tag);
              }
              onChanged(newTags);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.getCardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: () => _showAddTagDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: AppColors.getTextSecondary(context)),
                const SizedBox(width: 4),
                Text(
                  'Add Tag',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTagDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter tag name',
            prefixText: '#',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final tag = controller.text.trim();
              if (tag.isNotEmpty) {
                onChanged([...selectedTags, tag]);
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class AdvancedRecurrenceSelector extends StatelessWidget {
  final AdvancedRecurrenceType selected;
  final int? nthWeekday;
  final int? weekdayIndex;
  final ValueChanged<AdvancedRecurrenceType> onTypeChanged;
  final ValueChanged<int>? onNthWeekdayChanged;
  final ValueChanged<int>? onWeekdayIndexChanged;

  const AdvancedRecurrenceSelector({
    super.key,
    required this.selected,
    this.nthWeekday,
    this.weekdayIndex,
    required this.onTypeChanged,
    this.onNthWeekdayChanged,
    this.onWeekdayIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Recurrence',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AdvancedRecurrenceType.values.map((type) {
            final isSelected = selected == type;
            return GestureDetector(
              onTap: () => onTypeChanged(type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.getCardBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppColors.primary : AppColors.getTextSecondary(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected == AdvancedRecurrenceType.nthWeekdayOfMonth) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: nthWeekday ?? 1,
                  decoration: const InputDecoration(
                    labelText: 'Nth',
                    border: OutlineInputBorder(),
                  ),
                  items: [1, 2, 3, 4, 5]
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(_ordinal(n)),
                          ))
                      .toList(),
                  onChanged: (v) => onNthWeekdayChanged?.call(v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: weekdayIndex ?? 1,
                  decoration: const InputDecoration(
                    labelText: 'Weekday',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ]
                      .asMap()
                      .entries
                      .map((e) => DropdownMenuItem(
                            value: e.key + 1,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => onWeekdayIndexChanged?.call(v ?? 1),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _ordinal(int n) {
    switch (n) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${n}th';
    }
  }
}

class AttachmentsList extends StatelessWidget {
  final List<String> attachmentUrls;
  final Function(String)? onDelete;
  final VoidCallback? onAdd;

  const AttachmentsList({
    super.key,
    required this.attachmentUrls,
    this.onDelete,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            if (onAdd != null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: onAdd,
                iconSize: 20,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (attachmentUrls.isEmpty)
          Text(
            'No attachments',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(context),
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: attachmentUrls.map((url) {
              final isPdf = url.toLowerCase().contains('.pdf');
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.getCardBg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: isPdf
                          ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32)
                          : const Icon(Icons.image, color: Colors.blue, size: 32),
                    ),
                    if (onDelete != null)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => onDelete!(url),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
