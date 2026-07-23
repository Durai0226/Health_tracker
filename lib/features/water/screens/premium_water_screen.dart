import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';

import '../services/water_service.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../models/enhanced_water_log.dart';
import '../widgets/water_bottle_widget.dart';
import '../widgets/water_quick_actions.dart';
import '../widgets/water_insights_card.dart';
import '../widgets/water_weekly_chart.dart';
import 'water_statistics_screen.dart';
import 'water_calendar_screen.dart';
import 'hydration_profile_screen.dart';

/// Premium Water Tracking Screen
/// Modern 2025/2026 UI with glassmorphism, animations, and premium features
class PremiumWaterScreen extends StatefulWidget {
  const PremiumWaterScreen({super.key});

  @override
  State<PremiumWaterScreen> createState() => _PremiumWaterScreenState();
}

class _PremiumWaterScreenState extends State<PremiumWaterScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _headerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  // Data
  DailyWaterData _todayData = DailyWaterData(
    id: '',
    date: DateTime.now(),
    dailyGoalMl: 2000,
  );
  BeverageType _selectedBeverage = BeverageType.defaultBeverages.first;
  List<WaterContainer> _containers = [];
  List<DailyWaterSummary> _weekData = [];
  List<WaterLogEntry> _recentLogs = [];

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
      curve: Curves.easeOut,
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
      curve: Curves.easeOutCubic,
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
    await WaterService.init();

    final todayData = WaterService.getTodayData();
    final containers = WaterService.getFrequentContainers(limit: 3);

    // Build week data
    final weekData = <DailyWaterSummary>[];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isAfter(now)) break;

      final dayData = WaterService.getDataForDate(date);
      weekData.add(DailyWaterSummary(
        date: date,
        intakeMl: dayData?.effectiveHydrationMl ?? 0,
        goalMl: todayData.dailyGoalMl,
      ));
    }

    // Build recent logs
    final recentLogs = todayData.logs.reversed.take(5).map((log) {
      final beverage = WaterService.getBeverage(log.beverageId);
      return WaterLogEntry(
        id: log.id,
        beverageName: beverage?.name ?? log.beverageName,
        emoji: beverage?.emoji ?? '💧',
        colorHex: beverage?.colorHex ?? '#2196F3',
        amountMl: log.amountMl,
        time: log.time,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _todayData = todayData;
        _containers = containers;
        _weekData = weekData;
        _recentLogs = recentLogs;
      });
    }
  }

  Future<void> _addWater(int amountMl, BeverageType beverage) async {
    HapticFeedback.mediumImpact();

    final updatedData = await WaterService.addWaterLog(
      amountMl: amountMl,
      beverage: beverage,
    );

    setState(() {
      _todayData = updatedData;
    });

    // Reload to update logs
    _loadData();

    // Show success feedback
    if (mounted) {
      _showAddedSnackBar(amountMl, beverage);
    }
  }

  void _showAddedSnackBar(int amountMl, BeverageType beverage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(
              beverage.emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Text(
              '+${amountMl}ml ${beverage.name}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(int.parse(
            beverage.colorHex.replaceFirst('#', '0xFF'))),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBeverageSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BeverageSelectionSheet(
        beverages: WaterService.getAllBeverages(),
        selectedBeverage: _selectedBeverage,
        onSelect: (beverage) {
          setState(() {
            _selectedBeverage = beverage;
          });
        },
      ),
    );
  }

  void _showCustomAmountDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomAmountDialog(
        beverage: _selectedBeverage,
        onConfirm: (amount) => _addWater(amount, _selectedBeverage),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background gradient
          _buildBackground(),
          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App bar
              _buildSliverAppBar(),
              // Content
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        // Water bottle visualization
                        _buildWaterBottleSection(),
                        const SizedBox(height: 32),
                        // Quick add actions
                        WaterQuickActions(
                          containers: _containers,
                          selectedBeverage: _selectedBeverage,
                          onQuickAdd: _addWater,
                          onCustomAmount: _showCustomAmountDialog,
                          onBeverageSelect: _showBeverageSelection,
                        ),
                        const SizedBox(height: 32),
                        // Insights card
                        WaterInsightsCard(
                          currentStreak: WaterService.getCurrentStreak(),
                          longestStreak: WaterService.getAchievements().longestStreak,
                          todayProgress: _todayData.progress,
                          todayCaffeine: _todayData.totalCaffeineMg,
                          todayAlcohol: _todayData.alcoholicDrinksCount,
                          avgDailyMl: WaterService.getWeeklyStats()['averageMl'] ?? 0,
                          goalMl: _todayData.dailyGoalMl,
                          onTapDetails: () => _navigateToStats(),
                        ),
                        const SizedBox(height: 32),
                        // Weekly chart
                        WaterWeeklyChart(
                          weekData: _weekData,
                          goalMl: _todayData.dailyGoalMl,
                          onTapHistory: () => _navigateToCalendar(),
                        ),
                        const SizedBox(height: 32),
                        // Recent activity
                        WaterHistoryTimeline(
                          entries: _recentLogs,
                          onTapViewAll: () => _navigateToCalendar(),
                        ),
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

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              const Color(0xFFF8FAFC),
            ],
            stops: const [0.0, 0.3],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: SlideTransition(
          position: _headerSlideAnimation,
          child: Opacity(
            opacity: _headerOpacity,
            child: _buildHeader(),
          ),
        ),
      ),
      actions: [
        _buildHeaderAction(
          Symbols.bar_chart_rounded,
          () => _navigateToStats(),
        ),
        _buildHeaderAction(
          Symbols.settings_rounded,
          () => _navigateToProfile(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Title with gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.blue.shade600, Colors.cyan.shade500],
                  ).createShader(bounds),
                  child: const Text(
                    'Hydration',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                // Streak badge
                CompactStreakWidget(
                  streak: WaterService.getCurrentStreak(),
                  isActive: WaterService.getCurrentStreak() > 0,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getGreeting(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildWaterBottleSection() {
    return Center(
      child: WaterBottleWidget(
        progress: _todayData.progress,
        currentMl: _todayData.effectiveHydrationMl,
        goalMl: _todayData.dailyGoalMl,
        waterColor: Color(int.parse(
            _selectedBeverage.colorHex.replaceFirst('#', '0xFF'))),
        onTap: _showBeverageSelection,
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
      MaterialPageRoute(
        builder: (context) => const WaterStatisticsScreen(),
      ),
    );
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WaterCalendarScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HydrationProfileScreen(),
      ),
    );
  }
}
