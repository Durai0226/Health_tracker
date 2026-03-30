import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/finance_theme.dart';
import '../models/finance_models.dart';
import '../services/finance_service.dart';

/// Pie chart widget showing spending by category
class SpendingChart extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final double size;

  const SpendingChart({
    super.key,
    this.startDate,
    this.endDate,
    this.size = 200,
  });

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Map<String, double> _categorySpending = {};
  double _totalSpending = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await FinanceService.init();
    final transactions = FinanceService.getTransactions(
      startDate: widget.startDate,
      endDate: widget.endDate,
    ).where((t) => t.type == TransactionType.expense).toList();

    final categories = FinanceService.getCategories();
    final spending = <String, double>{};

    for (final t in transactions) {
      final category = categories.firstWhere(
        (c) => c.id == t.categoryId,
        orElse: () => FinanceCategory.create(
          name: 'Other', 
          isIncome: false,
          icon: Icons.category,
          color: Colors.grey,
        ),
      );
      spending[category.name] = (spending[category.name] ?? 0) + t.amount;
    }

    setState(() {
      _categorySpending = spending;
      _totalSpending = spending.values.fold(0, (a, b) => a + b);
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_categorySpending.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Chart
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _PieChartPainter(
                  data: _categorySpending,
                  total: _totalSpending,
                  progress: _animation.value,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: FinanceTheme.labelS.copyWith(
                          color: FinanceTheme.textSecondary,
                        ),
                      ),
                      Text(
                        FinanceService.formatCurrency(_totalSpending),
                        style: FinanceTheme.headingM.copyWith(
                          color: FinanceTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: FinanceTheme.spacingL),
        
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _categorySpending.entries.map((entry) {
            final color = _getCategoryColor(entry.key);
            final percent = (_totalSpending > 0)
                ? (entry.value / _totalSpending * 100).toStringAsFixed(1)
                : '0';
            return _LegendItem(
              color: color,
              label: entry.key,
              value: FinanceService.formatCurrency(entry.value),
              percent: '$percent%',
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: FinanceTheme.textLight,
            ),
            const SizedBox(height: 8),
            Text(
              'No spending data',
              style: FinanceTheme.bodyM.copyWith(
                color: FinanceTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String name) {
    final colors = [
      FinanceTheme.primary,
      FinanceTheme.accent,
      FinanceTheme.income,
      FinanceTheme.expense,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}

class _PieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final double total;
  final double progress;

  _PieChartPainter({
    required this.data,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final innerRadius = radius * 0.6;

    final colors = [
      FinanceTheme.primary,
      FinanceTheme.accent,
      FinanceTheme.income,
      FinanceTheme.expense,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];

    double startAngle = -math.pi / 2;
    int colorIndex = 0;

    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi * progress;
      final color = colors[colorIndex % colors.length];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius - innerRadius
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: (radius + innerRadius) / 2,
        ),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
      colorIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.data != data;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String percent;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FinanceTheme.surfaceVariant,
        borderRadius: FinanceTheme.borderRadiusS,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: FinanceTheme.bodyS.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            percent,
            style: FinanceTheme.labelS.copyWith(
              color: FinanceTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Monthly trend chart showing income vs expense
class MonthlyTrendChart extends StatefulWidget {
  final int monthsToShow;
  final double height;

  const MonthlyTrendChart({
    super.key,
    this.monthsToShow = 6,
    this.height = 200,
  });

  @override
  State<MonthlyTrendChart> createState() => _MonthlyTrendChartState();
}

class _MonthlyTrendChartState extends State<MonthlyTrendChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<_MonthData> _monthlyData = [];
  double _maxValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await FinanceService.init();
    final now = DateTime.now();
    final data = <_MonthData>[];

    for (int i = widget.monthsToShow - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final income = FinanceService.getTotalIncome(
        startDate: month,
        endDate: endOfMonth,
      );
      final expense = FinanceService.getTotalExpense(
        startDate: month,
        endDate: endOfMonth,
      );

      data.add(_MonthData(
        month: month,
        income: income,
        expense: expense,
      ));
    }

    setState(() {
      _monthlyData = data;
      _maxValue = data.fold(0.0, (max, d) => 
        math.max(max, math.max(d.income, d.expense)));
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_monthlyData.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _buildLegendDot(FinanceTheme.income, 'Income'),
            const SizedBox(width: 16),
            _buildLegendDot(FinanceTheme.expense, 'Expense'),
          ],
        ),
        const SizedBox(height: FinanceTheme.spacingM),
        
        // Chart
        SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _monthlyData.map((data) {
                  return Expanded(
                    child: _MonthBar(
                      data: data,
                      maxValue: _maxValue,
                      progress: _animation.value,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
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
          style: FinanceTheme.labelS.copyWith(
            color: FinanceTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MonthData {
  final DateTime month;
  final double income;
  final double expense;

  _MonthData({
    required this.month,
    required this.income,
    required this.expense,
  });

  String get monthLabel {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month.month - 1];
  }
}

class _MonthBar extends StatelessWidget {
  final _MonthData data;
  final double maxValue;
  final double progress;

  const _MonthBar({
    required this.data,
    required this.maxValue,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final incomeHeight = maxValue > 0 ? (data.income / maxValue) * 140 * progress : 0.0;
    final expenseHeight = maxValue > 0 ? (data.expense / maxValue) * 140 * progress : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Income bar
              Container(
                width: 12,
                height: incomeHeight,
                decoration: BoxDecoration(
                  color: FinanceTheme.income,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // Expense bar
              Container(
                width: 12,
                height: expenseHeight,
                decoration: BoxDecoration(
                  color: FinanceTheme.expense,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.monthLabel,
            style: FinanceTheme.labelS.copyWith(
              color: FinanceTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
