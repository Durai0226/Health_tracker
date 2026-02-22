import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/feature_manager.dart';
import '../../../core/services/category_manager.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../water/services/water_service.dart';
import '../../water/models/enhanced_water_log.dart';
import '../../water/models/beverage_type.dart';
import '../../water/screens/water_dashboard_screen.dart';
import '../../fitness/screens/fitness_dashboard_screen.dart';
import '../../focus/screens/focus_screen.dart';
import '../../medication/screens/enhanced_medicine_dashboard.dart';
import '../../period_tracking/screens/period_overview_screen.dart';
import '../../period_tracking/screens/period_intro_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    final categoryManager = CategoryManager();
    final selectedCategory = categoryManager.selectedCategory;
    final enabledFeatures = categoryManager.enabledFeatureIds;
    
    final waterData = WaterService.getTodayData();
    final isPeriodEnabled = StorageService.isPeriodTrackingEnabled;
    final medicines = StorageService.getAllMedicines();
    final fitnessReminders = StorageService.getAllFitnessReminders();
    final focusService = FocusModeService();
    
    // Get analytics data
    final medicineStats = StorageService.getMedicineAdherenceStats(days: 7);
    final fitnessStats = StorageService.getFitnessStats(days: 7);
    
    // Calculate water stats
    final weeklyWaterStats = WaterService.getWeeklyStats();
    final dailyGoal = WaterService.getDailyGoal();
    final avgDailyMl = weeklyWaterStats['averageMl'] as int;
    final waterStats = {
      'avgDailyMl': avgDailyMl,
      'dailyGoal': dailyGoal,
      'avgCompletionRate': dailyGoal > 0 ? (avgDailyMl / dailyGoal * 100).round() : 0,
    };
    
    // Helper to check if feature is enabled for selected category
    bool isFeatureEnabled(String featureId) {
      return enabledFeatures.contains(featureId) || 
             categoryManager.isFeatureEnabled(featureId);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),

                // Quick Stats Overview - filtered by category
                _buildQuickStatsRow(
                  todayData: isFeatureEnabled('water') ? waterData : null,
                  medicineCount: isFeatureEnabled('medicine') ? medicines.length : 0,
                  fitnessCount: isFeatureEnabled('fitness') ? fitnessReminders.length : 0,
                  focusMinutes: isFeatureEnabled('focus') ? focusService.todayMinutes : 0,
                  enabledFeatures: enabledFeatures,
                ),
                const SizedBox(height: 24),

                // Quick Actions Section - filtered by category
                _buildSectionHeader('Quick Actions', icon: Icons.flash_on_rounded),
                const SizedBox(height: 14),
                _buildQuickActionsGrid(context, waterData, enabledFeatures),
                const SizedBox(height: 24),

                // Habit Streaks Section
                _buildSectionHeader('Habit Streaks', icon: Icons.local_fire_department_rounded),
                const SizedBox(height: 14),
                _buildHabitStreaksSection(
                  medicineStats: medicineStats,
                  waterStats: waterStats,
                  fitnessStats: fitnessStats,
                  focusService: focusService,
                ),
                const SizedBox(height: 24),

                // Health Category Cards - filtered by selected category
                _buildSectionHeader('Health Categories', icon: Icons.category_rounded),
                const SizedBox(height: 14),
                _buildCategoryCards(
                  context,
                  todayData: waterData,
                  medicineStats: medicineStats,
                  fitnessStats: fitnessStats,
                  focusService: focusService,
                  waterStats: waterStats,
                  isPeriodEnabled: isPeriodEnabled,
                  enabledFeatures: enabledFeatures,
                ),
                const SizedBox(height: 28),

                // Detailed Analytics per Category - filtered by selected category
                _buildSectionHeader('Category Insights', icon: Icons.insights_rounded),
                const SizedBox(height: 14),
                _buildDetailedAnalytics(
                  medicineStats: medicineStats,
                  waterStats: waterStats,
                  fitnessStats: fitnessStats,
                  focusService: focusService,
                  enabledFeatures: enabledFeatures,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracking',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Monitor your health goals',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                Color.lerp(AppColors.primary, Colors.purple, 0.3)!,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 26),
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

  // ============ QUICK STATS ROW ============
  Widget _buildQuickStatsRow({
    required DailyWaterData? todayData,
    required int medicineCount,
    required int fitnessCount,
    required int focusMinutes,
    required List<String> enabledFeatures,
  }) {
    // Build list of enabled stats
    final stats = <Widget>[];
    
    if (enabledFeatures.contains('water') || enabledFeatures.contains('medicine')) {
      stats.add(_buildQuickStat(
        icon: Icons.water_drop_rounded,
        color: AppColors.info,
        value: '${((todayData?.effectiveHydrationMl ?? 0) / 1000).toStringAsFixed(1)}L',
        label: 'Water',
      ));
    }
    
    if (enabledFeatures.contains('medicine')) {
      if (stats.isNotEmpty) stats.add(_buildStatDivider());
      stats.add(_buildQuickStat(
        icon: Icons.medication_rounded,
        color: AppColors.primary,
        value: '$medicineCount',
        label: 'Meds',
      ));
    }
    
    if (enabledFeatures.contains('fitness')) {
      if (stats.isNotEmpty) stats.add(_buildStatDivider());
      stats.add(_buildQuickStat(
        icon: Icons.fitness_center_rounded,
        color: AppColors.warning,
        value: '$fitnessCount',
        label: 'Workouts',
      ));
    }
    
    if (enabledFeatures.contains('focus')) {
      if (stats.isNotEmpty) stats.add(_buildStatDivider());
      stats.add(_buildQuickStat(
        icon: Icons.self_improvement_rounded,
        color: AppColors.focusPrimary,
        value: '${focusMinutes}m',
        label: 'Focus',
      ));
    }
    
    // If no features enabled, show a placeholder
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.primaryLight.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats,
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
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

  // ============ CATEGORY CARDS ============
  Widget _buildCategoryCards(
    BuildContext context, {
    required DailyWaterData? todayData,
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> fitnessStats,
    required FocusModeService focusService,
    required Map<String, dynamic> waterStats,
    required bool isPeriodEnabled,
    required List<String> enabledFeatures,
  }) {
    // Helper to check if feature is in enabled list
    bool isEnabled(String featureId) => enabledFeatures.contains(featureId);
    
    return Column(
      children: [
        // Medicine & Water Row - show only if enabled for selected category
        if (isEnabled('medicine') || isEnabled('water'))
          Row(
            children: [
              if (isEnabled('medicine'))
                Expanded(
                  child: _buildCategoryCard(
                    context,
                    title: 'Medicine',
                    icon: Icons.medication_rounded,
                    color: AppColors.primary,
                    mainValue: '${medicineStats['adherenceRate']}%',
                    subtitle: 'Adherence Rate',
                    detail: '${medicineStats['taken']} taken this week',
                    screen: const EnhancedMedicineDashboard(),
                    progress: (medicineStats['adherenceRate'] as int) / 100,
                  ),
                ),
              if (isEnabled('medicine') && isEnabled('water'))
                const SizedBox(width: 12),
              if (isEnabled('water'))
                Expanded(
                  child: _buildCategoryCard(
                    context,
                    title: 'Hydration',
                    icon: Icons.water_drop_rounded,
                    color: AppColors.info,
                    mainValue: '${((todayData?.effectiveHydrationMl ?? 0) / 1000).toStringAsFixed(1)}L',
                    subtitle: 'Today\'s intake',
                    detail: 'Goal: ${(waterStats['dailyGoal']! / 1000).toStringAsFixed(1)}L',
                    screen: const WaterDashboardScreen(),
                    progress: todayData?.progress ?? 0.0,
                  ),
                ),
            ],
          ),
        // Spacing between rows
        if (isEnabled('medicine') || isEnabled('water'))
          const SizedBox(height: 12),
        // Fitness & Focus Row - show if enabled for selected category
        if (isEnabled('fitness') || isEnabled('focus'))
          Row(
            children: [
              if (isEnabled('fitness'))
                Expanded(
                  child: _buildCategoryCard(
                    context,
                    title: 'Fitness',
                    icon: Icons.fitness_center_rounded,
                    color: AppColors.warning,
                    mainValue: '${fitnessStats['totalMinutes']}m',
                    subtitle: 'This Week',
                    detail: '${fitnessStats['completed']} sessions done',
                    screen: const FitnessDashboardScreen(),
                    progress: (fitnessStats['completionRate'] as int) / 100,
                  ),
                ),
              if (isEnabled('fitness') && isEnabled('focus'))
                const SizedBox(width: 12),
              if (isEnabled('focus'))
                Expanded(
                  child: _buildCategoryCard(
                    context,
                    title: 'Focus',
                    icon: Icons.self_improvement_rounded,
                    color: AppColors.focusPrimary,
                    mainValue: '${focusService.todayMinutes}m',
                    subtitle: 'Today',
                    detail: '${focusService.totalSessions} total sessions',
                    screen: const FocusScreen(),
                    progress: (focusService.todayMinutes / 60).clamp(0.0, 1.0),
                  ),
                ),
            ],
          ),
        // Period Tracking Wide Card - show if enabled for selected category
        if (isEnabled('period')) ...[
          const SizedBox(height: 12),
          _buildWideCard(
            context,
            title: 'Period Tracking',
            icon: Icons.calendar_month_rounded,
            color: AppColors.periodPrimary,
            value: isPeriodEnabled ? 'Active' : 'Set Up',
            subtitle: isPeriodEnabled ? 'Track your cycle' : 'Start tracking today',
            screen: isPeriodEnabled ? const PeriodOverviewScreen() : const PeriodIntroScreen(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String mainValue,
    required String subtitle,
    required String detail,
    required Widget screen,
    required double progress,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.95),
              color.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
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
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              mainValue,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String value,
    required String subtitle,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
            Icon(Icons.chevron_right_rounded, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  // ============ DETAILED ANALYTICS ============
  Widget _buildDetailedAnalytics({
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> waterStats,
    required Map<String, dynamic> fitnessStats,
    required FocusModeService focusService,
  }) {
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '7-Day Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'On Track',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Medicine Analytics
          _buildAnalyticsRow(
            icon: Icons.medication_rounded,
            color: AppColors.primary,
            title: 'Medicine Adherence',
            value: '${medicineStats['adherenceRate']}%',
            progress: (medicineStats['adherenceRate'] as int) / 100,
            stats: '${medicineStats['taken']} taken • ${medicineStats['skipped']} skipped',
          ),
          const SizedBox(height: 16),
          
          // Water Analytics
          _buildAnalyticsRow(
            icon: Icons.water_drop_rounded,
            color: AppColors.info,
            title: 'Hydration Goal',
            value: '${waterStats['avgCompletionRate']}%',
            progress: (waterStats['avgCompletionRate'] as int) / 100,
            stats: 'Avg ${(waterStats['avgDailyMl'] / 1000).toStringAsFixed(1)}L / day',
          ),
          const SizedBox(height: 16),
          
          // Fitness Analytics
          _buildAnalyticsRow(
            icon: Icons.fitness_center_rounded,
            color: AppColors.warning,
            title: 'Fitness Activity',
            value: '${fitnessStats['totalMinutes']}m',
            progress: (fitnessStats['completionRate'] as int) / 100,
            stats: '${fitnessStats['completed']} sessions completed',
          ),
          const SizedBox(height: 16),
          
          // Focus Analytics
          _buildAnalyticsRow(
            icon: Icons.self_improvement_rounded,
            color: AppColors.focusPrimary,
            title: 'Focus Time',
            value: '${focusService.weekMinutes}m',
            progress: (focusService.weekMinutes / 300).clamp(0.0, 1.0),
            stats: '${focusService.totalSessions} sessions • ${focusService.todayMinutes}m today',
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required double progress,
    required String stats,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stats,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============ QUICK ACTIONS GRID ============
  Widget _buildQuickActionsGrid(BuildContext context, DailyWaterData? waterData) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.water_drop_rounded,
                  label: '+250ml Water',
                  color: AppColors.info,
                  onTap: () async {
                    await WaterService.addWaterLog(
                      amountMl: 250,
                      beverage: WaterService.getBeverage('water') ?? 
                        BeverageType.defaultBeverages.first,
                    );
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('✓ +250ml water logged'),
                          backgroundColor: AppColors.info,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.medication_rounded,
                  label: 'Log Medicine',
                  color: AppColors.primary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnhancedMedicineDashboard())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.fitness_center_rounded,
                  label: 'Log Workout',
                  color: AppColors.warning,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessDashboardScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.self_improvement_rounded,
                  label: 'Start Focus',
                  color: AppColors.focusPrimary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ HABIT STREAKS SECTION ============
  Widget _buildHabitStreaksSection({
    required Map<String, dynamic> medicineStats,
    required Map<String, dynamic> waterStats,
    required Map<String, dynamic> fitnessStats,
    required FocusModeService focusService,
  }) {
    final medStreak = _calculateStreak(medicineStats['adherenceRate'] as int);
    final waterStreak = _calculateStreak(waterStats['avgCompletionRate'] as int);
    final fitnessStreak = _calculateStreak(fitnessStats['completionRate'] as int);
    final focusStreak = focusService.todayMinutes >= 30 ? 1 : 0;
    final totalStreak = medStreak + waterStreak + fitnessStreak + focusStreak;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFFF6B35).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with total streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Streak',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$totalStreak days',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: totalStreak > 0 ? AppColors.success.withOpacity(0.12) : AppColors.border.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  totalStreak > 0 ? '🔥 Active' : 'Start today!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: totalStreak > 0 ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Individual streaks
          Row(
            children: [
              Expanded(child: _buildStreakItem('Medicine', medStreak, AppColors.primary, Icons.medication_rounded)),
              Expanded(child: _buildStreakItem('Water', waterStreak, AppColors.info, Icons.water_drop_rounded)),
              Expanded(child: _buildStreakItem('Fitness', fitnessStreak, AppColors.warning, Icons.fitness_center_rounded)),
              Expanded(child: _buildStreakItem('Focus', focusStreak, AppColors.focusPrimary, Icons.self_improvement_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateStreak(int adherenceRate) {
    if (adherenceRate >= 90) return 7;
    if (adherenceRate >= 80) return 5;
    if (adherenceRate >= 70) return 3;
    if (adherenceRate >= 50) return 1;
    return 0;
  }

  Widget _buildStreakItem(String label, int days, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 12,
              color: days > 0 ? const Color(0xFFFF6B35) : AppColors.textLight,
            ),
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
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
