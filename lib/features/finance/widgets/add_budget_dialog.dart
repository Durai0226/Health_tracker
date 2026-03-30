import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Bottom sheet dialog for creating/editing budgets
class AddBudgetDialog extends StatefulWidget {
  final FinanceBudget? existingBudget;
  final VoidCallback? onSaved;

  const AddBudgetDialog({
    super.key,
    this.existingBudget,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {
    FinanceBudget? existingBudget,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddBudgetDialog(
        existingBudget: existingBudget,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _limitController;
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  List<String> _selectedCategoryIds = [];
  List<FinanceCategory> _categories = [];
  bool _isLoading = false;

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingBudget?.name ?? '',
    );
    _limitController = TextEditingController(
      text: widget.existingBudget?.limit.toStringAsFixed(0) ?? '',
    );
    if (widget.existingBudget != null) {
      _selectedPeriod = widget.existingBudget!.period;
      _selectedCategoryIds = List.from(widget.existingBudget!.categoryIds);
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    await FinanceService.init();
    setState(() {
      _categories = FinanceService.getCategories()
          .where((c) => !c.isIncome)
          .toList();
    });
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
                _isEditing ? 'Edit Budget' : 'Create Budget',
                style: FinanceTheme.headingM,
              ),
              const SizedBox(height: FinanceTheme.spacingL),

              // Budget name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Budget Name',
                  hintText: 'e.g., Groceries, Entertainment',
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a budget name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Budget limit
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Budget Limit',
                  hintText: 'Enter amount',
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
                    return 'Please enter a budget limit';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Period selection
              Text('Budget Period', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              Wrap(
                spacing: 8,
                children: BudgetPeriod.values.map((period) {
                  final isSelected = period == _selectedPeriod;
                  return ChoiceChip(
                    label: Text(_getPeriodLabel(period)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPeriod = period);
                      }
                    },
                    selectedColor: FinanceTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FinanceTheme.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Category selection (multi-select)
              Text('Categories', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategoryIds.contains(cat.id);
                  return FilterChip(
                    label: Text(cat.name),
                    avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategoryIds.add(cat.id);
                        } else {
                          _selectedCategoryIds.remove(cat.id);
                        }
                      });
                    },
                    selectedColor: FinanceTheme.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : FinanceTheme.textPrimary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: FinanceTheme.spacingXL),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBudget,
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
                          _isEditing ? 'Update Budget' : 'Create Budget',
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

  String _getPeriodLabel(BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final limit = double.parse(_limitController.text);
      final now = DateTime.now();

      if (_isEditing) {
        final updated = widget.existingBudget!.copyWith(
          name: _nameController.text,
          limit: limit,
          period: _selectedPeriod,
          categoryIds: _selectedCategoryIds,
          updatedAt: now,
        );
        await FinanceService.updateBudget(updated);
      } else {
        final budget = FinanceBudget.create(
          name: _nameController.text,
          limit: limit,
          period: _selectedPeriod,
          categoryIds: _selectedCategoryIds.isEmpty 
              ? _categories.map((c) => c.id).toList() 
              : _selectedCategoryIds,
        );
        await FinanceService.addBudget(budget);
      }

      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
