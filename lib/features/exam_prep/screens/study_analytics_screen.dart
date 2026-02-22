import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/exam_prep_service.dart';
import '../models/study_analytics_model.dart';

class StudyAnalyticsScreen extends StatefulWidget {
  const StudyAnalyticsScreen({super.key});

  @override
  State<StudyAnalyticsScreen> createState() => _StudyAnalyticsScreenState();
}

class _StudyAnalyticsScreenState extends State<StudyAnalyticsScreen> {
  final ExamPrepService _examPrepService = ExamPrepService();
  int _selectedPeriod = 7; // Days

  @override
  void initState() {
    super.initState();
    _examPrepService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _examPrepService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = _examPrepService.analytics;
    final todayStats = _examPrepService.getTodayStats();
    final weekStats = _examPrepService.getThisWeekStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Analytics'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _selectedPeriod,
            onSelected: (value) => setState(() => _selectedPeriod = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: analytics == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overview Cards
                  _buildOverviewCards(theme, analytics),
                  const SizedBox(height: 24),

                  // Weekly Chart
                  _buildSectionTitle(theme, 'Study Time This Week'),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(theme, weekStats),
                  const SizedBox(height: 24),

                  // Subject Distribution
                  _buildSectionTitle(theme, 'Time by Subject'),
                  const SizedBox(height: 12),
                  _buildSubjectDistribution(theme, analytics),
                  const SizedBox(height: 24),

                  // Productivity Insights
                  _buildSectionTitle(theme, 'Productivity Insights'),
                  const SizedBox(height: 12),
                  _buildProductivityInsights(theme, analytics),
                  const SizedBox(height: 24),

                  // Achievements
                  _buildSectionTitle(theme, 'Study Streaks & Goals'),
                  const SizedBox(height: 12),
                  _buildStreaksAndGoals(theme, analytics, todayStats),
                  const SizedBox(height: 24),

                  // Exam Performance
                  _buildSectionTitle(theme, 'Exam Performance'),
                  const SizedBox(height: 12),
                  _buildExamPerformance(theme, analytics),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildOverviewCards(ThemeData theme, StudyAnalytics analytics) {
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

  Widget _buildWeeklyChart(ThemeData theme, WeeklyStudyStats weekStats) {
    final dailyData = <FlSpot>[];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dayStats = weekStats.dailyStats.where((s) {
        final statDate = DateTime(s.date.year, s.date.month, s.date.day);
        final targetDate = DateTime(date.year, date.month, date.day);
        return statDate == targetDate;
      });
      
      final minutes = dayStats.isNotEmpty
          ? dayStats.first.totalMinutes.toDouble()
          : 0.0;
      dailyData.add(FlSpot(i.toDouble(), minutes / 60)); // Convert to hours
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: dailyData.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toStringAsFixed(1)}h',
                  const TextStyle(color: Colors.white),
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
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}h',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: dailyData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.y,
                  color: theme.colorScheme.primary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          gridData: const FlGridData(show: false),
        ),
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
