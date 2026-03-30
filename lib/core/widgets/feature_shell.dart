import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '../constants/app_colors.dart';
import '../services/haptic_service.dart';
import 'feature_profile_sheet.dart';

/// Navigation item configuration for feature bottom nav
class FeatureNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FeatureNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Reusable shell widget that wraps feature screens with bottom navigation
/// Provides consistent navigation pattern across all features
class FeatureShell extends StatefulWidget {
  final String featureId;
  final String featureName;
  final Color featureColor;
  final IconData featureIcon;
  final List<Widget> screens;
  final List<FeatureNavItem> navItems;
  final int initialIndex;
  final List<FeatureSettingItem> profileSettings;
  final VoidCallback? onSyncTap;
  final VoidCallback onSignOut;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final ThemeData? theme;

  const FeatureShell({
    super.key,
    required this.featureId,
    required this.featureName,
    required this.featureColor,
    required this.featureIcon,
    required this.screens,
    required this.navItems,
    this.initialIndex = 0,
    required this.profileSettings,
    this.onSyncTap,
    required this.onSignOut,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.theme,
  });

  @override
  State<FeatureShell> createState() => _FeatureShellState();
}

class _FeatureShellState extends State<FeatureShell> {
  final HapticService _hapticService = HapticService();
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    if (_currentIndex != index) {
      _hapticService.selection();
      setState(() => _currentIndex = index);
    }
  }

  void _openProfile() {
    _hapticService.selection();
    FeatureProfileSheet.show(
      context: context,
      featureName: widget.featureName,
      featureColor: widget.featureColor,
      featureIcon: widget.featureIcon,
      settings: widget.profileSettings,
      onSyncTap: widget.onSyncTap,
      onSignOut: widget.onSignOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: widget.screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
    );

    if (widget.theme != null) {
      return Theme(data: widget.theme!, child: content);
    }
    return content;
  }

  Widget _buildBottomNav() {
    final isDark = AppColors.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: widget.featureColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65 + (bottomPadding > 0 ? 0 : 8),
          child: StylishBottomBar(
            option: BubbleBarOptions(
              barStyle: BubbleBarStyle.horizontal,
              bubbleFillStyle: BubbleFillStyle.fill,
              opacity: 0.2,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: widget.navItems.asMap().entries.map((entry) {
              final item = entry.value;
              final isProfile = item.label.toLowerCase() == 'profile';
              
              return BottomBarItem(
                icon: Icon(
                  item.icon, 
                  color: AppColors.getTextSecondary(context),
                ),
                selectedIcon: Icon(
                  item.activeIcon, 
                  color: isProfile ? AppColors.getTextSecondary(context) : widget.featureColor,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isProfile ? AppColors.getTextSecondary(context) : widget.featureColor,
                  ),
                ),
                backgroundColor: isProfile 
                    ? Colors.transparent 
                    : widget.featureColor.withOpacity(0.15),
                selectedColor: widget.featureColor,
                unSelectedColor: AppColors.getTextSecondary(context),
              );
            }).toList(),
            currentIndex: _currentIndex,
            onTap: (index) {
              HapticFeedback.selectionClick();
              final item = widget.navItems[index];
              if (item.label.toLowerCase() == 'profile') {
                _openProfile();
              } else {
                _onNavTap(index);
              }
            },
            fabLocation: StylishBarFabLocation.end,
            hasNotch: false,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

/// Helper class to define feature configurations
class FeatureConfig {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final List<FeatureNavItem> navItems;
  final List<FeatureSettingItem> settings;

  const FeatureConfig({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.navItems,
    required this.settings,
  });
}

/// Predefined feature configurations
class FeatureConfigs {
  static const medicine = FeatureConfig(
    id: 'medicine',
    name: 'Medicine',
    color: Color(0xFF6366F1),
    icon: Icons.medication_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.medication_outlined, activeIcon: Icons.medication_rounded, label: 'Meds'),
      FeatureNavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded, label: 'History'),
      FeatureNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const water = FeatureConfig(
    id: 'water',
    name: 'Water',
    color: Color(0xFF06B6D4),
    icon: Icons.water_drop_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle_rounded, label: 'Log'),
      FeatureNavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Stats'),
      FeatureNavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events_rounded, label: 'Challenges'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const focus = FeatureConfig(
    id: 'focus',
    name: 'Focus',
    color: Color(0xFF8B5CF6),
    icon: Icons.self_improvement_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.timer_outlined, activeIcon: Icons.timer_rounded, label: 'Sessions'),
      FeatureNavItem(icon: Icons.park_outlined, activeIcon: Icons.park_rounded, label: 'Garden'),
      FeatureNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Stats'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const fitness = FeatureConfig(
    id: 'fitness',
    name: 'Fitness',
    color: Color(0xFFEF4444),
    icon: Icons.fitness_center_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center_rounded, label: 'Workouts'),
      FeatureNavItem(icon: Icons.trending_up_outlined, activeIcon: Icons.trending_up_rounded, label: 'Progress'),
      FeatureNavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events_rounded, label: 'Challenges'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const finance = FeatureConfig(
    id: 'finance',
    name: 'Finance',
    color: Color(0xFF22C55E),
    icon: Icons.account_balance_wallet_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Transactions'),
      FeatureNavItem(icon: Icons.pie_chart_outline, activeIcon: Icons.pie_chart_rounded, label: 'Budget'),
      FeatureNavItem(icon: Icons.event_note_outlined, activeIcon: Icons.event_note_rounded, label: 'Bills'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const period = FeatureConfig(
    id: 'period',
    name: 'Period',
    color: Color(0xFFEC4899),
    icon: Icons.calendar_month_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Calendar'),
      FeatureNavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: 'Community'),
      FeatureNavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded, label: 'Safety'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const mood = FeatureConfig(
    id: 'mood',
    name: 'Mood',
    color: Color(0xFFFF6B9D),
    icon: Icons.mood_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Calendar'),
      FeatureNavItem(icon: Icons.air_outlined, activeIcon: Icons.air_rounded, label: 'Breath'),
      FeatureNavItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Insights'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const notes = FeatureConfig(
    id: 'notes',
    name: 'Notes',
    color: Color(0xFF10B981),
    icon: Icons.note_alt_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.note_outlined, activeIcon: Icons.note_rounded, label: 'Notes'),
      FeatureNavItem(icon: Icons.label_outline, activeIcon: Icons.label_rounded, label: 'Tags'),
      FeatureNavItem(icon: Icons.check_circle_outline, activeIcon: Icons.check_circle_rounded, label: 'Tasks'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const examPrep = FeatureConfig(
    id: 'exam_prep',
    name: 'Exam Prep',
    color: Color(0xFF3B82F6),
    icon: Icons.school_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.quiz_outlined, activeIcon: Icons.quiz_rounded, label: 'Exams'),
      FeatureNavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Study'),
      FeatureNavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Materials'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const reminders = FeatureConfig(
    id: 'reminders',
    name: 'Reminders',
    color: Color(0xFFF59E0B),
    icon: Icons.notifications_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt_rounded, label: 'All'),
      FeatureNavItem(icon: Icons.category_outlined, activeIcon: Icons.category_rounded, label: 'Categories'),
      FeatureNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );

  static const habit = FeatureConfig(
    id: 'habit',
    name: 'Habits',
    color: Color(0xFF7C91F4),
    icon: Icons.track_changes_rounded,
    navItems: [
      FeatureNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
      FeatureNavItem(icon: Icons.repeat_outlined, activeIcon: Icons.repeat_rounded, label: 'Habits'),
      FeatureNavItem(icon: Icons.book_outlined, activeIcon: Icons.book_rounded, label: 'Journal'),
      FeatureNavItem(icon: Icons.location_city_outlined, activeIcon: Icons.location_city_rounded, label: 'City'),
      FeatureNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ],
    settings: [],
  );
}
