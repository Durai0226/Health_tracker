import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Grid widget showing spending per category for home screen
class CategorySpendingGrid extends StatefulWidget {
  final VoidCallback? onViewAll;
  final Function(FinanceCategory category)? onCategoryTap;

  const CategorySpendingGrid({
    super.key,
    this.onViewAll,
    this.onCategoryTap,
  });

  @override
  State<CategorySpendingGrid> createState() => _CategorySpendingGridState();
}

class _CategorySpendingGridState extends State<CategorySpendingGrid> {
  Map<String, double> _categorySpending = {};
  List<FinanceCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await FinanceService.init();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    setState(() {
      _categorySpending = FinanceService.getExpensesByCategory(startDate: startOfMonth);
      _categories = FinanceService.getCategories(isIncome: false);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Get top 5 categories by spending + "More" tile
    final sortedCategories = _categories
        .where((c) => _categorySpending.containsKey(c.name))
        .toList()
      ..sort((a, b) => 
          (_categorySpending[b.name] ?? 0).compareTo(_categorySpending[a.name] ?? 0));

    final displayCategories = sortedCategories.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Spending by Category', style: FinanceTheme.headingS),
            if (widget.onViewAll != null)
              TextButton(
                onPressed: widget.onViewAll,
                child: Text(
                  'View All',
                  style: FinanceTheme.bodyM.copyWith(color: FinanceTheme.primary),
                ),
              ),
          ],
        ),
        const SizedBox(height: FinanceTheme.spacingM),

        // Grid
        if (displayCategories.isEmpty)
          _buildEmptyState()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: displayCategories.length + (sortedCategories.length > 5 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < displayCategories.length) {
                final category = displayCategories[index];
                final amount = _categorySpending[category.name] ?? 0;
                return _CategoryTile(
                  category: category,
                  amount: amount,
                  onTap: () => widget.onCategoryTap?.call(category),
                );
              } else {
                // "More" tile
                return _MoreTile(
                  count: sortedCategories.length - 5,
                  onTap: widget.onViewAll,
                );
              }
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingL),
      decoration: BoxDecoration(
        color: FinanceTheme.surfaceVariant,
        borderRadius: FinanceTheme.borderRadiusM,
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: FinanceTheme.textLight,
          ),
          const SizedBox(height: FinanceTheme.spacingS),
          Text(
            'No expenses this month',
            style: FinanceTheme.bodyM.copyWith(color: FinanceTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final FinanceCategory category;
  final double amount;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.category,
    required this.amount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FinanceTheme.spacingS),
        decoration: BoxDecoration(
          color: FinanceTheme.surface,
          borderRadius: FinanceTheme.borderRadiusM,
          boxShadow: FinanceTheme.shadowSoft,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: FinanceTheme.borderRadiusS,
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              style: FinanceTheme.labelS.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              FinanceService.formatCurrency(amount),
              style: FinanceTheme.labelS.copyWith(
                color: FinanceTheme.expense,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _MoreTile({
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(FinanceTheme.spacingS),
        decoration: BoxDecoration(
          color: FinanceTheme.surfaceVariant,
          borderRadius: FinanceTheme.borderRadiusM,
          border: Border.all(
            color: FinanceTheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FinanceTheme.primary.withValues(alpha: 0.15),
                borderRadius: FinanceTheme.borderRadiusS,
              ),
              child: const Icon(
                Icons.more_horiz,
                color: FinanceTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '+$count more',
              style: FinanceTheme.labelS.copyWith(
                color: FinanceTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal category spending list
class CategorySpendingList extends StatelessWidget {
  final Map<String, double> spending;
  final List<FinanceCategory> categories;

  const CategorySpendingList({
    super.key,
    required this.spending,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final sortedCategories = categories
        .where((c) => spending.containsKey(c.name))
        .toList()
      ..sort((a, b) => 
          (spending[b.name] ?? 0).compareTo(spending[a.name] ?? 0));

    if (sortedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          final amount = spending[category.name] ?? 0;
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(FinanceTheme.spacingS),
            decoration: BoxDecoration(
              color: FinanceTheme.surface,
              borderRadius: FinanceTheme.borderRadiusM,
              boxShadow: FinanceTheme.shadowSoft,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, color: category.color, size: 24),
                const SizedBox(height: 4),
                Text(
                  category.name,
                  style: FinanceTheme.labelS,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  FinanceService.formatCurrency(amount),
                  style: FinanceTheme.labelS.copyWith(
                    fontWeight: FontWeight.w600,
                    color: FinanceTheme.expense,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
