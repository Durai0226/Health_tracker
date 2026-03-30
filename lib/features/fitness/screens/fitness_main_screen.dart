import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'fitness_home_screen.dart';
import 'fitness_discover_screen.dart';
import 'fitness_progress_screen.dart';
import 'nutrition/nutrition_dashboard_screen.dart';
import 'onboarding/fitness_onboarding_screen.dart';
import 'settings/fitness_goals_settings_screen.dart';
import 'settings/fitness_bmi_settings_screen.dart';
import 'settings/fitness_reminders_settings_screen.dart';
import 'settings/fitness_custom_workouts_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Fitness feature with modern dark nav and floating center progress button
class FitnessMainScreen extends StatefulWidget {
  const FitnessMainScreen({super.key});

  @override
  State<FitnessMainScreen> createState() => _FitnessMainScreenState();
}

class _FitnessMainScreenState extends State<FitnessMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  
  // Use neon lime green from FitnessTheme
  static const _featureColor = Color(0xFFCDFF00);

  // 5 screens: Home, Workouts, Progress (center), Nutrition, Profile
  final List<Widget> _screens = const [
    FitnessHomeScreen(),
    FitnessDiscoverScreen(),
    FitnessProgressScreen(),
    NutritionDashboardScreen(),
    SizedBox(), // Profile is handled via sheet
  ];

  // 5 nav items with Progress as center floating button (index 2)
  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    GlassNavItem(icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center_rounded, label: 'Workout'),
    GlassNavItem(icon: Icons.show_chart_outlined, activeIcon: Icons.show_chart_rounded, label: 'Progress'),
    GlassNavItem(icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu_rounded, label: 'Nutrition'),
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
      featureName: 'Fitness',
      featureColor: _featureColor,
      featureIcon: Icons.fitness_center_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.person_outline,
      title: 'Edit Fitness Profile',
      subtitle: 'Update your preferences and goals',
      onTap: _editProfile,
    ),
    FeatureSettingItem(
      icon: Icons.flag_outlined,
      title: 'Fitness Goals',
      subtitle: 'Set your workout targets',
      onTap: _openGoals,
    ),
    FeatureSettingItem(
      icon: Icons.monitor_weight_outlined,
      title: 'BMI & Body Stats',
      subtitle: 'Track body measurements',
      onTap: _openBmi,
    ),
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Workout Reminders',
      subtitle: 'Configure exercise alerts',
      onTap: _openReminders,
    ),
    FeatureSettingItem(
      icon: Icons.fitness_center_outlined,
      title: 'Custom Workouts',
      subtitle: 'Create your own routines',
      onTap: _openCustomWorkouts,
    ),
  ];

  void _openGoals() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessGoalsSettingsScreen()));
  }

  void _openBmi() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessBmiSettingsScreen()));
  }

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessRemindersSettingsScreen()));
  }

  void _openCustomWorkouts() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FitnessCustomWorkoutsScreen()));
  }

  void _editProfile() {
    // Close profile sheet first, then navigate after a brief delay
    // to ensure proper context handling
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const FitnessOnboardingScreen(isEditMode: true),
          ),
        );
      }
    });
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
      bottomNavigationBar: FitnessBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
