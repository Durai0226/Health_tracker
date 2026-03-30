import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aqua_theme.dart';
import '../widgets/aqua_droplet_widget.dart';
import '../widgets/aqua_glass_card.dart';
import '../widgets/aqua_quick_add_grid.dart';
import '../widgets/aqua_timeline_list.dart';
import '../widgets/aqua_weekly_progress.dart';
import '../widgets/aqua_beverage_sheet.dart';
import '../models/enhanced_water_log.dart';
import '../models/beverage_type.dart';
import '../services/water_service.dart';
import 'water_statistics_screen.dart';
import 'water_calendar_screen.dart';
import 'water_achievements_screen.dart';
import 'hydration_profile_screen.dart';
import 'hydration_challenges_screen.dart';
import 'caffeine_insights_screen.dart';

/// Modern Aqua Water Dashboard
/// Features: Animated droplet, dynamic beverage gradients, glassmorphism
class AquaWaterDashboard extends StatefulWidget {
  const AquaWaterDashboard({super.key});

  @override
  State<AquaWaterDashboard> createState() => _AquaWaterDashboardState();
}

class _AquaWaterDashboardState extends State<AquaWaterDashboard>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _headerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  // Data
  DailyWaterData? _todayData;
  int _dailyGoal = 2500;
  bool _isLoading = true;
  String _selectedBeverageId = 'water';
  List<DayProgress> _weekData = [];

  // Scroll controller
  final _scrollController = ScrollController();
  double _headerOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AquaTheme.curveDefault,
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: AquaTheme.curveDefault,
    ));

    _fadeController.forward();
    _headerController.forward();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _headerOpacity = (1 - (offset / 150)).clamp(0.0, 1.0);
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await WaterService.init();
      final todayData = WaterService.getTodayData();
      final goal = WaterService.getDailyGoal();

      // Build week data
      final weekData = <DayProgress>[];
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        if (date.isAfter(now)) break;

        final dayData = WaterService.getDataForDate(date);
        weekData.add(DayProgress(
          date: date,
          intakeMl: dayData?.effectiveHydrationMl ?? 0,
          goalMl: goal,
        ));
      }

      if (mounted) {
        setState(() {
          _todayData = todayData;
          _dailyGoal = goal;
          _weekData = weekData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading water data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addWater(int amountMl, String beverageId) async {
    try {
      final beverage = WaterService.getBeverage(beverageId) ??
          BeverageType.defaultBeverages.first;

      await WaterService.addWaterLog(
        amountMl: amountMl,
        beverage: beverage,
      );

      await _loadData();

      if (mounted) {
        HapticFeedback.mediumImpact();
        final beverageTheme = AquaTheme.getBeverage(beverageId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(beverageTheme.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(
                  '+${amountMl}ml ${beverageTheme.name}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: beverageTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding water: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add water: $e'),
            backgroundColor: AquaTheme.error,
          ),
        );
      }
    }
  }

  void _showBeverageSelector() async {
    final result = await AquaBeverageSheet.show(context, _selectedBeverageId);
    if (result != null && mounted) {
      setState(() => _selectedBeverageId = result);
    }
  }

  void _showCustomAmountDialog() {
    showDialog(
      context: context,
      builder: (context) => AquaCustomAmountDialog(
        beverageId: _selectedBeverageId,
        onConfirm: (amount) => _addWater(amount, _selectedBeverageId),
      ),
    );
  }

  void _showGoalDialog() {
    int newGoal = _dailyGoal;
    final beverage = AquaTheme.getBeverage(_selectedBeverageId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: AquaTheme.spacingL,
            right: AquaTheme.spacingL,
            top: AquaTheme.spacingL,
            bottom: MediaQuery.of(context).viewInsets.bottom + AquaTheme.spacingL,
          ),
          decoration: BoxDecoration(
            color: AquaTheme.getCardBg(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AquaTheme.radiusLarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AquaTheme.spacingL),
              Text(
                'Daily Goal',
                style: AquaTheme.heading2.copyWith(
                  color: AquaTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AquaTheme.spacingXL),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setModalState(() {
                        newGoal = (newGoal - 250).clamp(500, 5000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: beverage.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.remove, color: beverage.primary),
                    ),
                  ),
                  const SizedBox(width: AquaTheme.spacingL),
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                        child: Text(
                          '${newGoal}ml',
                          style: AquaTheme.displayLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '${(newGoal / 250).round()} glasses',
                        style: AquaTheme.bodySmall.copyWith(
                          color: AquaTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AquaTheme.spacingL),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setModalState(() {
                        newGoal = (newGoal + 250).clamp(500, 5000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: beverage.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, color: beverage.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AquaTheme.spacingXL),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final profile = WaterService.getProfile();
                  final updatedProfile = profile.copyWith(
                    customGoalMl: newGoal,
                    useCustomGoal: true,
                  );
                  await WaterService.saveProfile(updatedProfile);

                  final todayData = WaterService.getTodayData();
                  final updatedData = todayData.copyWith(dailyGoalMl: newGoal);
                  await WaterService.saveDailyData(updatedData);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: beverage.gradient,
                    borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: beverage.primary.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Save Goal',
                        style: AquaTheme.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _headerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AquaTheme.getBackground(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💧', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              CircularProgressIndicator(
                color: AquaTheme.waterPrimary,
              ),
            ],
          ),
        ),
      );
    }

    final listenable = WaterService.listenToDailyData();
    if (listenable == null) {
      return _buildContent(context);
    }

    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, _, __) {
        final todayData = WaterService.getTodayData();
        return _buildContentWithData(context, todayData);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final todayData = _todayData ?? DailyWaterData(
      id: '',
      date: DateTime.now(),
      dailyGoalMl: _dailyGoal,
    );
    return _buildContentWithData(context, todayData);
  }

  Widget _buildContentWithData(BuildContext context, DailyWaterData todayData) {
    final isDark = AquaTheme.isDark(context);
    final beverage = AquaTheme.getBeverage(_selectedBeverageId);
    final progress = todayData.progress.clamp(0.0, 1.0);
    final currentStreak = WaterService.getCurrentStreak();

    return Scaffold(
      backgroundColor: AquaTheme.getBackground(context),
      body: Stack(
        children: [
          // Background gradient
          _buildBackground(beverage, isDark),
          
          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App bar
              _buildSliverAppBar(beverage, currentStreak),
              
              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AquaTheme.spacingM),
                    child: Column(
                      children: [
                        const SizedBox(height: AquaTheme.spacingM),
                        
                        // Droplet visualization
                        AquaDropletWidget(
                          progress: progress,
                          currentMl: todayData.effectiveHydrationMl,
                          goalMl: todayData.dailyGoalMl,
                          beverageId: _selectedBeverageId,
                          onTap: _showBeverageSelector,
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Quick add section
                        AquaSectionHeader(
                          title: 'Quick Add',
                          icon: Icons.add_circle_outline,
                          beverageId: _selectedBeverageId,
                        ),
                        const SizedBox(height: AquaTheme.spacingS),
                        AquaQuickAddGrid(
                          selectedBeverageId: _selectedBeverageId,
                          onQuickAdd: _addWater,
                          onCustomAmount: _showCustomAmountDialog,
                          onBeverageSelect: _showBeverageSelector,
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Today's log
                        AquaSectionHeader(
                          title: "Today's Log",
                          icon: Icons.history,
                          actionText: 'Edit',
                          onAction: () => _navigateToHistory(),
                          beverageId: _selectedBeverageId,
                        ),
                        const SizedBox(height: AquaTheme.spacingS),
                        AquaTimelineList(
                          logs: todayData.logs,
                          maxItems: 5,
                          onViewAll: () => _navigateToHistory(),
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Weekly progress
                        AquaWeeklyProgress(
                          weekData: _weekData,
                          goalMl: todayData.dailyGoalMl,
                          beverageId: _selectedBeverageId,
                          onTapHistory: () => _navigateToCalendar(),
                        ),
                        
                        const SizedBox(height: AquaTheme.spacingXL),
                        
                        // Quick access menu
                        _buildQuickAccessMenu(beverage, isDark),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(BeverageThemeData beverage, bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              beverage.primary.withOpacity(isDark ? 0.15 : 0.1),
              AquaTheme.getBackground(context),
            ],
            stops: const [0.0, 0.35],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BeverageThemeData beverage, int streak) {
    final isDark = AquaTheme.isDark(context);
    
    return SliverAppBar(
      expandedHeight: 110,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AquaTheme.getCardBg(context),
            shape: BoxShape.circle,
            boxShadow: AquaTheme.subtleShadow,
          ),
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: AquaTheme.getTextPrimary(context),
            size: 18,
          ),
        ),
      ),
      actions: [
        _buildHeaderAction(
          Icons.flag_outlined,
          () => _showGoalDialog(),
          beverage,
        ),
        _buildHeaderAction(
          Icons.bar_chart_rounded,
          () => _navigateToStats(),
          beverage,
        ),
        _buildHeaderAction(
          Icons.settings_outlined,
          () => _navigateToProfile(),
          beverage,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: _headerSlideAnimation,
          child: Opacity(
            opacity: _headerOpacity,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                          child: Text(
                            'Hydration',
                            style: AquaTheme.displayMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (streak > 0) AquaStreakBadge(streak: streak),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getGreeting(),
                      style: AquaTheme.bodyMedium.copyWith(
                        color: AquaTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap, BeverageThemeData beverage) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AquaTheme.getCardBg(context).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: AquaTheme.subtleShadow,
        ),
        child: Icon(
          icon,
          size: 20,
          color: beverage.primary,
        ),
      ),
    );
  }

  Widget _buildQuickAccessMenu(BeverageThemeData beverage, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AquaSectionHeader(
          title: 'More Features',
          icon: Icons.apps_rounded,
          beverageId: _selectedBeverageId,
        ),
        const SizedBox(height: AquaTheme.spacingS),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            _buildFeatureCard(
              icon: Icons.analytics_outlined,
              label: 'Stats',
              color: const Color(0xFF8B5CF6),
              onTap: () => _navigateToStats(),
            ),
            _buildFeatureCard(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
              color: const Color(0xFFF59E0B),
              onTap: () => _navigateToCalendar(),
            ),
            _buildFeatureCard(
              icon: Icons.emoji_events_outlined,
              label: 'Awards',
              color: const Color(0xFFEAB308),
              onTap: () => _navigateToAchievements(),
            ),
            _buildFeatureCard(
              icon: Icons.flag_outlined,
              label: 'Challenges',
              color: const Color(0xFFEF4444),
              onTap: () => _navigateToChallenges(),
            ),
            _buildFeatureCard(
              icon: Icons.coffee_outlined,
              label: 'Caffeine',
              color: const Color(0xFF78350F),
              onTap: () => _navigateToCaffeine(),
            ),
            _buildFeatureCard(
              icon: Icons.person_outline,
              label: 'Profile',
              color: const Color(0xFF6366F1),
              onTap: () => _navigateToProfile(),
            ),
            _buildFeatureCard(
              icon: Icons.notifications_outlined,
              label: 'Reminders',
              color: const Color(0xFF10B981),
              onTap: () => _navigateToReminders(),
            ),
            _buildFeatureCard(
              icon: Icons.local_drink_outlined,
              label: 'Drinks',
              color: beverage.primary,
              onTap: _showBeverageSelector,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AquaTheme.isDark(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AquaTheme.getCardBg(context),
          borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
          boxShadow: AquaTheme.cardShadow(color),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AquaTheme.caption.copyWith(
                color: AquaTheme.getTextPrimary(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning! Stay hydrated today.';
    } else if (hour < 17) {
      return 'Good afternoon! Keep up the hydration.';
    } else {
      return 'Good evening! How\'s your hydration?';
    }
  }

  void _navigateToStats() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterStatisticsScreen()),
    );
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterCalendarScreen()),
    );
  }

  void _navigateToAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterAchievementsScreen()),
    );
  }

  void _navigateToChallenges() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HydrationChallengesScreen()),
    );
  }

  void _navigateToCaffeine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CaffeineInsightsScreen()),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HydrationProfileScreen()),
    );
  }

  void _navigateToReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterCalendarScreen()),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WaterCalendarScreen()),
    );
  }
}
