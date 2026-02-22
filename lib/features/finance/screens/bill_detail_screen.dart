import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../services/bill_storage_service.dart';
import '../services/bill_reminder_service.dart';
import '../widgets/bill_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import 'add_bill_screen.dart';

class BillDetailScreen extends StatefulWidget {
  final Bill bill;

  const BillDetailScreen({super.key, required this.bill});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late Bill _bill;
  List<BillPayment> _payments = [];

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
    _loadPayments();
  }

  void _loadPayments() {
    _payments = BillStorageService.getPaymentsForBill(_bill.id);
    if (mounted) setState(() {});
  }

  void _refreshBill() {
    final updated = BillStorageService.getBill(_bill.id);
    if (updated != null) {
      setState(() => _bill = updated);
      _loadPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = BillStorageService.getCategory(_bill.categoryId ?? '');
    final statusColor = Color(_bill.status.colorValue);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _bill.color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_bill.color, _bill.color.withValues(alpha: 0.8)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                category?.icon ?? _bill.icon,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const Spacer(),
                            BillStatusBadge(status: _bill.status),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _bill.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${NumberFormat('#,##,###').format(_bill.amount)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddBillScreen(editBill: _bill),
                    ),
                  );
                  _refreshBill();
                },
              ),
              PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy),
                        SizedBox(width: 8),
                        Text('Duplicate'),
                      ],
                    ),
                  ),
                  if (!_bill.isArchived)
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive),
                          SizedBox(width: 8),
                          Text('Archive'),
                        ],
                      ),
                    ),
                  if (_bill.isArchived)
                    const PopupMenuItem(
                      value: 'unarchive',
                      child: Row(
                        children: [
                          Icon(Icons.unarchive),
                          SizedBox(width: 8),
                          Text('Unarchive'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Progress
                  if (_bill.isPartiallyPaid || _bill.status == BillStatus.paid)
                    _buildPaymentProgress(),

                  // Quick Actions
                  if (_bill.status != BillStatus.paid && !_bill.isArchived)
                    _buildQuickActions(),

                  const SizedBox(height: 24),

                  // Bill Details
                  _buildBillDetails(),

                  const SizedBox(height: 24),

                  // Reminders
                  _buildRemindersSection(),

                  const SizedBox(height: 24),

                  // Payment History
                  _buildPaymentHistory(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _bill.status != BillStatus.paid && !_bill.isArchived
          ? FloatingActionButton.extended(
              onPressed: _addPayment,
              icon: const Icon(Icons.payment),
              label: const Text('Add Payment'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildPaymentProgress() {
    final progress = _bill.paidAmount / _bill.amount;

    return CommonCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1 ? Colors.green : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? Colors.green : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  Text(
                    '₹${NumberFormat('#,##,###').format(_bill.paidAmount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  Text(
                    '₹${NumberFormat('#,##,###').format(_bill.remainingAmount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _bill.remainingAmount > 0
                          ? Colors.orange[600]
                          : Colors.green[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: CommonButton(
            text: 'Pay Full',
            icon: Icons.check_circle,
            variant: ButtonVariant.success,
            onPressed: _payFull,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CommonButton(
            text: 'Pay Partial',
            icon: Icons.payment,
            variant: ButtonVariant.outline,
            onPressed: _addPayment,
          ),
        ),
      ],
    );
  }

  Widget _buildBillDetails() {
    final category = BillStorageService.getCategory(_bill.categoryId ?? '');

    return CommonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),

          _buildDetailRow(
            'Due Date',
            DateFormat('EEEE, MMMM d, yyyy').format(_bill.dueDate),
            Icons.calendar_today,
          ),
          _buildDetailRow(
            'Recurrence',
            _bill.recurrence.displayName,
            Icons.repeat,
          ),
          if (category != null)
            _buildDetailRow(
              'Category',
              category.name,
              category.icon,
              color: category.color,
            ),
          if (_bill.gracePeriodDays > 0)
            _buildDetailRow(
              'Grace Period',
              '${_bill.gracePeriodDays} days',
              Icons.timer,
            ),
          if (_bill.note != null && _bill.note!.isNotEmpty)
            _buildDetailRow(
              'Note',
              _bill.note!,
              Icons.note,
            ),
          _buildDetailRow(
            'Created',
            DateFormat('MMM d, yyyy').format(_bill.createdAt),
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.getTextSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection() {
    return CommonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              Switch(
                value: _bill.remindersEnabled,
                onChanged: (value) async {
                  final updated = _bill.copyWith(remindersEnabled: value);
                  await BillStorageService.updateBill(updated);
                  if (value) {
                    await BillReminderService.scheduleRemindersForBill(updated);
                  } else {
                    await BillReminderService.cancelRemindersForBill(_bill.id);
                  }
                  _refreshBill();
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
          if (_bill.remindersEnabled && _bill.reminders.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._bill.reminders.map((reminder) => ReminderItem(
                  reminder: reminder,
                  onToggle: () async {
                    final index = _bill.reminders.indexOf(reminder);
                    final updatedReminders = List<BillReminder>.from(_bill.reminders);
                    updatedReminders[index] = reminder.copyWith(
                      isEnabled: !reminder.isEnabled,
                    );
                    final updated = _bill.copyWith(reminders: updatedReminders);
                    await BillStorageService.updateBill(updated);
                    await BillReminderService.scheduleRemindersForBill(updated);
                    _refreshBill();
                  },
                )),
          ],
          if (_bill.reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No reminders set',
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            if (_payments.isNotEmpty)
              Text(
                '${_payments.length} payment${_payments.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_payments.isEmpty)
          CommonCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.payment,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No payments yet',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._payments.map((payment) => PaymentHistoryItem(
                payment: payment,
                onEdit: () => _editPayment(payment),
                onDelete: () => _deletePayment(payment),
              )),
      ],
    );
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'duplicate':
        await BillStorageService.duplicateBill(_bill.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill duplicated')),
          );
          Navigator.pop(context);
        }
        break;
      case 'archive':
        await BillStorageService.archiveBill(_bill.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill archived')),
          );
          Navigator.pop(context);
        }
        break;
      case 'unarchive':
        await BillStorageService.unarchiveBill(_bill.id);
        _refreshBill();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill unarchived')),
          );
        }
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Are you sure you want to delete "${_bill.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BillStorageService.deleteBill(_bill.id);
      await BillReminderService.cancelRemindersForBill(_bill.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill deleted')),
        );
      }
    }
  }

  Future<void> _payFull() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay Full Amount'),
        content: Text(
          'Mark this bill as fully paid?\n\nRemaining: ₹${NumberFormat('#,##,###').format(_bill.remainingAmount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Pay Full'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BillStorageService.markBillAsPaid(_bill.id);
      _refreshBill();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _addPayment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddPaymentSheet(
          maxAmount: _bill.remainingAmount,
          onAdd: (amount, note) async {
            await BillStorageService.addPayment(
              billId: _bill.id,
              amount: amount,
              note: note,
            );
            _refreshBill();
          },
        ),
      ),
    );
  }

  void _editPayment(BillPayment payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddPaymentSheet(
          initialAmount: payment.amount,
          initialNote: payment.note,
          maxAmount: _bill.remainingAmount + payment.amount,
          onAdd: (amount, note) async {
            final updated = payment.copyWith(amount: amount, note: note);
            await BillStorageService.updatePayment(updated);
            _refreshBill();
          },
        ),
      ),
    );
  }

  void _deletePayment(BillPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
          'Delete payment of ₹${NumberFormat('#,##,###').format(payment.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BillStorageService.deletePayment(payment.id);
      _refreshBill();
    }
  }
}

class _AddPaymentSheet extends StatefulWidget {
  final double? initialAmount;
  final String? initialNote;
  final double maxAmount;
  final Function(double amount, String? note) onAdd;

  const _AddPaymentSheet({
    this.initialAmount,
    this.initialNote,
    required this.maxAmount,
    required this.onAdd,
  });

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialAmount != null ? 'Edit Payment' : 'Add Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Max: ₹${NumberFormat('#,##,###').format(widget.maxAmount)}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) return 'Enter amount';
                  final amount = double.tryParse(value!);
                  if (amount == null || amount <= 0) return 'Invalid amount';
                  if (amount > widget.maxAmount) return 'Exceeds remaining amount';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: CommonButton(
                      text: 'Cancel',
                      variant: ButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CommonButton(
                      text: widget.initialAmount != null ? 'Update' : 'Add',
                      variant: ButtonVariant.success,
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          widget.onAdd(
                            double.parse(_amountController.text),
                            _noteController.text.isEmpty ? null : _noteController.text,
                          );
                          Navigator.pop(context);
                        }
                      },
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
