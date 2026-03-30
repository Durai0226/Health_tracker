import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'exam_prep_home_screen.dart';
import 'exam_list_screen.dart';
import 'study_plan_screen.dart';
import 'study_materials_screen.dart';
import 'settings/exam_subjects_settings_screen.dart';
import 'settings/exam_schedule_settings_screen.dart';
import 'settings/exam_reminders_settings_screen.dart';
import 'settings/exam_performance_settings_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Exam Prep feature with unique book spine ridge bottom navigation
class ExamMainScreen extends StatefulWidget {
  const ExamMainScreen({super.key});

  @override
  State<ExamMainScreen> createState() => _ExamMainScreenState();
}

class _ExamMainScreenState extends State<ExamMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFF3B82F6);

  final List<Widget> _screens = const [
    ExamPrepHomeScreen(),
    ExamListScreen(),
    StudyPlanScreen(),
    StudyMaterialsScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard'),
    GlassNavItem(icon: Icons.quiz_outlined, activeIcon: Icons.quiz_rounded, label: 'Exams'),
    GlassNavItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book_rounded, label: 'Study'),
    GlassNavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Materials'),
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
      featureName: 'Exam Prep',
      featureColor: _featureColor,
      featureIcon: Icons.school_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.school_outlined,
      title: 'Subjects',
      subtitle: 'Manage your subjects',
      onTap: _openSubjects,
    ),
    FeatureSettingItem(
      icon: Icons.schedule_outlined,
      title: 'Study Schedule',
      subtitle: 'Configure study times',
      onTap: _openSchedule,
    ),
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Study Reminders',
      subtitle: 'Exam & study alerts',
      onTap: _openReminders,
    ),
    FeatureSettingItem(
      icon: Icons.analytics_outlined,
      title: 'Performance',
      subtitle: 'View study analytics',
      onTap: _openPerformance,
    ),
  ];

  void _openSubjects() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamSubjectsSettingsScreen()));
  }

  void _openSchedule() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamScheduleSettingsScreen()));
  }

  void _openReminders() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamRemindersSettingsScreen()));
  }

  void _openPerformance() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamPerformanceSettingsScreen()));
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
      bottomNavigationBar: ExamBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
      ),
    );
  }
}
