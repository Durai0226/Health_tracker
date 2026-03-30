import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../screens/bloom_mood_home_screen.dart';
import '../screens/bloom_mood_calendar_screen.dart';
import '../screens/bloom_mood_settings_screen.dart';
import '../breathing/screens/bloom_breath_list_screen.dart';

/// Main navigation wrapper for Mood Tracker
/// 4-tab navigation: Home, Mood, Breath, Settings
class MoodTabNavigation extends StatefulWidget {
  final String? userName;

  const MoodTabNavigation({
    super.key,
    this.userName,
  });

  @override
  State<MoodTabNavigation> createState() => _MoodTabNavigationState();
}

class _MoodTabNavigationState extends State<MoodTabNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      BloomMoodHomeScreen(userName: widget.userName),
      const BloomMoodCalendarScreen(),
      const BloomBreathListScreen(),
      const BloomMoodSettingsScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: _MoodBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}

/// Custom bottom navigation bar matching Behance design
/// Rounded pill style with 4 icons
class _MoodBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MoodBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MoodTheme.spacingLg,
        vertical: MoodTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: MoodTheme.backgroundSecondary,
            borderRadius: MoodTheme.borderRadiusXxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.mood_rounded,
                label: 'Mood',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.air_rounded,
                label: 'Breath',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MoodTheme.animationFast,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? MoodTheme.surface : Colors.transparent,
          borderRadius: MoodTheme.borderRadiusRound,
          boxShadow: isSelected ? MoodTheme.softShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? MoodTheme.primary : MoodTheme.textMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: MoodTheme.titleSm.copyWith(
                  color: MoodTheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
