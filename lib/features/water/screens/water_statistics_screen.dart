import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/design/app_colors_ext.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';

/// Advanced Statistics Screen with charts and insights
class WaterStatisticsScreen extends StatefulWidget {
  const WaterStatisticsScreen({super.key});

  @override
  State<WaterStatisticsScreen> createState() => _WaterStatisticsScreenState();
}

class _WaterStatisticsScreenState extends State<WaterStatisticsScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  late MonthlyWaterStats _monthlyStats;
  late Map<String, dynamic> _weeklyStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    _monthlyStats = WaterService.getMonthlyStats(_selectedYear, _selectedMonth);
    _weeklyStats = WaterService.getWeeklyStats();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
      _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportData,
            tooltip: 'Export Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthSelector(),
            const SizedBox(height: 20),
            _buildOverviewCards(),
            const SizedBox(height: 24),
            _buildWeeklyChart(),
            const SizedBox(height: 24),
            _buildHourlyDistribution(),
            const SizedBox(height: 24),
            _buildBeverageBreakdown(),
            const SizedBox(height: 24),
            _buildStreakCard(),
            const SizedBox(height: 24),
            _buildInsights(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final ext = AppColorsExt.of(context);
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${monthNames[_selectedMonth - 1]} $_selectedYear',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedMonth == DateTime.now().month &&
                    _selectedYear == DateTime.now().year
                ? null
                : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final ext = AppColorsExt.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            icon: Icons.water_drop,
            iconColor: ext.mark(ext.water),
            value: '${(_monthlyStats.totalIntakeMl / 1000).toStringAsFixed(1)}L',
            label: 'Total Intake',
            trend: _monthlyStats.averageDailyMl > WaterService.getDailyGoal() ? '+' : '',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            icon: Icons.analytics,
            iconColor: ext.mark(ext.success),
            value: '${_monthlyStats.averageDailyMl}ml',
            label: 'Daily Average',
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? trend,
  }) {
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (trend != null && trend.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ext.mark(ext.success).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: ext.mark(ext.success),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: ext.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final ext = AppColorsExt.of(context);
    final dailyData = _weeklyStats['dailyData'] as List<DailyWaterData>? ?? [];
    final goal = WaterService.getDailyGoal();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ext.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ext.mark(ext.water).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${((_weeklyStats['completionRate'] as double) * 100).toInt()}% complete',
                  style: TextStyle(
                    color: ext.mark(ext.water),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final day = DateTime.now().subtract(Duration(days: 6 - index));
                final dayData = dailyData.where((d) =>
                    d.date.day == day.day &&
                    d.date.month == day.month).toList();

                final amount = dayData.isNotEmpty ? dayData.first.effectiveHydrationMl : 0;
                final progress = goal > 0 ? (amount / goal).clamp(0.0, 1.5) : 0.0;
                final isToday = index == 6;
                final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      amount > 0 ? '${(amount / 1000).toStringAsFixed(1)}L' : '-',
                      style: TextStyle(
                        fontSize: 10,
                        color: ext.textSecondary,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      // Clamp so an over-goal day (>120%) can't grow the bar past
                      // its box and overflow the column; color still flips to
                      // success at/above the goal.
                      height: 100 * progress.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: progress >= 1
                            ? ext.success.base
                            : isToday
                                ? ext.water.base
                                : ext.water.base.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayNames[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? ext.mark(ext.water) : ext.textSecondary,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ext.success.base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Goal met',
                style: TextStyle(fontSize: 10, color: ext.textSecondary),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ext.water.base,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'In progress',
                style: TextStyle(fontSize: 10, color: ext.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyDistribution() {
    final ext = AppColorsExt.of(context);
    final todayData = WaterService.getTodayData();
    final hourlyData = todayData.hourlyDistribution;
    final maxValue = hourlyData.values.isEmpty
        ? 1
        : hourlyData.values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Hourly Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 80,
            child: Row(
              children: List.generate(24, (hour) {
                final amount = hourlyData[hour] ?? 0;
                final height = maxValue > 0 ? (amount / maxValue) * 60 : 0.0;
                final isActive = hour >= 6 && hour <= 22;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: amount > 0
                              ? ext.water.base
                              : isActive
                                  ? ext.surfaceVariant
                                  : ext.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hour % 4 == 0)
                        Text(
                          '$hour',
                          style: TextStyle(
                            fontSize: 8,
                            color: ext.textSecondary,
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeverageBreakdown() {
    final ext = AppColorsExt.of(context);
    final breakdown = _monthlyStats.beverageBreakdown;
    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = breakdown.values.fold(0, (sum, v) => sum + v);
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beverage Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.take(5).map((entry) {
            final beverage = WaterService.getBeverage(entry.key);
            final percent = total > 0 ? (entry.value / total * 100) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    beverage?.emoji ?? '💧',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beverage?.name ?? entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: ext.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: ext.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation(ext.water.base),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ext.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final achievements = WaterService.getAchievements();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${achievements.currentStreak} Day Streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Best: ${achievements.longestStreak} days',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    final ext = AppColorsExt.of(context);
    final insights = WaterService.getInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: ext.mark(ext.warning)),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ext.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.take(3).map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ext.textPrimary,
                        ),
                      ),
                      Text(
                        insight.description,
                        style: TextStyle(
                          color: ext.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _exportData() {
    final ext = AppColorsExt.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Export Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ext.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ext.mark(ext.water).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.summarize, color: ext.mark(ext.water)),
              ),
              title: const Text('Summary CSV'),
              subtitle: const Text('Daily totals'),
              onTap: () {
                final csv = WaterService.exportToCsv();
                debugPrint(csv);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Summary exported (check console)')),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ext.mark(ext.success).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.list_alt, color: ext.mark(ext.success)),
              ),
              title: const Text('Detailed CSV'),
              subtitle: const Text('All drink logs'),
              onTap: () {
                final csv = WaterService.exportDetailedCsv();
                debugPrint(csv);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Detailed log exported (check console)')),
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}
