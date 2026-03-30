import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/category_manager.dart';
import '../../../core/widgets/category_widgets.dart';
import '../../onboarding/screens/category_selection_screen.dart';

class EnhancedCategoryManagementScreen extends StatefulWidget {
  const EnhancedCategoryManagementScreen({super.key});

  @override
  State<EnhancedCategoryManagementScreen> createState() => _EnhancedCategoryManagementScreenState();
}

class _EnhancedCategoryManagementScreenState extends State<EnhancedCategoryManagementScreen> 
    with TickerProviderStateMixin {
  final CategoryManager _categoryManager = CategoryManager();
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final selectedConfig = _categoryManager.selectedCategoryConfig;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? [
              AppColors.darkBackground,
              AppColors.darkSurface,
              selectedConfig?.color.withOpacity(0.05) ?? AppColors.primary.withOpacity(0.05),
            ] : [
              AppColors.primary.withOpacity(0.02),
              AppColors.background,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Current Category Section
                          if (selectedConfig != null) ...[
                            _buildSectionHeader('Current Selection'),
                            const SizedBox(height: 16),
                            CategoryWidgets.buildCategoryOverviewCard(
                              context,
                              config: selectedConfig,
                              analytics: _getMockAnalytics(selectedConfig.category),
                              onTap: () => _navigateToCategorySelection(),
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Quick Switcher Section
                          _buildSectionHeader('Quick Switch'),
                          const SizedBox(height: 16),
                          CategoryWidgets.buildCategoryMiniSelector(
                            context,
                            onCategorySelected: _handleCategorySwitch,
                          ),
                          const SizedBox(height: 32),

                          // All Categories Overview
                          _buildSectionHeader('All Categories'),
                          const SizedBox(height: 16),
                          _buildAllCategoriesGrid(),
                          const SizedBox(height: 32),

                          // Feature Comparison
                          _buildSectionHeader('Feature Comparison'),
                          const SizedBox(height: 16),
                          _buildFeatureComparisonCard(),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? AppColors.darkCard
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.getBorder(context),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColors.getTextPrimary(context),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Manager',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.getTextPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Customize your experience',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.category_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.5)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
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

  Widget _buildAllCategoriesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: CategoryManager.allCategories.length,
      itemBuilder: (context, index) {
        final config = CategoryManager.allCategories[index];
        final isSelected = _categoryManager.selectedCategory == config.category;
        
        return _buildCategoryGridItem(config, isSelected);
      },
    );
  }

  Widget _buildCategoryGridItem(CategoryConfig config, bool isSelected) {
    final isDark = AppColors.isDark(context);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (!isSelected) {
          _handleCategorySwitch(config.category);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                ? config.color.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark ? [
                        config.color.withOpacity(0.3),
                        config.color.withOpacity(0.15),
                      ] : [
                        config.color.withOpacity(0.15),
                        config.color.withOpacity(0.05),
                      ],
                    )
                  : LinearGradient(
                      colors: isDark ? [
                        AppColors.darkCard,
                        AppColors.darkElevatedCard,
                      ] : [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
                    ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                    ? config.color.withOpacity(0.5)
                    : AppColors.getBorder(context),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  // Icon and badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [config.color, config.color.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: config.color.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          config.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: config.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Category name
                  Text(
                    config.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  
                  // Tagline
                  Text(
                    config.tagline,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? config.color : AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  
                  // Feature count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: config.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${config.features.length} Features',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: config.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureComparisonCard() {
    final isDark = AppColors.isDark(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [
                  AppColors.darkCard,
                  AppColors.darkElevatedCard,
                ] : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getBorder(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.focusGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.compare_arrows_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Feature Overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...CategoryManager.allCategories.map((config) => 
                  _buildFeatureRow(config)
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.focusPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.focusPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fun & Relax features are always available with any category selection.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.focusPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _buildFeatureRow(CategoryConfig config) {
    final isSelected = _categoryManager.selectedCategory == config.category;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              config.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected 
                  ? config.color 
                  : AppColors.getTextPrimary(context),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: config.features.map((feature) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  feature.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: config.color,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final isDark = AppColors.isDark(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark ? [
            Colors.transparent,
            AppColors.darkBackground,
          ] : [
            Colors.transparent,
            Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _navigateToCategorySelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: AppColors.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.tune_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Change Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCategorySelection() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CategorySelectionScreen(isOnboarding: false),
      ),
    );
  }

  void _handleCategorySwitch(AppCategory category) async {
    if (_categoryManager.selectedCategory == category) return;
    
    HapticFeedback.heavyImpact();
    
    // Show confirmation dialog for category change
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmationDialog(category),
    );
    
    if (confirm == true) {
      await _categoryManager.selectCategory(category);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Switched to ${_categoryManager.getCategoryConfig(category).name}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildConfirmationDialog(AppCategory category) {
    final config = _categoryManager.getCategoryConfig(category);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [config.color, config.color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Switch Category?'),
        ],
      ),
      content: Text('Change your focus to ${config.name}?\n\n${config.description}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: config.color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Switch'),
        ),
      ],
    );
  }

  Map<String, dynamic> _getMockAnalytics(AppCategory category) {
    // Mock analytics data - replace with real data
    switch (category) {
      case AppCategory.health:
        return {'completionRate': 88};
      case AppCategory.productivity:
        return {'completionRate': 75};
      case AppCategory.fitness:
        return {'completionRate': 92};
      case AppCategory.finance:
        return {'completionRate': 68};
      case AppCategory.periodTracking:
        return {'completionRate': 85};
    }
  }
}
