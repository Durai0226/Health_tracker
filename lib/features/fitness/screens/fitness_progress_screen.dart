import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_progress_ring.dart';
import '../models/workout_session.dart';
import '../services/fitness_storage_service.dart';

class FitnessProgressScreen extends StatefulWidget {
  const FitnessProgressScreen({super.key});

  @override
  State<FitnessProgressScreen> createState() => _FitnessProgressScreenState();
}

class _FitnessProgressScreenState extends State<FitnessProgressScreen>
    with SingleTickerProviderStateMixin {
  final FitnessStorageService _storage = FitnessStorageService();
  late TabController _tabController;

  WeeklyWorkoutSummary? _weeklySummary;
  Map<String, dynamic>? _allTimeStats;
  List<WorkoutSession> _recentSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final summary = await _storage.getWeeklySummary();
      final allTime = await _storage.getAllTimeStats();
      final sessions = await _storage.getAllSessions();

      if (mounted) {
        setState(() {
          _weeklySummary = summary;
          _allTimeStats = allTime;
          _recentSessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading progress data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          title: const Text('Progress', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: FitnessTheme.primary,
            labelColor: FitnessTheme.primary,
            unselectedLabelColor: FitnessTheme.textMuted,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FitnessTheme.primary),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildHistoryTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: FitnessTheme.primary,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(FitnessTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeeklyOverview(),
            const SizedBox(height: FitnessTheme.spacingLg),
            _buildWeeklyChart(),
            const SizedBox(height: FitnessTheme.spacingLg),
            _buildAllTimeStats(),
            const SizedBox(height: FitnessTheme.spacingLg),
            _buildBodyPartDistribution(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    final summary = _weeklySummary;
    final weeklyGoal = 5;
    final progress = summary != null
        ? (summary.totalWorkouts / weeklyGoal).clamp(0.0, 1.0)
        : 0.0;

    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: FitnessTheme.headingSm),
          const SizedBox(height: FitnessTheme.spacingMd),
          Row(
            children: [
              AnimatedProgressRing(
                progress: progress,
                size: 100,
                strokeWidth: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary?.totalWorkouts ?? 0}',
                      style: FitnessTheme.headingMd.copyWith(
                        color: FitnessTheme.primary,
                      ),
                    ),
                    Text('of $weeklyGoal', style: FitnessTheme.caption),
                  ],
                ),
              ),
              const SizedBox(width: FitnessTheme.spacingLg),
              Expanded(
                child: Column(
                  children: [
                    _buildStatRow(
                      Icons.local_fire_department,
                      '${summary?.totalCalories ?? 0}',
                      'Calories burned',
                      FitnessTheme.warning,
                    ),
                    const SizedBox(height: FitnessTheme.spacingSm),
                    _buildStatRow(
                      Icons.timer,
                      '${summary?.totalMinutes ?? 0} min',
                      'Total time',
                      FitnessTheme.info,
                    ),
                    const SizedBox(height: FitnessTheme.spacingSm),
                    _buildStatRow(
                      Icons.local_fire_department_outlined,
                      '${summary?.currentStreak ?? 0} days',
                      'Current streak',
                      FitnessTheme.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: FitnessTheme.borderRadiusSm,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: FitnessTheme.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: FitnessTheme.titleSm),
              Text(label, style: FitnessTheme.caption),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final dailyStats = _weeklySummary?.dailyStats ?? [];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Activity', style: FitnessTheme.headingSm),
          const SizedBox(height: FitnessTheme.spacingMd),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 3,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: FitnessTheme.caption,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (index) {
                  final value = index < dailyStats.length
                      ? dailyStats[index].workoutsCompleted.toDouble()
                      : 0.0;
                  final isToday = index == DateTime.now().weekday - 1;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value > 0 ? value : 0.1,
                        color: isToday
                            ? FitnessTheme.primary
                            : value > 0
                                ? FitnessTheme.primary.withOpacity(0.5)
                                : FitnessTheme.surface,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTimeStats() {
    final stats = _allTimeStats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All Time', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Workouts',
                value: '${stats?['totalWorkouts'] ?? 0}',
                icon: Icons.fitness_center,
                color: FitnessTheme.primary,
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingSm),
            Expanded(
              child: StatsCard(
                title: 'Calories',
                value: '${stats?['totalCalories'] ?? 0}',
                icon: Icons.local_fire_department,
                color: FitnessTheme.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'Minutes',
                value: '${stats?['totalMinutes'] ?? 0}',
                icon: Icons.timer,
                color: FitnessTheme.info,
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingSm),
            Expanded(
              child: StatsCard(
                title: 'Best Streak',
                value: '${stats?['longestStreak'] ?? 0}',
                subtitle: 'days',
                icon: Icons.emoji_events,
                color: FitnessTheme.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBodyPartDistribution() {
    final bodyPartFreq = _weeklySummary?.bodyPartFrequency ?? {};
    if (bodyPartFreq.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = bodyPartFreq.values.fold<int>(0, (sum, v) => sum + v);

    return FitnessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Body Parts Worked', style: FitnessTheme.headingSm),
          const SizedBox(height: FitnessTheme.spacingMd),
          ...bodyPartFreq.entries.map((entry) {
            final percentage = total > 0 ? entry.value / total : 0.0;
            final color = FitnessTheme.getBodyPartColor(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: FitnessTheme.titleSm),
                      Text(
                        '${entry.value} workouts',
                        style: FitnessTheme.bodySm,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: FitnessTheme.surface,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                    borderRadius: FitnessTheme.borderRadiusSm,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_recentSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 64,
              color: FitnessTheme.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: FitnessTheme.spacingMd),
            Text(
              'No workouts yet',
              style: FitnessTheme.titleMd.copyWith(color: FitnessTheme.textMuted),
            ),
            const SizedBox(height: FitnessTheme.spacingSm),
            Text(
              'Start your first workout!',
              style: FitnessTheme.bodySm,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      itemCount: _recentSessions.length,
      itemBuilder: (context, index) {
        final session = _recentSessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(WorkoutSession session) {
    return FitnessCard(
      margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: session.wasCompleted
                  ? FitnessTheme.success.withOpacity(0.2)
                  : FitnessTheme.warning.withOpacity(0.2),
              borderRadius: FitnessTheme.borderRadiusSm,
            ),
            child: Icon(
              session.wasCompleted ? Icons.check_circle : Icons.timer,
              color: session.wasCompleted
                  ? FitnessTheme.success
                  : FitnessTheme.warning,
            ),
          ),
          const SizedBox(width: FitnessTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.workoutName,
                  style: FitnessTheme.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(session.startedAt),
                  style: FitnessTheme.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                session.formattedDuration,
                style: FitnessTheme.titleSm.copyWith(
                  color: FitnessTheme.primary,
                ),
              ),
              Text(
                '${session.caloriesBurned} cal',
                style: FitnessTheme.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today';
    } else if (sessionDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
