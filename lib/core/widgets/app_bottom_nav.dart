import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';
import '../constants/app_colors.dart';

/// Unified bottom navigation bar using stylish_bottom_bar package
/// Provides consistent navigation across all features with proper SafeArea handling
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;
  final Color? activeColor;
  final bool showFab;
  final VoidCallback? onFabTap;
  final IconData fabIcon;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor,
    this.showFab = false,
    this.onFabTap,
    this.fabIcon = Symbols.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final color = activeColor ?? AppColors.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65 + (bottomPadding > 0 ? 0 : 8),
          child: StylishBottomBar(
            option: BubbleBarOptions(
              barStyle: BubbleBarStyle.horizontal,
              bubbleFillStyle: BubbleFillStyle.fill,
              opacity: 0.2,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: items.map((item) => BottomBarItem(
              icon: Icon(item.icon, color: AppColors.getTextSecondary(context)),
              selectedIcon: Icon(item.activeIcon, color: color),
              title: Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              backgroundColor: color.withOpacity(0.15),
              selectedColor: color,
              unSelectedColor: AppColors.getTextSecondary(context),
            )).toList(),
            currentIndex: currentIndex,
            onTap: (index) {
              HapticFeedback.selectionClick();
              onTap(index);
            },
            fabLocation: showFab ? StylishBarFabLocation.center : StylishBarFabLocation.end,
            hasNotch: showFab,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

/// Navigation item configuration
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Feature-specific bottom nav with profile support
class FeatureBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;
  final Color featureColor;
  final VoidCallback? onProfileTap;
  final bool showFab;
  final VoidCallback? onFabTap;

  const FeatureBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.featureColor,
    this.onProfileTap,
    this.showFab = false,
    this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: featureColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65 + (bottomPadding > 0 ? 0 : 8),
          child: StylishBottomBar(
            option: BubbleBarOptions(
              barStyle: BubbleBarStyle.horizontal,
              bubbleFillStyle: BubbleFillStyle.fill,
              opacity: 0.2,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isProfile = item.label.toLowerCase() == 'profile';
              
              return BottomBarItem(
                icon: Icon(
                  item.icon, 
                  color: AppColors.getTextSecondary(context),
                ),
                selectedIcon: Icon(
                  item.activeIcon, 
                  color: isProfile ? AppColors.getTextSecondary(context) : featureColor,
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isProfile ? AppColors.getTextSecondary(context) : featureColor,
                  ),
                ),
                backgroundColor: isProfile 
                    ? Colors.transparent 
                    : featureColor.withOpacity(0.15),
                selectedColor: featureColor,
                unSelectedColor: AppColors.getTextSecondary(context),
              );
            }).toList(),
            currentIndex: currentIndex,
            onTap: (index) {
              HapticFeedback.selectionClick();
              final item = items[index];
              if (item.label.toLowerCase() == 'profile' && onProfileTap != null) {
                onProfileTap!();
              } else {
                onTap(index);
              }
            },
            fabLocation: showFab ? StylishBarFabLocation.center : StylishBarFabLocation.end,
            hasNotch: showFab,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

/// Floating action button for center position
class FeatureNavFab extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const FeatureNavFab({
    super.key,
    required this.onTap,
    required this.color,
    this.icon = Symbols.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      backgroundColor: color,
      elevation: 4,
      shape: const CircleBorder(),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}
