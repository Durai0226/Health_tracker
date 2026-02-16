import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/training_models.dart';
import 'training_plans_screen.dart';
import 'workout_analysis_screen.dart';
import 'personal_records_screen.dart';
import 'heart_rate_zones_screen.dart';
import 'live_workout_screen.dart';

class EnhancedFitnessDashboard extends StatefulWidget {
  const EnhancedFitnessDashboard({super.key});

  @override
  State<EnhancedFitnessDashboard> createState() => _EnhancedFitnessDashboardState();
}

class _EnhancedFitnessDashboardState extends State<EnhancedFitnessDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  
  // Sample data - would come from storage/API
  ReadinessScore? _todayReadiness;
  List<PersonalRecord> _recentPRs = [];
  TrainingPlan? _activeTrainingPlan;
  int _weeklyRelativeEffort = 0;
  final int _weeklyTargetEffort = 150;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _todayReadiness = StorageService.getTodayReadiness();
        
        _recentPRs = StorageService.getAllPersonalRecords().take(3).toList();
        
        final plans = StorageService.getAllTrainingPlans();
        try {
            _activeTrainingPlan = plans.firstWhere((p) => p.isActive);
        } catch (_) {
            _activeTrainingPlan = null;
        }

        // Calculate weekly relative effort from activities
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final activities = StorageService.getAllFitnessActivities()
            .where((a) => a.startTime.isAfter(weekStart))
            .toList();
            
        // Simple calculation logic for demo purposes if exact RelativeEffort isn't stored
        // In a real app, we'd sum up the actual RelativeEffort scores linked to activities
        _weeklyRelativeEffort = activities.fold(0, (sum, a) => sum + (a.durationMinutes * (a.heartRateAvg != null ? (a.heartRateAvg! / 100) : 1)).round());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildReadinessCard()),
          SliverToBoxAdapter(child: _buildQuickStartSection()),
          SliverToBoxAdapter(child: _buildWeeklyEffortCard()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Training'),
                  Tab(text: 'Analysis'),
                  Tab(text: 'Records'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildTrainingTab(),
            _buildAnalysisTab(),
            _buildRecordsTab(),
          ],
        ),
      ),
      floatingActionButton: _buildStartWorkoutFAB(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border_rounded, color: Colors.white),
          onPressed: () => _navigateTo(const HeartRateZonesScreen()),
          tooltip: 'Heart Rate Zones',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Performance Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                const Color(0xFF26A69A),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 60,
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 40, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(width: 8),
                    Icon(Icons.fitness_center_rounded, size: 35, color: Colors.white.withOpacity(0.15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadinessCard() {
    if (_todayReadiness == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            _getReadinessColor(_todayReadiness!.overallScore).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getReadinessColor(_todayReadiness!.overallScore).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getReadinessColor(_todayReadiness!.overallScore).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.battery_charging_full_rounded,
                  color: _getReadinessColor(_todayReadiness!.overallScore),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Readiness',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_todayReadiness!.overallScore}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _getReadinessColor(_todayReadiness!.overallScore),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _todayReadiness!.scoreLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _getReadinessColor(_todayReadiness!.overallScore),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildReadinessMiniRing(_todayReadiness!.overallScore),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, 
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _todayReadiness!.recommendation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildReadinessMetric('Sleep', _todayReadiness!.sleepScore, Icons.bedtime_rounded),
              _buildReadinessMetric('Recovery', _todayReadiness!.recoveryScore, Icons.refresh_rounded),
              _buildReadinessMetric('HRV', _todayReadiness!.hrvStatus, Icons.monitor_heart_rounded),
              _buildReadinessMetric('Activity', _todayReadiness!.activityBalance, Icons.directions_run_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessMiniRing(int score) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 55,
            height: 55,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_getReadinessColor(score)),
            ),
          ),
          Text(
            _todayReadiness!.scoreEmoji,
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessMetric(String label, int value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getReadinessColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.info;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildQuickStartSection() {
    final workouts = [
      {'type': 'run', 'icon': Icons.directions_run, 'label': 'Run', 'color': Colors.orange},
      {'type': 'cycling', 'icon': Icons.pedal_bike, 'label': 'Cycle', 'color': Colors.blue},
      {'type': 'gym', 'icon': Icons.fitness_center, 'label': 'Strength', 'color': Colors.purple},
      {'type': 'hiit', 'icon': Icons.bolt, 'label': 'HIIT', 'color': Colors.red},
      {'type': 'yoga', 'icon': Icons.self_improvement, 'label': 'Yoga', 'color': Colors.teal},
      {'type': 'swim', 'icon': Icons.pool, 'label': 'Swim', 'color': Colors.cyan},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Start',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: workouts.length,
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return _buildQuickStartCard(
                  icon: workout['icon'] as IconData,
                  label: workout['label'] as String,
                  color: workout['color'] as Color,
                  onTap: () => _startWorkout(workout['type'] as String),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyEffortCard() {
    final progress = (_weeklyRelativeEffort / _weeklyTargetEffort).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded, 
                    color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Relative Effort',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Cardio Load Score',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$_weeklyRelativeEffort / $_weeklyTargetEffort',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.orange.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? AppColors.success : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}% of weekly goal',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${_weeklyTargetEffort - _weeklyRelativeEffort} to go',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRecentPRsCard(),
        const SizedBox(height: 16),
        _buildActiveTrainingPlanCard(),
        const SizedBox(height: 16),
        _buildFeatureGrid(),
      ],
    );
  }

  Widget _buildRecentPRsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Recent PRs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _navigateTo(const PersonalRecordsScreen()),
                child: const Text(
                  'View All',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentPRs.isEmpty)
            const Text(
              'Complete activities to earn PRs!',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._recentPRs.take(3).map((pr) => _buildPRItem(pr)),
        ],
      ),
    );
  }

  Widget _buildPRItem(PersonalRecord pr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pr.distance} ${pr.activityType.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  pr.formattedValue,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (pr.improvement != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '↑ ${pr.improvement!.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTrainingPlanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, 
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Training Plans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _navigateTo(const TrainingPlansScreen()),
                child: const Text('Browse'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_activeTrainingPlan == null)
            GestureDetector(
              onTap: () => _navigateTo(const TrainingPlansScreen()),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start a Training Plan',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '5K, 10K, Half Marathon & more',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      {'icon': Icons.show_chart_rounded, 'label': 'Workout Analysis', 'color': Colors.blue, 'screen': const WorkoutAnalysisScreen()},
      {'icon': Icons.favorite_rounded, 'label': 'HR Zones', 'color': Colors.red, 'screen': const HeartRateZonesScreen()},
      {'icon': Icons.emoji_events_rounded, 'label': 'Personal Records', 'color': Colors.amber, 'screen': const PersonalRecordsScreen()},
      {'icon': Icons.calendar_today_rounded, 'label': 'Training Plans', 'color': Colors.purple, 'screen': const TrainingPlansScreen()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(
          icon: feature['icon'] as IconData,
          label: feature['label'] as String,
          color: feature['color'] as Color,
          onTap: () => _navigateTo(feature['screen'] as Widget),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTrainingRecommendation(),
        const SizedBox(height: 16),
        _buildThisWeekWorkouts(),
      ],
    );
  }

  Widget _buildTrainingRecommendation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'AI Recommendation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Suggested Workout',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 6),
                Text(
                  'Moderate Tempo Run - 45 min',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Based on your readiness score and weekly training load, a tempo run would help build endurance without overtraining.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startWorkout('run'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Start Workout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekWorkouts() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildDayRow('Mon', true, 'Easy Run - 30 min'),
          _buildDayRow('Tue', true, 'Strength Training'),
          _buildDayRow('Wed', true, 'Rest Day'),
          _buildDayRow('Thu', false, 'Tempo Run - 45 min'),
          _buildDayRow('Fri', false, 'Cross Training'),
          _buildDayRow('Sat', false, 'Long Run - 60 min'),
          _buildDayRow('Sun', false, 'Recovery'),
        ],
      ),
    );
  }

  Widget _buildDayRow(String day, bool completed, String workout) {
    final isToday = day == 'Thu'; // Simplified logic
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: completed
                  ? AppColors.success.withOpacity(0.15)
                  : (isToday ? AppColors.primary.withOpacity(0.15) : AppColors.background),
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                  : Text(
                      day.substring(0, 1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isToday ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  workout,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TODAY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return const Center(
      child: Text('Workout Analysis - Coming Soon'),
    );
  }

  Widget _buildRecordsTab() {
    return const Center(
      child: Text('Personal Records - Coming Soon'),
    );
  }

  Widget _buildStartWorkoutFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _startWorkout('run'),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
      label: const Text('Start Workout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  void _startWorkout(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveWorkoutScreen(workoutType: type),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
