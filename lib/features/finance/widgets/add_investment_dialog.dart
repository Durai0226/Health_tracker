import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Bottom sheet dialog for creating/editing investments
class AddInvestmentDialog extends StatefulWidget {
  final FinanceInvestment? existingInvestment;
  final VoidCallback? onSaved;

  const AddInvestmentDialog({
    super.key,
    this.existingInvestment,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {
    FinanceInvestment? existingInvestment,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddInvestmentDialog(
        existingInvestment: existingInvestment,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddInvestmentDialog> createState() => _AddInvestmentDialogState();
}

class _AddInvestmentDialogState extends State<AddInvestmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _currentValueController;
  late TextEditingController _noteController;
  InvestmentType _selectedType = InvestmentType.stock;
  bool _isLoading = false;

  bool get _isEditing => widget.existingInvestment != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingInvestment?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.existingInvestment?.investedAmount.toStringAsFixed(2) ?? '',
    );
    _currentValueController = TextEditingController(
      text: widget.existingInvestment?.currentValue.toStringAsFixed(2) ?? '',
    );
    _noteController = TextEditingController(
      text: widget.existingInvestment?.note ?? '',
    );
    if (widget.existingInvestment != null) {
      _selectedType = widget.existingInvestment!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _currentValueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FinanceTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FinanceTheme.spacingL),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FinanceTheme.textLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingL),

              // Title
              Text(
                _isEditing ? 'Edit Investment' : 'Add Investment',
                style: FinanceTheme.headingM,
              ),
              const SizedBox(height: FinanceTheme.spacingL),

              // Investment type
              Text('Investment Type', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: InvestmentType.values.map((type) {
                  final isSelected = type == _selectedType;
                  return ChoiceChip(
                    label: Text(_getTypeLabel(type)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                      }
                    },
                    avatar: Icon(
                      _getTypeIcon(type),
                      size: 18,
                      color: isSelected ? Colors.white : FinanceTheme.textSecondary,
                    ),
                    selectedColor: FinanceTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FinanceTheme.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Investment name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Investment Name',
                  hintText: 'e.g., Apple Stock, Bank Deposit',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter investment name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Invested amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Invested Amount',
                  hintText: 'Initial investment',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter invested amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Current value
              TextFormField(
                controller: _currentValueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Current Value',
                  hintText: 'Current market value',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter current value';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Notes
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Additional details...',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingXL),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveInvestment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinanceTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: FinanceTheme.borderRadiusM,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Investment' : 'Add Investment',
                          style: FinanceTheme.bodyL.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingM),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(InvestmentType type) {
    switch (type) {
      case InvestmentType.stock:
        return 'Stock';
      case InvestmentType.bond:
        return 'Bond';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.insurance:
        return 'Insurance';
      case InvestmentType.crypto:
        return 'Crypto';
      case InvestmentType.realEstate:
        return 'Real Estate';
      case InvestmentType.deposit:
        return 'Deposit';
      case InvestmentType.other:
        return 'Other';
    }
  }

  IconData _getTypeIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.stock:
        return Icons.trending_up;
      case InvestmentType.bond:
        return Icons.account_balance;
      case InvestmentType.mutualFund:
        return Icons.pie_chart;
      case InvestmentType.insurance:
        return Icons.security;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin;
      case InvestmentType.realEstate:
        return Icons.home_work;
      case InvestmentType.deposit:
        return Icons.savings;
      case InvestmentType.other:
        return Icons.category;
    }
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final investedAmount = double.parse(_amountController.text);
      final currentValue = double.parse(_currentValueController.text);
      final now = DateTime.now();

      if (_isEditing) {
        final updated = widget.existingInvestment!.copyWith(
          name: _nameController.text,
          type: _selectedType,
          investedAmount: investedAmount,
          currentValue: currentValue,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          updatedAt: now,
        );
        await FinanceService.updateInvestment(updated);
      } else {
        final investment = FinanceInvestment.create(
          name: _nameController.text,
          type: _selectedType,
          investedAmount: investedAmount,
          currentValue: currentValue,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
        await FinanceService.addInvestment(investment);
      }

      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving investment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
