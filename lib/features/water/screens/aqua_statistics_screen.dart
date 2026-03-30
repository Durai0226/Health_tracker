import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/aqua_theme.dart';
import '../widgets/aqua_glass_card.dart';
import '../services/water_service.dart';

/// Modern Aqua Statistics Screen
/// Features: Charts, trends, insights with dynamic beverage gradients
class AquaStatisticsScreen extends StatefulWidget {
  const AquaStatisticsScreen({super.key});

  @override
  State<AquaStatisticsScreen> createState() => _AquaStatisticsScreenState();
}

class _AquaStatisticsScreenState extends State<AquaStatisticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  String _selectedPeriod = 'week';
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: AquaTheme.curveDefault,
    );
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    await WaterService.init();
    final weeklyStats = WaterService.getWeeklyStats();
    
    if (mounted) {
      setState(() {
        _stats = weeklyStats;
        _isLoading = false;
      });
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);

    return Scaffold(
      backgroundColor: AquaTheme.getBackground(context),
      body: Stack(
        children: [
          // Background
          _buildBackground(isDark),
          
          // Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(AquaTheme.spacingM),
                    child: Column(
                      children: [
                        // Period selector
                        _buildPeriodSelector(),
                        const SizedBox(height: AquaTheme.spacingL),
                        
                        // Overview cards
                        _buildOverviewCards(),
                        const SizedBox(height: AquaTheme.spacingL),
                        
                        // Weekly chart
                        _buildWeeklyChart(),
                        const SizedBox(height: AquaTheme.spacingL),
                        
                        // Beverage breakdown
                        _buildBeverageBreakdown(),
                        const SizedBox(height: AquaTheme.spacingL),
                        
                        // Insights
                        _buildInsights(),
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

  Widget _buildBackground(bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AquaTheme.waterPrimary.withOpacity(isDark ? 0.15 : 0.1),
              AquaTheme.getBackground(context),
            ],
            stops: const [0.0, 0.3],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
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
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AquaTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (bounds) => AquaTheme.primaryGradient.createShader(bounds),
                      child: Text(
                        'Statistics',
                        style: AquaTheme.displayMedium.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['week', 'month', 'year'];
    final labels = ['This Week', 'This Month', 'This Year'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AquaTheme.getCardBg(context),
        borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
        boxShadow: AquaTheme.subtleShadow,
      ),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == periods[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = periods[index]),
              child: AnimatedContainer(
                duration: AquaTheme.animationFast,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AquaTheme.primaryGradient : null,
                  borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: AquaTheme.labelMedium.copyWith(
                    color: isSelected ? Colors.white : AquaTheme.getTextSecondary(context),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final avgMl = _stats['averageMl'] ?? 0;
    final totalMl = _stats['totalMl'] ?? 0;
    final streak = WaterService.getCurrentStreak();
    final goalRate = _stats['goalCompletionRate'] ?? 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          icon: Icons.water_drop_rounded,
          value: '${(totalMl / 1000).toStringAsFixed(1)}L',
          label: 'Total Intake',
          color: AquaTheme.waterPrimary,
        ),
        _buildStatCard(
          icon: Icons.show_chart_rounded,
          value: '${avgMl}ml',
          label: 'Daily Average',
          color: const Color(0xFF8B5CF6),
        ),
        _buildStatCard(
          icon: Icons.local_fire_department_rounded,
          value: '$streak',
          label: 'Day Streak',
          color: const Color(0xFFFF9500),
        ),
        _buildStatCard(
          icon: Icons.check_circle_rounded,
          value: '${(goalRate * 100).toInt()}%',
          label: 'Goal Rate',
          color: AquaTheme.success,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final isDark = AquaTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingM),
      decoration: BoxDecoration(
        color: AquaTheme.getCardBg(context),
        borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
        boxShadow: AquaTheme.cardShadow(color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AquaTheme.heading2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AquaTheme.caption.copyWith(
                  color: AquaTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday;
    final goal = WaterService.getDailyGoal();

    return AquaGlassCard(
      beverageId: 'water',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AquaTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Weekly Overview',
                style: AquaTheme.heading3.copyWith(
                  color: AquaTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AquaTheme.spacingL),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final dayNum = index + 1;
                final isToday = dayNum == today;
                final isPast = dayNum < today;
                
                // Get actual data or use demo
                double progress = 0;
                if (isPast) {
                  progress = 0.5 + (math.Random(index).nextDouble() * 0.5);
                } else if (isToday) {
                  final todayData = WaterService.getTodayData();
                  progress = todayData.progress;
                }
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildBarItem(
                      label: days[index],
                      progress: progress.clamp(0.0, 1.0),
                      isToday: isToday,
                      isFuture: dayNum > today,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AquaTheme.spacingM),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Goal', AquaTheme.success),
              const SizedBox(width: 20),
              _buildLegendItem('Partial', AquaTheme.waterPrimary),
              const SizedBox(width: 20),
              _buildLegendItem('None', Colors.grey.shade300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem({
    required String label,
    required double progress,
    required bool isToday,
    required bool isFuture,
  }) {
    final isDark = AquaTheme.isDark(context);
    final isComplete = progress >= 1.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: AquaTheme.animationMedium,
                height: isFuture ? 0 : (progress * 120).clamp(0, 120),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isComplete
                        ? [AquaTheme.success, const Color(0xFF34D399)]
                        : [AquaTheme.waterPrimary, AquaTheme.waterSecondary],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: isToday ? AquaTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
          ),
          child: Text(
            label,
            style: AquaTheme.caption.copyWith(
              color: isToday ? Colors.white : AquaTheme.getTextSecondary(context),
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AquaTheme.caption.copyWith(
            color: AquaTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildBeverageBreakdown() {
    // Demo data for beverage breakdown
    final beverages = [
      {'id': 'water', 'percentage': 65, 'amount': 1625},
      {'id': 'coffee', 'percentage': 20, 'amount': 500},
      {'id': 'tea', 'percentage': 10, 'amount': 250},
      {'id': 'juice', 'percentage': 5, 'amount': 125},
    ];

    return AquaGlassCard(
      beverageId: 'water',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AquaTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Beverage Breakdown',
                style: AquaTheme.heading3.copyWith(
                  color: AquaTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AquaTheme.spacingM),
          ...beverages.map((bev) {
            final beverage = AquaTheme.getBeverage(bev['id'] as String);
            final percentage = bev['percentage'] as int;
            final amount = bev['amount'] as int;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(beverage.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              beverage.name,
                              style: AquaTheme.bodyMedium.copyWith(
                                color: AquaTheme.getTextPrimary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${amount}ml',
                              style: AquaTheme.labelMedium.copyWith(
                                color: beverage.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: beverage.primary.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation(beverage.primary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$percentage%',
                    style: AquaTheme.labelMedium.copyWith(
                      color: AquaTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    final insights = [
      {
        'icon': Icons.trending_up_rounded,
        'title': 'Great Progress!',
        'message': 'You\'ve been consistent this week. Keep it up!',
        'color': AquaTheme.success,
      },
      {
        'icon': Icons.lightbulb_outline_rounded,
        'title': 'Tip',
        'message': 'Try drinking a glass of water first thing in the morning.',
        'color': AquaTheme.warning,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AquaSectionHeader(
          title: 'Insights',
          icon: Icons.psychology_rounded,
          beverageId: 'water',
        ),
        const SizedBox(height: AquaTheme.spacingS),
        ...insights.map((insight) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(AquaTheme.spacingM),
          decoration: AquaTheme.getCardDecoration(
            context,
            accentColor: insight['color'] as Color,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (insight['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  insight['icon'] as IconData,
                  color: insight['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight['title'] as String,
                      style: AquaTheme.labelLarge.copyWith(
                        color: AquaTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insight['message'] as String,
                      style: AquaTheme.bodySmall.copyWith(
                        color: AquaTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
