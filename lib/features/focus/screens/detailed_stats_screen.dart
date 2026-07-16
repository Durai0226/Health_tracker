import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/haptic_service.dart';
import '../models/detailed_stats.dart';
import '../models/focus_session.dart';
import '../services/stats_service.dart';
import '../services/focus_service.dart';
import '../services/tag_service.dart';
import 'focus_garden_screen.dart';

/// Consolidated focus statistics hub (FOCUS-4).
///
/// Single stats surface for the Focus feature: a Day / Week / Month / Year
/// [SegmentedToggle] drives accurate charts computed from
/// [FocusService.sessions] (via [StatsService.buildFromSessions]), plus a
/// streak card, tag breakdown, activity breakdown, productivity patterns,
/// insights and a link into the Garden.
class DetailedStatsScreen extends StatefulWidget {
  const DetailedStatsScreen({super.key});

  @override
  State<DetailedStatsScreen> createState() => _DetailedStatsScreenState();
}

class _DetailedStatsScreenState extends State<DetailedStatsScreen> {
  final StatsService _statsService = StatsService();
  final FocusService _focusService = FocusService();
  final TagService _tagService = TagService();
  final HapticService _hapticService = HapticService();
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

    return AccentScope(
      feature: FeatureAccent.focus,
      child: AppScaffold(
        body: Column(
          children: [
            _buildHeader(ext),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge(
                    [_statsService, _tagService, _focusService]),
                builder: (context, _) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.xs,
                      AppSpacing.gutter,
                      120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedToggle(
                          accent: ext.focus,
                          index: StatsPeriod.values.indexOf(_selectedPeriod),
                          onChanged: (i) => setState(
                              () => _selectedPeriod = StatsPeriod.values[i]),
                          items: const [
                            SegmentItem(
                                icon: Icons.today_rounded, label: 'Day'),
                            SegmentItem(
                                icon: Icons.view_week_rounded, label: 'Week'),
                            SegmentItem(
                                icon: Icons.calendar_month_rounded,
                                label: 'Month'),
                            SegmentItem(
                                icon: Icons.calendar_today_rounded,
                                label: 'Year'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildOverviewCard(ext),
                        const SizedBox(height: AppSpacing.lg),
                        _buildStreakCard(ext),
                        const SizedBox(height: AppSpacing.lg),
                        _buildTimeChart(ext),
                        const SizedBox(height: AppSpacing.lg),
                        _buildActivityBreakdown(ext),
                        _buildTagStatistics(ext),
                        _buildProductivityPatterns(ext),
                        _buildInsights(ext),
                        _buildGardenLink(ext),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorsExt ext) {
    return AppHeader(
      title: 'Statistics',
      greeting: 'Your focus insights',
      icon: Icons.insights_rounded,
      accent: ext.focus,
      leading: AppIconButton(
        icon: Icons.arrow_back_rounded,
        accent: ext.focus,
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        AppIconButton(
          icon: Icons.park_rounded,
          accent: ext.focus,
          onPressed: () {
            _hapticService.navigation();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusGardenScreen()),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Overview (period-aware)
  // ---------------------------------------------------------------------------

  Widget _buildOverviewCard(AppColorsExt ext) {
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

    final focusHero = ext.isDark ? ext.focus.container : ext.focus.base;
    final heroFg = ext.isDark ? ext.focus.onContainer : ext.focus.on;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [focusHero, focusHero.withOpacity(0.85)],
        ),
        borderRadius: AppRadius.brCard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildOverviewStat(
              '${hours}h ${mins}m', 'Focus Time', Icons.timer_rounded, heroFg),
          Container(width: 1, height: 50, color: heroFg.withOpacity(0.24)),
          _buildOverviewStat(
              '$sessions', 'Sessions', Icons.flag_rounded, heroFg),
          Container(width: 1, height: 50, color: heroFg.withOpacity(0.24)),
          _buildOverviewStat('${(completionRate * 100).toInt()}%', 'Completed',
              Icons.check_circle_rounded, heroFg),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(
      String value, String label, IconData icon, Color fg) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: fg.withOpacity(0.85), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: tt.headlineSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: fg.withOpacity(0.85)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Streak
  // ---------------------------------------------------------------------------

  Widget _buildStreakCard(AppColorsExt ext) {
    final stats = _focusService.stats;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ext.warning.container,
              borderRadius: AppRadius.brMd,
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${stats.currentStreak} Day Streak',
                    style: tt.titleLarge),
                const SizedBox(height: 2),
                Text(
                  'Longest: ${stats.longestStreak} days',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Time trend chart
  // ---------------------------------------------------------------------------

  Widget _buildTimeChart(AppColorsExt ext) {
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
          final dayData =
              weekStats.where((s) => s.date.weekday == i + 1).toList();
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Focus Time Trend', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          if (data.any((d) => d.value > 0))
            SizedBox(height: 150, child: _buildBarChart(ext, data))
          else
            _buildChartEmptyState(ext),
        ],
      ),
    );
  }

  Widget _buildChartEmptyState(AppColorsExt ext) {
    return EmptyState(
      icon: Icons.bar_chart_rounded,
      title: 'No focus sessions yet',
      message: 'Complete a session to see your trend',
      accent: ext.focus,
    );
  }

  Widget _buildBarChart(AppColorsExt ext, List<_ChartData> data) {
    final tt = Theme.of(context).textTheme;
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
                  borderRadius: AppRadius.brSm,
                ),
              ),
              const SizedBox(height: 8),
              Text(d.label,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Activity breakdown
  // ---------------------------------------------------------------------------

  Widget _buildActivityBreakdown(AppColorsExt ext) {
    final breakdown = _statsService.getActivityBreakdown(_selectedPeriod);

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = breakdown.values.fold(0, (a, b) => a + b);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Breakdown', style: tt.titleLarge),
            const SizedBox(height: AppSpacing.lg),
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
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(entry.key.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key.name,
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${entry.value} min',
                          style: tt.bodyMedium?.copyWith(
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tag breakdown
  // ---------------------------------------------------------------------------

  Widget _buildTagStatistics(AppColorsExt ext) {
    final stats = _tagService.calculateTagStatistics(_focusService.sessions);

    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxMins = stats.first.totalMinutes;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tag Breakdown', style: tt.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            ...stats.take(6).map((stat) {
              final percentage =
                  maxMins > 0 ? stat.totalMinutes / maxMins : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: stat.tagColor.withOpacity(0.12),
                            borderRadius: AppRadius.brSm,
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
                            style: tt.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${stat.totalHours}h ${stat.totalMinutes % 60}m · ${stat.sessionCount}x',
                          style: tt.bodySmall?.copyWith(
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
    );
  }

  // ---------------------------------------------------------------------------
  // Productivity patterns
  // ---------------------------------------------------------------------------

  Widget _buildProductivityPatterns(AppColorsExt ext) {
    final pattern = _statsService.productivityPattern;

    if (pattern == null) {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productivity Patterns', style: tt.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildPatternCard(
                    '⏰',
                    'Peak Hour',
                    pattern.mostProductiveHourLabel,
                    ext.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildPatternCard(
                    '📅',
                    'Best Day',
                    pattern.mostProductiveDayLabel,
                    ext.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Hourly Distribution',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: _buildHourlyHeatmap(ext, pattern),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternCard(
      String emoji, String label, String value, AccentSwatch accent) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.container,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(label, style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          Text(
            value,
            style: tt.titleLarge?.copyWith(color: accent.onContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyHeatmap(AppColorsExt ext, ProductivityPattern pattern) {
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
              color: value > 0
                  ? ext.focus.base.withOpacity(intensity.clamp(0.15, 1.0).toDouble())
                  : ext.surfaceVariant,
              borderRadius: AppRadius.brSm,
            ),
            child: hour % 6 == 0
                ? Center(
                    child: Text(
                      '$hour',
                      style: TextStyle(
                        fontSize: 8,
                        color: intensity > 0.5
                            ? ext.focus.on
                            : ext.textSecondary,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Insights
  // ---------------------------------------------------------------------------

  Widget _buildInsights(AppColorsExt ext) {
    final insights = _statsService.getInsights();

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Insights', style: tt.titleLarge),
            const SizedBox(height: AppSpacing.md),
            ...insights.map((insight) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: insight.color.withOpacity(0.1),
                    borderRadius: AppRadius.brMd,
                    border: Border.all(color: insight.color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(insight.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight.title,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: insight.color,
                              ),
                            ),
                            Text(
                              insight.description,
                              style: tt.bodySmall
                                  ?.copyWith(color: ext.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Garden link
  // ---------------------------------------------------------------------------

  Widget _buildGardenLink(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: () {
        _hapticService.navigation();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FocusGardenScreen()),
        );
      },
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ext.focus.container,
              borderRadius: AppRadius.brMd,
            ),
            child: const Center(child: Text('🌳', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Garden', style: tt.titleLarge),
                const SizedBox(height: 3),
                Text(
                  'See every plant you have grown',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: ext.mark(ext.focus), size: 22),
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
