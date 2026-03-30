import 'package:flutter/material.dart';
import '../../../core/widgets/bottom_nav/bottom_nav.dart';
import '../../../core/widgets/feature_profile_sheet.dart';
import '../../../core/services/auth_service.dart';
import 'luna_dashboard_screen.dart';
import 'luna_calendar_screen.dart';
import 'luna_community_screen.dart';
import 'luna_safety_screen.dart';
import 'luna_settings_screen.dart';
import 'flo_partner_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Luna Cycle feature with unique crescent moon bottom navigation + center FAB
class LunaMainScreen extends StatefulWidget {
  const LunaMainScreen({super.key});

  @override
  State<LunaMainScreen> createState() => _LunaMainScreenState();
}

class _LunaMainScreenState extends State<LunaMainScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  static const _featureColor = Color(0xFFEC4899);

  final List<Widget> _screens = const [
    LunaDashboardScreen(),
    LunaCalendarScreen(),
    LunaCommunityScreen(),
    LunaSafetyScreen(),
  ];

  final List<GlassNavItem> _navItems = const [
    GlassNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Home'),
    GlassNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Calendar'),
    GlassNavItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: 'Community'),
    GlassNavItem(icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded, label: 'Safety'),
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
      featureName: 'Luna Cycle',
      featureColor: _featureColor,
      featureIcon: Icons.calendar_month_rounded,
      settings: _profileSettings,
      onSyncTap: () {},
      onSignOut: _handleSignOut,
    );
  }

  void _showQuickLog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quick log opened...')),
    );
  }

  List<FeatureSettingItem> get _profileSettings => [
    FeatureSettingItem(
      icon: Icons.calendar_today_outlined,
      title: 'Cycle Settings',
      subtitle: 'Configure cycle length & periods',
      onTap: _openSettings,
    ),
    FeatureSettingItem(
      icon: Icons.favorite_outline,
      title: 'Partner Sharing',
      subtitle: 'Share with your partner',
      onTap: _openPartner,
    ),
    FeatureSettingItem(
      icon: Icons.notifications_outlined,
      title: 'Reminders',
      subtitle: 'Period & fertility alerts',
      onTap: _openSettings,
    ),
    FeatureSettingItem(
      icon: Icons.privacy_tip_outlined,
      title: 'Privacy',
      subtitle: 'Data protection settings',
      onTap: _openSettings,
    ),
  ];

  void _openSettings() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LunaSettingsScreen()));
  }

  void _openPartner() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FloPartnerScreen()));
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
      bottomNavigationBar: LunaBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
        featureColor: _featureColor,
        showFab: true,
        onFabTap: _showQuickLog,
      ),
    );
  }
}
