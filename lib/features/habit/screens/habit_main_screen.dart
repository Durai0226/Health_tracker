import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'habit_dashboard.dart';
import 'create_habit_screen.dart';
import 'habit_journal_screen.dart';
import 'city_view_screen.dart';
import 'character_selection_screen.dart';
import 'settings/habit_goals_settings_screen.dart';
import 'settings/habit_reminders_settings_screen.dart';
import 'settings/habit_achievements_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Habit feature with unique flame streak bottom navigation
class HabitMainScreen extends StatefulWidget {
  const HabitMainScreen({super.key});

  @override
  State<HabitMainScreen> createState() => _HabitMainScreenState();
}

class _HabitMainScreenState extends State<HabitMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFF7C91F4);

  final List<Widget> _screens = const [
    HabitDashboard(),
    CreateHabitScreen(),
    HabitJournalScreen(),
    CityViewScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle_rounded, label: 'Create'),
    GlassNavItem(icon: Icons.book_outlined, activeIcon: Icons.book_rounded, label: 'Journal'),
    GlassNavItem(icon: Icons.location_city_outlined, activeIcon: Icons.location_city_rounded, label: 'City'),
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
      featureName: 'Habits',
      featureColor: _featureColor,
      featureIcon: Icons.track_changes_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.person_outline,
      title: 'Character',
      subtitle: 'Customize your avatar',
      onTap: _openCharacter,
    ),
    FeatureSettingItem(
      icon: Icons.flag_outlined,
      title: 'Goals',
      subtitle: 'Set habit targets',
      onTap: _openGoals,
    ),
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Reminders',
      subtitle: 'Habit check-in alerts',
      onTap: _openReminders,
    ),
    FeatureSettingItem(
      icon: Icons.emoji_events_outlined,
      title: 'Achievements',
      subtitle: 'View your badges',
      onTap: _openAchievements,
    ),
  ];

  void _openCharacter() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CharacterSelectionScreen()),
    );
  }

  void _openGoals() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HabitGoalsSettingsScreen()),
    );
  }

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HabitRemindersSettingsScreen()),
    );
  }

  void _openAchievements() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HabitAchievementsScreen()),
    );
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
      bottomNavigationBar: HabitBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
