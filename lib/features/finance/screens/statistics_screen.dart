import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/finance_theme.dart';
import '../services/finance_service.dart';

/// Statistics dashboard screen with analytics
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedPeriod = 1; // 0=Week, 1=Month, 2=Year
  bool _isLoading = true;
  
  double _totalIncome = 0;
  double _totalExpense = 0;
  Map<String, double> _categorySpending = {};
  List<Map<String, dynamic>> _dailyData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await FinanceService.init();
    
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedPeriod) {
      case 0: // Week
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 1: // Month
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 2: // Year
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    setState(() {
      _totalIncome = FinanceService.getTotalIncome(startDate: startDate);
      _totalExpense = FinanceService.getTotalExpense(startDate: startDate);
      _categorySpending = FinanceService.getExpensesByCategory(startDate: startDate);
      _dailyData = FinanceService.getDailyTransactionSummary(
        days: _selectedPeriod == 0 ? 7 : (_selectedPeriod == 1 ? 30 : 365),
      );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinanceTheme.background,
      appBar: AppBar(
        backgroundColor: FinanceTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FinanceTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Statistics', style: FinanceTheme.headingL),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(FinanceTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    _buildPeriodSelector(),
                    const SizedBox(height: FinanceTheme.spacingL),

                    // Summary cards
                    _buildSummaryCards(),
                    const SizedBox(height: FinanceTheme.spacingL),

                    // Spending trend chart
                    _buildSpendingTrendSection(),
                    const SizedBox(height: FinanceTheme.spacingL),

                    // Category breakdown
                    _buildCategoryBreakdown(),
                    const SizedBox(height: FinanceTheme.spacingL),

                    // Savings rate
                    _buildSavingsRate(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FinanceTheme.surfaceVariant,
        borderRadius: FinanceTheme.borderRadiusM,
      ),
      child: Row(
        children: [
          _PeriodButton(
            label: 'Week',
            isSelected: _selectedPeriod == 0,
            onTap: () {
              setState(() => _selectedPeriod = 0);
              _loadData();
            },
          ),
          _PeriodButton(
            label: 'Month',
            isSelected: _selectedPeriod == 1,
            onTap: () {
              setState(() => _selectedPeriod = 1);
              _loadData();
            },
          ),
          _PeriodButton(
            label: 'Year',
            isSelected: _selectedPeriod == 2,
            onTap: () {
              setState(() => _selectedPeriod = 2);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Income',
            amount: _totalIncome,
            icon: Icons.arrow_downward,
            color: FinanceTheme.income,
            gradient: FinanceTheme.incomeGradient,
          ),
        ),
        const SizedBox(width: FinanceTheme.spacingM),
        Expanded(
          child: _SummaryCard(
            title: 'Expense',
            amount: _totalExpense,
            icon: Icons.arrow_upward,
            color: FinanceTheme.expense,
            gradient: FinanceTheme.expenseGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingTrendSection() {
    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingM),
      decoration: BoxDecoration(
        color: FinanceTheme.surface,
        borderRadius: FinanceTheme.borderRadiusL,
        boxShadow: FinanceTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending Trend', style: FinanceTheme.headingS),
          const SizedBox(height: FinanceTheme.spacingS),
          Row(
            children: [
              _LegendDot(color: FinanceTheme.income, label: 'Income'),
              const SizedBox(width: FinanceTheme.spacingM),
              _LegendDot(color: FinanceTheme.expense, label: 'Expense'),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          SizedBox(
            height: 200,
            child: _SpendingTrendChart(data: _dailyData),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final sortedCategories = _categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final totalSpending = _categorySpending.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingM),
      decoration: BoxDecoration(
        color: FinanceTheme.surface,
        borderRadius: FinanceTheme.borderRadiusL,
        boxShadow: FinanceTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spending by Category', style: FinanceTheme.headingS),
              Text(
                FinanceService.formatCurrency(totalSpending),
                style: FinanceTheme.bodyM.copyWith(
                  fontWeight: FontWeight.w600,
                  color: FinanceTheme.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingM),
          
          if (sortedCategories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(FinanceTheme.spacingL),
                child: Text(
                  'No expenses in this period',
                  style: FinanceTheme.bodyM.copyWith(
                    color: FinanceTheme.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...sortedCategories.take(6).map((entry) {
              final percent = totalSpending > 0 
                  ? (entry.value / totalSpending * 100) 
                  : 0.0;
              return _CategoryBar(
                name: entry.key,
                amount: entry.value,
                percent: percent,
                color: _getCategoryColor(entry.key),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSavingsRate() {
    final savingsRate = _totalIncome > 0 
        ? ((_totalIncome - _totalExpense) / _totalIncome * 100).clamp(-100, 100)
        : 0.0;
    final isPositive = savingsRate >= 0;

    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingL),
      decoration: BoxDecoration(
        gradient: isPositive ? FinanceTheme.incomeGradient : FinanceTheme.expenseGradient,
        borderRadius: FinanceTheme.borderRadiusL,
        boxShadow: FinanceTheme.shadowMedium,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: FinanceTheme.borderRadiusM,
            ),
            child: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: FinanceTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings Rate',
                  style: FinanceTheme.labelM.copyWith(color: Colors.white70),
                ),
                Text(
                  '${savingsRate.toStringAsFixed(1)}%',
                  style: FinanceTheme.headingL.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                  ),
                ),
                Text(
                  isPositive 
                      ? 'Great job! Keep saving!' 
                      : 'Try to reduce expenses',
                  style: FinanceTheme.bodyS.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String name) {
    final colors = [
      FinanceTheme.primary,
      FinanceTheme.accent,
      FinanceTheme.income,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? FinanceTheme.primary : Colors.transparent,
            borderRadius: FinanceTheme.borderRadiusS,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: FinanceTheme.bodyM.copyWith(
              color: isSelected ? Colors.white : FinanceTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FinanceTheme.spacingM),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: FinanceTheme.borderRadiusL,
        boxShadow: FinanceTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: FinanceTheme.labelM.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: FinanceTheme.spacingS),
          Text(
            FinanceService.formatCurrency(amount),
            style: FinanceTheme.headingM.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: FinanceTheme.labelS.copyWith(color: FinanceTheme.textSecondary),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String name;
  final double amount;
  final double percent;
  final Color color;

  const _CategoryBar({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FinanceTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: FinanceTheme.bodyM,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                FinanceService.formatCurrency(amount),
                style: FinanceTheme.bodyM.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 45,
                child: Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: FinanceTheme.labelS.copyWith(
                    color: FinanceTheme.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendingTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _SpendingTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: FinanceTheme.bodyM.copyWith(color: FinanceTheme.textSecondary),
        ),
      );
    }

    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _TrendChartPainter(data: data),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _TrendChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = 40.0;
    final chartWidth = size.width - padding;
    final chartHeight = size.height - padding;

    // Find max value
    double maxValue = 0;
    for (final d in data) {
      final income = (d['income'] as num?)?.toDouble() ?? 0;
      final expense = (d['expense'] as num?)?.toDouble() ?? 0;
      maxValue = math.max(maxValue, math.max(income, expense));
    }
    if (maxValue == 0) maxValue = 100;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = FinanceTheme.textLight.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = padding / 2 + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw lines
    final incomePoints = <Offset>[];
    final expensePoints = <Offset>[];

    final step = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;

    for (int i = 0; i < data.length; i++) {
      final x = padding + step * i;
      final income = (data[i]['income'] as num?)?.toDouble() ?? 0;
      final expense = (data[i]['expense'] as num?)?.toDouble() ?? 0;

      final incomeY = padding / 2 + chartHeight - (income / maxValue * chartHeight);
      final expenseY = padding / 2 + chartHeight - (expense / maxValue * chartHeight);

      incomePoints.add(Offset(x, incomeY));
      expensePoints.add(Offset(x, expenseY));
    }

    // Draw income line
    final incomePaint = Paint()
      ..color = FinanceTheme.income
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final incomePath = Path();
    for (int i = 0; i < incomePoints.length; i++) {
      if (i == 0) {
        incomePath.moveTo(incomePoints[i].dx, incomePoints[i].dy);
      } else {
        incomePath.lineTo(incomePoints[i].dx, incomePoints[i].dy);
      }
    }
    canvas.drawPath(incomePath, incomePaint);

    // Draw expense line
    final expensePaint = Paint()
      ..color = FinanceTheme.expense
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final expensePath = Path();
    for (int i = 0; i < expensePoints.length; i++) {
      if (i == 0) {
        expensePath.moveTo(expensePoints[i].dx, expensePoints[i].dy);
      } else {
        expensePath.lineTo(expensePoints[i].dx, expensePoints[i].dy);
      }
    }
    canvas.drawPath(expensePath, expensePaint);

    // Draw dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    
    for (final point in incomePoints) {
      dotPaint.color = FinanceTheme.income;
      canvas.drawCircle(point, 3, dotPaint);
    }
    
    for (final point in expensePoints) {
      dotPaint.color = FinanceTheme.expense;
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
