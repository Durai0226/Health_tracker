import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Dialog for creating/editing savings goals
class AddSavingsGoalDialog extends StatefulWidget {
  final FinanceSavingsGoal? existingGoal;
  final VoidCallback? onSaved;

  const AddSavingsGoalDialog({
    super.key,
    this.existingGoal,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    FinanceSavingsGoal? existingGoal,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddSavingsGoalDialog(
        existingGoal: existingGoal,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddSavingsGoalDialog> createState() => _AddSavingsGoalDialogState();
}

class _AddSavingsGoalDialogState extends State<AddSavingsGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _currentController;
  DateTime? _deadline;
  SavingsGoalPreset? _selectedPreset;
  IconData _selectedIcon = Icons.savings;
  Color _selectedColor = Colors.teal;
  bool _isLoading = false;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingGoal?.name ?? '');
    _targetController = TextEditingController(
      text: widget.existingGoal?.targetAmount.toStringAsFixed(0) ?? '',
    );
    _currentController = TextEditingController(
      text: widget.existingGoal?.currentAmount.toStringAsFixed(0) ?? '0',
    );
    if (widget.existingGoal != null) {
      _deadline = widget.existingGoal!.deadline;
      _selectedIcon = widget.existingGoal!.icon;
      _selectedColor = widget.existingGoal!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
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
                _isEditing ? 'Edit Savings Goal' : 'New Savings Goal',
                style: FinanceTheme.headingM,
              ),
              const SizedBox(height: FinanceTheme.spacingL),

              // Presets (only for new goals)
              if (!_isEditing) ...[
                Text('Quick Start', style: FinanceTheme.labelM),
                const SizedBox(height: FinanceTheme.spacingS),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: FinanceSavingsGoal.presets.length,
                    itemBuilder: (context, index) {
                      final preset = FinanceSavingsGoal.presets[index];
                      final isSelected = _selectedPreset == preset;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _selectPreset(preset),
                          child: Container(
                            width: 80,
                            padding: const EdgeInsets.all(FinanceTheme.spacingS),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? preset.color.withValues(alpha: 0.15)
                                  : FinanceTheme.surfaceVariant,
                              borderRadius: FinanceTheme.borderRadiusM,
                              border: isSelected 
                                  ? Border.all(color: preset.color, width: 2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(preset.icon, color: preset.color, size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  preset.name,
                                  style: FinanceTheme.labelS,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: FinanceTheme.spacingL),
              ],

              // Goal name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Goal Name',
                  hintText: 'e.g., New Car',
                  prefixIcon: Icon(_selectedIcon, color: _selectedColor),
                  filled: true,
                  fillColor: FinanceTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: FinanceTheme.borderRadiusM,
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Target amount
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target Amount',
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
                    return 'Please enter target amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: FinanceTheme.spacingM),

              // Current amount (for editing)
              if (_isEditing) ...[
                TextFormField(
                  controller: _currentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Current Savings',
                    prefixText: '\$ ',
                    filled: true,
                    fillColor: FinanceTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: FinanceTheme.borderRadiusM,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: FinanceTheme.spacingM),
              ],

              // Deadline picker
              Text('Target Date (Optional)', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              InkWell(
                onTap: _pickDeadline,
                borderRadius: FinanceTheme.borderRadiusM,
                child: Container(
                  padding: const EdgeInsets.all(FinanceTheme.spacingM),
                  decoration: BoxDecoration(
                    color: FinanceTheme.surfaceVariant,
                    borderRadius: FinanceTheme.borderRadiusM,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, 
                          color: FinanceTheme.textSecondary, size: 20),
                      const SizedBox(width: FinanceTheme.spacingM),
                      Text(
                        _deadline != null 
                            ? _formatDate(_deadline!)
                            : 'No deadline set',
                        style: FinanceTheme.bodyM.copyWith(
                          color: _deadline != null 
                              ? FinanceTheme.textPrimary 
                              : FinanceTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (_deadline != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _deadline = null),
                          color: FinanceTheme.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FinanceTheme.spacingL),

              // Color picker
              Text('Color', style: FinanceTheme.labelM),
              const SizedBox(height: FinanceTheme.spacingS),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Colors.teal,
                  Colors.blue,
                  Colors.purple,
                  Colors.pink,
                  Colors.orange,
                  Colors.green,
                  Colors.red,
                  Colors.indigo,
                ].map((color) {
                  final isSelected = _selectedColor.value == color.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected 
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected 
                            ? [BoxShadow(color: color, blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected 
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: FinanceTheme.spacingXL),

              // Monthly contribution hint
              if (_deadline != null && _targetController.text.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(FinanceTheme.spacingM),
                  decoration: BoxDecoration(
                    color: _selectedColor.withValues(alpha: 0.1),
                    borderRadius: FinanceTheme.borderRadiusM,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: _selectedColor),
                      const SizedBox(width: FinanceTheme.spacingS),
                      Expanded(
                        child: Text(
                          'Save ${_calculateMonthlyContribution()} per month to reach your goal',
                          style: FinanceTheme.bodyS.copyWith(
                            color: _selectedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FinanceTheme.spacingL),
              ],

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: FinanceTheme.borderRadiusM,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Goal' : 'Create Goal',
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

  void _selectPreset(SavingsGoalPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _nameController.text = preset.name == 'Custom' ? '' : preset.name;
      _targetController.text = preset.suggestedTarget.toStringAsFixed(0);
      _selectedIcon = preset.icon;
      _selectedColor = preset.color;
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _selectedColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _calculateMonthlyContribution() {
    final target = double.tryParse(_targetController.text) ?? 0;
    final current = double.tryParse(_currentController.text) ?? 0;
    final remaining = target - current;
    if (_deadline == null || remaining <= 0) return '\$0';
    
    final monthsRemaining = _deadline!.difference(DateTime.now()).inDays / 30;
    if (monthsRemaining <= 0) return FinanceService.formatCurrency(remaining);
    
    final monthly = remaining / monthsRemaining;
    return FinanceService.formatCurrency(monthly);
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final target = double.parse(_targetController.text);
      final current = double.tryParse(_currentController.text) ?? 0;

      if (_isEditing) {
        final updated = widget.existingGoal!.copyWith(
          name: _nameController.text,
          targetAmount: target,
          currentAmount: current,
          deadline: _deadline,
          iconCodePoint: _selectedIcon.codePoint,
          colorValue: _selectedColor.value,
          isCompleted: current >= target,
        );
        await FinanceService.updateSavingsGoal(updated);
      } else {
        final goal = FinanceSavingsGoal.create(
          name: _nameController.text,
          targetAmount: target,
          deadline: _deadline,
          icon: _selectedIcon,
          color: _selectedColor,
        );
        await FinanceService.addSavingsGoal(goal);
      }

      widget.onSaved?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/// Dialog for adding contribution to a goal
class AddContributionDialog extends StatefulWidget {
  final FinanceSavingsGoal goal;
  final VoidCallback? onSaved;

  const AddContributionDialog({
    super.key,
    required this.goal,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required FinanceSavingsGoal goal,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddContributionDialog(
        goal: goal,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddContributionDialog> createState() => _AddContributionDialogState();
}

class _AddContributionDialogState extends State<AddContributionDialog> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
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
        left: FinanceTheme.spacingL,
        right: FinanceTheme.spacingL,
        top: FinanceTheme.spacingL,
        bottom: MediaQuery.of(context).viewInsets.bottom + FinanceTheme.spacingL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Text('Add to ${widget.goal.name}', style: FinanceTheme.headingM),
          const SizedBox(height: FinanceTheme.spacingS),
          Text(
            'Current: ${FinanceService.formatCurrency(widget.goal.currentAmount)} of ${FinanceService.formatCurrency(widget.goal.targetAmount)}',
            style: FinanceTheme.bodyM.copyWith(color: FinanceTheme.textSecondary),
          ),
          const SizedBox(height: FinanceTheme.spacingL),

          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              filled: true,
              fillColor: FinanceTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: FinanceTheme.borderRadiusM,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: FinanceTheme.spacingM),

          // Quick amount buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [50, 100, 200, 500].map((amount) {
              return ActionChip(
                label: Text('\$$amount'),
                onPressed: () {
                  _amountController.text = amount.toString();
                },
                backgroundColor: widget.goal.color.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: widget.goal.color),
              );
            }).toList(),
          ),
          const SizedBox(height: FinanceTheme.spacingXL),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addContribution,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.goal.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: FinanceTheme.borderRadiusM,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Contribution'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addContribution() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FinanceService.addContributionToGoal(widget.goal.id, amount);
      widget.onSaved?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${FinanceService.formatCurrency(amount)} to ${widget.goal.name}'),
            backgroundColor: FinanceTheme.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
