import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import '../../onboarding/screens/welcome_screen.dart';
import 'reminders_screen.dart';
import 'all_reminders_screen.dart';
import 'category_management_screen.dart';
import 'reminder_analysis_screen.dart';
import 'settings/reminders_notifications_settings_screen.dart';
import 'settings/reminders_categories_settings_screen.dart';
import 'settings/reminders_patterns_settings_screen.dart';
import 'settings/reminders_sounds_settings_screen.dart';

/// Reminders feature with unique bell dome bottom navigation
class RemindersMainScreen extends StatefulWidget {
  const RemindersMainScreen({super.key});

  @override
  State<RemindersMainScreen> createState() => _RemindersMainScreenState();
}

class _RemindersMainScreenState extends State<RemindersMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFFF59E0B);

  final List<Widget> _screens = const [
    RemindersScreen(),
    AllRemindersScreen(),
    CategoryManagementScreen(),
    ReminderAnalysisScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt_rounded, label: 'All'),
    GlassNavItem(icon: Icons.category_outlined, activeIcon: Icons.category_rounded, label: 'Categories'),
    GlassNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics'),
    GlassNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  void _onNavTap(int index) {
    if (index == 4) {
      _openProfile();
    } else if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _openProfile() {
    FeatureProfileSheet.show(
      context: context,
      featureName: 'Reminders',
      featureColor: _featureColor,
      featureIcon: Icons.notifications_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Notification Settings',
      subtitle: 'Configure alert preferences',
      onTap: _openNotifications,
    ),
    FeatureSettingItem(
      icon: Icons.category_outlined,
      title: 'Categories',
      subtitle: 'Manage reminder categories',
      onTap: _openCategories,
    ),
    FeatureSettingItem(
      icon: Icons.repeat_outlined,
      title: 'Repeat Patterns',
      subtitle: 'Default recurrence settings',
      onTap: _openPatterns,
    ),
    FeatureSettingItem(
      icon: Icons.volume_up_outlined,
      title: 'Sounds',
      subtitle: 'Notification sounds',
      onTap: _openSounds,
    ),
  ];

  void _openNotifications() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersNotificationsSettingsScreen()));
  }

  void _openCategories() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersCategoriesSettingsScreen()));
  }

  void _openPatterns() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersPatternsSettingsScreen()));
  }

  void _openSounds() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersSoundsSettingsScreen()));
  }

  void _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
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
      bottomNavigationBar: RemindersBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
