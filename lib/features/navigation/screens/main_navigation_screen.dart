
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../focus/screens/focus_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2;
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FocusScreen(),
    const HomeScreen(),
    const TrackingScreen(),
    const SettingsScreen(),
  ];

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
      bottomNavigationBar: _buildPremiumNavBar(),
    );
  }

  Widget _buildPremiumNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.85),
                  Colors.white.withOpacity(0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPremiumNavItem(
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                ),
                _buildPremiumNavItem(
                  index: 1,
                  icon: Icons.self_improvement_outlined,
                  activeIcon: Icons.self_improvement_rounded,
                  label: 'Focus',
                ),
                _buildPremiumNavItem(
                  index: 2,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isCenter: true,
                ),
                _buildPremiumNavItem(
                  index: 3,
                  icon: Icons.track_changes_outlined,
                  activeIcon: Icons.track_changes_rounded,
                  label: 'Tracking',
                ),
                _buildPremiumNavItem(
                  index: 4,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool isCenter = false,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.85),
                        Color.lerp(AppColors.primary, Colors.purple, 0.3)!,
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondary.withOpacity(0.7),
                size: isCenter ? 26 : 24,
              ),
            ),
          );
        },
      ),
    );
  }
}
