import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/haptic_service.dart';
import '../models/fitness_reminder.dart';
import '../models/fitness_activity.dart';
import 'add_fitness_screen.dart';

/// Fitness Dashboard - Fitbit/Strava-style fitness tracking
/// Features: Real-time stats, workout tracking, progress rings, activity history
class FitnessDashboardScreen extends StatefulWidget {
  const FitnessDashboardScreen({super.key});

  @override
  State<FitnessDashboardScreen> createState() => _FitnessDashboardScreenState();
}

class _FitnessDashboardScreenState extends State<FitnessDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HapticService _hapticService = HapticService();
  List<FitnessReminder> _reminders = [];
  List<FitnessActivity> _activities = [];
  bool _isLoading = true;
  
  // Weekly stats
  int _weeklyWorkouts = 0;
  int _weeklyMinutes = 0;
  int _weeklyCalories = 0;
  
  // Goals
  final int _weeklyWorkoutGoal = 5;
  final int _weeklyMinutesGoal = 150;
  final int _weeklyCaloriesGoal = 2000;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      await Future.delayed(const Duration(milliseconds: 100));
      
      final reminders = StorageService.getAllFitnessReminders();
      // Load activities from storage (we'll add this method)
      final activities = await _loadActivities();
      
      // Calculate weekly stats
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekActivities = activities.where((a) => 
        a.startTime.isAfter(weekStart) && a.isCompleted
      ).toList();
      
      if (mounted) {
        setState(() {
          _reminders = reminders;
          _activities = activities;
          _weeklyWorkouts = weekActivities.length;
          _weeklyMinutes = weekActivities.fold(0, (sum, a) => sum + a.durationMinutes);
          _weeklyCalories = weekActivities.fold(0, (sum, a) => sum + (a.caloriesBurned ?? 0));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fitness data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<FitnessActivity>> _loadActivities() async {
    // For now, return empty list - would load from Hive
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildWeeklyProgress()),
                SliverToBoxAdapter(child: _buildQuickActions()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'Reminders'),
                        Tab(text: 'Activity'),
                        Tab(text: 'Stats'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildRemindersTab(),
                  _buildActivityTab(),
                  _buildStatsTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Workout', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Fitness Tracker',
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
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: 50,
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 50,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            children: [
              const Icon(Icons.calendar_today_rounded, 
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'This Week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _getWeekDateRange(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildProgressRing(
                  icon: Icons.fitness_center,
                  label: 'Workouts',
                  value: _weeklyWorkouts,
                  goal: _weeklyWorkoutGoal,
                  color: AppColors.primary,
                  unit: '',
                ),
              ),
              Expanded(
                child: _buildProgressRing(
                  icon: Icons.timer_outlined,
                  label: 'Minutes',
                  value: _weeklyMinutes,
                  goal: _weeklyMinutesGoal,
                  color: AppColors.success,
                  unit: 'min',
                ),
              ),
              Expanded(
                child: _buildProgressRing(
                  icon: Icons.local_fire_department,
                  label: 'Calories',
                  value: _weeklyCalories,
                  goal: _weeklyCaloriesGoal,
                  color: AppColors.warning,
                  unit: 'kcal',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing({
    required IconData icon,
    required String label,
    required int value,
    required int goal,
    required Color color,
    required String unit,
  }) {
    final progress = (value / goal).clamp(0.0, 1.0);
    
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$value${unit.isNotEmpty ? " $unit" : ""}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          'of $goal $label',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final activities = [
      {'type': 'walk', 'icon': Icons.directions_walk, 'label': 'Walk', 'color': Colors.green},
      {'type': 'run', 'icon': Icons.directions_run, 'label': 'Run', 'color': Colors.orange},
      {'type': 'cycling', 'icon': Icons.pedal_bike, 'label': 'Cycle', 'color': Colors.blue},
      {'type': 'gym', 'icon': Icons.fitness_center, 'label': 'Gym', 'color': Colors.purple},
      {'type': 'yoga', 'icon': Icons.self_improvement, 'label': 'Yoga', 'color': Colors.teal},
      {'type': 'swimming', 'icon': Icons.pool, 'label': 'Swim', 'color': Colors.cyan},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Start',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildQuickActionCard(
                  icon: activity['icon'] as IconData,
                  label: activity['label'] as String,
                  color: activity['color'] as Color,
                  onTap: () => _startQuickWorkout(activity['type'] as String),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersTab() {
    if (_reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center_outlined, 
                size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No workout reminders yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add one',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return _buildReminderCard(reminder);
        },
      ),
    );
  }

  Widget _buildReminderCard(FitnessReminder reminder) {
    final timeStr = TimeOfDay.fromDateTime(reminder.reminderTime).format(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(reminder.emoji, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(
          reminder.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(timeStr, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  reminder.frequency.capitalize(),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${reminder.durationMinutes} min',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        trailing: Switch.adaptive(
          value: reminder.isEnabled,
          onChanged: (v) => _toggleReminder(reminder, v),
          activeColor: AppColors.primary,
        ),
        onTap: () => _editReminder(reminder),
      ),
    );
  }

  Widget _buildActivityTab() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, 
                size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No activities logged yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete workouts to see them here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final activity = _activities[index];
          return _buildActivityCard(activity);
        },
      ),
    );
  }

  Widget _buildActivityCard(FitnessActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(activity.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatDate(activity.startTime),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (activity.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✓ Done',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildActivityStat(
                Icons.timer_outlined,
                activity.formattedDuration,
                'Duration',
              ),
              _buildActivityStat(
                Icons.local_fire_department,
                '${activity.caloriesBurned ?? 0}',
                'Calories',
              ),
              if (activity.distanceKm != null)
                _buildActivityStat(
                  Icons.straighten,
                  activity.formattedDistance,
                  'Distance',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStat(IconData icon, String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWeeklyChart(),
        const SizedBox(height: 16),
        _buildStreakCard(),
        const SizedBox(height: 16),
        _buildAllTimeStats(),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Weekly Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isToday = index + 1 == today;
              final hasActivity = _weeklyWorkouts > index;
              
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasActivity
                          ? AppColors.primary
                          : (isToday
                              ? AppColors.primary.withOpacity(0.2)
                              : Colors.grey[200]),
                      border: isToday
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: hasActivity
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, 
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Streak',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_weeklyWorkouts days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.emoji_events, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildAllTimeStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'All Time Stats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.fitness_center,
                  '$_weeklyWorkouts',
                  'Workouts',
                  AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.timer_outlined,
                  '$_weeklyMinutes',
                  'Minutes',
                  AppColors.success,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  Icons.local_fire_department,
                  '$_weeklyCalories',
                  'Calories',
                  AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getWeekDateRange() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return '${weekStart.day}/${weekStart.month} - ${weekEnd.day}/${weekEnd.month}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today at ${TimeOfDay.fromDateTime(date).format(context)}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  void _addReminder() async {
    _hapticService.fitnessStart();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddFitnessScreen()),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _editReminder(FitnessReminder reminder) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFitnessScreen(existingReminder: reminder),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _toggleReminder(FitnessReminder reminder, bool enabled) async {
    _hapticService.toggle();
    try {
      final updated = FitnessReminder(
        id: reminder.id,
        type: reminder.type,
        title: reminder.title,
        reminderTime: reminder.reminderTime,
        frequency: reminder.frequency,
        durationMinutes: reminder.durationMinutes,
        isEnabled: enabled,
        customDays: reminder.customDays,
      );
      await StorageService.updateFitnessReminder(updated);
      _loadData();
    } catch (e) {
      debugPrint('Error toggling reminder: $e');
    }
  }

  void _startQuickWorkout(String type) {
    _hapticService.fitnessStart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${type.capitalize()} workout...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Could navigate to active workout screen
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
