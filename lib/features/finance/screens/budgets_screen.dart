import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/finance_storage_service.dart';
import '../models/budget.dart';
import '../models/finance_enums.dart';
import '../models/finance_category.dart';
import '../../../core/constants/app_colors.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final budgets = FinanceStorageService.getAllBudgets();
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Budgets',
          style: TextStyle(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showAddBudgetSheet(context),
          ),
        ],
      ),
      body: budgets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline,
                      size: 64,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No budgets yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a budget to track your spending',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBudgetSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Budget'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final budget = budgets[index];
                return _buildBudgetCard(budget, isDark);
              },
            ),
    );
  }

  Widget _buildBudgetCard(Budget budget, bool isDark) {
    final percentUsed = budget.percentUsed;
    final isOverBudget = budget.isOverBudget;
    final categoryNames = budget.categoryIds
        .map((id) => FinanceStorageService.getCategory(id)?.name ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    Color progressColor;
    if (isOverBudget) {
      progressColor = const Color(0xFFEF4444);
    } else if (percentUsed >= 80) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = const Color(0xFF22C55E);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: budget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    budget.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert, color: AppColors.getTextSecondary(context)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                    onTap: () async {
                      await FinanceStorageService.deleteBudget(budget.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            categoryNames.join(', '),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(budget.spent)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
              Text(
                'of ₹${NumberFormat('#,##,###').format(budget.limit)}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentUsed / 100).clamp(0.0, 1.0),
              backgroundColor: progressColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentUsed.toStringAsFixed(0)}% used',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: progressColor,
                ),
              ),
              Text(
                '₹${NumberFormat('#,##,###').format(budget.remaining)} left',
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

  void _showAddBudgetSheet(BuildContext context) {
    final nameController = TextEditingController();
    final limitController = TextEditingController();
    BudgetPeriod selectedPeriod = BudgetPeriod.monthly;
    List<String> selectedCategoryIds = [];
    Color selectedColor = const Color(0xFFF59E0B);

    final categories = FinanceStorageService.getExpenseCategories();
    final colors = [
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFF22C55E),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.getCardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getDivider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Create Budget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Budget Name',
                          hintText: 'e.g., Food Budget',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: limitController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Budget Limit',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Period',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: BudgetPeriod.values.map((period) {
                          final isSelected = selectedPeriod == period;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setSheetState(() => selectedPeriod = period),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.getDivider(context),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    period.displayName,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((category) {
                          final isSelected = selectedCategoryIds.contains(category.id);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (isSelected) {
                                  selectedCategoryIds.remove(category.id);
                                } else {
                                  selectedCategoryIds.add(category.id);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? category.color : Colors.transparent,
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
                                    size: 16,
                                    color: isSelected ? Colors.white : category.color,
                                  ),
                                  const SizedBox(width: 6),
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
                      const SizedBox(height: 16),
                      Text(
                        'Color',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: colors.map((color) {
                          final isSelected = selectedColor == color;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedColor = color),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty ||
                        limitController.text.isEmpty ||
                        selectedCategoryIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    final budget = Budget(
                      name: nameController.text,
                      limit: double.tryParse(limitController.text) ?? 0,
                      period: selectedPeriod,
                      categoryIds: selectedCategoryIds,
                      colorValue: selectedColor.value,
                    );

                    await FinanceStorageService.addBudget(budget);
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Create Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
