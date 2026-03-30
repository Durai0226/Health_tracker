import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'bloom_mood_home_screen.dart';
import 'bloom_mood_calendar_screen.dart';
import 'bloom_mood_insights_screen.dart';
import '../breathing/screens/bloom_breath_list_screen.dart';
import 'settings/mood_reminders_settings_screen.dart';
import 'settings/mood_themes_settings_screen.dart';
import 'settings/mood_export_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Mood feature with unique organic blob bottom navigation
class MoodMainScreen extends StatefulWidget {
  const MoodMainScreen({super.key});

  @override
  State<MoodMainScreen> createState() => _MoodMainScreenState();
}

class _MoodMainScreenState extends State<MoodMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFFFF6B9D);

  final List<Widget> _screens = const [
    BloomMoodHomeScreen(),
    BloomMoodCalendarScreen(),
    BloomBreathListScreen(),
    BloomMoodInsightsScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Calendar'),
    GlassNavItem(icon: Icons.air_outlined, activeIcon: Icons.air_rounded, label: 'Breath'),
    GlassNavItem(icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Insights'),
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
      featureName: 'Mood',
      featureColor: _featureColor,
      featureIcon: Icons.mood_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Check-in Reminders',
      subtitle: 'Daily mood tracking alerts',
      onTap: _openReminders,
    ),
    FeatureSettingItem(
      icon: Icons.palette_outlined,
      title: 'Themes',
      subtitle: 'Customize app appearance',
      onTap: _openThemes,
    ),
    FeatureSettingItem(
      icon: Icons.air_outlined,
      title: 'Breathing Exercises',
      subtitle: 'Manage saved exercises',
      onTap: _openBreathing,
    ),
    FeatureSettingItem(
      icon: Icons.download_outlined,
      title: 'Export Journal',
      subtitle: 'Download mood history',
      onTap: _openExport,
    ),
  ];

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodRemindersSettingsScreen()));
  }

  void _openThemes() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodThemesSettingsScreen()));
  }

  void _openBreathing() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BloomBreathListScreen()));
  }

  void _openExport() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodExportScreen()));
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
      bottomNavigationBar: MoodBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
