import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/haptic_service.dart';
import '../theme/manrope_theme.dart';
import '../models/meditation_activity.dart';
import '../services/manrope_wellness_service.dart';

class ManropeStatsScreen extends StatefulWidget {
  const ManropeStatsScreen({super.key});

  @override
  State<ManropeStatsScreen> createState() => _ManropeStatsScreenState();
}

class _ManropeStatsScreenState extends State<ManropeStatsScreen>
    with TickerProviderStateMixin {
  final ManropeWellnessService _wellnessService = ManropeWellnessService();
  final HapticService _hapticService = HapticService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
              : ManropeTheme.background,
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
                          const SizedBox(height: 16),
                          _buildPeriodSelector(isDark),
                          const SizedBox(height: 24),
                          _buildOverviewCards(isDark),
                          const SizedBox(height: 24),
                          _buildCalendarHeatmap(isDark),
                          const SizedBox(height: 24),
                          _buildActivityBreakdown(isDark),
                          const SizedBox(height: 24),
                          _buildStreakSection(isDark),
                          const SizedBox(height: 24),
                          _buildInsightsCard(isDark),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Symbols.arrow_back_rounded,
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Statistics',
              style: ManropeTheme.titleLarge.copyWith(
                color: isDark
                    ? ManropeTheme.textPrimaryDark
                    : ManropeTheme.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: ManropeTheme.primaryGradient,
              borderRadius: ManropeTheme.borderRadiusMedium,
            ),
            child: const Icon(
              Symbols.bar_chart_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ['Week', 'Month', 'Year'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? ManropeTheme.backgroundDarkCard
              : ManropeTheme.surfaceLight,
          borderRadius: ManropeTheme.borderRadiusRound,
        ),
        child: Row(
          children: periods.asMap().entries.map((entry) {
            final index = entry.key;
            final period = entry.value;
            final isSelected = _selectedPeriod == index;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  _hapticService.selection();
                  setState(() => _selectedPeriod = index);
                },
                child: AnimatedContainer(
                  duration: ManropeTheme.durationFast,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected ? ManropeTheme.primaryGradient : null,
                    borderRadius: ManropeTheme.borderRadiusRound,
                  ),
                  child: Text(
                    period,
                    textAlign: TextAlign.center,
                    style: ManropeTheme.labelLarge.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? ManropeTheme.textSecondaryDark
                              : ManropeTheme.textSecondary),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(bool isDark) {
    final stats = _wellnessService.stats;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewCard(
              title: 'Total Time',
              value: '${stats.totalMinutes}',
              unit: 'min',
              icon: Symbols.timer_rounded,
              color: ManropeTheme.primaryOrange,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildOverviewCard(
              title: 'Sessions',
              value: '${stats.completedSessions}',
              unit: 'completed',
              icon: Symbols.check_circle_rounded,
              color: ManropeTheme.accentGreen,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
        borderRadius: ManropeTheme.borderRadiusXLarge,
        boxShadow: ManropeTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: ManropeTheme.borderRadiusMedium,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: ManropeTheme.headlineMedium.copyWith(
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
          Text(
            unit,
            style: ManropeTheme.bodySmall.copyWith(
              color: isDark
                  ? ManropeTheme.textTertiaryDark
                  : ManropeTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: ManropeTheme.labelMedium.copyWith(
              color: isDark
                  ? ManropeTheme.textSecondaryDark
                  : ManropeTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeatmap(bool isDark) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
          borderRadius: ManropeTheme.borderRadiusXLarge,
          boxShadow: ManropeTheme.shadowMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity Calendar',
                  style: ManropeTheme.titleMedium.copyWith(
                    color: isDark
                        ? ManropeTheme.textPrimaryDark
                        : ManropeTheme.textPrimary,
                  ),
                ),
                Text(
                  _getMonthName(now.month),
                  style: ManropeTheme.labelMedium.copyWith(
                    color: ManropeTheme.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final date = DateTime(now.year, now.month, day);
                final hasActivity = _wellnessService.hasActivityOn(date);
                final isToday = day == now.day;

                return Container(
                  decoration: BoxDecoration(
                    color: hasActivity
                        ? ManropeTheme.accentGreen
                        : (isDark
                            ? ManropeTheme.backgroundDarkElevated
                            : ManropeTheme.surfaceLight),
                    borderRadius: ManropeTheme.borderRadiusSmall,
                    border: isToday
                        ? Border.all(
                            color: ManropeTheme.primaryOrange,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: ManropeTheme.labelSmall.copyWith(
                        color: hasActivity
                            ? Colors.white
                            : (isDark
                                ? ManropeTheme.textTertiaryDark
                                : ManropeTheme.textTertiary),
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityBreakdown(bool isDark) {
    final stats = _wellnessService.stats;
    final activities = WellnessActivityType.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
          borderRadius: ManropeTheme.borderRadiusXLarge,
          boxShadow: ManropeTheme.shadowMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Breakdown',
              style: ManropeTheme.titleMedium.copyWith(
                color: isDark
                    ? ManropeTheme.textPrimaryDark
                    : ManropeTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ...activities.map((activity) {
              final minutes = stats.minutesByActivity[activity.id] ?? 0;
              final sessions = stats.sessionsByActivity[activity.id] ?? 0;
              final maxMinutes = stats.minutesByActivity.values.isEmpty
                  ? 1
                  : stats.minutesByActivity.values
                      .reduce((a, b) => a > b ? a : b);
              final progress = maxMinutes > 0 ? minutes / maxMinutes : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: activity.gradient,
                            borderRadius: ManropeTheme.borderRadiusSmall,
                          ),
                          child: Icon(
                            activity.icon,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activity.displayName,
                            style: ManropeTheme.labelLarge.copyWith(
                              color: isDark
                                  ? ManropeTheme.textPrimaryDark
                                  : ManropeTheme.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$minutes min',
                          style: ManropeTheme.labelMedium.copyWith(
                            color: activity.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: ManropeTheme.borderRadiusSmall,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark
                            ? ManropeTheme.backgroundDarkElevated
                            : ManropeTheme.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          activity.primaryColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sessions sessions',
                      style: ManropeTheme.labelSmall.copyWith(
                        color: isDark
                            ? ManropeTheme.textTertiaryDark
                            : ManropeTheme.textTertiary,
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

  Widget _buildStreakSection(bool isDark) {
    final stats = _wellnessService.stats;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: ManropeTheme.meditationGradient,
          borderRadius: ManropeTheme.borderRadiusXXLarge,
          boxShadow: ManropeTheme.shadowColored(ManropeTheme.primaryOrange),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🔥',
                        style: TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Streak',
                            style: ManropeTheme.labelMedium.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            '${stats.currentStreak} days',
                            style: ManropeTheme.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 60,
              width: 1,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Longest',
                    style: ManropeTheme.labelMedium.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    '${stats.longestStreak} days',
                    style: ManropeTheme.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(bool isDark) {
    final stats = _wellnessService.stats;
    final avgSession = stats.averageSessionMinutes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
          borderRadius: ManropeTheme.borderRadiusXLarge,
          boxShadow: ManropeTheme.shadowMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ManropeTheme.deepPurple.withOpacity(0.1),
                    borderRadius: ManropeTheme.borderRadiusMedium,
                  ),
                  child: const Icon(
                    Symbols.lightbulb_rounded,
                    color: ManropeTheme.deepPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Insights',
                  style: ManropeTheme.titleMedium.copyWith(
                    color: isDark
                        ? ManropeTheme.textPrimaryDark
                        : ManropeTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInsightRow(
              icon: Symbols.schedule_rounded,
              text: 'Average session: $avgSession minutes',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: Symbols.trending_up_rounded,
              text: 'Completion rate: ${(stats.completionRate * 100).toInt()}%',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildInsightRow(
              icon: Symbols.calendar_today_rounded,
              text: stats.lastSessionDate != null
                  ? 'Last session: ${_formatDate(stats.lastSessionDate!)}'
                  : 'No sessions yet',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark
              ? ManropeTheme.textTertiaryDark
              : ManropeTheme.textTertiary,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: ManropeTheme.bodyMedium.copyWith(
            color: isDark
                ? ManropeTheme.textSecondaryDark
                : ManropeTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day} ${_getMonthName(date.month).substring(0, 3)}';
  }
}
