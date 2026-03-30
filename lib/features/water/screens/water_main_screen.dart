import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'aqua_water_dashboard.dart';
import 'aqua_statistics_screen.dart';
import 'hydration_challenges_screen.dart';
import 'water_tracking_screen.dart';
import 'settings/water_goal_settings_screen.dart';
import 'settings/water_cups_settings_screen.dart';
import 'settings/water_reminders_settings_screen.dart';
import 'settings/water_beverages_settings_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Water tracking with unique wave-top bottom navigation
class WaterMainScreen extends StatefulWidget {
  const WaterMainScreen({super.key});

  @override
  State<WaterMainScreen> createState() => _WaterMainScreenState();
}

class _WaterMainScreenState extends State<WaterMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFF06B6D4);

  final List<Widget> _screens = const [
    AquaWaterDashboard(),
    WaterTrackingScreen(),
    AquaStatisticsScreen(),
    HydrationChallengesScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle_rounded, label: 'Log'),
    GlassNavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Stats'),
    GlassNavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events_rounded, label: 'Challenges'),
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
      featureName: 'Water',
      featureColor: _featureColor,
      featureIcon: Icons.water_drop_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.flag_outlined,
      title: 'Daily Goal',
      subtitle: 'Set your hydration target',
      onTap: _openGoal,
    ),
    FeatureSettingItem(
      icon: Icons.local_drink_outlined,
      title: 'Cup Sizes',
      subtitle: 'Customize your containers',
      onTap: _openCups,
    ),
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Reminders',
      subtitle: 'Configure drink reminders',
      onTap: _openReminders,
    ),
    FeatureSettingItem(
      icon: Icons.palette_outlined,
      title: 'Beverages',
      subtitle: 'Manage beverage types',
      onTap: _openBeverages,
    ),
  ];

  void _openGoal() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterGoalSettingsScreen()));
  }

  void _openCups() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterCupsSettingsScreen()));
  }

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterRemindersSettingsScreen()));
  }

  void _openBeverages() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WaterBeveragesSettingsScreen()));
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
      bottomNavigationBar: WaterBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
