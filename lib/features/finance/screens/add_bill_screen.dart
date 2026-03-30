import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Full screen for adding/editing bills
class AddBillScreen extends StatefulWidget {
  final FinanceBill? existingBill;

  const AddBillScreen({super.key, this.existingBill});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  BillRecurrence _selectedRecurrence = BillRecurrence.monthly;
  String? _selectedAccountId;
  int _remindDaysBefore = 3;
  bool _remindersEnabled = true;
  bool _isLoading = false;

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingBill?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.existingBill?.amount.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.existingBill?.note ?? '',
    );
    if (widget.existingBill != null) {
      _dueDate = widget.existingBill!.dueDate;
      _selectedRecurrence = widget.existingBill!.recurrence;
      _selectedAccountId = widget.existingBill!.accountId;
      _remindDaysBefore = widget.existingBill!.remindDaysBefore;
      _remindersEnabled = widget.existingBill!.remindersEnabled;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: FinanceTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Bill' : 'Add Bill',
          style: FinanceTheme.headingM,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBill,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: FinanceTheme.bodyL.copyWith(
                      color: FinanceTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(FinanceTheme.spacingM),
          children: [
            // Bill name
            _buildSectionTitle('Bill Name'),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                hintText: 'e.g., Electricity, Rent, Netflix',
                prefixIcon: Icons.receipt_outlined,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter bill name';
                }
                return null;
              },
            ),
            const SizedBox(height: FinanceTheme.spacingL),

            // Amount
            _buildSectionTitle('Amount'),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                hintText: '0.00',
                prefixIcon: Icons.attach_money,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: FinanceTheme.spacingL),

            // Due date
            _buildSectionTitle('Due Date'),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: FinanceTheme.borderRadiusM,
              child: Container(
                padding: const EdgeInsets.all(FinanceTheme.spacingM),
                decoration: BoxDecoration(
                  color: FinanceTheme.surfaceVariant,
                  borderRadius: FinanceTheme.borderRadiusM,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: FinanceTheme.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_dueDate),
                      style: FinanceTheme.bodyL,
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: FinanceTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FinanceTheme.spacingL),

            // Recurrence
            _buildSectionTitle('Recurrence'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BillRecurrence.values.map((recurrence) {
                final isSelected = recurrence == _selectedRecurrence;
                return ChoiceChip(
                  label: Text(_getRecurrenceLabel(recurrence)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRecurrence = recurrence);
                    }
                  },
                  selectedColor: FinanceTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : FinanceTheme.textPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: FinanceTheme.spacingL),

            // Payment account
            _buildSectionTitle('Payment Account'),
            FutureBuilder<List<FinanceAccount>>(
              future: _getAccounts(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? [];
                return DropdownButtonFormField<String?>(
                  value: _selectedAccountId,
                  decoration: _inputDecoration(
                    hintText: 'Select account',
                    prefixIcon: Icons.account_balance_wallet,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No account selected'),
                    ),
                    ...accounts.map((acc) => DropdownMenuItem<String?>(
                      value: acc.id,
                      child: Row(
                        children: [
                          Icon(acc.icon, size: 20, color: acc.color),
                          const SizedBox(width: 8),
                          Text(acc.name),
                        ],
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAccountId = value);
                  },
                );
              },
            ),
            const SizedBox(height: FinanceTheme.spacingL),

            // Reminders
            _buildSectionTitle('Reminders'),
            Container(
              decoration: BoxDecoration(
                color: FinanceTheme.surfaceVariant,
                borderRadius: FinanceTheme.borderRadiusM,
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Reminders'),
                    value: _remindersEnabled,
                    onChanged: (value) {
                      setState(() => _remindersEnabled = value);
                    },
                    activeTrackColor: FinanceTheme.primary,
                  ),
                  if (_remindersEnabled)
                    ListTile(
                      title: const Text('Remind me'),
                      trailing: DropdownButton<int>(
                        value: _remindDaysBefore,
                        underline: const SizedBox(),
                        items: [1, 2, 3, 5, 7].map((days) => DropdownMenuItem<int>(
                          value: days,
                          child: Text('$days day${days > 1 ? 's' : ''} before'),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _remindDaysBefore = value);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FinanceTheme.spacingL),

            // Notes
            _buildSectionTitle('Notes (Optional)'),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: _inputDecoration(
                hintText: 'Add any additional notes...',
                prefixIcon: Icons.notes,
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FinanceTheme.spacingS),
      child: Text(title, style: FinanceTheme.labelM),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: FinanceTheme.textSecondary),
      filled: true,
      fillColor: FinanceTheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: FinanceTheme.borderRadiusM,
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<List<FinanceAccount>> _getAccounts() async {
    await FinanceService.init();
    return FinanceService.getAccounts();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: FinanceTheme.primary,
              onPrimary: Colors.white,
              surface: FinanceTheme.surface,
              onSurface: FinanceTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRecurrenceLabel(BillRecurrence recurrence) {
    switch (recurrence) {
      case BillRecurrence.oneTime:
        return 'One Time';
      case BillRecurrence.daily:
        return 'Daily';
      case BillRecurrence.weekly:
        return 'Weekly';
      case BillRecurrence.biWeekly:
        return 'Bi-weekly';
      case BillRecurrence.monthly:
        return 'Monthly';
      case BillRecurrence.quarterly:
        return 'Quarterly';
      case BillRecurrence.yearly:
        return 'Yearly';
    }
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text);
      final now = DateTime.now();

      if (_isEditing) {
        final updated = widget.existingBill!.copyWith(
          name: _nameController.text,
          amount: amount,
          dueDate: _dueDate,
          recurrence: _selectedRecurrence,
          accountId: _selectedAccountId,
          remindDaysBefore: _remindDaysBefore,
          remindersEnabled: _remindersEnabled,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          updatedAt: now,
        );
        await FinanceService.updateBill(updated);
      } else {
        final bill = FinanceBill.create(
          name: _nameController.text,
          amount: amount,
          dueDate: _dueDate,
          recurrence: _selectedRecurrence,
          accountId: _selectedAccountId,
          remindDaysBefore: _remindDaysBefore,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
        await FinanceService.addBill(bill);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
