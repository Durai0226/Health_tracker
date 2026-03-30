import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';

/// Custom bottom navigation bar for Luna Cycle
class LunaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAddTap;

  const LunaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = LunaTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? LunaTheme.surfaceDark : LunaTheme.surface,
        boxShadow: [
          BoxShadow(
            color: LunaTheme.primaryPink.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: 'Calendar',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              // Center add button
              if (onAddTap != null)
                _AddButton(onTap: onAddTap!),
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people_rounded,
                label: 'Community',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.shield_outlined,
                activeIcon: Icons.shield_rounded,
                label: 'Safety',
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
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: LunaTheme.animFast,
        padding: const EdgeInsets.symmetric(
          horizontal: LunaTheme.spacingMd,
          vertical: LunaTheme.spacingSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: LunaTheme.animFast,
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? LunaTheme.primaryPink
                    : LunaTheme.getTextTertiary(context),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: LunaTheme.labelSmall.copyWith(
                color: isSelected
                    ? LunaTheme.primaryPink
                    : LunaTheme.getTextTertiary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LunaTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: LunaTheme.shadowColored(LunaTheme.primaryPink),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

/// Luna Cycle app bar
class LunaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  const LunaAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LunaTheme.spacingMd,
            vertical: LunaTheme.spacingSm,
          ),
          child: Row(
            children: [
              if (showBackButton)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (onBackPressed != null) {
                      onBackPressed!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: LunaTheme.getSurface(context),
                      shape: BoxShape.circle,
                      boxShadow: LunaTheme.shadowXs,
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: LunaTheme.getTextPrimary(context),
                      size: 18,
                    ),
                  ),
                ),
              if (showBackButton) const SizedBox(width: LunaTheme.spacingMd),
              
              Expanded(
                child: titleWidget ?? (title != null
                    ? Text(
                        title!,
                        style: LunaTheme.headlineMedium.copyWith(
                          color: LunaTheme.getTextPrimary(context),
                        ),
                      )
                    : const SizedBox()),
              ),
              
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Greeting header for dashboard
class LunaGreetingHeader extends StatelessWidget {
  final String userName;
  final LunaCyclePhase? currentPhase;
  final VoidCallback? onProfileTap;

  const LunaGreetingHeader({
    super.key,
    required this.userName,
    this.currentPhase,
    this.onProfileTap,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _phaseMessage {
    if (currentPhase == null) return 'Track your cycle with Luna';
    return LunaTheme.getPhaseDescription(currentPhase!);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $userName',
                  style: LunaTheme.headlineLarge.copyWith(
                    color: LunaTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: LunaTheme.spacingXs),
                Row(
                  children: [
                    if (currentPhase != null) ...[
                      Text(
                        LunaTheme.getPhaseMoonEmoji(currentPhase!),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: LunaTheme.spacingXs),
                    ],
                    Expanded(
                      child: Text(
                        _phaseMessage,
                        style: LunaTheme.bodyMedium.copyWith(
                          color: LunaTheme.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onProfileTap?.call();
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: currentPhase != null
                    ? LunaTheme.getPhaseGradient(currentPhase!)
                    : LunaTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: LunaTheme.shadowSm,
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'L',
                  style: LunaTheme.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab bar for Luna screens
class LunaTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const LunaTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
      decoration: BoxDecoration(
        color: LunaTheme.getDivider(context),
        borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(index);
              },
              child: AnimatedContainer(
                duration: LunaTheme.animFast,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? LunaTheme.primaryPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
                ),
                child: Center(
                  child: Text(
                    tab,
                    style: LunaTheme.labelLarge.copyWith(
                      color: isSelected
                          ? Colors.white
                          : LunaTheme.getTextSecondary(context),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Empty state widget
class LunaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const LunaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LunaTheme.spacing3xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: LunaTheme.primaryPink.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: LunaTheme.primaryPink,
                size: 36,
              ),
            ),
            const SizedBox(height: LunaTheme.spacingLg),
            Text(
              title,
              style: LunaTheme.headlineSmall.copyWith(
                color: LunaTheme.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: LunaTheme.spacingSm),
              Text(
                subtitle!,
                style: LunaTheme.bodyMedium.copyWith(
                  color: LunaTheme.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: LunaTheme.spacingXl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
