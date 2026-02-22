import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../services/finance_storage_service.dart';
import '../models/transaction.dart';
import '../models/finance_enums.dart';
import '../models/finance_category.dart';
import '../models/finance_account.dart';

class AddTransactionScreen extends StatefulWidget {
  final FinanceTransaction? editTransaction;

  const AddTransactionScreen({super.key, this.editTransaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String? _selectedToAccountId;
  DateTime _selectedDate = DateTime.now();
  RecurrenceType _recurrence = RecurrenceType.none;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  void _initDefaults() {
    if (widget.editTransaction != null) {
      final t = widget.editTransaction!;
      _amountController.text = t.amount.toString();
      _noteController.text = t.note ?? '';
      _selectedType = t.type;
      _selectedCategoryId = t.categoryId;
      _selectedAccountId = t.accountId;
      _selectedToAccountId = t.toAccountId;
      _selectedDate = t.date;
      _recurrence = t.recurrence;
    } else {
      final accounts = FinanceStorageService.getAllAccounts();
      if (accounts.isNotEmpty) {
        _selectedAccountId = accounts.first.id;
      }
      final categories = FinanceStorageService.getExpenseCategories();
      if (categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<FinanceCategory> get _categories {
    return _selectedType == TransactionType.income
        ? FinanceStorageService.getIncomeCategories()
        : FinanceStorageService.getExpenseCategories();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select category and account')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transaction = FinanceTransaction(
        id: widget.editTransaction?.id,
        amount: double.parse(_amountController.text),
        type: _selectedType,
        categoryId: _selectedCategoryId!,
        accountId: _selectedAccountId!,
        toAccountId: _selectedType == TransactionType.transfer ? _selectedToAccountId : null,
        date: _selectedDate,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        recurrence: _recurrence,
      );

      if (widget.editTransaction != null) {
        await FinanceStorageService.updateTransaction(transaction);
      } else {
        await FinanceStorageService.addTransaction(transaction);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.editTransaction != null ? 'Edit Transaction' : 'Add Transaction',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveTransaction,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildAmountField(),
              const SizedBox(height: 24),
              _buildCategorySelector(),
              const SizedBox(height: 24),
              _buildAccountSelector(),
              if (_selectedType == TransactionType.transfer) ...[
                const SizedBox(height: 24),
                _buildToAccountSelector(),
              ],
              const SizedBox(height: 24),
              _buildDateSelector(),
              const SizedBox(height: 24),
              _buildNoteField(),
              const SizedBox(height: 24),
              _buildRecurrenceSelector(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return CommonCard(
      child: Row(
        children: TransactionType.values.map((type) {
          final isSelected = _selectedType == type;
          Color color;
          switch (type) {
            case TransactionType.income:
              color = const Color(0xFF22C55E);
              break;
            case TransactionType.expense:
              color = const Color(0xFFEF4444);
              break;
            case TransactionType.transfer:
              color = const Color(0xFF3B82F6);
              break;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = type;
                  _selectedCategoryId = _categories.isNotEmpty ? _categories.first.id : null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  type.displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAmountField() {
    Color accentColor;
    switch (_selectedType) {
      case TransactionType.income:
        accentColor = const Color(0xFF22C55E);
        break;
      case TransactionType.expense:
        accentColor = const Color(0xFFEF4444);
        break;
      case TransactionType.transfer:
        accentColor = const Color(0xFF3B82F6);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        CommonCard(
          border: Border.all(color: accentColor.withOpacity(0.3)),
          child: TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              hintText: '0.00',
              hintStyle: TextStyle(color: accentColor.withOpacity(0.4)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Please enter a valid amount';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = _categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        CommonCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final isSelected = _selectedCategoryId == category.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryId = category.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? category.color : AppColors.getCardBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? category.color : category.color.withOpacity(0.3),
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
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    final accounts = FinanceStorageService.getAllAccounts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedType == TransactionType.transfer ? 'From Account' : 'Account',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        CommonCard(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: accounts.map((account) {
                final isSelected = _selectedAccountId == account.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAccountId = account.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? account.color : AppColors.getCardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? account.color : account.color.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            account.type.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            account.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${NumberFormat('#,##,###').format(account.balance)}',
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : AppColors.getTextSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToAccountSelector() {
    final accounts = FinanceStorageService.getAllAccounts()
        .where((a) => a.id != _selectedAccountId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'To Account',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        CommonCard(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: accounts.map((account) {
                final isSelected = _selectedToAccountId == account.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedToAccountId = account.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? account.color : AppColors.getCardBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? account.color : account.color.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            account.type.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            account.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        CommonCard(
          child: GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextFormField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a note...',
              hintStyle: TextStyle(color: AppColors.getTextSecondary(context)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
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
          'Repeat',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RecurrenceType.values.map((type) {
            final isSelected = _recurrence == type;
            return GestureDetector(
              onTap: () => setState(() => _recurrence = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.getCardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.getTextSecondary(context).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
