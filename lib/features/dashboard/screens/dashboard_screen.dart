
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/models/action_log.dart';
import '../../medication/models/medicine.dart';
import '../../health_check/models/health_check.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../fitness/models/fitness_reminder.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/models/action_log.dart';
import '../../medication/models/enhanced_medicine.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../health_check/models/health_check.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../fitness/models/fitness_reminder.dart';
import '../../dashboard/widgets/banner_ad_placeholder.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicines = MedicineStorageService.getActiveMedicinesForToday();
    final healthChecks = StorageService.getAllHealthChecks();
    final waterData = WaterService.getTodayData();
    final fitnessReminders = StorageService.getAllFitnessReminders();
    final today = DateTime.now();
    
    // Get real analytics data
    final medicineStats = MedicineStorageService.getAdherenceStats(days: 7);
    final fitnessStats = StorageService.getFitnessStats(days: 7);
    
    final wStats = WaterService.getWeeklyStats();
    final dailyGoal = WaterService.getDailyGoal();
    final avgDailyMl = wStats['averageMl'] as int;
    final waterStats = {
      'avgDailyMl': avgDailyMl,
      'dailyGoal': dailyGoal,
      'avgCompletionRate': dailyGoal > 0 ? (avgDailyMl / dailyGoal * 100).round() : 0,
    };

    final focusService = FocusModeService();
    final todayLogs = StorageService.getActionLogsForDate(today);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(today),
                  const SizedBox(height: 24),

                  // Premium Hero Analytics Card
                  _buildHeroAnalyticsCard(
                    medicineStats: medicineStats,
                    waterStats: waterStats,
                    fitnessStats: fitnessStats,
                    focusMinutes: focusService.todayMinutes,
                    waterData: waterData,
                    medicines: medicines,
                  ),
                  const SizedBox(height: 24),

                  // Category Analytics Section
                  _buildSectionHeader('Health Analytics', icon: Icons.analytics_rounded),
                  const SizedBox(height: 14),
                  _buildCategoryAnalyticsGrid(
                    medicineStats: medicineStats,
                    waterStats: waterStats,
                    fitnessStats: fitnessStats,
                    focusService: focusService,
                  ),
                  const SizedBox(height: 28),

                  // Insights & Recommendations
                  _buildSectionHeader('Smart Insights', icon: Icons.lightbulb_rounded),
                  const SizedBox(height: 14),
                  _buildInsightsSection(
                    medicineStats: medicineStats,
                    waterStats: waterStats,
                    fitnessStats: fitnessStats,
                    focusMinutes: focusService.todayMinutes,
                  ),
                  const SizedBox(height: 28),

                  // Weekly Trends
                  _buildSectionHeader('Weekly Trends', icon: Icons.trending_up_rounded),
                  const SizedBox(height: 14),
                  _buildWeeklyTrendsCard(medicineStats, waterStats, fitnessStats),
                  const SizedBox(height: 28),

                  // Today's Activity Timeline
                  _buildSectionHeader('Today\'s Activity', icon: Icons.timeline_rounded),
                  const SizedBox(height: 14),
                  _buildActivityTimeline(todayLogs),
                  const SizedBox(height: 28),

                  // Banner Ad
                  const BannerAdPlaceholder(),
                  const SizedBox(height: 28),

                  // Upcoming Schedule
                  _buildSectionHeader('Upcoming Schedule', icon: Icons.schedule_rounded),
                  const SizedBox(height: 14),
                  _buildScheduleList(medicines, healthChecks, fitnessReminders),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DateTime today) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success.withOpacity(0.2),
                        AppColors.success.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d').format(today),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Container(
         
        child: SvgPicture.asset(
  'assets/images/logo.svg',
  height: 72,
  fit: BoxFit.contain,
),

        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        if (icon != null) ...[
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  // ============ PREMIUM HERO ANALYTICS CARD ============
  Widget _buildHeroAnalyticsCard({
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> waterStats,
    required Map<String, dynamic> fitnessStats,
    required int focusMinutes,
    required DailyWaterData? waterData,
    required List<EnhancedMedicine> medicines,
  }) {
    final medAdherence = (medicineStats['adherenceRate'] as int).toDouble() / 100;
    final waterCompletion = waterData?.progress ?? 0.0;
    final fitnessRate = (fitnessStats['completionRate'] as int).toDouble() / 100;
    const focusGoal = 60; // 1 hour daily goal
    final focusProgress = (focusMinutes / focusGoal).clamp(0.0, 1.0);
    final overallScore = ((medAdherence + waterCompletion + fitnessRate + focusProgress) / 4 * 100).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.98),
                  Colors.white.withOpacity(0.9),
                  AppColors.primaryLight.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Premium Multi-ring Progress
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CustomPaint(
                        painter: _MultiRingProgressPainter(
                          medProgress: medAdherence,
                          waterProgress: waterCompletion,
                          fitnessProgress: fitnessRate,
                          focusProgress: focusProgress,
                        ),
                        child: Center(
                          child: Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Colors.white.withOpacity(0.9)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$overallScore',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Health Score',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildScoreBadge(overallScore),
                          const SizedBox(height: 10),
                          const Text(
                            'Daily Wellness',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getMotivationalMessage(overallScore),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress Legend
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                        icon: Icons.medication_rounded,
                        color: AppColors.primary,
                        label: 'Medicine',
                        value: '${(medAdherence * 100).round()}%',
                      ),
                      _buildVerticalDivider(),
                      _buildMiniStat(
                        icon: Icons.water_drop_rounded,
                        color: AppColors.info,
                        label: 'Hydration',
                        value: '${(waterCompletion * 100).round()}%',
                      ),
                      _buildVerticalDivider(),
                      _buildMiniStat(
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.warning,
                        label: 'Fitness',
                        value: '${(fitnessRate * 100).round()}%',
                      ),
                      _buildVerticalDivider(),
                      _buildMiniStat(
                        icon: Icons.self_improvement_rounded,
                        color: AppColors.focusPrimary,
                        label: 'Focus',
                        value: '${focusMinutes}m',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge(int score) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (score >= 80) {
      bgColor = AppColors.success.withOpacity(0.15);
      textColor = AppColors.success;
      label = 'Excellent';
      icon = Icons.star_rounded;
    } else if (score >= 60) {
      bgColor = AppColors.primary.withOpacity(0.15);
      textColor = AppColors.primary;
      label = 'Good';
      icon = Icons.trending_up_rounded;
    } else if (score >= 40) {
      bgColor = AppColors.warning.withOpacity(0.15);
      textColor = AppColors.warning;
      label = 'Fair';
      icon = Icons.remove_rounded;
    } else {
      bgColor = AppColors.error.withOpacity(0.15);
      textColor = AppColors.error;
      label = 'Needs Work';
      icon = Icons.trending_down_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }

  String _getMotivationalMessage(int score) {
    if (score >= 80) return "Outstanding! You're crushing your health goals!";
    if (score >= 60) return "Great progress! Keep up the momentum.";
    if (score >= 40) return "You're on track. Push a little harder!";
    return "Every step counts. Let's improve today!";
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 50,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.border.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ============ CATEGORY ANALYTICS GRID ============
  Widget _buildCategoryAnalyticsGrid({
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> waterStats,
    required Map<String, dynamic> fitnessStats,
    required FocusModeService focusService,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Medicine',
                icon: Icons.medication_rounded,
                color: AppColors.primary,
                mainValue: '${medicineStats['adherenceRate']}%',
                mainLabel: 'Adherence',
                stats: [
                  {'label': 'Taken', 'value': '${medicineStats['taken']}'},
                  {'label': 'Skipped', 'value': '${medicineStats['skipped']}'},
                ],
                trend: medicineStats['adherenceRate'] >= 80 ? 'up' : 'down',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Hydration',
                icon: Icons.water_drop_rounded,
                color: AppColors.info,
                mainValue: '${(waterStats['avgDailyMl'] / 1000).toStringAsFixed(1)}L',
                mainLabel: 'Daily Avg',
                stats: [
                  {'label': 'Goal', 'value': '${(waterStats['dailyGoal'] / 1000).toStringAsFixed(1)}L'},
                  {'label': 'Rate', 'value': '${waterStats['avgCompletionRate']}%'},
                ],
                trend: waterStats['avgCompletionRate'] >= 70 ? 'up' : 'down',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Fitness',
                icon: Icons.fitness_center_rounded,
                color: AppColors.warning,
                mainValue: '${fitnessStats['totalMinutes']}',
                mainLabel: 'Minutes',
                stats: [
                  {'label': 'Sessions', 'value': '${fitnessStats['completed']}'},
                  {'label': 'Rate', 'value': '${fitnessStats['completionRate']}%'},
                ],
                trend: fitnessStats['completionRate'] >= 70 ? 'up' : 'down',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnalyticsCard(
                title: 'Focus',
                icon: Icons.self_improvement_rounded,
                color: AppColors.focusPrimary,
                mainValue: '${focusService.todayMinutes}m',
                mainLabel: 'Today',
                stats: [
                  {'label': 'Week', 'value': '${focusService.weekMinutes}m'},
                  {'label': 'Sessions', 'value': '${focusService.totalSessions}'},
                ],
                trend: focusService.todayMinutes >= 30 ? 'up' : 'neutral',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required IconData icon,
    required Color color,
    required String mainValue,
    required String mainLabel,
    required List<Map<String, String>> stats,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              _buildTrendIndicator(trend, color),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            mainLabel,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: stats.map((stat) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat['value']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    stat['label']!,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendIndicator(String trend, Color color) {
    IconData icon;
    Color bgColor;
    
    switch (trend) {
      case 'up':
        icon = Icons.trending_up_rounded;
        bgColor = AppColors.success;
        break;
      case 'down':
        icon = Icons.trending_down_rounded;
        bgColor = AppColors.error;
        break;
      default:
        icon = Icons.remove_rounded;
        bgColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: bgColor),
    );
  }

  // ============ INSIGHTS SECTION ============
  Widget _buildInsightsSection({
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> waterStats,
    required Map<String, dynamic> fitnessStats,
    required int focusMinutes,
  }) {
    final insights = _generateInsights(medicineStats, waterStats, fitnessStats, focusMinutes);
    
    return Column(
      children: insights.map((insight) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildInsightCard(
          icon: insight['icon'] as IconData,
          color: insight['color'] as Color,
          title: insight['title'] as String,
          description: insight['description'] as String,
          action: insight['action'] as String?,
        ),
      )).toList(),
    );
  }

  List<Map<String, dynamic>> _generateInsights(
    Map<String, dynamic> medicineStats,
    Map<String, dynamic> waterStats,
    Map<String, dynamic> fitnessStats,
    int focusMinutes,
  ) {
    final insights = <Map<String, dynamic>>[];

    // Medicine insights
    if (medicineStats['adherenceRate'] < 80) {
      insights.add({
        'icon': Icons.medication_rounded,
        'color': AppColors.primary,
        'title': 'Medicine Reminder',
        'description': 'Your adherence is ${medicineStats['adherenceRate']}%. Try setting earlier reminders.',
        'action': 'Set Reminder',
      });
    } else {
      insights.add({
        'icon': Icons.check_circle_rounded,
        'color': AppColors.success,
        'title': 'Great Medication Habits!',
        'description': 'You\'ve maintained ${medicineStats['adherenceRate']}% adherence this week.',
        'action': null,
      });
    }

    // Water insights
    if (waterStats['avgCompletionRate'] < 70) {
      insights.add({
        'icon': Icons.water_drop_rounded,
        'color': AppColors.info,
        'title': 'Hydration Goal',
        'description': 'Averaging ${waterStats['avgCompletionRate']}% of daily goal. Drink more water!',
        'action': 'Log Water',
      });
    }

    // Fitness insights
    if (fitnessStats['totalMinutes'] < 150) {
      insights.add({
        'icon': Icons.fitness_center_rounded,
        'color': AppColors.warning,
        'title': 'Activity Boost Needed',
        'description': 'Only ${fitnessStats['totalMinutes']} mins this week. WHO recommends 150 mins.',
        'action': 'Start Workout',
      });
    }

    // Focus insights
    if (focusMinutes < 30) {
      insights.add({
        'icon': Icons.self_improvement_rounded,
        'color': AppColors.focusPrimary,
        'title': 'Focus Time',
        'description': 'You\'ve focused for $focusMinutes mins today. Try a focus session!',
        'action': 'Start Focus',
      });
    }

    return insights.take(3).toList();
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    String? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.08)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ WEEKLY TRENDS CARD ============
  Widget _buildWeeklyTrendsCard(
    Map<String, dynamic> medicineStats,
    Map<String, dynamic> waterStats,
    Map<String, dynamic> fitnessStats,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '7-Day Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTrendRow('Medicine', medicineStats['adherenceRate'], AppColors.primary, Icons.medication_rounded),
          const SizedBox(height: 14),
          _buildTrendRow('Hydration', waterStats['avgCompletionRate'], AppColors.info, Icons.water_drop_rounded),
          const SizedBox(height: 14),
          _buildTrendRow('Fitness', fitnessStats['completionRate'], AppColors.warning, Icons.fitness_center_rounded),
        ],
      ),
    );
  }

  Widget _buildTrendRow(String label, int percentage, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============ ACTIVITY TIMELINE ============
  Widget _buildActivityTimeline(List<ActionLog> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.timeline_rounded, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'No activity yet today',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Your actions will appear here',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: logs.take(5).map((log) => _buildTimelineItem(log)).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(ActionLog log) {
    Color color;
    IconData icon;

    switch (log.type) {
      case ActionType.medicineTaken:
        color = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case ActionType.medicineSkipped:
        color = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      case ActionType.waterLogged:
        color = AppColors.info;
        icon = Icons.water_drop_rounded;
        break;
      case ActionType.fitnessCompleted:
        color = AppColors.warning;
        icon = Icons.fitness_center_rounded;
        break;
      case ActionType.healthCheckDone:
        color = AppColors.primary;
        icon = Icons.favorite_rounded;
        break;
      default:
        color = AppColors.textSecondary;
        icon = Icons.circle;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title ?? log.displayType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('h:mm a').format(log.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getActionLabel(log.type),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionLabel(ActionType type) {
    switch (type) {
      case ActionType.medicineTaken:
        return 'Taken';
      case ActionType.medicineSkipped:
        return 'Skipped';
      case ActionType.waterLogged:
        return 'Logged';
      case ActionType.fitnessCompleted:
        return 'Done';
      case ActionType.healthCheckDone:
        return 'Checked';
      default:
        return '';
    }
  }

  Widget _buildScheduleList(List<EnhancedMedicine> medicines, List<HealthCheck> healthChecks, List<FitnessReminder> fitnessReminders) {
    if (medicines.isEmpty && healthChecks.isEmpty && fitnessReminders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'No schedule yet',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // Process medicines to get individual doses sorted by time
    final now = DateTime.now();
    final todayLogs = MedicineStorageService.getLogsForDate(now);
    final List<Map<String, dynamic>> upcomingDoses = [];

    for (final medicine in medicines) {
      if (medicine.isPRN) continue;
      
      final times = medicine.schedule.getScheduledTimesForDate(now);
      for (final time in times) {
        // Check if taken
        final isTaken = todayLogs.any((log) => 
          log.medicineId == medicine.id && 
          log.scheduledTime.hour == time.hour &&
          log.scheduledTime.minute == time.minute &&
          log.isTaken
        );

        // Only show if not taken, or taken very recently? 
        // For dashboard usually we show upcoming.
        // Let's include all for today that are after now, or maybe the next few inclusive of now?
        // Let's stick to showing next 3 items regardless of type (med, health, fitness)
        
        // We'll create a common structure to sort them
        upcomingDoses.add({
          'type': 'medicine',
          'time': time,
          'data': medicine,
          'isTaken': isTaken,
        });
      }
    }

    // Add health checks and fitness reminders to the list
    for (final h in healthChecks) {
      upcomingDoses.add({
        'type': 'health_check',
        'time': h.reminderTime,
        'data': h,
        'isTaken': false, // Logic for health check done?
      });
    }

    for (final f in fitnessReminders) {
      upcomingDoses.add({
        'type': 'fitness',
        'time': f.reminderTime,
        'data': f,
        'isTaken': false,
      });
    }

    // Sort by time
    upcomingDoses.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
    
    // Filter to only show future items or items from today 
    // (Since we only fetched today's items above, the list is already scoped to today)
    // Let's maybe filter out items that are passed AND taken/done?
    final displayItems = upcomingDoses.where((item) {
       // Optional: Filter logic here. For now show all today sorted.
       return true;
    }).toList();


    return Column(
      children: [
        ...displayItems.take(3).map((item) {
            final type = item['type'] as String;
            final time = item['time'] as DateTime;
            
            if (type == 'medicine') {
              final m = item['data'] as EnhancedMedicine;
              final isTaken = item['isTaken'] as bool;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildScheduleCard(
                  icon: Icons.medication_rounded,
                  color: isTaken ? AppColors.success : AppColors.primary,
                  title: m.name,
                  subtitle: '${m.displayDosage} ${isTaken ? "(Taken)" : ""}',
                  time: DateFormat('h:mm a').format(time),
                ),
              );
            } else if (type == 'health_check') {
              final h = item['data'] as HealthCheck;
               return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildScheduleCard(
                  icon: Icons.favorite_rounded,
                  color: AppColors.error,
                  title: h.title,
                  subtitle: h.frequency,
                  time: DateFormat('h:mm a').format(time),
                ),
              );
            } else {
               final f = item['data'] as FitnessReminder;
               return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildScheduleCard(
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.warning,
                  title: f.title,
                  subtitle: '${f.durationMinutes} min • ${f.frequency}',
                  time: DateFormat('h:mm a').format(time),
                ),
              );
            }
        }),
      ],
    );
  }

  Widget _buildScheduleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiRingProgressPainter extends CustomPainter {
  final double medProgress;
  final double waterProgress;
  final double fitnessProgress;
  final double focusProgress;

  _MultiRingProgressPainter({
    required this.medProgress,
    required this.waterProgress,
    required this.fitnessProgress,
    required this.focusProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 8.0;
    const gap = 4.0;

    final rings = [
      {'progress': focusProgress, 'color': AppColors.success, 'radius': size.width / 2 - strokeWidth / 2},
      {'progress': fitnessProgress, 'color': AppColors.warning, 'radius': size.width / 2 - strokeWidth - gap - strokeWidth / 2},
      {'progress': waterProgress, 'color': AppColors.info, 'radius': size.width / 2 - (strokeWidth + gap) * 2 - strokeWidth / 2},
      {'progress': medProgress, 'color': AppColors.primary, 'radius': size.width / 2 - (strokeWidth + gap) * 3 - strokeWidth / 2},
    ];

    for (var ring in rings) {
      final radius = ring['radius'] as double;
      final progress = (ring['progress'] as double).clamp(0.0, 1.0);
      final color = ring['color'] as Color;

      // Background ring
      final bgPaint = Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, bgPaint);

      // Progress arc
      if (progress > 0) {
        final progressPaint = Paint()
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: math.pi * 1.5,
            colors: [
              color,
              color.withOpacity(0.8),
              color,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        final sweepAngle = 2 * math.pi * progress;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -math.pi / 2,
          sweepAngle,
          false,
          progressPaint,
        );

        // End cap glow effect
        final endAngle = -math.pi / 2 + sweepAngle;
        final endX = center.dx + radius * math.cos(endAngle);
        final endY = center.dy + radius * math.sin(endAngle);

        final glowPaint = Paint()
          ..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawCircle(Offset(endX, endY), strokeWidth / 2, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiRingProgressPainter oldDelegate) {
    return oldDelegate.medProgress != medProgress ||
        oldDelegate.waterProgress != waterProgress ||
        oldDelegate.fitnessProgress != fitnessProgress ||
        oldDelegate.focusProgress != focusProgress;
  }
}
