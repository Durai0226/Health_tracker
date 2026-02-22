import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/bill_enums.dart';
import '../services/bill_storage_service.dart';
import '../services/bill_reminder_service.dart';
import '../widgets/bill_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';

class AddBillScreen extends StatefulWidget {
  final Bill? editBill;

  const AddBillScreen({super.key, this.editBill});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  BillRecurrence _recurrence = BillRecurrence.monthly;
  int _customInterval = 1;
  CustomRecurrenceUnit _customUnit = CustomRecurrenceUnit.months;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  int _gracePeriodDays = 0;
  int _colorValue = 0xFF3B82F6;
  int _iconCodePoint = Icons.receipt_long.codePoint;
  List<BillReminder> _reminders = [];
  bool _remindersEnabled = true;
  String _currency = 'INR';
  double _exchangeRate = 1.0;
  List<String> _tags = [];

  bool _isLoading = false;
  bool get _isEditing => widget.editBill != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateEditData();
    } else {
      _reminders = BillReminderService.createDefaultReminders();
    }
  }

  void _populateEditData() {
    final bill = widget.editBill!;
    _nameController.text = bill.name;
    _amountController.text = bill.amount.toString();
    _noteController.text = bill.note ?? '';
    _dueDate = bill.dueDate;
    _recurrence = bill.recurrence;
    _customInterval = bill.customRecurrenceInterval ?? 1;
    _customUnit = bill.customRecurrenceUnit ?? CustomRecurrenceUnit.months;
    _selectedCategoryId = bill.categoryId;
    _selectedAccountId = bill.accountId;
    _gracePeriodDays = bill.gracePeriodDays;
    _colorValue = bill.colorValue;
    _iconCodePoint = bill.iconCodePoint;
    _reminders = List.from(bill.reminders);
    _remindersEnabled = bill.remindersEnabled;
    _currency = bill.currency ?? 'INR';
    _exchangeRate = bill.exchangeRate ?? 1.0;
    _tags = List.from(bill.tags);
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
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Bill' : 'Add Bill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.getTextPrimary(context),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _duplicateBill,
              tooltip: 'Duplicate',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNameField(),
              const SizedBox(height: 20),
              _buildAmountField(),
              const SizedBox(height: 20),
              _buildCategorySelector(),
              const SizedBox(height: 20),
              _buildDueDateSelector(),
              const SizedBox(height: 20),
              _buildRecurrenceSelector(),
              const SizedBox(height: 20),
              _buildAccountSelector(),
              const SizedBox(height: 20),
              _buildRemindersSection(),
              const SizedBox(height: 20),
              _buildAdvancedOptions(),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bill Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        CommonCard(
          padding: EdgeInsets.zero,
          child: TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'e.g., Electricity Bill, Netflix',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Icon(
                IconData(_iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Color(_colorValue),
              ),
            ),
            validator: (value) =>
                value?.isEmpty == true ? 'Please enter bill name' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        CommonCard(
          padding: EdgeInsets.zero,
          child: TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(_colorValue),
                  ),
                ),
              ),
              suffixIcon: _currency != 'INR'
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '× $_exchangeRate',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    )
                  : null,
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            validator: (value) {
              if (value?.isEmpty == true) return 'Please enter amount';
              if (double.tryParse(value!) == null) return 'Invalid amount';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = BillStorageService.getAllCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((category) {
              final isSelected = _selectedCategoryId == category.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: BillCategoryChip(
                  category: category,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = category.id;
                      _colorValue = category.colorValue;
                      _iconCodePoint = category.iconCodePoint;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDueDate,
          child: CommonCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(_colorValue)),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_dueDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recurrence',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        CommonCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BillRecurrence.values.map((recurrence) {
                  final isSelected = _recurrence == recurrence;
                  return GestureDetector(
                    onTap: () => setState(() => _recurrence = recurrence),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_colorValue)
                            : AppColors.getCardBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Color(_colorValue)
                              : AppColors.isDark(context)
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        recurrence.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_recurrence == BillRecurrence.custom) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _customInterval.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Every',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _customInterval = int.tryParse(value) ?? 1;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<CustomRecurrenceUnit>(
                        value: _customUnit,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: CustomRecurrenceUnit.values
                            .map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.displayName),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _customUnit = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pay From (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectAccount,
          child: CommonCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Color(_colorValue)),
                const SizedBox(width: 12),
                Text(
                  _selectedAccountId != null ? 'Account Selected' : 'Select Account',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reminders',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            Switch(
              value: _remindersEnabled,
              onChanged: (value) => setState(() => _remindersEnabled = value),
              activeColor: Color(_colorValue),
            ),
          ],
        ),
        if (_remindersEnabled) ...[
          const SizedBox(height: 8),
          ..._reminders.asMap().entries.map((entry) {
            final index = entry.key;
            final reminder = entry.value;
            return ReminderItem(
              reminder: reminder,
              onToggle: () {
                setState(() {
                  _reminders[index] = reminder.copyWith(
                    isEnabled: !reminder.isEnabled,
                  );
                });
              },
              onDelete: () {
                setState(() => _reminders.removeAt(index));
              },
            );
          }),
          const SizedBox(height: 8),
          CommonButton(
            text: 'Add Reminder',
            icon: Icons.add,
            variant: ButtonVariant.outline,
            onPressed: _addReminder,
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedOptions() {
    return ExpansionTile(
      title: Text(
        'Advanced Options',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextPrimary(context),
        ),
      ),
      tilePadding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        CommonCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grace Period',
                    style: TextStyle(color: AppColors.getTextPrimary(context)),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _gracePeriodDays > 0
                            ? () => setState(() => _gracePeriodDays--)
                            : null,
                      ),
                      Text('$_gracePeriodDays days'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _gracePeriodDays < 30
                            ? () => setState(() => _gracePeriodDays++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Add any notes or description...',
                  border: InputBorder.none,
                  labelStyle: TextStyle(color: AppColors.getTextSecondary(context)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: CommonButton(
        text: _isEditing ? 'Update Bill' : 'Save Bill',
        icon: Icons.check,
        variant: ButtonVariant.gradient,
        isLoading: _isLoading,
        onPressed: _saveBill,
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  void _selectAccount() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.do_not_disturb),
                title: const Text('No Account'),
                onTap: () {
                  setState(() => _selectedAccountId = null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addReminder() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _AddReminderSheet(
        onAdd: (reminder) {
          setState(() => _reminders.add(reminder));
        },
      ),
    );
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final bill = Bill(
        id: widget.editBill?.id,
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        dueDate: _dueDate,
        recurrence: _recurrence,
        customRecurrenceInterval:
            _recurrence == BillRecurrence.custom ? _customInterval : null,
        customRecurrenceUnit:
            _recurrence == BillRecurrence.custom ? _customUnit : null,
        categoryId: _selectedCategoryId,
        accountId: _selectedAccountId,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        gracePeriodDays: _gracePeriodDays,
        colorValue: _colorValue,
        iconCodePoint: _iconCodePoint,
        reminders: _reminders,
        remindersEnabled: _remindersEnabled,
        currency: _currency,
        exchangeRate: _exchangeRate,
        tags: _tags,
        createdAt: widget.editBill?.createdAt,
        paidAmount: widget.editBill?.paidAmount ?? 0,
      );

      await BillStorageService.saveBill(bill);

      if (_remindersEnabled && _reminders.isNotEmpty) {
        await BillReminderService.scheduleRemindersForBill(bill);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Bill updated' : 'Bill added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving bill: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _duplicateBill() async {
    if (widget.editBill == null) return;

    try {
      final duplicate = await BillStorageService.duplicateBill(widget.editBill!.id);
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddBillScreen(editBill: duplicate),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating bill: $e')),
        );
      }
    }
  }
}

class _AddReminderSheet extends StatefulWidget {
  final Function(BillReminder) onAdd;

  const _AddReminderSheet({required this.onAdd});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  ReminderType _type = ReminderType.daysBefore;
  int _daysBefore = 1;
  int _hour = 9;
  int _minute = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Reminder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _daysBefore,
                    decoration: const InputDecoration(
                      labelText: 'Days Before',
                      border: OutlineInputBorder(),
                    ),
                    items: [0, 1, 2, 3, 5, 7, 14, 30]
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d == 0 ? 'Same day' : '$d day${d > 1 ? 's' : ''}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _daysBefore = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: _hour, minute: _minute),
                      );
                      if (time != null) {
                        setState(() {
                          _hour = time.hour;
                          _minute = time.minute;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${_hour > 12 ? _hour - 12 : (_hour == 0 ? 12 : _hour)}:${_minute.toString().padLeft(2, '0')} ${_hour >= 12 ? 'PM' : 'AM'}',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: CommonButton(
                text: 'Add Reminder',
                variant: ButtonVariant.primary,
                onPressed: () {
                  final reminder = BillReminder(
                    type: _daysBefore == 0 ? ReminderType.sameDay : ReminderType.daysBefore,
                    daysBefore: _daysBefore,
                    hour: _hour,
                    minute: _minute,
                  );
                  widget.onAdd(reminder);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
