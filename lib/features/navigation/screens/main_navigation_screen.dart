
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/services/category_manager.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../focus/screens/focus_screen.dart';
import '../../fun/screens/fun_relax_dashboard.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2;
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();
  final CategoryManager _categoryManager = CategoryManager();

  List<Widget> get _screens {
    final category = _categoryManager.selectedCategory;
    
    // Dynamic screens based on selected category
    // Always include: Dashboard, Home, Settings
    // Category-specific: varies
    // Fun/Relax: always available
    
    return [
      const DashboardScreen(),
      _getCategorySpecificScreen(category),
      const HomeScreen(),
      const FunRelaxDashboard(), // Fun/Relax always available
      const SettingsScreen(),
    ];
  }
  
  Widget _getCategorySpecificScreen(AppCategory? category) {
    switch (category) {
      case AppCategory.health:
        return const TrackingScreen();
      case AppCategory.productivity:
        return const FocusScreen();
      case AppCategory.fitness:
        return const TrackingScreen();
      case AppCategory.finance:
        return const TrackingScreen();
      case AppCategory.periodTracking:
        return const TrackingScreen();
      case null:
        return const TrackingScreen();
    }
  }
  
  IconData _getCategoryIcon(AppCategory? category, {bool active = false}) {
    switch (category) {
      case AppCategory.health:
        return active ? Icons.monitor_heart_rounded : Icons.monitor_heart_outlined;
      case AppCategory.productivity:
        return active ? Icons.self_improvement_rounded : Icons.self_improvement_outlined;
      case AppCategory.fitness:
        return active ? Icons.fitness_center_rounded : Icons.fitness_center_outlined;
      case AppCategory.finance:
        return active ? Icons.account_balance_wallet_rounded : Icons.account_balance_wallet_outlined;
      case AppCategory.periodTracking:
        return active ? Icons.calendar_month_rounded : Icons.calendar_month_outlined;
      case null:
        return active ? Icons.track_changes_rounded : Icons.track_changes_outlined;
    }
  }
  
  String _getCategoryLabel(AppCategory? category) {
    switch (category) {
      case AppCategory.health:
        return 'Health';
      case AppCategory.productivity:
        return 'Focus';
      case AppCategory.fitness:
        return 'Fitness';
      case AppCategory.finance:
        return 'Finance';
      case AppCategory.periodTracking:
        return 'Cycle';
      case null:
        return 'Tracking';
    }
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      _hapticService.navigation();
      _vitaVibeService.navigation();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    final isDark = AppColors.isDark(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.6)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: _getCategoryIcon(_categoryManager.selectedCategory, active: false),
                    activeIcon: _getCategoryIcon(_categoryManager.selectedCategory, active: true),
                    label: _getCategoryLabel(_categoryManager.selectedCategory),
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  _buildNavItem(
                    index: 3,
                    icon: Icons.spa_outlined,
                    activeIcon: Icons.spa_rounded,
                    label: 'Relax',
                  ),
                  _buildNavItem(
                    index: 4,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.primary.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.getTextSecondary(context),
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.getTextSecondary(context),
                  letterSpacing: 0.1,
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
