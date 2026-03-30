import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'focus_screen.dart';
import 'focus_garden_screen.dart';
import 'focus_stats_screen.dart';
import 'manrope_focus_dashboard.dart';
import 'settings/focus_durations_settings_screen.dart';
import 'settings/focus_sounds_settings_screen.dart';
import 'settings/focus_plants_settings_screen.dart';
import 'settings/focus_reminders_settings_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Focus feature with unique zen-circle bottom navigation
class FocusMainScreen extends StatefulWidget {
  const FocusMainScreen({super.key});

  @override
  State<FocusMainScreen> createState() => _FocusMainScreenState();
}

class _FocusMainScreenState extends State<FocusMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFF8B5CF6);

  final List<Widget> _screens = const [
    FocusScreen(),
    ManropeFocusDashboard(),
    FocusGardenScreen(),
    FocusStatsScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.timer_outlined, activeIcon: Icons.timer_rounded, label: 'Sessions'),
    GlassNavItem(icon: Icons.park_outlined, activeIcon: Icons.park_rounded, label: 'Garden'),
    GlassNavItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Stats'),
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
      featureName: 'Focus',
      featureColor: _featureColor,
      featureIcon: Icons.self_improvement_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.timer_outlined,
      title: 'Session Durations',
      subtitle: 'Customize focus lengths',
      onTap: _openDurations,
    ),
    FeatureSettingItem(
      icon: Icons.music_note_outlined,
      title: 'Ambient Sounds',
      subtitle: 'Manage background audio',
      onTap: _openSounds,
    ),
    FeatureSettingItem(
      icon: Icons.park_outlined,
      title: 'Plants & Garden',
      subtitle: 'Unlock and customize plants',
      onTap: _openPlants,
    ),
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Reminders',
      subtitle: 'Focus session reminders',
      onTap: _openReminders,
    ),
  ];

  void _openDurations() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusDurationsSettingsScreen()));
  }

  void _openSounds() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusSoundsSettingsScreen()));
  }

  void _openPlants() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusPlantsSettingsScreen()));
  }

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusRemindersSettingsScreen()));
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
      bottomNavigationBar: FocusBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
