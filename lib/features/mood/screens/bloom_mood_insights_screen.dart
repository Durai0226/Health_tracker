import 'package:flutter/material.dart';
import '../theme/mood_theme.dart';
import '../models/mood_type.dart';
import '../models/mood_insight.dart';
import '../models/mood_streak.dart';
import '../services/mood_firestore_service.dart';
import '../widgets/bloom_glass_container.dart';
import '../widgets/mood_stats_card.dart';

/// Insights and analytics screen for mood tracking
class BloomMoodInsightsScreen extends StatefulWidget {
  const BloomMoodInsightsScreen({super.key});

  @override
  State<BloomMoodInsightsScreen> createState() =>
      _BloomMoodInsightsScreenState();
}

class _BloomMoodInsightsScreenState extends State<BloomMoodInsightsScreen>
    with SingleTickerProviderStateMixin {
  final MoodFirestoreService _firestoreService = MoodFirestoreService();

  MoodInsight? _weeklyInsight;
  MoodInsight? _monthlyInsight;
  MoodStreak _streak = MoodStreak();
  bool _isLoading = true;
  int _selectedPeriod = 0; // 0 = week, 1 = month

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedPeriod = _tabController.index);
    });
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
      final weeklyInsight = await _firestoreService.getWeeklyInsight();
      final monthlyInsight = await _firestoreService.getMonthlyInsight();
      final streak = await _firestoreService.getStreak();

      setState(() {
        _weeklyInsight = weeklyInsight;
        _monthlyInsight = monthlyInsight;
        _streak = streak;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading insights: $e');
      setState(() => _isLoading = false);
    }
  }

  MoodInsight? get _currentInsight =>
      _selectedPeriod == 0 ? _weeklyInsight : _monthlyInsight;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Insights',
            style: MoodTheme.headingSm,
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: MoodTheme.primary),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: MoodTheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(MoodTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Period selector
                      _buildPeriodSelector(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Overview card
                      _buildOverviewCard(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Mood distribution
                      _buildMoodDistribution(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Stats grid
                      _buildStatsGrid(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Streak section
                      _buildStreakSection(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Trends
                      if (_currentInsight?.trends.isNotEmpty ?? false)
                        _buildTrendsSection(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Top activities
                      _buildTopActivities(),
                      const SizedBox(height: MoodTheme.spacingLg),

                      // Best day
                      _buildBestDayCard(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MoodTheme.backgroundSecondary,
        borderRadius: MoodTheme.borderRadiusRound,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: MoodTheme.primary,
          borderRadius: MoodTheme.borderRadiusRound,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: MoodTheme.textSecondary,
        labelStyle: MoodTheme.titleSm,
        tabs: const [
          Tab(text: 'This Week'),
          Tab(text: 'This Month'),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final insight = _currentInsight;
    final dominantMood = insight?.dominantMood;

    return BloomGlassContainer(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Column(
        children: [
          Text(
            _selectedPeriod == 0 ? 'Weekly Overview' : 'Monthly Overview',
            style: MoodTheme.titleMd.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
          const SizedBox(height: MoodTheme.spacingMd),

          // Dominant mood
          if (dominantMood != null) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: MoodTheme.getMoodLightColor(dominantMood.value),
                shape: BoxShape.circle,
                boxShadow: MoodTheme.getMoodShadow(dominantMood.value),
              ),
              child: Center(
                child: Text(
                  dominantMood.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: MoodTheme.spacingMd),
            Text(
              'Mostly ${dominantMood.label}',
              style: MoodTheme.headingMd.copyWith(
                color: MoodTheme.getMoodColor(dominantMood.value),
              ),
            ),
          ] else ...[
            const Text('😶', style: TextStyle(fontSize: 48)),
            const SizedBox(height: MoodTheme.spacingMd),
            Text(
              'No data yet',
              style: MoodTheme.headingMd.copyWith(
                color: MoodTheme.textMuted,
              ),
            ),
          ],

          const SizedBox(height: MoodTheme.spacingSm),
          Text(
            '${insight?.totalEntries ?? 0} entries • ${insight?.positivityLevel ?? 'N/A'} positivity',
            style: MoodTheme.bodyMd.copyWith(
              color: MoodTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodDistribution() {
    final insight = _currentInsight;
    if (insight == null || insight.totalEntries == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mood Distribution', style: MoodTheme.titleLg),
        const SizedBox(height: MoodTheme.spacingMd),
        BloomGlassContainer(
          padding: const EdgeInsets.all(MoodTheme.spacingMd),
          child: Column(
            children: MoodType.primaryMoods.map((mood) {
              final percentage = insight.getMoodPercentage(mood);
              final count = insight.moodCounts[mood] ?? 0;
              final moodColor = MoodTheme.getMoodColor(mood.value);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                mood.label,
                                style: MoodTheme.titleSm,
                              ),
                              Text(
                                '$count (${percentage.toStringAsFixed(0)}%)',
                                style: MoodTheme.bodySm.copyWith(
                                  color: MoodTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: MoodTheme.borderRadiusRound,
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: moodColor.withOpacity(0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(moodColor),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final insight = _currentInsight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Statistics', style: MoodTheme.titleLg),
        const SizedBox(height: MoodTheme.spacingMd),
        Row(
          children: [
            Expanded(
              child: MoodStatsCard(
                title: 'Total Entries',
                value: '${insight?.totalEntries ?? 0}',
                subtitle: _selectedPeriod == 0 ? 'this week' : 'this month',
                icon: Icons.edit_note_rounded,
                accentColor: MoodTheme.primary,
              ),
            ),
            const SizedBox(width: MoodTheme.spacingMd),
            Expanded(
              child: MoodStatsCard(
                title: 'Avg Intensity',
                value: insight != null
                    ? insight.averageIntensity.toStringAsFixed(1)
                    : 'N/A',
                subtitle: 'out of 5',
                icon: Icons.speed_rounded,
                accentColor: MoodTheme.accentGold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Streak', style: MoodTheme.titleLg),
        const SizedBox(height: MoodTheme.spacingMd),
        StreakCard(
          currentStreak: _streak.currentStreak,
          longestStreak: _streak.longestStreak,
          motivationalMessage: _streak.motivationalMessage,
        ),
        if (_streak.milestones.isNotEmpty) ...[
          const SizedBox(height: MoodTheme.spacingMd),
          _buildMilestones(),
        ],
      ],
    );
  }

  Widget _buildMilestones() {
    return Wrap(
      spacing: MoodTheme.spacingSm,
      runSpacing: MoodTheme.spacingSm,
      children: _streak.milestones.map((milestone) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            gradient: MoodTheme.primaryGradient,
            borderRadius: MoodTheme.borderRadiusRound,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '$milestone days',
                style: MoodTheme.titleSm.copyWith(color: Colors.white),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrendsSection() {
    final trends = _currentInsight?.trends ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trends', style: MoodTheme.titleLg),
        const SizedBox(height: MoodTheme.spacingMd),
        ...trends.map((trend) {
          Color trendColor;
          IconData trendIcon;

          switch (trend.type) {
            case TrendType.improving:
              trendColor = const Color(0xFF4CAF50);
              trendIcon = Icons.trending_up_rounded;
              break;
            case TrendType.declining:
              trendColor = const Color(0xFFE53935);
              trendIcon = Icons.trending_down_rounded;
              break;
            case TrendType.stable:
              trendColor = MoodTheme.textSecondary;
              trendIcon = Icons.trending_flat_rounded;
              break;
          }

          return BloomGlassContainer(
            margin: const EdgeInsets.only(bottom: MoodTheme.spacingSm),
            padding: const EdgeInsets.all(MoodTheme.spacingMd),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: trendColor.withOpacity(0.15),
                    borderRadius: MoodTheme.borderRadiusSm,
                  ),
                  child: Icon(trendIcon, color: trendColor),
                ),
                const SizedBox(width: MoodTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trend.type.emoji} ${trend.type.name.toUpperCase()}',
                        style: MoodTheme.titleSm.copyWith(
                          color: trendColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trend.description,
                        style: MoodTheme.bodySm.copyWith(
                          color: MoodTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTopActivities() {
    final topActivities = _currentInsight?.topActivities ?? [];
    if (topActivities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Activities', style: MoodTheme.titleLg),
        const SizedBox(height: MoodTheme.spacingMd),
        BloomGlassContainer(
          padding: const EdgeInsets.all(MoodTheme.spacingMd),
          child: Column(
            children: topActivities.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value.key;
              final count = entry.value.value;
              final color =
                  MoodTheme.activityColors[activity.value] ?? MoodTheme.primary;
              final icon =
                  MoodTheme.activityIcons[activity.value] ?? Icons.star_rounded;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: MoodTheme.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: MoodTheme.titleSm.copyWith(color: color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activity.label,
                        style: MoodTheme.titleSm,
                      ),
                    ),
                    Text(
                      '$count times',
                      style: MoodTheme.bodySm.copyWith(
                        color: MoodTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBestDayCard() {
    final bestDay = _currentInsight?.bestDayOfWeek;
    if (bestDay == null) return const SizedBox.shrink();

    return BloomGlassContainer(
      padding: const EdgeInsets.all(MoodTheme.spacingLg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: MoodTheme.primaryGradient,
              borderRadius: MoodTheme.borderRadiusMd,
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: MoodTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Best Day',
                  style: MoodTheme.bodySm.copyWith(
                    color: MoodTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bestDay,
                  style: MoodTheme.headingSm.copyWith(
                    color: MoodTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your happiest day of the week',
                  style: MoodTheme.caption.copyWith(
                    color: MoodTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
