import 'package:flutter/material.dart';
import '../../../core/design/app_colors_ext.dart';
import '../models/focus_session.dart';
import '../models/detailed_stats.dart';
import '../services/stats_service.dart';
import '../services/focus_service.dart';
import '../services/tag_service.dart';

class DetailedStatsScreen extends StatefulWidget {
  const DetailedStatsScreen({super.key});

  @override
  State<DetailedStatsScreen> createState() => _DetailedStatsScreenState();
}

class _DetailedStatsScreenState extends State<DetailedStatsScreen> {
  final StatsService _statsService = StatsService();
  final FocusService _focusService = FocusService();
  final TagService _tagService = TagService();
  StatsPeriod _selectedPeriod = StatsPeriod.weekly;

  @override
  void initState() {
    super.initState();
    _statsService.init();
    _tagService.init();
    // Derive daily aggregates + patterns straight from the persisted sessions
    // so the trend charts always reflect real data.
    _statsService.buildFromSessions(_focusService.sessions);
    _statsService.updateProductivityPattern(_focusService.sessions);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_statsService, _tagService]),
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildPeriodSelector()),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildOverviewCard(),
                      const SizedBox(height: 24),
                      _buildTimeChart(),
                      const SizedBox(height: 24),
                      _buildActivityBreakdown(),
                      const SizedBox(height: 24),
                      _buildTagStatistics(),
                      _buildProductivityPatterns(),
                      const SizedBox(height: 24),
                      _buildInsights(),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final ext = AppColorsExt.of(context);
    return SliverAppBar(
      pinned: true,
      backgroundColor: ext.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ext.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: ext.textPrimary),
        ),
      ),
      title: Text(
        'Detailed Statistics',
        style: TextStyle(fontWeight: FontWeight.bold, color: ext.textPrimary),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final ext = AppColorsExt.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: StatsPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: period != StatsPeriod.yearly ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriod = period),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? ext.fillBg(ext.focus) : ext.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? ext.fillBg(ext.focus) : ext.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      period.shortName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? ext.fillFg(ext.focus) : ext.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final totalMinutes = _statsService.getTotalMinutes(_selectedPeriod);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    int sessions;
    double completionRate;

    switch (_selectedPeriod) {
      case StatsPeriod.daily:
        final today = _statsService.getTodayStats();
        sessions = today.sessionsCount;
        completionRate = today.completionRate;
        break;
      case StatsPeriod.weekly:
        final week = _statsService.getWeekStats();
        sessions = week.totalSessions;
        completionRate = week.completionRate;
        break;
      case StatsPeriod.monthly:
        final month = _statsService.getMonthStats();
        sessions = month.totalSessions;
        completionRate = month.completionRate;
        break;
      case StatsPeriod.yearly:
        final year = _statsService.getYearStats();
        sessions = year.totalSessions;
        completionRate = year.completionRate;
        break;
    }

    final ext = AppColorsExt.of(context);
    final focusHero = ext.isDark ? ext.focus.container : ext.focus.base;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [focusHero, focusHero.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: ext.focus.base.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewStat(
                '${hours}h ${mins}m',
                'Focus Time',
                Icons.timer_rounded,
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildOverviewStat(
                '$sessions',
                'Sessions',
                Icons.flag_rounded,
              ),
              Container(width: 1, height: 50, color: Colors.white24),
              _buildOverviewStat(
                '${(completionRate * 100).toInt()}%',
                'Completed',
                Icons.check_circle_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeChart() {
    List<_ChartData> data;
    
    switch (_selectedPeriod) {
      case StatsPeriod.daily:
        final pattern = _statsService.productivityPattern;
        if (pattern == null) {
          data = [];
        } else {
          data = List.generate(24, (hour) {
            return _ChartData(
              label: hour % 6 == 0 ? '${hour}h' : '',
              value: (pattern.minutesByHour[hour] ?? 0).toDouble(),
            );
          });
        }
        break;
      case StatsPeriod.weekly:
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekStats = _statsService.getLast7Days();
        data = List.generate(7, (i) {
          final dayData = weekStats.where((s) => s.date.weekday == i + 1).toList();
          final total = dayData.fold(0, (sum, d) => sum + d.totalMinutes);
          return _ChartData(label: days[i], value: total.toDouble());
        });
        break;
      case StatsPeriod.monthly:
        final weeks = _statsService.getLast4Weeks();
        data = weeks.reversed.map((w) {
          return _ChartData(
            label: 'W${w.weekStart.day}',
            value: w.totalMinutes.toDouble(),
          );
        }).toList();
        break;
      case StatsPeriod.yearly:
        final months = _statsService.getLast12Months();
        data = months.reversed.map((m) {
          return _ChartData(
            label: m.monthName,
            value: m.totalMinutes.toDouble(),
          );
        }).toList();
        break;
    }

    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus Time Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: data.any((d) => d.value > 0)
                ? _buildBarChart(data)
                : _buildChartEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartEmptyState() {
    final ext = AppColorsExt.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 36,
            color: ext.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            'No focus sessions yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ext.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete a session to see your trend',
            style: TextStyle(
              fontSize: 12,
              color: ext.textSecondary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagStatistics() {
    final stats = _tagService.calculateTagStatistics(_focusService.sessions);

    if (stats.isEmpty) {
      return const SizedBox();
    }

    final maxMins = stats.first.totalMinutes;
    final ext = AppColorsExt.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ext.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tag Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ext.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ...stats.take(6).map((stat) {
                final percentage = maxMins > 0 ? stat.totalMinutes / maxMins : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: stat.tagColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                _tagService.getTagById(stat.tagId)?.emoji ?? '🏷️',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              stat.tagName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ext.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${stat.totalHours}h ${stat.totalMinutes % 60}m · ${stat.sessionCount}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: stat.tagColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: ext.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(stat.tagColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBarChart(List<_ChartData> data) {
    final ext = AppColorsExt.of(context);
    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((d) {
        final height = maxValue > 0 ? (d.value / maxValue) * 120 : 0.0;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: height.clamp(4.0, 120.0),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: ext.focus.base.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                d.label,
                style: TextStyle(
                  fontSize: 10,
                  color: ext.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityBreakdown() {
    final breakdown = _statsService.getActivityBreakdown(_selectedPeriod);
    
    if (breakdown.isEmpty) {
      return const SizedBox();
    }

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final total = breakdown.values.fold(0, (a, b) => a + b);
    final ext = AppColorsExt.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ...sortedEntries.map((entry) {
            final percentage = total > 0 ? entry.value / total : 0.0;
            final colors = [
              ext.focus.base,
              ext.info.base,
              ext.success.base,
              ext.warning.base,
              ext.error.base,
            ];
            final color = colors[entry.key.index % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(entry.key.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ext.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} min',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: ext.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
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

  Widget _buildProductivityPatterns() {
    final pattern = _statsService.productivityPattern;
    
    if (pattern == null) {
      return const SizedBox();
    }

    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productivity Patterns',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPatternCard(
                  '⏰',
                  'Peak Hour',
                  pattern.mostProductiveHourLabel,
                  ext.success.base,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPatternCard(
                  '📅',
                  'Best Day',
                  pattern.mostProductiveDayLabel,
                  ext.info.base,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hourly Distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: _buildHourlyHeatmap(pattern),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternCard(String emoji, String label, String value, Color color) {
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ext.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyHeatmap(ProductivityPattern pattern) {
    final ext = AppColorsExt.of(context);
    final maxValue = pattern.minutesByHour.values.isEmpty
        ? 1
        : pattern.minutesByHour.values.reduce((a, b) => a > b ? a : b);

    return Row(
      children: List.generate(24, (hour) {
        final value = pattern.minutesByHour[hour] ?? 0;
        final intensity = maxValue > 0 ? value / maxValue : 0;

        return Expanded(
          child: Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: ext.focus.base.withOpacity(intensity.clamp(0.1, 1.0).toDouble()),
              borderRadius: BorderRadius.circular(4),
            ),
            child: hour % 6 == 0
                ? Center(
                    child: Text(
                      '$hour',
                      style: TextStyle(
                        fontSize: 8,
                        color: intensity > 0.5 ? ext.focus.on : ext.textSecondary,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildInsights() {
    final insights = _statsService.getInsights();
    
    if (insights.isEmpty) {
      return const SizedBox();
    }

    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ext.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: insight.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: insight.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Text(insight.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: insight.color,
                        ),
                      ),
                      Text(
                        insight.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: ext.textSecondary,
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
}

class _ChartData {
  final String label;
  final double value;

  _ChartData({required this.label, required this.value});
}
