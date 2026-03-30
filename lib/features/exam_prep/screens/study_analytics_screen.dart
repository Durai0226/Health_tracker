import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/exam_prep_service.dart';
import '../models/study_analytics_model.dart';
import '../../../core/constants/app_colors.dart';

class StudyAnalyticsScreen extends StatefulWidget {
  const StudyAnalyticsScreen({super.key});

  @override
  State<StudyAnalyticsScreen> createState() => _StudyAnalyticsScreenState();
}

class _StudyAnalyticsScreenState extends State<StudyAnalyticsScreen>
    with TickerProviderStateMixin {
  final ExamPrepService _examPrepService = ExamPrepService();
  int _selectedPeriod = 7;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _examPrepService.addListener(_onServiceUpdate);
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _examPrepService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = _examPrepService.analytics;
    final todayStats = _examPrepService.getTodayStats();
    final weekStats = _examPrepService.getThisWeekStats();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: analytics == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.info),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading analytics...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Premium Header
                    SliverToBoxAdapter(
                      child: _buildPremiumHeader(theme),
                    ),
                    // Period Selector
                    SliverToBoxAdapter(
                      child: _buildPeriodSelector(theme),
                    ),
                    // Overview Cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: _buildOverviewCards(theme, analytics),
                      ),
                    ),
                    // Weekly Chart
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: _buildSectionTitle(theme, 'Weekly Progress', Icons.trending_up_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildPremiumWeeklyChart(theme, weekStats),
                      ),
                    ),
                    // Subject Distribution
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: _buildSectionTitle(theme, 'Time by Subject', Icons.pie_chart_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildSubjectDistribution(theme, analytics),
                      ),
                    ),
                    // Productivity Insights
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: _buildSectionTitle(theme, 'Productivity', Icons.insights_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildProductivityInsights(theme, analytics),
                      ),
                    ),
                    // Streaks & Goals
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: _buildSectionTitle(theme, 'Streaks & Goals', Icons.local_fire_department_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildStreaksAndGoals(theme, analytics, todayStats),
                      ),
                    ),
                    // Exam Performance
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: _buildSectionTitle(theme, 'Exam Performance', Icons.school_rounded),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        child: _buildExamPerformance(theme, analytics),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.getTextPrimary(context),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Progress',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.info, Color(0xFF0EA5E9)],
                  ).createShader(bounds),
                  child: Text(
                    'Study Analytics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final periods = [
      {'value': 7, 'label': '7 Days'},
      {'value': 30, 'label': '30 Days'},
      {'value': 90, 'label': '90 Days'},
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period['value'];
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedPeriod = period['value'] as int);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.info.withOpacity(0.15),
                            AppColors.info.withOpacity(0.08),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: AppColors.info.withOpacity(0.2))
                      : null,
                ),
                child: Center(
                  child: Text(
                    period['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.info
                          : AppColors.getTextSecondary(context),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
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

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.info, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCards(ThemeData theme, StudyAnalytics analytics) {
    final isDark = theme.brightness == Brightness.dark;
    final cards = [
      {
        'icon': Icons.timer_rounded,
        'value': '${analytics.totalLifetimeMinutes ~/ 60}h ${analytics.totalLifetimeMinutes % 60}m',
        'label': 'Total Study',
        'color': AppColors.primary,
      },
      {
        'icon': Icons.play_circle_rounded,
        'value': '${analytics.totalLifetimeSessions}',
        'label': 'Sessions',
        'color': AppColors.info,
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'value': '${analytics.currentStreak}',
        'label': 'Day Streak',
        'color': AppColors.warning,
      },
      {
        'icon': Icons.speed_rounded,
        'value': '${analytics.totalLifetimeSessions > 0 ? (analytics.totalLifetimeMinutes / analytics.totalLifetimeSessions).round() : 0}m',
        'label': 'Avg Session',
        'color': AppColors.success,
      },
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final color = card['color'] as Color;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      color.withOpacity(0.15),
                      color.withOpacity(0.08),
                    ]
                  : [
                      Colors.white,
                      color.withOpacity(0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(card['icon'] as IconData, color: Colors.white, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card['value'] as String,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    card['label'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumWeeklyChart(ThemeData theme, WeeklyStudyStats weekStats) {
    final isDark = theme.brightness == Brightness.dark;
    final dailyMinutes = List.generate(7, (index) {
      return index < weekStats.dailyStats.length ? weekStats.dailyStats[index].totalMinutes : 0;
    });
    final maxMinutes = dailyMinutes.reduce((a, b) => a > b ? a : b);
    final normalizedMax = maxMinutes == 0 ? 60 : maxMinutes.toDouble();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.03)]
                  : [Colors.white, AppColors.info.withOpacity(0.03)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${weekStats.totalMinutes ~/ 60}h ${weekStats.totalMinutes % 60}m',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${weekStats.totalSessions} sessions',
                      style: TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 150,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: normalizedMax * 1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${dailyMinutes[group.x.toInt()]} min',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                            return Text(
                              days[value.toInt()],
                              style: TextStyle(
                                color: AppColors.getTextSecondary(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(7, (index) {
                      final value = dailyMinutes[index].toDouble();
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: value,
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.info.withOpacity(0.6),
                                AppColors.info,
                              ],
                            ),
                            width: 24,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Keep original method names for compatibility
  Widget _buildWeeklyChart(ThemeData theme, WeeklyStudyStats weekStats) {
    return _buildPremiumWeeklyChart(theme, weekStats);
  }

  Widget _buildOverviewCardsOld(ThemeData theme, StudyAnalytics analytics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          theme,
          icon: Icons.timer,
          value: '${analytics.totalLifetimeHours.toStringAsFixed(1)}h',
          label: 'Total Study Time',
          color: Colors.blue,
        ),
        _buildStatCard(
          theme,
          icon: Icons.event_available,
          value: '${analytics.totalLifetimeSessions}',
          label: 'Total Sessions',
          color: Colors.green,
        ),
        _buildStatCard(
          theme,
          icon: Icons.local_fire_department,
          value: '${analytics.currentStreak}',
          label: 'Current Streak',
          color: Colors.orange,
        ),
        _buildStatCard(
          theme,
          icon: Icons.emoji_events,
          value: '${analytics.longestStreak}',
          label: 'Best Streak',
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }


  Widget _buildSubjectDistribution(ThemeData theme, StudyAnalytics analytics) {
    final subjects = _examPrepService.subjects;
    final minutesBySubject = analytics.minutesBySubject;

    if (minutesBySubject.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                const Text('No study data yet'),
              ],
            ),
          ),
        ),
      );
    }

    final totalMinutes = minutesBySubject.values.fold(0, (a, b) => a + b);
    final sortedEntries = minutesBySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sortedEntries.take(5).map((entry) {
            final subject = subjects.where((s) => s.id == entry.key).firstOrNull;
            final percentage = (entry.value / totalMinutes * 100);
            final color = subject != null
                ? Color(int.parse(subject.colorHex.replaceAll('#', '0xFF')))
                : Colors.grey;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
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
                  Expanded(
                    flex: 2,
                    child: Text(
                      subject?.name ?? 'Unknown',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${(entry.value / 60).toStringAsFixed(1)}h',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductivityInsights(ThemeData theme, StudyAnalytics analytics) {
    final productiveHour = analytics.mostProductiveHour;
    final productiveDay = analytics.productiveDayName;

    String timeOfDay;
    if (productiveHour < 6) {
      timeOfDay = 'Early Morning';
    } else if (productiveHour < 12) {
      timeOfDay = 'Morning';
    } else if (productiveHour < 17) {
      timeOfDay = 'Afternoon';
    } else if (productiveHour < 21) {
      timeOfDay = 'Evening';
    } else {
      timeOfDay = 'Night';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInsightRow(
              icon: Icons.access_time,
              label: 'Most Productive Time',
              value: '$timeOfDay (${productiveHour.toString().padLeft(2, '0')}:00)',
              color: Colors.blue,
            ),
            const Divider(),
            _buildInsightRow(
              icon: Icons.calendar_today,
              label: 'Most Productive Day',
              value: productiveDay,
              color: Colors.green,
            ),
            const Divider(),
            _buildInsightRow(
              icon: Icons.topic,
              label: 'Topics Completed',
              value: '${analytics.totalTopicsCompleted}',
              color: Colors.orange,
            ),
            const Divider(),
            _buildInsightRow(
              icon: Icons.star,
              label: 'Topics Mastered',
              value: '${analytics.totalTopicsMastered}',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreaksAndGoals(
      ThemeData theme, StudyAnalytics analytics, DailyStudyStats todayStats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Daily Goal Progress
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Goal',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: todayStats.goalProgress,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${todayStats.totalMinutes}/${todayStats.goalMinutes} min',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Streak Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStreakColumn(
                  '🔥',
                  '${analytics.currentStreak}',
                  'Current',
                ),
                _buildStreakColumn(
                  '🏆',
                  '${analytics.longestStreak}',
                  'Best',
                ),
                _buildStreakColumn(
                  '📅',
                  '${analytics.weeklyGoalDays}',
                  'Goal Days',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakColumn(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildExamPerformance(ThemeData theme, StudyAnalytics analytics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildExamStatColumn(
                  theme,
                  '${analytics.totalExamsCompleted}',
                  'Exams Taken',
                  Colors.blue,
                ),
                _buildExamStatColumn(
                  theme,
                  '${analytics.totalExamsPassed}',
                  'Passed',
                  Colors.green,
                ),
                _buildExamStatColumn(
                  theme,
                  '${(analytics.examPassRate * 100).toStringAsFixed(0)}%',
                  'Pass Rate',
                  Colors.orange,
                ),
              ],
            ),
            if (analytics.averageGrade > 0) ...[
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Average Grade: '),
                  Text(
                    '${analytics.averageGrade.toStringAsFixed(1)}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getGradeColor(analytics.averageGrade),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamStatColumn(
    ThemeData theme,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return Colors.green;
    if (grade >= 80) return Colors.lightGreen;
    if (grade >= 70) return Colors.amber;
    if (grade >= 60) return Colors.orange;
    return Colors.red;
  }
}
