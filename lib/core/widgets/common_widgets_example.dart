import 'package:flutter/material.dart';
import 'common_widgets.dart';
import 'common_tab_widgets.dart';
import 'premium_category_selector.dart';
import '../constants/app_colors.dart';
import '../services/category_manager.dart';

/// Example usage and documentation for common widgets
/// This file demonstrates how to use the common widgets throughout the app
class CommonWidgetsExample extends StatefulWidget {
  const CommonWidgetsExample({super.key});

  @override
  State<CommonWidgetsExample> createState() => _CommonWidgetsExampleState();
}

class _CommonWidgetsExampleState extends State<CommonWidgetsExample> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pillTabIndex = 0;
  int _segmentedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Common Widgets Examples'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.getBackground(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Examples Section
            _buildSectionHeader('Card Examples'),
            const SizedBox(height: 16),
            
            // Basic CommonCard
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic CommonCard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is a basic card with consistent styling across the app. It automatically adapts to light/dark themes.',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ElevatedCard Example
            ElevatedCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.star, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elevated Card',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Premium styling with gradient background',
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // GradientCard Example
            GradientCard(
              colors: [Colors.blue, Colors.purple],
              child: Row(
                children: [
                  const Icon(Icons.palette, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Gradient Card',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Custom gradient colors',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ListTileCard Example
            ListTileCard(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('List tile card tapped!')),
              ),
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.notifications, color: Colors.white),
              ),
              title: Text(
                'List Tile Card',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              subtitle: Text(
                'Consistent list item styling',
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
            
            const SizedBox(height: 24),
            
            // Button Examples Section
            _buildSectionHeader('Button Examples'),
            const SizedBox(height: 16),
            
            // Button variants in a grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CommonButton(
                  text: 'Primary',
                  variant: ButtonVariant.primary,
                  onPressed: () => _showSnackBar(context, 'Primary button pressed'),
                ),
                CommonButton(
                  text: 'Secondary',
                  variant: ButtonVariant.secondary,
                  onPressed: () => _showSnackBar(context, 'Secondary button pressed'),
                ),
                CommonButton(
                  text: 'Outline',
                  variant: ButtonVariant.outline,
                  onPressed: () => _showSnackBar(context, 'Outline button pressed'),
                ),
                CommonButton(
                  text: 'Success',
                  variant: ButtonVariant.success,
                  onPressed: () => _showSnackBar(context, 'Success button pressed'),
                ),
                CommonButton(
                  text: 'Danger',
                  variant: ButtonVariant.danger,
                  onPressed: () => _showSnackBar(context, 'Danger button pressed'),
                ),
                CommonButton(
                  text: 'Gradient',
                  variant: ButtonVariant.gradient,
                  onPressed: () => _showSnackBar(context, 'Gradient button pressed'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Buttons with icons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                CommonButton(
                  text: 'Add Item',
                  icon: Icons.add,
                  variant: ButtonVariant.primary,
                  onPressed: () => _showSnackBar(context, 'Add item pressed'),
                ),
                CommonButton(
                  text: 'Download',
                  icon: Icons.download,
                  variant: ButtonVariant.outline,
                  onPressed: () => _showSnackBar(context, 'Download pressed'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Loading button example
            CommonCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loading State',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CommonButton(
                          text: 'Processing',
                          isLoading: true,
                          onPressed: null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Icon Button Examples
            _buildSectionHeader('Icon Button Examples'),
            const SizedBox(height: 16),
            
            Row(
              children: [
                CommonIconButton(
                  icon: Icons.favorite,
                  onPressed: () => _showSnackBar(context, 'Favorite pressed'),
                ),
                const SizedBox(width: 12),
                CommonIconButton(
                  icon: Icons.share,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  iconColor: Colors.blue,
                  onPressed: () => _showSnackBar(context, 'Share pressed'),
                ),
                const SizedBox(width: 12),
                CommonIconButton(
                  icon: Icons.settings,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  iconColor: Colors.grey[700],
                  onPressed: () => _showSnackBar(context, 'Settings pressed'),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Analytics Card Example
            _buildSectionHeader('Analytics Card Example'),
            const SizedBox(height: 16),
            
            AnalyticsCard(
              title: 'Health Score',
              icon: Icons.favorite,
              color: Colors.red,
              mainValue: '85%',
              mainLabel: 'Overall',
              stats: [
                {'label': 'This Week', 'value': '+12%'},
                {'label': 'Goal', 'value': '90%'},
              ],
              trend: 'up',
            ),
            
            const SizedBox(height: 24),
            
            // Tab Widget Examples Section
            _buildSectionHeader('Tab Widget Examples'),
            const SizedBox(height: 16),
            
            // Pill Tab Bar Example
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pill Tab Bar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PillTabBar(
                    tabs: const ['Overview', 'Details', 'Stats'],
                    selectedIndex: _pillTabIndex,
                    onTabSelected: (index) {
                      setState(() => _pillTabIndex = index);
                      _showSnackBar(context, 'Selected tab: $index');
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Compact pill-style selector for modern UIs',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Segmented Tab Bar Example
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Segmented Tab Bar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedTabBar(
                    tabs: const ['Daily', 'Weekly', 'Monthly'],
                    selectedIndex: _segmentedTabIndex,
                    onTabSelected: (index) {
                      setState(() => _segmentedTabIndex = index);
                      _showSnackBar(context, 'Selected: ${['Daily', 'Weekly', 'Monthly'][index]}');
                    },
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'iOS-style segmented control for data filtering',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tab Modal Example
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tab Modal Bottom Sheet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CommonButton(
                    text: 'Show Tab Modal',
                    icon: Icons.tab,
                    variant: ButtonVariant.primary,
                    onPressed: () {
                      TabBarModal.show(
                        context: context,
                        title: 'Select Category',
                        tabs: const [
                          TabItem(label: 'Health', icon: Icons.favorite),
                          TabItem(label: 'Fitness', icon: Icons.fitness_center),
                          TabItem(label: 'Nutrition', icon: Icons.restaurant),
                        ],
                        tabViews: [
                          _buildModalTabContent('Health', Icons.favorite, Colors.red),
                          _buildModalTabContent('Fitness', Icons.fitness_center, Colors.orange),
                          _buildModalTabContent('Nutrition', Icons.restaurant, Colors.green),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Modern bottom sheet with tabbed navigation',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Category Selector Examples Section
            _buildSectionHeader('Category Selection Examples'),
            const SizedBox(height: 16),
            
            // Compact Category Selector Example
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compact Category Selector',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CompactCategorySelector(
                    initialCategory: AppCategory.health,
                    onCategorySelected: (category) {
                      final config = CategoryManager.allCategories
                          .firstWhere((c) => c.category == category);
                      _showSnackBar(context, 'Selected: ${config.name}');
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Horizontal scrolling selector for modals and bottom sheets',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category Detail Card Example
            CategoryDetailCard(
              config: CategoryManager.allCategories[1], // Productivity
              isSelected: false,
              onSelect: () {
                _showSnackBar(context, 'Selected Focus & Productivity!');
              },
            ),
            
            const SizedBox(height: 24),
            
            // Usage Guidelines
            _buildSectionHeader('Usage Guidelines'),
            const SizedBox(height: 16),
            
            CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Best Practices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGuideline('Use CommonCard for basic content containers'),
                  _buildGuideline('Use ElevatedCard for important or premium content'),
                  _buildGuideline('Use GradientCard for special highlights or CTAs'),
                  _buildGuideline('Use ListTileCard for consistent list items'),
                  _buildGuideline('Use AnalyticsCard for dashboard metrics'),
                  _buildGuideline('Choose appropriate button variants based on action importance'),
                  _buildGuideline('Use loading states for async operations'),
                  _buildGuideline('Use PillTabBar for compact 2-4 tab selections'),
                  _buildGuideline('Use SegmentedTabBar for data filtering options'),
                  _buildGuideline('Use TabScreen for full-screen tabbed interfaces'),
                  _buildGuideline('Use TabBarModal for bottom sheet selections'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModalTabContent(String title, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Content for $title tab',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
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
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildGuideline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Code Examples for developers
/// 
/// Basic CommonCard usage:
/// ```dart
/// CommonCard(
///   padding: EdgeInsets.all(16),
///   margin: EdgeInsets.only(bottom: 12),
///   child: Text('Your content here'),
/// )
/// ```
/// 
/// ElevatedCard with premium styling:
/// ```dart
/// ElevatedCard(
///   child: Column(
///     children: [
///       Text('Premium Content'),
///       // Your premium content
///     ],
///   ),
/// )
/// ```
/// 
/// GradientCard with custom colors:
/// ```dart
/// GradientCard(
///   colors: [Colors.blue, Colors.purple],
///   child: Text('Highlighted content', style: TextStyle(color: Colors.white)),
/// )
/// ```
/// 
/// CommonButton variants:
/// ```dart
/// CommonButton(
///   text: 'Save',
///   icon: Icons.save,
///   variant: ButtonVariant.primary,
///   onPressed: () => saveData(),
/// )
/// 
/// CommonButton(
///   text: 'Cancel',
///   variant: ButtonVariant.outline,
///   onPressed: () => Navigator.pop(context),
/// )
/// ```
/// 
/// ListTileCard for lists:
/// ```dart
/// ListTileCard(
///   onTap: () => navigateToDetail(),
///   leading: Icon(Icons.person),
///   title: Text('User Name'),
///   subtitle: Text('user@email.com'),
///   trailing: Icon(Icons.chevron_right),
/// )
/// ```
/// 
/// AnalyticsCard for dashboard metrics:
/// ```dart
/// AnalyticsCard(
///   title: 'Water Intake',
///   icon: Icons.water_drop,
///   color: Colors.blue,
///   mainValue: '2.1L',
///   mainLabel: 'Today',
///   stats: [
///     {'label': 'Goal', 'value': '2.5L'},
///     {'label': 'Progress', 'value': '84%'},
///   ],
///   trend: 'up',
/// )
/// ```
