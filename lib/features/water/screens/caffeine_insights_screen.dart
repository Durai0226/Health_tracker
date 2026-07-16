import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/design/app_colors_ext.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';

/// Dedicated screen for caffeine tracking and insights
class CaffeineInsightsScreen extends StatefulWidget {
  const CaffeineInsightsScreen({super.key});

  @override
  State<CaffeineInsightsScreen> createState() => _CaffeineInsightsScreenState();
}

class _CaffeineInsightsScreenState extends State<CaffeineInsightsScreen> {
  DailyWaterData? _todayData;
  Map<String, dynamic> _weeklyStats = {};
  List<DailyWaterData> _weeklyData = [];
  bool _isLoading = true;
  
  // Recommended daily caffeine limits
  static const int _recommendedMax = 400; // mg
  static const int _warningThreshold = 300; // mg

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await WaterService.init();
      if (mounted) {
        setState(() {
          _todayData = WaterService.getTodayData();
          _weeklyStats = WaterService.getWeeklyStats();
          _weeklyData = _weeklyStats['dailyData'] as List<DailyWaterData>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading caffeine data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color get _caffeineColor {
    final ext = AppColorsExt.of(context);
    final mg = _todayData?.totalCaffeineMg ?? 0;
    if (mg >= _recommendedMax) return ext.error.base;
    if (mg >= _warningThreshold) return Colors.orange;
    return ext.isDark ? Colors.brown.shade300 : Colors.brown;
  }

  /// Caffeine's brown identity kept readable as a mark on app surfaces in dark.
  Color get _brownMark =>
      AppColorsExt.of(context).isDark ? Colors.brown.shade200 : Colors.brown.shade700;

  /// Subtle brown tint for chips/badges that stays legible in dark mode.
  Color _brownTint(AppColorsExt ext) =>
      Colors.brown.withOpacity(ext.isDark ? 0.22 : 0.1);

  String get _caffeineStatus {
    final mg = _todayData?.totalCaffeineMg ?? 0;
    if (mg >= _recommendedMax) return 'High - Consider reducing';
    if (mg >= _warningThreshold) return 'Moderate - Approaching limit';
    if (mg > 0) return 'Within healthy range';
    return 'No caffeine today';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
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

      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.brown))
        : _todayData == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: ext.error.base),
                const SizedBox(height: 16),
                const Text('Failed to load caffeine data'),
                const SizedBox(height: 16),
                CommonButton(
                  text: 'Retry',
                  variant: ButtonVariant.primary,
                  backgroundColor: Colors.brown,
                  onPressed: _loadData,
                ),
              ],
            ),
          )
        : RefreshIndicator(
        onRefresh: () async {
          await _loadData();
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
    if (_todayData == null) {
      return const SizedBox.shrink();
    }
    final ext = AppColorsExt.of(context);
    final todayData = _todayData!;
    final progress = (todayData.totalCaffeineMg / _recommendedMax).clamp(0.0, 1.0);
    
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
                    progress >= 1 ? ext.error.base : Colors.white,
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
                    '${todayData.totalCaffeineMg}',
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
    if (_todayData == null) {
      return const SizedBox.shrink();
    }
    final ext = AppColorsExt.of(context);
    final todayData = _todayData!;
    final caffeinedrinks = todayData.logs.where((l) => l.caffeineAmount > 0).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(20),
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
            'Today\'s Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ext.textPrimary),
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
                value: '${todayData.totalCaffeineMg}mg',
                label: 'Total',
                color: _caffeineColor,
              ),
              const SizedBox(width: 16),
              _buildSummaryItem(
                icon: Icons.water_drop,
                value: '${_calculateHydrationImpact()}ml',
                label: 'Hydration Impact',
                color: ext.mark(ext.water),
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
    final ext = AppColorsExt.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(ext.isDark ? 0.18 : 0.1),
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
              style: TextStyle(
                fontSize: 10,
                color: ext.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _calculateHydrationImpact() {
    if (_todayData == null) return 0;
    
    int impact = 0;
    final logs = _todayData!.logs;
    for (final log in logs) {
      if (log.caffeineAmount > 0) {
        impact += log.effectiveHydrationMl - log.amountMl;
      }
    }
    return impact;
  }

  Widget _buildWeeklyChart() {
    final ext = AppColorsExt.of(context);
    if (_weeklyData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'No weekly data available',
            style: TextStyle(color: ext.textSecondary),
          ),
        ),
      );
    }
    
    final maxCaffeine = math.max(
      _weeklyData.map((d) => d.totalCaffeineMg).reduce(math.max).toDouble(),
      _recommendedMax.toDouble(),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(20),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ext.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _brownTint(ext),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_calculateWeeklyAverage()}mg avg',
                  style: TextStyle(
                    color: _brownMark,
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
                    d.date.day == day.day && 
                    d.date.month == day.month && 
                    d.date.year == day.year).toList();
                
                final caffeine = dayData.isNotEmpty ? dayData.first.totalCaffeineMg : 0;
                final height = maxCaffeine > 0 ? (caffeine / maxCaffeine) * 100 : 0.0;
                final isToday = index == 6;
                final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                Color barColor = Colors.brown.shade300;
                if (caffeine >= _recommendedMax) {
                  barColor = ext.error.base;
                } else if (caffeine >= _warningThreshold) {
                  barColor = Colors.orange;
                } else if (isToday) {
                  barColor = ext.isDark ? Colors.brown.shade400 : Colors.brown.shade600;
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      caffeine > 0 ? '${caffeine}mg' : '-',
                      style: TextStyle(
                        fontSize: 9,
                        color: ext.textSecondary,
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
                        color: isToday ? _brownMark : ext.textSecondary,
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
              _buildLegendItem(ext.error.base, 'High'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    final ext = AppColorsExt.of(context);
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
          style: TextStyle(fontSize: 10, color: ext.textSecondary),
        ),
      ],
    );
  }

  int _calculateWeeklyAverage() {
    if (_weeklyData.isEmpty) return 0;
    try {
      final total = _weeklyData.fold(0, (sum, d) => sum + d.totalCaffeineMg);
      return (total / _weeklyData.length).round();
    } catch (e) {
      debugPrint('Error calculating weekly average: $e');
      return 0;
    }
  }

  Widget _buildCaffeineSources() {
    if (_todayData == null) {
      return const SizedBox.shrink();
    }
    
    final caffeineBreakdown = <String, int>{};
    final logs = _todayData!.logs;
    for (final log in logs) {
      if (log.caffeineAmount > 0) {
        caffeineBreakdown[log.beverageId] = 
            (caffeineBreakdown[log.beverageId] ?? 0) + log.caffeineAmount;
      }
    }

    if (caffeineBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final ext = AppColorsExt.of(context);
    final sortedEntries = caffeineBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(20),
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
            'Caffeine Sources Today',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ext.textPrimary),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.map((entry) {
            final beverage = WaterService.getBeverage(entry.key);
            final totalCaffeine = _todayData?.totalCaffeineMg ?? 0;
            final percent = totalCaffeine > 0
                ? (entry.value / totalCaffeine * 100)
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
                          style: TextStyle(fontWeight: FontWeight.w500, color: ext.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: ext.surfaceVariant,
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
                      color: _brownMark,
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
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ext.isDark
              ? [ext.surfaceVariant, ext.surfaceVariant]
              : [Colors.amber.shade100, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: ext.isDark ? ext.mark(ext.warning) : Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'Caffeine Tips',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ext.isDark ? ext.textPrimary : Colors.brown.shade900),
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
    final ext = AppColorsExt.of(context);
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
              style: TextStyle(
                fontSize: 13,
                color: ext.isDark ? ext.textSecondary : Colors.brown.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayDrinks() {
    if (_todayData == null) {
      return const SizedBox.shrink();
    }
    
    final allLogs = _todayData!.logs;
    final caffeineDrinks = allLogs.where((l) => l.caffeineAmount > 0).toList();
    
    final ext = AppColorsExt.of(context);
    if (caffeineDrinks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Text('☕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No caffeinated drinks today',
              style: TextStyle(
                color: ext.textSecondary,
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
        color: ext.surface,
        borderRadius: BorderRadius.circular(20),
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
                'Today\'s Caffeine Drinks',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ext.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _brownTint(ext),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${caffeineDrinks.length} drinks',
                  style: TextStyle(
                    color: _brownMark,
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
    final ext = AppColorsExt.of(context);
    final time = '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _brownTint(ext),
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
                  style: TextStyle(fontWeight: FontWeight.w600, color: ext.textPrimary),
                ),
                Text(
                  '$time • ${log.amountMl}ml',
                  style: TextStyle(fontSize: 12, color: ext.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _brownTint(ext),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${log.caffeineAmount}mg',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _brownMark,
              ),
            ),
          ),

        ],
      ),
    );
  }
}
