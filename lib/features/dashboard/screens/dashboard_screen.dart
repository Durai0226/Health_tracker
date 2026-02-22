
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../../core/services/category_manager.dart';
import '../../../core/models/action_log.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../medication/models/enhanced_medicine.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../fitness/models/fitness_reminder.dart';
import '../../../widgets/smart_ad_widgets.dart';
import '../../exam_prep/services/exam_prep_service.dart';
import '../../finance/services/finance_storage_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final CategoryManager _categoryManager = CategoryManager();
  
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
    final selectedCategory = _categoryManager.selectedCategory;
    final today = DateTime.now();
    final todayLogs = StorageService.getActionLogsForDate(today);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
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
                  
                  // Category-specific content
                  ..._buildCategoryContent(selectedCategory, today, todayLogs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryContent(AppCategory? category, DateTime today, List<ActionLog> todayLogs) {
    switch (category) {
      case AppCategory.health:
        return _buildHealthCategoryContent(today, todayLogs);
      case AppCategory.productivity:
        return _buildProductivityCategoryContent(today, todayLogs);
      case AppCategory.fitness:
        return _buildFitnessCategoryContent(today, todayLogs);
      case AppCategory.finance:
        return _buildFinanceCategoryContent(today, todayLogs);
      case AppCategory.periodTracking:
        return _buildHealthCategoryContent(today, todayLogs); // Similar to health
      case null:
        return _buildHealthCategoryContent(today, todayLogs); // Default to health
    }
  }

  // Health Category Content (Medicine, Water, Reminders)
  List<Widget> _buildHealthCategoryContent(DateTime today, List<ActionLog> todayLogs) {
    final medicines = MedicineStorageService.getActiveMedicinesForToday();
    final waterData = WaterService.getTodayData();
    final fitnessReminders = StorageService.getAllFitnessReminders();
    
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

    return [
      // Hero Analytics Card
      _buildHeroAnalyticsCard(
        medicineStats: medicineStats,
        waterStats: waterStats,
        fitnessStats: fitnessStats,
        focusMinutes: focusService.todayMinutes,
        waterData: waterData,
        medicines: medicines,
      ),
      const SizedBox(height: 24),

      // Health Analytics Section
      _buildSectionHeader('Health Analytics', icon: Icons.analytics_rounded),
      const SizedBox(height: 14),
      _buildCategoryAnalyticsGrid(
        medicineStats: medicineStats,
        waterStats: waterStats,
        fitnessStats: fitnessStats,
        focusService: focusService,
      ),
      const SizedBox(height: 28),

      // Insights
      _buildSectionHeader('Smart Insights', icon: Icons.lightbulb_rounded),
      const SizedBox(height: 14),
      _buildInsightsSection(
        medicineStats: medicineStats,
        waterStats: waterStats,
        fitnessStats: fitnessStats,
        focusMinutes: focusService.todayMinutes,
      ),
      const SizedBox(height: 28),

      // Streaks & Goals
      _buildSectionHeader('Streaks & Goals', icon: Icons.local_fire_department_rounded),
      const SizedBox(height: 14),
      _buildStreaksAndGoalsSection(
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

      // Activity Timeline
      _buildSectionHeader('Today\'s Activity', icon: Icons.timeline_rounded),
      const SizedBox(height: 14),
      _buildActivityTimeline(todayLogs),
      const SizedBox(height: 28),

      const SmartDashboardBanner(),
      const SizedBox(height: 28),

      // Schedule
      _buildSectionHeader('Upcoming Schedule', icon: Icons.schedule_rounded),
      const SizedBox(height: 14),
      _buildScheduleList(medicines, fitnessReminders),
    ];
  }

  // Productivity Category Content (Focus, Notes, Exam Prep)
  List<Widget> _buildProductivityCategoryContent(DateTime today, List<ActionLog> todayLogs) {
    final focusService = FocusModeService();

    return [
      // Productivity Hero Card
      _buildProductivityHeroCard(focusService),
      const SizedBox(height: 24),

      // Focus Analytics
      _buildSectionHeader('Focus Analytics', icon: Icons.psychology_rounded),
      const SizedBox(height: 14),
      _buildProductivityAnalyticsGrid(focusService),
      const SizedBox(height: 28),

      // Study Progress (Exam Prep)
      _buildSectionHeader('Study Progress', icon: Icons.school_rounded),
      const SizedBox(height: 14),
      _buildStudyProgressCard(),
      const SizedBox(height: 28),

      // Notes Overview
      _buildSectionHeader('Recent Notes', icon: Icons.note_alt_rounded),
      const SizedBox(height: 14),
      _buildNotesOverviewCard(),
      const SizedBox(height: 28),

      // Focus Insights
      _buildSectionHeader('Productivity Insights', icon: Icons.lightbulb_rounded),
      const SizedBox(height: 14),
      _buildProductivityInsights(focusService),
      const SizedBox(height: 28),

      const SmartDashboardBanner(),
      const SizedBox(height: 28),

      // Activity Timeline
      _buildSectionHeader('Today\'s Activity', icon: Icons.timeline_rounded),
      const SizedBox(height: 14),
      _buildActivityTimeline(todayLogs),
    ];
  }

  // Fitness Category Content
  List<Widget> _buildFitnessCategoryContent(DateTime today, List<ActionLog> todayLogs) {
    final fitnessReminders = StorageService.getAllFitnessReminders();
    final fitnessStats = StorageService.getFitnessStats(days: 7);

    return [
      // Fitness Hero Card
      _buildFitnessHeroCard(fitnessStats),
      const SizedBox(height: 24),

      // Fitness Analytics
      _buildSectionHeader('Fitness Analytics', icon: Icons.fitness_center_rounded),
      const SizedBox(height: 14),
      _buildFitnessAnalyticsGrid(fitnessStats),
      const SizedBox(height: 28),

      // Workout Schedule
      _buildSectionHeader('Workout Schedule', icon: Icons.schedule_rounded),
      const SizedBox(height: 14),
      _buildFitnessScheduleCard(fitnessReminders),
      const SizedBox(height: 28),

      // Fitness Insights
      _buildSectionHeader('Fitness Insights', icon: Icons.lightbulb_rounded),
      const SizedBox(height: 14),
      _buildFitnessInsights(fitnessStats),
      const SizedBox(height: 28),

      const SmartDashboardBanner(),
      const SizedBox(height: 28),

      // Activity Timeline
      _buildSectionHeader('Today\'s Activity', icon: Icons.timeline_rounded),
      const SizedBox(height: 14),
      _buildActivityTimeline(todayLogs),
    ];
  }

  // Finance Category Content
  List<Widget> _buildFinanceCategoryContent(DateTime today, List<ActionLog> todayLogs) {
    return [
      // Finance Hero Card
      _buildFinanceHeroCard(),
      const SizedBox(height: 24),

      // Spending Analytics
      _buildSectionHeader('Spending Overview', icon: Icons.account_balance_wallet_rounded),
      const SizedBox(height: 14),
      _buildFinanceAnalyticsGrid(),
      const SizedBox(height: 28),

      // Recent Transactions
      _buildSectionHeader('Recent Transactions', icon: Icons.receipt_long_rounded),
      const SizedBox(height: 14),
      _buildRecentTransactionsCard(),
      const SizedBox(height: 28),

      // Budget Insights
      _buildSectionHeader('Budget Insights', icon: Icons.lightbulb_rounded),
      const SizedBox(height: 14),
      _buildFinanceInsights(),
      const SizedBox(height: 28),

      const SmartDashboardBanner(),
    ];
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
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.getTextPrimary(context),
                    letterSpacing: -0.8,
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
                  DateFormat('EEEE, MMM d').format(today),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(context),
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.getTextPrimary(context),
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
              gradient: AppColors.isDark(context)
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.darkCard,
                        AppColors.darkElevatedCard,
                        AppColors.primary.withOpacity(0.1),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.98),
                        Colors.white.withOpacity(0.9),
                        AppColors.primaryLight.withOpacity(0.4),
                      ],
                    ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.isDark(context)
                    ? AppColors.darkBorder.withOpacity(0.5)
                    : Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Multi-ring Progress
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
                                colors: AppColors.isDark(context)
                                    ? [AppColors.darkElevatedCard, AppColors.darkCard]
                                    : [Colors.white, Colors.white.withOpacity(0.9)],
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
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                                Text(
                                  'Health Score',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: AppColors.getTextSecondary(context),
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
                          Text(
                            'Daily Wellness',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getMotivationalMessage(overallScore),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
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
                    color: AppColors.isDark(context)
                        ? AppColors.darkSurface.withOpacity(0.5)
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.isDark(context)
                          ? AppColors.darkBorder.withOpacity(0.5)
                          : Colors.white.withOpacity(0.9),
                    ),
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
    return AnalyticsCard(
      title: title,
      icon: icon,
      color: color,
      mainValue: mainValue,
      mainLabel: mainLabel,
      stats: stats,
      trend: trend,
    );
  }

  Widget _buildAnalyticsCardOld({
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
    return CommonCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      border: Border.all(color: color.withOpacity(0.2)),
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

  Widget _buildScheduleList(List<EnhancedMedicine> medicines, List<FitnessReminder> fitnessReminders) {
    if (medicines.isEmpty && fitnessReminders.isEmpty) {
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

    final now = DateTime.now();
    final todayLogs = MedicineStorageService.getLogsForDate(now);
    final List<Map<String, dynamic>> upcomingDoses = [];

    for (final medicine in medicines) {
      if (medicine.isPRN) continue;
      
      final times = medicine.schedule.getScheduledTimesForDate(now);
      for (final time in times) {
        final isTaken = todayLogs.any((log) => 
          log.medicineId == medicine.id && 
          log.scheduledTime.hour == time.hour &&
          log.scheduledTime.minute == time.minute &&
          log.isTaken
        );

        upcomingDoses.add({
          'type': 'medicine',
          'time': time,
          'data': medicine,
          'isTaken': isTaken,
        });
      }
    }

    for (final f in fitnessReminders) {
      upcomingDoses.add({
        'type': 'fitness',
        'time': f.reminderTime,
        'data': f,
        'isTaken': false,
      });
    }

    upcomingDoses.sort((a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));
    
    final displayItems = upcomingDoses.where((item) => true).toList();

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

  // ============ STREAKS & GOALS SECTION ============
  Widget _buildStreaksAndGoalsSection({
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> waterStats,
    required Map<String, dynamic> fitnessStats,
    required int focusMinutes,
  }) {
    // Calculate streaks based on adherence
    final medStreak = _calculateStreakDays(medicineStats['adherenceRate'] as int);
    final waterStreak = _calculateStreakDays(waterStats['avgCompletionRate'] as int);
    final fitnessStreak = _calculateStreakDays(fitnessStats['completionRate'] as int);
    final focusStreak = focusMinutes >= 30 ? 1 : 0;

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
          // Streaks Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Streaks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${medStreak + waterStreak + fitnessStreak + focusStreak} days',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Streak Cards
          Row(
            children: [
              Expanded(child: _buildStreakCard('Medicine', medStreak, AppColors.primary, Icons.medication_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildStreakCard('Water', waterStreak, AppColors.info, Icons.water_drop_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildStreakCard('Fitness', fitnessStreak, AppColors.warning, Icons.fitness_center_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildStreakCard('Focus', focusStreak, AppColors.focusPrimary, Icons.self_improvement_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          // Goals Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Goals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_countCompletedGoals(medicineStats, waterStats, fitnessStats, focusMinutes)}/4 completed',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGoalProgressRow('Medicine 80%+', (medicineStats['adherenceRate'] as int) >= 80, AppColors.primary),
          const SizedBox(height: 10),
          _buildGoalProgressRow('Water Goal Met', (waterStats['avgCompletionRate'] as int) >= 100, AppColors.info),
          const SizedBox(height: 10),
          _buildGoalProgressRow('Workout Done', (fitnessStats['completed'] as int) > 0, AppColors.warning),
          const SizedBox(height: 10),
          _buildGoalProgressRow('30min Focus', focusMinutes >= 30, AppColors.focusPrimary),
        ],
      ),
    );
  }

  int _calculateStreakDays(int adherenceRate) {
    if (adherenceRate >= 90) return 7;
    if (adherenceRate >= 80) return 5;
    if (adherenceRate >= 70) return 3;
    if (adherenceRate >= 50) return 1;
    return 0;
  }

  int _countCompletedGoals(Map<String, dynamic> medicineStats, Map<String, dynamic> waterStats, Map<String, dynamic> fitnessStats, int focusMinutes) {
    int count = 0;
    if ((medicineStats['adherenceRate'] as int) >= 80) count++;
    if ((waterStats['avgCompletionRate'] as int) >= 100) count++;
    if ((fitnessStats['completed'] as int) > 0) count++;
    if (focusMinutes >= 30) count++;
    return count;
  }

  Widget _buildStreakCard(String label, int days, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded, color: days > 0 ? const Color(0xFFFF6B35) : AppColors.textLight, size: 12),
              const SizedBox(width: 2),
              Text(
                '$days',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: days > 0 ? AppColors.textPrimary : AppColors.textLight,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressRow(String label, bool completed, Color color) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: completed ? color : AppColors.border.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            completed ? Icons.check_rounded : Icons.close_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: completed ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: completed ? AppColors.success.withOpacity(0.12) : AppColors.border.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            completed ? 'Done' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: completed ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ============ WEEKLY COMPARISON CHART ============
  Widget _buildWeeklyComparisonChart(
    Map<String, dynamic> medicineStats,
    Map<String, dynamic> waterStats,
    Map<String, dynamic> fitnessStats,
  ) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1;

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
                'This Week vs Last Week',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot(AppColors.primary, 'This'),
                  const SizedBox(width: 12),
                  _buildLegendDot(AppColors.textLight, 'Last'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final isToday = index == currentDayIndex;
                final thisWeekValue = index <= currentDayIndex ? 0.3 + (index * 0.1) : 0.0;
                final lastWeekValue = 0.2 + (index * 0.08);
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Last week bar
                            Container(
                              width: 8,
                              height: 80 * lastWeekValue,
                              decoration: BoxDecoration(
                                color: AppColors.textLight.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 3),
                            // This week bar
                            Container(
                              width: 8,
                              height: 80 * thisWeekValue,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isToday ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          days[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Summary Row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildComparisonStat('Medicine', '+${(medicineStats['adherenceRate'] as int) - 75}%', true),
                _buildComparisonStat('Water', '+${(waterStats['avgCompletionRate'] as int) - 60}%', true),
                _buildComparisonStat('Fitness', '+${(fitnessStats['completionRate'] as int) - 50}%', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildComparisonStat(String label, String change, bool isPositive) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12,
              color: isPositive ? AppColors.success : AppColors.error,
            ),
            Text(
              change,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPositive ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============ PRODUCTIVITY CATEGORY WIDGETS ============
  Widget _buildProductivityHeroCard(FocusModeService focusService) {
    final focusGoal = 120; // 2 hours daily
    final focusProgress = (focusService.todayMinutes / focusGoal).clamp(0.0, 1.0);
    final weeklyMinutes = focusService.weekMinutes;
    final totalSessions = focusService.totalSessions;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.focusPrimary.withOpacity(0.15),
            AppColors.focusPrimary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.focusPrimary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.focusGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.focusPrimary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${focusService.todayMinutes}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Focus Time Today',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(focusProgress * 100).round()}% of daily goal',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.focusPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildProductivityMiniStat('This Week', '${weeklyMinutes}m', Icons.calendar_today_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildProductivityMiniStat('Sessions', '$totalSessions', Icons.timer_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildProductivityMiniStat('Streak', '${_calculateFocusStreak(focusService)}d', Icons.local_fire_department_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateFocusStreak(FocusModeService service) {
    return service.todayMinutes >= 30 ? 1 : 0;
  }

  Widget _buildProductivityMiniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.focusPrimary, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildProductivityAnalyticsGrid(FocusModeService focusService) {
    return Row(
      children: [
        Expanded(
          child: AnalyticsCard(
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
        const SizedBox(width: 12),
        Expanded(
          child: AnalyticsCard(
            title: 'Productivity',
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
            mainValue: '${((focusService.todayMinutes / 120) * 100).round()}%',
            mainLabel: 'Score',
            stats: [
              {'label': 'Goal', 'value': '2h'},
              {'label': 'Avg', 'value': '${(focusService.weekMinutes ~/ 7)}m'},
            ],
            trend: 'up',
          ),
        ),
      ],
    );
  }

  Widget _buildStudyProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF8B5CF6), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exam Preparation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Track your study progress', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: _StudyStatItem(label: 'Subjects', value: '0', icon: Icons.book_rounded)),
              SizedBox(width: 12),
              Expanded(child: _StudyStatItem(label: 'Sessions', value: '0', icon: Icons.timer_rounded)),
              SizedBox(width: 12),
              Expanded(child: _StudyStatItem(label: 'Hours', value: '0', icon: Icons.access_time_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.note_alt_rounded, color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Capture your thoughts', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('+ New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getGrey100(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create your first note to get started',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityInsights(FocusModeService focusService) {
    final insights = <Map<String, dynamic>>[];

    if (focusService.todayMinutes < 30) {
      insights.add({
        'icon': Icons.self_improvement_rounded,
        'color': AppColors.focusPrimary,
        'title': 'Start a Focus Session',
        'description': 'You haven\'t focused today. Try a 25-minute session!',
      });
    }
    insights.add({
      'icon': Icons.school_rounded,
      'color': const Color(0xFF8B5CF6),
      'title': 'Plan Your Study',
      'description': 'Set up subjects and track your exam preparation.',
    });

    return Column(
      children: insights.take(2).map((insight) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildInsightCard(
          icon: insight['icon'],
          color: insight['color'],
          title: insight['title'],
          description: insight['description'],
          action: null,
        ),
      )).toList(),
    );
  }

  // ============ FITNESS CATEGORY WIDGETS ============
  Widget _buildFitnessHeroCard(Map<String, dynamic> fitnessStats) {
    final completionRate = fitnessStats['completionRate'] as int;
    final totalMinutes = fitnessStats['totalMinutes'] as int;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning.withOpacity(0.15),
            AppColors.warning.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.warning.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.warning, AppColors.warning.withOpacity(0.8)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.fitness_center_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fitness Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('$completionRate% completion rate', style: TextStyle(fontSize: 14, color: AppColors.warning, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildFitnessMiniStat('Total', '${totalMinutes}m', Icons.timer_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildFitnessMiniStat('Sessions', '${fitnessStats['completed']}', Icons.check_circle_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildFitnessMiniStat('Goal', '150m', Icons.flag_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessMiniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.warning, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFitnessAnalyticsGrid(Map<String, dynamic> fitnessStats) {
    return Row(
      children: [
        Expanded(
          child: AnalyticsCard(
            title: 'Workouts',
            icon: Icons.fitness_center_rounded,
            color: AppColors.warning,
            mainValue: '${fitnessStats['completed']}',
            mainLabel: 'Completed',
            stats: [
              {'label': 'Total', 'value': '${fitnessStats['total']}'},
              {'label': 'Rate', 'value': '${fitnessStats['completionRate']}%'},
            ],
            trend: (fitnessStats['completionRate'] as int) >= 70 ? 'up' : 'down',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnalyticsCard(
            title: 'Activity',
            icon: Icons.directions_run_rounded,
            color: AppColors.success,
            mainValue: '${fitnessStats['totalMinutes']}',
            mainLabel: 'Minutes',
            stats: [
              {'label': 'Goal', 'value': '150m'},
              {'label': 'Avg', 'value': '${(fitnessStats['totalMinutes'] as int) ~/ 7}m'},
            ],
            trend: (fitnessStats['totalMinutes'] as int) >= 100 ? 'up' : 'neutral',
          ),
        ),
      ],
    );
  }

  Widget _buildFitnessScheduleCard(List<FitnessReminder> reminders) {
    if (reminders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.isDark(context) ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            Icon(Icons.fitness_center_rounded, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('No workouts scheduled', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: reminders.take(3).map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildScheduleCard(
          icon: Icons.fitness_center_rounded,
          color: AppColors.warning,
          title: r.title,
          subtitle: '${r.durationMinutes} min',
          time: DateFormat('h:mm a').format(r.reminderTime),
        ),
      )).toList(),
    );
  }

  Widget _buildFitnessInsights(Map<String, dynamic> fitnessStats) {
    final insights = <Map<String, dynamic>>[];
    final totalMinutes = fitnessStats['totalMinutes'] as int;

    if (totalMinutes < 150) {
      insights.add({
        'icon': Icons.fitness_center_rounded,
        'color': AppColors.warning,
        'title': 'Activity Boost Needed',
        'description': 'Only ${totalMinutes}min this week. WHO recommends 150min.',
      });
    } else {
      insights.add({
        'icon': Icons.check_circle_rounded,
        'color': AppColors.success,
        'title': 'Great Progress!',
        'description': 'You\'ve hit your weekly activity goal!',
      });
    }

    return Column(
      children: insights.map((insight) => _buildInsightCard(
        icon: insight['icon'],
        color: insight['color'],
        title: insight['title'],
        description: insight['description'],
        action: null,
      )).toList(),
    );
  }

  // ============ FINANCE CATEGORY WIDGETS ============
  Widget _buildFinanceHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withOpacity(0.15),
            AppColors.success.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.success, AppColors.success.withOpacity(0.8)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finance Tracker', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Track your spending', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildFinanceMiniStat('Today', '₹0', Icons.today_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildFinanceMiniStat('This Week', '₹0', Icons.calendar_view_week_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildFinanceMiniStat('This Month', '₹0', Icons.calendar_month_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceMiniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.success, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFinanceAnalyticsGrid() {
    return Row(
      children: [
        Expanded(
          child: AnalyticsCard(
            title: 'Expenses',
            icon: Icons.trending_down_rounded,
            color: AppColors.error,
            mainValue: '₹0',
            mainLabel: 'This Month',
            stats: [
              {'label': 'Today', 'value': '₹0'},
              {'label': 'Avg', 'value': '₹0'},
            ],
            trend: 'neutral',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnalyticsCard(
            title: 'Budget',
            icon: Icons.pie_chart_rounded,
            color: AppColors.success,
            mainValue: '100%',
            mainLabel: 'Remaining',
            stats: [
              {'label': 'Set', 'value': '₹0'},
              {'label': 'Used', 'value': '₹0'},
            ],
            trend: 'up',
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          const Text('No transactions yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Add your first expense', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildFinanceInsights() {
    return _buildInsightCard(
      icon: Icons.lightbulb_rounded,
      color: AppColors.success,
      title: 'Start Tracking',
      description: 'Add expenses to get personalized budget insights.',
      action: null,
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

// Study stat item widget for exam prep
class _StudyStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StudyStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getGrey100(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
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
}
