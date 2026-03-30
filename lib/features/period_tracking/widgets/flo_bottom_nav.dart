import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/flo_theme.dart';

/// Custom bottom navigation bar for Flo-style period tracking
/// Matches the Behance design with Home, Calendar, Symptoms, Partner, and + button
class FloBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onAddPressed;

  const FloBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FloTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FloTheme.spacingLg,
        vertical: FloTheme.spacingSm,
      ),
      margin: const EdgeInsets.all(FloTheme.spacingLg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(FloTheme.radius2xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Home
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            
            // Calendar
            _NavItem(
              icon: Icons.calendar_today_rounded,
              label: 'Calendar',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            
            // Symptoms
            _NavItem(
              icon: Icons.favorite_rounded,
              label: 'Symptoms',
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            
            // Partner
            _NavItem(
              icon: Icons.people_rounded,
              label: 'Partner',
              isSelected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
            
            // Add button
            _AddButton(onTap: onAddPressed),
          ],
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: FloTheme.animFast,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? FloTheme.spacingMd : FloTheme.spacingSm,
          vertical: FloTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? FloTheme.periodPink : Colors.transparent,
          borderRadius: BorderRadius.circular(FloTheme.radiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: FloTheme.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(FloTheme.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(FloTheme.radiusMd),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Floating action button for quick log
class FloQuickLogFab extends StatefulWidget {
  final VoidCallback onTap;

  const FloQuickLogFab({
    super.key,
    required this.onTap,
  });

  @override
  State<FloQuickLogFab> createState() => _FloQuickLogFabState();
}

class _FloQuickLogFabState extends State<FloQuickLogFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: FloTheme.animFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FloTheme.spacingXl,
              vertical: FloTheme.spacingMd,
            ),
            decoration: BoxDecoration(
              color: FloTheme.periodPink,
              borderRadius: BorderRadius.circular(FloTheme.radiusFull),
              boxShadow: FloTheme.shadowColored(FloTheme.periodPink),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Log Period',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: FloTheme.spacingSm),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic app bar for Flo screens
class FloAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;

  const FloAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              onPressed: onBackPressed ?? () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: FloTheme.getTextPrimary(context),
              ),
            )
          : null,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: FloTheme.headlineMedium.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                )
              : null),
      centerTitle: true,
      actions: actions,
    );
  }
}

/// Header with greeting and profile picture
class FloGreetingHeader extends StatelessWidget {
  final String userName;
  final String? profileImageUrl;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;

  const FloGreetingHeader({
    super.key,
    required this.userName,
    this.profileImageUrl,
    this.onProfileTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName',
                style: FloTheme.headlineLarge.copyWith(
                  color: FloTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Notification/Video icon (from Behance)
              if (onNotificationTap != null)
                GestureDetector(
                  onTap: onNotificationTap,
                  child: Container(
                    padding: const EdgeInsets.all(FloTheme.spacingSm),
                    decoration: BoxDecoration(
                      color: FloTheme.periodPink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: FloTheme.periodPink,
                      size: 20,
                    ),
                  ),
                ),
              
              const SizedBox(width: FloTheme.spacingMd),
              
              // Profile picture
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FloTheme.periodPinkLight,
                    border: Border.all(
                      color: FloTheme.periodPink.withOpacity(0.3),
                      width: 2,
                    ),
                    image: profileImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(profileImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profileImageUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          color: FloTheme.periodPink,
                          size: 24,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
