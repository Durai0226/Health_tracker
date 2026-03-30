import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/services/category_manager.dart';

import '../../settings/screens/settings_screen.dart';
import '../../focus/screens/focus_screen.dart';
import '../../fun/screens/fun_relax_dashboard.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../fitness/screens/fitness_home_screen.dart';
import '../../finance/screens/finance_home_screen.dart';
import '../../period_tracking/screens/luna_dashboard_screen.dart';
import 'category_home_screen.dart';
import 'category_dashboard_screen.dart';

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
    // Dashboard: Analytics overview for selected category
    // Category-specific: Primary feature screen
    // Home: All features for selected category
    // Fun/Relax: always available
    // Settings: App settings
    
    return [
      const CategoryDashboardScreen(),
      _getCategorySpecificScreen(category),
      const CategoryHomeScreen(),
      const FunRelaxDashboard(),
      const SettingsScreen(),
    ];
  }
  
  Widget _getCategorySpecificScreen(AppCategory? category) {
    switch (category) {
      case AppCategory.health:
        return const NunitoMedicationDashboard();
      case AppCategory.productivity:
        return const FocusScreen();
      case AppCategory.fitness:
        return const FitnessHomeScreen();
      case AppCategory.finance:
        return const FinanceHomeScreen();
      case AppCategory.periodTracking:
        return const LunaDashboardScreen();
      case null:
        return const CategoryHomeScreen();
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
        return 'Her Elara';
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

  List<GlassNavItem> get _navItems {
    final category = _categoryManager.selectedCategory;
    return [
      const GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      GlassNavItem(icon: _getCategoryIcon(category, active: false), activeIcon: _getCategoryIcon(category, active: true), label: _getCategoryLabel(category)),
      const GlassNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      const GlassNavItem(icon: Icons.spa_outlined, activeIcon: Icons.spa_rounded, label: 'Relax'),
      const GlassNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
    ];
  }

  Widget _buildNavBar() {
    final category = _categoryManager.selectedCategory;

    return MainBottomNav(
      currentIndex: _currentIndex,
      onTap: _onItemTapped,
      items: _navItems,
      featureColor: AppColors.primary,
      dynamicCategoryIcon: _getCategoryIcon(category, active: _currentIndex == 1),
      dynamicCategoryLabel: _getCategoryLabel(category),
    );
  }
}

