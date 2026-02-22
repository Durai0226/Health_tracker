import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/category_manager.dart';
import 'common_widgets.dart';

/// Premium category selector with modern, compact, and user-friendly design
class PremiumCategorySelector extends StatefulWidget {
  final Function(AppCategory)? onCategorySelected;
  final AppCategory? initialCategory;
  final bool showHeader;

  const PremiumCategorySelector({
    super.key,
    this.onCategorySelected,
    this.initialCategory,
    this.showHeader = true,
  });

  @override
  State<PremiumCategorySelector> createState() => _PremiumCategorySelectorState();
}

class _PremiumCategorySelectorState extends State<PremiumCategorySelector>
    with SingleTickerProviderStateMixin {
  AppCategory? _selectedCategory;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          _buildHeader(),
          const SizedBox(height: 24),
        ],
        _buildCategoryGrid(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.dashboard_customize_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Your Focus',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select one category to personalize your experience',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: CategoryManager.allCategories.length,
      itemBuilder: (context, index) {
        final category = CategoryManager.allCategories[index];
        final isSelected = _selectedCategory == category.category;
        
        return _buildCategoryCard(category, isSelected, index);
      },
    );
  }

  Widget _buildCategoryCard(CategoryConfig config, bool isSelected, int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = config.category);
          widget.onCategorySelected?.call(config.category);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          transform: isSelected
              ? (Matrix4.identity()..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: isSelected
                ? config.color.withOpacity(0.08)
                : AppColors.getCardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? config.color
                  : Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Container(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: config.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            config.icon,
                            color: config.color,
                            size: 28,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: config.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: config.color.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Category name
                    Text(
                      config.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? config.color : AppColors.getTextPrimary(context),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Tagline
                    Text(
                      config.tagline,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                  ],
                ),
          ),
      ),
    );
  }
}

/// Compact horizontal category selector for modals/bottom sheets
class CompactCategorySelector extends StatefulWidget {
  final Function(AppCategory)? onCategorySelected;
  final AppCategory? initialCategory;

  const CompactCategorySelector({
    super.key,
    this.onCategorySelected,
    this.initialCategory,
  });

  @override
  State<CompactCategorySelector> createState() => _CompactCategorySelectorState();
}

class _CompactCategorySelectorState extends State<CompactCategorySelector> {
  AppCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: CategoryManager.allCategories.length,
        itemBuilder: (context, index) {
          final category = CategoryManager.allCategories[index];
          final isSelected = _selectedCategory == category.category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildCompactCard(category, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCompactCard(CategoryConfig config, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = config.category);
        widget.onCategorySelected?.call(config.category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? config.color.withOpacity(0.1)
              : AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? config.color : Colors.black.withOpacity(0.06),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    config.icon,
                    color: config.color,
                    size: 20,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: config.color,
                    size: 18,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? config.color : AppColors.getTextPrimary(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${config.features.length} features',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Category detail card with expanded information
class CategoryDetailCard extends StatelessWidget {
  final CategoryConfig config;
  final VoidCallback? onSelect;
  final bool isSelected;

  const CategoryDetailCard({
    super.key,
    required this.config,
    this.onSelect,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      shadowColor: config.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and name
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(config.icon, color: config.color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.tagline,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            config.description,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(context),
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Features list
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: config.features.map((feature) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: config.color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: config.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatFeatureName(feature),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: config.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          
          if (onSelect != null) ...[
            const SizedBox(height: 20),
            CommonButton(
              text: isSelected ? 'Selected' : 'Select ${config.name}',
              icon: isSelected ? Icons.check_circle : Icons.arrow_forward_rounded,
              variant: isSelected ? ButtonVariant.success : ButtonVariant.primary,
              onPressed: isSelected ? null : onSelect,
            ),
          ],
        ],
      ),
    );
  }

  String _formatFeatureName(String feature) {
    return feature
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
