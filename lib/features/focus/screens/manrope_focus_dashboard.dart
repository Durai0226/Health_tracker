import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../theme/manrope_theme.dart';
import '../models/meditation_activity.dart';
import '../models/daily_routine.dart';
import '../services/manrope_wellness_service.dart';
import 'manrope_activity_screen.dart';
import 'manrope_stats_screen.dart';
import 'manrope_reminders_screen.dart';

class ManropeFocusDashboard extends StatefulWidget {
  const ManropeFocusDashboard({super.key});

  @override
  State<ManropeFocusDashboard> createState() => _ManropeFocusDashboardState();
}

class _ManropeFocusDashboardState extends State<ManropeFocusDashboard>
    with TickerProviderStateMixin {
  final ManropeWellnessService _wellnessService = ManropeWellnessService();
  final HapticService _hapticService = HapticService();

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
    late Animation<double> _pulseAnimation;

  DateTime _selectedDate = DateTime.now();
  int _hoveredActivityIndex = -1;

  @override
  void initState() {
    super.initState();
    _wellnessService.init();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: ManropeTheme.durationMedium,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: ManropeTheme.curveDefault,
    );
    _fadeController.forward();

    _scaleController = AnimationController(
      duration: ManropeTheme.durationSlow,
      vsync: this,
    );
    _scaleController.forward();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ManropeTheme.isDark(context);

    return ListenableBuilder(
      listenable: _wellnessService,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark
              ? ManropeTheme.backgroundDark
              : ManropeTheme.backgroundWarm,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildDateSelector(isDark),
                          const SizedBox(height: 24),
                          _buildQuickStatsBar(isDark),
                          const SizedBox(height: 24),
                          _buildActivityGrid(isDark),
                          const SizedBox(height: 24),
                          _buildTodaySchedule(isDark),
                          const SizedBox(height: 24),
                          _buildMotivationCard(isDark),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    final greeting = _getGreeting();
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: ManropeTheme.bodyMedium.copyWith(
                    color: isDark
                        ? ManropeTheme.textSecondaryDark
                        : ManropeTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (bounds) => ManropeTheme.primaryGradient
                      .createShader(bounds),
                  child: Text(
                    'Mindful Journey',
                    style: ManropeTheme.headlineMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildHeaderIconButton(
                icon: Icons.notifications_outlined,
                onTap: () => _navigateToReminders(),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildHeaderIconButton(
                icon: Icons.bar_chart_rounded,
                onTap: () => _navigateToStats(),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        _hapticService.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? ManropeTheme.backgroundDarkCard
              : Colors.white,
          borderRadius: ManropeTheme.borderRadiusMedium,
          boxShadow: ManropeTheme.shadowSmall,
        ),
        child: Icon(
          icon,
          size: 22,
          color: isDark
              ? ManropeTheme.textPrimaryDark
              : ManropeTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildDateSelector(bool isDark) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 3 - i)));

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, now);
          final hasActivity = _wellnessService.hasActivityOn(date);

          return GestureDetector(
            onTap: () {
              _hapticService.selection();
              setState(() => _selectedDate = date);
            },
            child: AnimatedContainer(
              duration: ManropeTheme.durationFast,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected ? ManropeTheme.primaryGradient : null,
                color: isSelected
                    ? null
                    : (isDark
                        ? ManropeTheme.backgroundDarkCard
                        : Colors.white),
                borderRadius: ManropeTheme.borderRadiusLarge,
                boxShadow: isSelected
                    ? ManropeTheme.shadowColored(ManropeTheme.primaryOrange)
                    : ManropeTheme.shadowSmall,
                border: isToday && !isSelected
                    ? Border.all(
                        color: ManropeTheme.primaryOrange.withOpacity(0.5),
                        width: 2,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayName(date),
                    style: ManropeTheme.labelSmall.copyWith(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : (isDark
                              ? ManropeTheme.textTertiaryDark
                              : ManropeTheme.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: ManropeTheme.titleLarge.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? ManropeTheme.textPrimaryDark
                              : ManropeTheme.textPrimary),
                    ),
                  ),
                  if (hasActivity) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : ManropeTheme.accentGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStatsBar(bool isDark) {
    final stats = _wellnessService.stats;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_fire_department_rounded,
              value: '${stats.currentStreak}',
              label: 'Day Streak',
              color: ManropeTheme.primaryOrange,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.timer_outlined,
              value: '${_wellnessService.todayMinutes}',
              label: 'Min Today',
              color: ManropeTheme.accentGreen,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle_outline_rounded,
              value: '${_wellnessService.todaySessions}',
              label: 'Sessions',
              color: ManropeTheme.deepPurple,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
        borderRadius: ManropeTheme.borderRadiusLarge,
        boxShadow: ManropeTheme.shadowSmall,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: ManropeTheme.borderRadiusMedium,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: ManropeTheme.titleLarge.copyWith(
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: ManropeTheme.labelSmall.copyWith(
              color: isDark
                  ? ManropeTheme.textTertiaryDark
                  : ManropeTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGrid(bool isDark) {
    final activities = WellnessActivityType.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activities',
                style: ManropeTheme.titleLarge.copyWith(
                  color: isDark
                      ? ManropeTheme.textPrimaryDark
                      : ManropeTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _navigateToStats(),
                child: Text(
                  'View All',
                  style: ManropeTheme.labelMedium.copyWith(
                    color: ManropeTheme.primaryOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return _buildActivityCard(activity, index, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    WellnessActivityType activity,
    int index,
    bool isDark,
  ) {
    final isHovered = _hoveredActivityIndex == index;
    final todayMinutes = _wellnessService.getActivityMinutesToday(activity);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredActivityIndex = index),
      onExit: (_) => setState(() => _hoveredActivityIndex = -1),
      child: GestureDetector(
        onTap: () => _navigateToActivity(activity),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isHovered ? 1.02 : 1.0,
              child: AnimatedContainer(
                duration: ManropeTheme.durationFast,
                decoration: BoxDecoration(
                  gradient: activity.gradient,
                  borderRadius: ManropeTheme.borderRadiusXLarge,
                  boxShadow: isHovered
                      ? ManropeTheme.shadowColored(activity.primaryColor)
                      : ManropeTheme.shadowMedium,
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Opacity(
                        opacity: 0.2,
                        child: Icon(
                          activity.icon,
                          size: 100,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: ManropeTheme.borderRadiusMedium,
                            ),
                            child: Icon(
                              activity.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            activity.displayName,
                            style: ManropeTheme.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: Colors.white.withOpacity(0.8),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                todayMinutes > 0
                                    ? '$todayMinutes min today'
                                    : 'Start now',
                                style: ManropeTheme.labelSmall.copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodaySchedule(bool isDark) {
    final routine = _wellnessService.activeRoutine;
    if (routine == null || routine.activities.isEmpty) {
      return _buildEmptySchedule(isDark);
    }

    final todayActivities = routine.sortedActivities;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Schedule",
                style: ManropeTheme.titleLarge.copyWith(
                  color: isDark
                      ? ManropeTheme.textPrimaryDark
                      : ManropeTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ManropeTheme.accentGreen.withOpacity(0.1),
                  borderRadius: ManropeTheme.borderRadiusRound,
                ),
                child: Text(
                  '${routine.completedCount}/${routine.activityCount}',
                  style: ManropeTheme.labelMedium.copyWith(
                    color: ManropeTheme.accentGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...todayActivities.map((activity) => _buildScheduleItem(
                activity,
                isDark,
              )),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(RoutineActivity activity, bool isDark) {
    final activityType = activity.activityType;
    final isPast = _isTimePast(activity.hour, activity.minute);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
        borderRadius: ManropeTheme.borderRadiusLarge,
        boxShadow: ManropeTheme.shadowSmall,
        border: activity.isCompleted
            ? Border.all(color: ManropeTheme.accentGreen, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: activityType.gradient,
              borderRadius: ManropeTheme.borderRadiusMedium,
            ),
            child: Icon(
              activityType.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityType.displayName,
                  style: ManropeTheme.titleSmall.copyWith(
                    color: isDark
                        ? ManropeTheme.textPrimaryDark
                        : ManropeTheme.textPrimary,
                    decoration: activity.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activity.timeDisplay} • ${activity.durationMinutes} min',
                  style: ManropeTheme.bodySmall.copyWith(
                    color: isDark
                        ? ManropeTheme.textTertiaryDark
                        : ManropeTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (activity.isCompleted)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ManropeTheme.accentGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: ManropeTheme.accentGreen,
                size: 20,
              ),
            )
          else if (isPast)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ManropeTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule,
                color: ManropeTheme.error,
                size: 20,
              ),
            )
          else
            GestureDetector(
              onTap: () => _navigateToActivity(activityType),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: activityType.gradient,
                  borderRadius: ManropeTheme.borderRadiusRound,
                ),
                child: Text(
                  'Start',
                  style: ManropeTheme.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySchedule(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
          borderRadius: ManropeTheme.borderRadiusXLarge,
          boxShadow: ManropeTheme.shadowSmall,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ManropeTheme.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: ManropeTheme.primaryOrange,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Schedule Set',
              style: ManropeTheme.titleMedium.copyWith(
                color: isDark
                    ? ManropeTheme.textPrimaryDark
                    : ManropeTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a daily routine to stay consistent with your wellness practice',
              textAlign: TextAlign.center,
              style: ManropeTheme.bodySmall.copyWith(
                color: isDark
                    ? ManropeTheme.textTertiaryDark
                    : ManropeTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _navigateToReminders(),
              style: ElevatedButton.styleFrom(
                backgroundColor: ManropeTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: ManropeTheme.borderRadiusRound,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Create Routine'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationCard(bool isDark) {
    final quotes = [
      'The mind is everything. What you think you become.',
      'Calm mind brings inner strength and self-confidence.',
      'In the midst of movement and chaos, keep stillness inside of you.',
      'Peace comes from within. Do not seek it without.',
      'The present moment is the only moment available to us.',
    ];
    final quote = quotes[DateTime.now().day % quotes.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: ManropeTheme.warmSunset,
          borderRadius: ManropeTheme.borderRadiusXXLarge,
          boxShadow: ManropeTheme.shadowMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ManropeTheme.primaryOrange.withOpacity(0.2),
                    borderRadius: ManropeTheme.borderRadiusMedium,
                  ),
                  child: const Icon(
                    Icons.format_quote_rounded,
                    color: ManropeTheme.primaryOrangeDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Daily Inspiration',
                  style: ManropeTheme.titleSmall.copyWith(
                    color: ManropeTheme.primaryOrangeDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              quote,
              style: ManropeTheme.bodyLarge.copyWith(
                color: ManropeTheme.textPrimary,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isTimePast(int hour, int minute) {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    return now.isAfter(scheduledTime);
  }

  void _navigateToActivity(WellnessActivityType activity) {
    _hapticService.selection();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ManropeActivityScreen(activityType: activity),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: ManropeTheme.durationMedium,
      ),
    );
  }

  void _navigateToStats() {
    _hapticService.selection();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManropeStatsScreen()),
    );
  }

  void _navigateToReminders() {
    _hapticService.selection();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManropeRemindersScreen()),
    );
  }
}
