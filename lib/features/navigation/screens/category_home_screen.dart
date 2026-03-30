import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/category_manager.dart';
import '../../../core/services/feature_navigation_service.dart';
import '../../../core/services/haptic_service.dart';

class CategoryHomeScreen extends StatefulWidget {
  const CategoryHomeScreen({super.key});

  @override
  State<CategoryHomeScreen> createState() => _CategoryHomeScreenState();
}

class _CategoryHomeScreenState extends State<CategoryHomeScreen>
    with TickerProviderStateMixin {
  final CategoryManager _categoryManager = CategoryManager();
  final FeatureNavigationService _navService = FeatureNavigationService();
  final HapticService _hapticService = HapticService();
  
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
    _staggerController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
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
                _buildQuickActions(config),
                _buildFeaturesGrid(config, categoryColor),
                _buildFunRelaxSection(categoryColor),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CategoryConfig? config, Color categoryColor) {
    final isDark = AppColors.isDark(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  child: Icon(
                    config?.icon ?? Icons.apps_rounded,
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
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config?.name ?? 'Home',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.getTextPrimary(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: categoryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      config?.tagline ?? 'Your personal wellness companion',
                      style: TextStyle(
                        fontSize: 14,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildQuickActions(CategoryConfig? config) {
    if (config == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    final features = config.features;
    if (features.length <= 2) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Quick Access', config.color),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  final featureId = features[index];
                  return _buildQuickActionChip(featureId, config.color, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String featureId, Color categoryColor, int index) {
    final isDark = AppColors.isDark(context);
    final featureColor = _navService.getFeatureColor(featureId);
    final delay = index * 0.1;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animValue = Curves.easeOutCubic.transform(
          (_staggerController.value - delay).clamp(0.0, 1.0),
        );
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          _hapticService.selection();
          _navService.navigateToFeatureWithAuth(context, featureId);
        },
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      featureColor.withOpacity(0.2),
                      featureColor.withOpacity(0.1),
                    ]
                  : [
                      featureColor.withOpacity(0.12),
                      featureColor.withOpacity(0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: featureColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: featureColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _navService.getFeatureIcon(featureId),
                  color: featureColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _navService.getFeatureDisplayName(featureId),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: featureColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(CategoryConfig? config, Color categoryColor) {
    if (config == null) {
      return SliverToBoxAdapter(
        child: _buildNoCategory(),
      );
    }

    final features = config.features;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Your Features', categoryColor),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                return _buildFeatureCard(features[index], index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String featureId, int index) {
    final isDark = AppColors.isDark(context);
    final featureColor = _navService.getFeatureColor(featureId);
    final delay = index * 0.08;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animValue = Curves.easeOutBack.transform(
          ((_staggerController.value - delay) * 1.2).clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: 0.8 + (0.2 * animValue),
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          _hapticService.selection();
          HapticFeedback.mediumImpact();
          _navService.navigateToFeatureWithAuth(context, featureId);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: featureColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppColors.darkCard,
                            AppColors.darkElevatedCard,
                          ]
                        : [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? featureColor.withOpacity(0.2)
                        : featureColor.withOpacity(0.15),
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                featureColor,
                                featureColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: featureColor.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _navService.getFeatureIcon(featureId),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.getTextSecondary(context),
                          size: 16,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _navService.getFeatureDisplayName(featureId),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFeatureSubtitle(featureId),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildFunRelaxSection(Color categoryColor) {
    final isDark = AppColors.isDark(context);
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Always Available', const Color(0xFF9333EA)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                _hapticService.selection();
                _navService.navigateToFeatureWithAuth(context, 'fun');
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF9333EA).withOpacity(0.2),
                            const Color(0xFF7C3AED).withOpacity(0.1),
                          ]
                        : [
                            const Color(0xFF9333EA).withOpacity(0.1),
                            const Color(0xFF7C3AED).withOpacity(0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF9333EA).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9333EA).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Fun & Relax',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.getTextPrimary(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9333EA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'FREE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Relaxing experiences, games & haptic therapy',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: const Color(0xFF9333EA),
                      size: 18,
                    ),
                  ],
                ),
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

  Widget _buildNoCategory() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: AppColors.getTextSecondary(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No category selected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select a category to see your features',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
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
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFeatureSubtitle(String featureId) {
    switch (featureId) {
      case 'medicine':
        return 'Track medications & reminders';
      case 'water':
        return 'Stay hydrated daily';
      case 'reminders':
        return 'Never miss a thing';
      case 'focus':
        return 'Deep work sessions';
      case 'notes':
        return 'Capture your thoughts';
      case 'exam_prep':
        return 'Study smarter';
      case 'fitness':
        return 'Track your workouts';
      case 'finance':
        return 'Manage expenses';
      case 'period':
        return 'Cycle tracking';
      case 'mood':
        return 'Track emotions';
      case 'habit':
        return 'Build routines';
      default:
        return 'Tap to open';
    }
  }
}
