import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../widgets/fitness_progress_ring.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';
import '../models/fitness_profile.dart';
import '../services/fitness_storage_service.dart';
import '../data/workout_library.dart';
import 'fitness_discover_screen.dart';
import 'fitness_workout_detail_screen.dart';
import 'fitness_progress_screen.dart';
import 'fitness_settings_screen.dart';
import 'fitness_calendar_screen.dart';
import 'fitness_challenge_screen.dart';
import 'fitness_bmi_screen.dart';
import 'fitness_custom_workout_screen.dart';
import 'fitness_achievements_screen.dart';

class FitnessHomeScreen extends StatefulWidget {
  const FitnessHomeScreen({super.key});

  @override
  State<FitnessHomeScreen> createState() => _FitnessHomeScreenState();
}

class _FitnessHomeScreenState extends State<FitnessHomeScreen>
    with SingleTickerProviderStateMixin {
  final FitnessStorageService _storage = FitnessStorageService();
  late AnimationController _animController;
  final PageController _bodyPartPageController = PageController();
  int _currentBodyPartPage = 0;
  
  WeeklyWorkoutSummary? _weeklySummary;
  List<Workout> _featuredWorkouts = [];
  List<WorkoutSession> _recentSessions = [];
  FitnessProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _bodyPartPageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final summary = await _storage.getWeeklySummary();
      final sessions = await _storage.getAllSessions();
      final profile = await _storage.getProfile();
      
      // Filter workouts based on equipment preference
      final library = WorkoutLibrary();
      List<Workout> featured;
      
      if (profile.equipmentPreference == EquipmentPreference.none) {
        // Show only bodyweight workouts
        featured = library.bodyweightWorkouts.where((w) => w.tags.contains('featured')).toList();
        if (featured.isEmpty) {
          featured = library.bodyweightWorkouts.take(4).toList();
        }
      } else if (profile.equipmentPreference == EquipmentPreference.full) {
        // Show equipment workouts preferentially
        featured = library.equipmentWorkouts.where((w) => w.tags.contains('featured')).toList();
        if (featured.isEmpty) {
          featured = library.featuredWorkouts;
        }
      } else {
        // Minimal equipment - show all featured
        featured = library.featuredWorkouts;
      }

      if (mounted) {
        setState(() {
          _weeklySummary = summary;
          _recentSessions = sessions.take(3).toList();
          _featuredWorkouts = featured;
          _userProfile = profile;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      debugPrint('Error loading fitness data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getWorkoutTypeTitle() {
    final equipment = _userProfile?.equipmentPreference ?? EquipmentPreference.none;
    switch (equipment) {
      case EquipmentPreference.none:
        return 'Home Workout';
      case EquipmentPreference.minimal:
        return 'Minimal Gear';
      case EquipmentPreference.full:
        return 'Gym Workout';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FitnessTheme.primary),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: FitnessTheme.primary,
                backgroundColor: FitnessTheme.surface,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildWeeklyProgress(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildQuickStartSection(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildFeaturedWorkouts(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildBodyPartGrid(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          _buildMoreFeatures(),
                          const SizedBox(height: FitnessTheme.spacingLg),
                          if (_recentSessions.isNotEmpty) ...[
                            _buildRecentWorkouts(),
                            const SizedBox(height: FitnessTheme.spacingLg),
                          ],
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: FitnessTheme.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: FitnessTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: FitnessTheme.textPrimary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FitnessProgressScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: FitnessTheme.textPrimary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FitnessSettingsScreen()),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FitnessTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: FitnessTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getWorkoutTypeTitle(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FitnessTheme.textPrimary,
                  ),
                ),
                Text(
                  _userProfile?.equipmentPreference.displayName ?? 'No Equipment',
                  style: const TextStyle(
                    fontSize: 11,
                    color: FitnessTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                FitnessTheme.primary.withOpacity(0.1),
                FitnessTheme.background,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    final summary = _weeklySummary;
    final weeklyGoal = _userProfile?.weeklyWorkoutTarget ?? 5;
    final progress = summary != null 
        ? (summary.totalWorkouts / weeklyGoal).clamp(0.0, 1.0) 
        : 0.0;

    return FitnessCard(
      padding: const EdgeInsets.all(FitnessTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: FitnessTheme.titleLg.copyWith(
                        color: FitnessTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary?.totalWorkouts ?? 0}/$weeklyGoal workouts completed',
                      style: FitnessTheme.bodySm,
                    ),
                  ],
                ),
              ),
              AnimatedProgressRing(
                progress: progress,
                size: 70,
                strokeWidth: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: FitnessTheme.titleSm.copyWith(
                        color: FitnessTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          // Weekly bars
          WeeklyProgressBars(
            values: summary?.dailyStats.map((d) => d.workoutsCompleted.toDouble()).toList() 
                ?? List.filled(7, 0.0),
            maxValue: 2,
            height: 60,
          ),
          const SizedBox(height: FitnessTheme.spacingMd),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  Icons.local_fire_department,
                  '${summary?.totalCalories ?? 0}',
                  'Calories',
                  FitnessTheme.warning,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: FitnessTheme.surface,
              ),
              Expanded(
                child: _buildMiniStat(
                  Icons.timer_outlined,
                  '${summary?.totalMinutes ?? 0}',
                  'Minutes',
                  FitnessTheme.info,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: FitnessTheme.surface,
              ),
              Expanded(
                child: _buildMiniStat(
                  Icons.local_fire_department_outlined,
                  '${summary?.currentStreak ?? 0}',
                  'Day Streak',
                  FitnessTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: FitnessTheme.titleMd.copyWith(color: color),
        ),
        Text(label, style: FitnessTheme.caption),
      ],
    );
  }

  Widget _buildQuickStartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Start', style: FitnessTheme.headingSm),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FitnessDiscoverScreen()),
              ),
              child: Text(
                'See All',
                style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildQuickStartCard(
                '7 Min',
                'Full Body',
                Icons.accessibility_new,
                FitnessTheme.fullBody,
                () => _startQuickWorkout('full_body_beginner'),
              ),
              _buildQuickStartCard(
                '5 Min',
                'Abs',
                Icons.fitness_center,
                FitnessTheme.abs,
                () => _startQuickWorkout('quick_abs'),
              ),
              _buildQuickStartCard(
                '10 Min',
                'Arms',
                Icons.sports_gymnastics,
                FitnessTheme.arms,
                () => _startQuickWorkout('arms_toned'),
              ),
              _buildQuickStartCard(
                '12 Min',
                'Legs',
                Icons.directions_walk,
                FitnessTheme.legs,
                () => _startQuickWorkout('legs_beginner'),
              ),
              _buildQuickStartCard(
                '12 Min',
                'Cardio',
                Icons.favorite,
                FitnessTheme.cardio,
                () => _startQuickWorkout('cardio_blast'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStartCard(
    String duration,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: FitnessTheme.spacingMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.1),
            ],
          ),
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: FitnessTheme.titleSm,
              textAlign: TextAlign.center,
            ),
            Text(
              duration,
              style: FitnessTheme.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _startQuickWorkout(String workoutId) async {
    final workout = await _storage.getWorkoutById(workoutId);
    if (workout != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FitnessWorkoutDetailScreen(workout: workout),
        ),
      );
    }
  }

  Widget _buildFeaturedWorkouts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Featured Workouts', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        ..._featuredWorkouts.take(3).map((workout) => WorkoutCard(
          title: workout.name,
          subtitle: workout.description,
          duration: workout.formattedDuration,
          difficulty: workout.difficulty.displayName,
          bodyPart: workout.primaryBodyPart.displayName,
          exerciseCount: workout.exercises.length,
          showBadge: workout.tags.contains('featured'),
          badgeText: 'FEATURED',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FitnessWorkoutDetailScreen(workout: workout),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildBodyPartGrid() {
    final bodyParts = [
      {'part': BodyPart.fullBody, 'icon': Icons.accessibility_new},
      {'part': BodyPart.abs, 'icon': Icons.fitness_center},
      {'part': BodyPart.arms, 'icon': Icons.sports_gymnastics},
      {'part': BodyPart.legs, 'icon': Icons.directions_walk},
      {'part': BodyPart.chest, 'icon': Icons.airline_seat_flat},
      {'part': BodyPart.back, 'icon': Icons.airline_seat_recline_normal},
      {'part': BodyPart.shoulders, 'icon': Icons.sports_handball},
      {'part': BodyPart.cardio, 'icon': Icons.favorite},
    ];

    // Split into pages of 4 items each for 2x2 grid
    final pageCount = (bodyParts.length / 4).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Train by Body Part', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        // PageView with explicit 2x2 layout - guaranteed visibility
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _bodyPartPageController,
            onPageChanged: (page) {
              setState(() => _currentBodyPartPage = page);
            },
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * 4;
              final endIndex = (startIndex + 4).clamp(0, bodyParts.length);
              final pageItems = bodyParts.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    // First row
                    Expanded(
                      child: Row(
                        children: [
                          if (pageItems.isNotEmpty)
                            Expanded(child: _buildBodyPartCard(pageItems[0])),
                          const SizedBox(width: 12),
                          if (pageItems.length > 1)
                            Expanded(child: _buildBodyPartCard(pageItems[1]))
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Second row
                    Expanded(
                      child: Row(
                        children: [
                          if (pageItems.length > 2)
                            Expanded(child: _buildBodyPartCard(pageItems[2]))
                          else
                            const Expanded(child: SizedBox()),
                          const SizedBox(width: 12),
                          if (pageItems.length > 3)
                            Expanded(child: _buildBodyPartCard(pageItems[3]))
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Page indicator dots
        const SizedBox(height: FitnessTheme.spacingMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pageCount, (index) {
            final isActive = index == _currentBodyPartPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? FitnessTheme.primary : FitnessTheme.surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: FitnessTheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ] : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBodyPartCard(Map<String, dynamic> item) {
    final bodyPart = item['part'] as BodyPart;
    final icon = item['icon'] as IconData;
    final workouts = WorkoutLibrary().getByBodyPart(bodyPart);
    final color = FitnessTheme.getBodyPartColor(bodyPart.displayName);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FitnessDiscoverScreen(initialBodyPart: bodyPart),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FitnessTheme.cardBackground,
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              bodyPart.displayName,
              style: FitnessTheme.titleSm.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${workouts.length} workouts',
              style: FitnessTheme.caption.copyWith(
                color: FitnessTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('More Features', style: FitnessTheme.headingSm),
        const SizedBox(height: FitnessTheme.spacingMd),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: FitnessTheme.spacingMd,
          crossAxisSpacing: FitnessTheme.spacingMd,
          childAspectRatio: 1.5,
          children: [
            _buildFeatureCard(
              '30-Day\nChallenge',
              Icons.emoji_events,
              FitnessTheme.warning,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessChallengeScreen())),
            ),
            _buildFeatureCard(
              'Calendar\nView',
              Icons.calendar_month,
              FitnessTheme.info,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessCalendarScreen())),
            ),
            _buildFeatureCard(
              'BMI &\nWeight',
              Icons.monitor_weight,
              FitnessTheme.success,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessBmiScreen())),
            ),
            _buildFeatureCard(
              'Create\nWorkout',
              Icons.add_circle,
              FitnessTheme.primary,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessCustomWorkoutScreen())),
            ),
            _buildFeatureCard(
              'Achievements',
              Icons.military_tech,
              FitnessTheme.warning,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessAchievementsScreen())),
            ),
            _buildFeatureCard(
              'Progress\nStats',
              Icons.bar_chart_rounded,
              FitnessTheme.info,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessProgressScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: FitnessTheme.borderRadiusMd,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: FitnessTheme.titleSm.copyWith(height: 1.2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentWorkouts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity', style: FitnessTheme.headingSm),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FitnessProgressScreen()),
              ),
              child: Text(
                'View All',
                style: FitnessTheme.titleSm.copyWith(color: FitnessTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitnessTheme.spacingSm),
        ..._recentSessions.map((session) => _buildRecentSessionCard(session)),
      ],
    );
  }

  Widget _buildRecentSessionCard(WorkoutSession session) {
    return FitnessCard(
      margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
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
              color: session.wasCompleted ? FitnessTheme.success : FitnessTheme.warning,
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
                  _formatSessionDate(session.startedAt),
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

  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(date.year, date.month, date.day);

    if (sessionDate == today) {
      return 'Today, ${_formatTime(date)}';
    } else if (sessionDate == yesterday) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
