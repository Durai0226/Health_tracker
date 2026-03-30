import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/category_manager.dart';
import '../../../core/services/feature_navigation_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../finance/services/finance_service.dart';

class CategoryDashboardScreen extends StatefulWidget {
  const CategoryDashboardScreen({super.key});

  @override
  State<CategoryDashboardScreen> createState() => _CategoryDashboardScreenState();
}

class _CategoryDashboardScreenState extends State<CategoryDashboardScreen>
    with TickerProviderStateMixin {
  final CategoryManager _categoryManager = CategoryManager();
  final FeatureNavigationService _navService = FeatureNavigationService();
  final HapticService _hapticService = HapticService();
  
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _progressController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final config = _categoryManager.selectedCategoryConfig;
    final categoryColor = config?.color ?? AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkBackground,
                    AppColors.darkSurface,
                    categoryColor.withOpacity(0.05),
                  ]
                : [
                    categoryColor.withOpacity(0.03),
                    AppColors.background,
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(config, categoryColor),
                _buildOverallProgress(config, categoryColor),
                _buildFeatureStats(config, categoryColor),
                _buildRecentActivity(config, categoryColor),
                _buildInsights(config, categoryColor),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CategoryConfig? config, Color categoryColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [categoryColor, categoryColor.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: categoryColor.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    config?.name ?? 'Overview',
                    style: TextStyle(
                      fontSize: 14,
                      color: categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _buildDateBadge(categoryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(Color color) {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '${now.day}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            months[now.month - 1],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress(CategoryConfig? config, Color categoryColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                categoryColor,
                categoryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withOpacity(0.4),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        final value = (75 * _progressController.value).round();
                        return Text(
                          '$value%',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keep going! You\'re doing great.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                height: 100,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CircularProgressPainter(
                        progress: 0.75 * _progressController.value,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        progressColor: Colors.white,
                        strokeWidth: 10,
                      ),
                      child: Center(
                        child: Icon(
                          config?.icon ?? Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureStats(CategoryConfig? config, Color categoryColor) {
    if (config == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    final features = config.features;
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Feature Stats', categoryColor),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: features.length.clamp(0, 4),
              itemBuilder: (context, index) {
                return _buildStatCard(features[index], index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String featureId, int index) {
    final isDark = AppColors.isDark(context);
    final featureColor = _navService.getFeatureColor(featureId);
    final stats = _getMockStats(featureId);
    
    return GestureDetector(
      onTap: () {
        _hapticService.selection();
        _navService.navigateToFeature(context, featureId);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: featureColor.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: featureColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _navService.getFeatureIcon(featureId),
                    color: featureColor,
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stats['trend'] == 'up' 
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stats['trend'] == 'up'
                            ? Icons.trending_up_rounded
                            : Icons.trending_flat_rounded,
                        color: stats['trend'] == 'up'
                            ? AppColors.success
                            : AppColors.warning,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        stats['change'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: stats['trend'] == 'up'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              stats['value'],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            Text(
              _navService.getFeatureDisplayName(featureId),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(CategoryConfig? config, Color categoryColor) {
    final isDark = AppColors.isDark(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Recent Activity', categoryColor),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildActivityItem(
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    title: 'Completed daily goal',
                    subtitle: '2 hours ago',
                    isFirst: true,
                  ),
                  _buildActivityItem(
                    icon: Icons.notifications_active_rounded,
                    color: AppColors.warning,
                    title: 'Reminder triggered',
                    subtitle: '4 hours ago',
                  ),
                  _buildActivityItem(
                    icon: Icons.star_rounded,
                    color: const Color(0xFFFFB800),
                    title: 'New streak achieved!',
                    subtitle: 'Yesterday',
                  ),
                  _buildActivityItem(
                    icon: Icons.trending_up_rounded,
                    color: AppColors.info,
                    title: 'Progress increased',
                    subtitle: 'Yesterday',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.getBorder(context),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.getTextSecondary(context),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildInsights(CategoryConfig? config, Color categoryColor) {
    final isDark = AppColors.isDark(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Insights', categoryColor),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          categoryColor.withOpacity(0.15),
                          categoryColor.withOpacity(0.08),
                        ]
                      : [
                          categoryColor.withOpacity(0.08),
                          categoryColor.withOpacity(0.03),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: categoryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: categoryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Summary',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You\'ve been consistent this week! Your completion rate is up 12% compared to last week.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextSecondary(context),
                            height: 1.4,
                          ),
                        ),
                      ],
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

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.5)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getMockStats(String featureId) {
    switch (featureId) {
      case 'medicine':
        return {'value': '3/4', 'change': '+2', 'trend': 'up'};
      case 'water':
        return {'value': '1.8L', 'change': '+0.3L', 'trend': 'up'};
      case 'reminders':
        return {'value': '8', 'change': '0', 'trend': 'flat'};
      case 'focus':
        return {'value': '2h 15m', 'change': '+30m', 'trend': 'up'};
      case 'notes':
        return {'value': '12', 'change': '+3', 'trend': 'up'};
      case 'exam_prep':
        return {'value': '85%', 'change': '+5%', 'trend': 'up'};
      case 'fitness':
        return {'value': '4,523', 'change': '+800', 'trend': 'up'};
      case 'finance':
        try {
          final balance = FinanceService.getTotalBalance();
          return {'value': '\$${balance.abs().toStringAsFixed(0)}', 'change': balance >= 0 ? '+' : '-', 'trend': balance >= 0 ? 'up' : 'flat'};
        } catch (_) {
          return {'value': '\$0', 'change': '', 'trend': 'flat'};
        }
      case 'period':
        return {'value': 'Day 14', 'change': '', 'trend': 'flat'};
      case 'mood':
        return {'value': '😊', 'change': '+1', 'trend': 'up'};
      case 'habit':
        return {'value': '5/7', 'change': '+1', 'trend': 'up'};
      default:
        return {'value': '--', 'change': '0', 'trend': 'flat'};
    }
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
