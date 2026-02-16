import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';

/// Dedicated screen for caffeine tracking and insights
class CaffeineInsightsScreen extends StatefulWidget {
  const CaffeineInsightsScreen({super.key});

  @override
  State<CaffeineInsightsScreen> createState() => _CaffeineInsightsScreenState();
}

class _CaffeineInsightsScreenState extends State<CaffeineInsightsScreen> {
  late DailyWaterData _todayData;
  late Map<String, dynamic> _weeklyStats;
  List<DailyWaterData> _weeklyData = [];
  
  // Recommended daily caffeine limits
  static const int _recommendedMax = 400; // mg
  static const int _warningThreshold = 300; // mg

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _todayData = WaterService.getTodayData();
    _weeklyStats = WaterService.getWeeklyStats();
    _weeklyData = _weeklyStats['dailyData'] as List<DailyWaterData>? ?? [];
  }

  Color get _caffeineColor {
    final mg = _todayData.totalCaffeineMg;
    if (mg >= _recommendedMax) return AppColors.error;
    if (mg >= _warningThreshold) return Colors.orange;
    return Colors.brown;
  }

  String get _caffeineStatus {
    final mg = _todayData.totalCaffeineMg;
    if (mg >= _recommendedMax) return 'High - Consider reducing';
    if (mg >= _warningThreshold) return 'Moderate - Approaching limit';
    if (mg > 0) return 'Within healthy range';
    return 'No caffeine today';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.brown.shade700,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Caffeine Tracker',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _loadData());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodaySummary(),
                    const SizedBox(height: 20),
                    _buildWeeklyChart(),
                    const SizedBox(height: 20),
                    _buildCaffeineSources(),
                    const SizedBox(height: 20),
                    _buildHealthInfo(),
                    const SizedBox(height: 20),
                    _buildTodayDrinks(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = (_todayData.totalCaffeineMg / _recommendedMax).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.brown.shade700, Colors.brown.shade600],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1 ? AppColors.error : Colors.white,
                  ),
                ),
              ),
              Column(
                children: [
                  const Text(
                    '☕',
                    style: TextStyle(fontSize: 36),
                  ),
                  Text(
                    '${_todayData.totalCaffeineMg}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'of ${_recommendedMax}mg',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _caffeineStatus,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary() {
    final caffeinedrinks = _todayData.logs.where((l) => l.caffeineAmount > 0).toList();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSummaryItem(
                icon: Icons.coffee,
                value: '${caffeinedrinks.length}',
                label: 'Drinks',
                color: Colors.brown,
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                icon: Icons.speed,
                value: '${_todayData.totalCaffeineMg}mg',
                label: 'Total',
                color: _caffeineColor,
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                icon: Icons.water_drop,
                value: '${_calculateHydrationImpact()}ml',
                label: 'Hydration Impact',
                color: AppColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _calculateHydrationImpact() {
    int impact = 0;
    for (final log in _todayData.logs) {
      if (log.caffeineAmount > 0) {
        // Caffeine drinks have reduced hydration
        impact += log.effectiveHydrationMl - log.amountMl;
      }
    }
    return impact;
  }

  Widget _buildWeeklyChart() {
    final maxCaffeine = _weeklyData.isEmpty
        ? _recommendedMax.toDouble()
        : math.max(
            _weeklyData.map((d) => d.totalCaffeineMg).reduce(math.max).toDouble(),
            _recommendedMax.toDouble(),
          );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Text(
                'This Week',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.brown.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_calculateWeeklyAverage()}mg avg',
                  style: TextStyle(
                    color: Colors.brown.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final day = DateTime.now().subtract(Duration(days: 6 - index));
                final dayData = _weeklyData.where((d) =>
                    d.date.day == day.day && d.date.month == day.month).toList();
                
                final caffeine = dayData.isNotEmpty ? dayData.first.totalCaffeineMg : 0;
                final height = maxCaffeine > 0 ? (caffeine / maxCaffeine) * 100 : 0.0;
                final isToday = index == 6;
                final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                Color barColor = Colors.brown.shade300;
                if (caffeine >= _recommendedMax) {
                  barColor = AppColors.error;
                } else if (caffeine >= _warningThreshold) {
                  barColor = Colors.orange;
                } else if (isToday) {
                  barColor = Colors.brown.shade600;
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      caffeine > 0 ? '${caffeine}mg' : '-',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: height.clamp(4, 100),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayNames[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday ? Colors.brown : AppColors.textSecondary,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.brown.shade300, 'Normal'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orange, 'Warning'),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.error, 'High'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  int _calculateWeeklyAverage() {
    if (_weeklyData.isEmpty) return 0;
    final total = _weeklyData.fold(0, (sum, d) => sum + d.totalCaffeineMg);
    return (total / _weeklyData.length).round();
  }

  Widget _buildCaffeineSources() {
    final caffeineBreakdown = <String, int>{};
    for (final log in _todayData.logs) {
      if (log.caffeineAmount > 0) {
        caffeineBreakdown[log.beverageId] = 
            (caffeineBreakdown[log.beverageId] ?? 0) + log.caffeineAmount;
      }
    }

    if (caffeineBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = caffeineBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Caffeine Sources Today',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.map((entry) {
            final beverage = WaterService.getBeverage(entry.key);
            final percent = _todayData.totalCaffeineMg > 0
                ? (entry.value / _todayData.totalCaffeineMg * 100)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    beverage?.emoji ?? '☕',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beverage?.name ?? entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation(Colors.brown),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${entry.value}mg',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade700,
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

  Widget _buildHealthInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade100, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Caffeine Tips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTip('💡', 'FDA recommends max 400mg caffeine daily for healthy adults'),
          _buildTip('⏰', 'Avoid caffeine 6 hours before bedtime for better sleep'),
          _buildTip('💧', 'Caffeine is a mild diuretic - drink extra water to compensate'),
          _buildTip('📉', 'Caffeine effects peak 30-60 minutes after consumption'),
        ],
      ),
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayDrinks() {
    final caffeineDrinks = _todayData.logs.where((l) => l.caffeineAmount > 0).toList();
    
    if (caffeineDrinks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Text('☕', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'No caffeinated drinks today',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Text(
                'Today\'s Caffeine Drinks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.brown.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${caffeineDrinks.length} drinks',
                  style: TextStyle(
                    color: Colors.brown.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...caffeineDrinks.reversed.map((log) => _buildDrinkItem(log)),
        ],
      ),
    );
  }

  Widget _buildDrinkItem(EnhancedWaterLog log) {
    final time = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.brown.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(log.beverageEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.beverageName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$time • ${log.amountMl}ml',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.brown.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${log.caffeineAmount}mg',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.brown.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
