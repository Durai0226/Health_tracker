import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Finance Navigation Bar - Finance Tracker Category
/// Inspired by: Revolut, Robinhood, Venmo
/// 
/// Design Features:
/// - Sleek professional bar with sliding pill indicator
/// - Mint green accent (#00D09C / #22C55E)
/// - Sliding pill that morphs around active item
/// - Smooth 280ms spring physics
/// - Badge support for notifications
class FinanceNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final List<int>? badges;

  const FinanceNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
    this.badges,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<FinanceNavBar> createState() => _FinanceNavBarState();
}

class _FinanceNavBarState extends State<FinanceNavBar>
    with TickerProviderStateMixin {
  
  late AnimationController _pillController;
  late Animation<double> _pillAnimation;
  late List<AnimationController> _scaleControllers;
  
  int _previousIndex = 0;
  
  // Finance theme colors
  static const Color _primaryGreen = Color(0xFF00D09C);
  static const Color _primaryGreenDark = Color(0xFF00B386);
  static const Color _darkBg = Color(0xFF0D0D0D);
  static const Color _darkSurface = Color(0xFF1A1A1A);
  static const Color _lightBg = Color(0xFFF5F5F5);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  
  // Design constants
  static const double _barHeight = 64.0;
  static const double _iconSize = 24.0;
  static const double _pillHeight = 44.0;
  static const double _pillPadding = 8.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Sliding pill animation with spring physics
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    
    _pillAnimation = CurvedAnimation(
      parent: _pillController,
      curve: Curves.easeOutBack,
    );
    
    // Scale controllers for tap feedback
    _scaleControllers = List.generate(4, (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    ));
  }

  @override
  void didUpdateWidget(covariant FinanceNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _pillController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pillController.dispose();
    for (final controller in _scaleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  void _onItemTapDown(int index) {
    _scaleControllers[index].forward();
  }

  void _onItemTapUp(int index) {
    _scaleControllers[index].reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? _darkBg : _lightBg;
    final surfaceColor = isDark ? _darkSurface : _lightSurface;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);
    
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Container(
        height: _barHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Sliding pill indicator
                _buildSlidingPill(constraints.maxWidth, isDark),
                // Navigation items
                _buildNavItems(isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlidingPill(double totalWidth, bool isDark) {
    final itemWidth = totalWidth / 4;
    final pillWidth = itemWidth - (_pillPadding * 2);
    
    return AnimatedBuilder(
      animation: _pillAnimation,
      builder: (context, child) {
        final startX = (_previousIndex * itemWidth) + _pillPadding;
        final endX = (widget.currentIndex * itemWidth) + _pillPadding;
        final currentX = lerpDouble(startX, endX, _pillAnimation.value)!;
        
        return Positioned(
          left: currentX,
          top: (_barHeight - _pillHeight) / 2,
          child: Container(
            width: pillWidth,
            height: _pillHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primaryGreen.withOpacity(isDark ? 0.2 : 0.15),
                  _primaryGreenDark.withOpacity(isDark ? 0.1 : 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _primaryGreen.withOpacity(isDark ? 0.3 : 0.2),
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItems(bool isDark) {
    final badges = widget.badges;
    
    return Row(
      children: List.generate(4, (index) {
        final isSelected = widget.currentIndex == index;
        final badgeCount = badges != null && index < badges.length ? badges[index] : 0;
        
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onItemTapDown(index),
            onTapUp: (_) => _onItemTapUp(index),
            onTapCancel: () => _onItemTapUp(index),
            onTap: () => _onItemTap(index),
            child: AnimatedBuilder(
              animation: _scaleControllers[index],
              builder: (context, child) {
                final scale = 1.0 - (_scaleControllers[index].value * 0.08);
                
                return Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    height: _barHeight,
                    child: Center(
                      child: _FinanceNavIcon(
                        activeIcon: widget.activeIcons[index],
                        inactiveIcon: widget.inactiveIcons[index],
                        isSelected: isSelected,
                        isDark: isDark,
                        primaryColor: _primaryGreen,
                        iconSize: _iconSize,
                        badgeCount: badgeCount,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

class _FinanceNavIcon extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final bool isDark;
  final Color primaryColor;
  final double iconSize;
  final int badgeCount;

  const _FinanceNavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.isDark,
    required this.primaryColor,
    required this.iconSize,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = primaryColor;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.35);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: isSelected ? 0.0 : 1.0,
        end: isSelected ? 1.0 : 0.0,
      ),
      builder: (context, value, child) {
        final color = Color.lerp(inactiveColor, activeColor, value)!;
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                key: ValueKey('${isSelected}_$activeIcon'),
                color: color,
                size: iconSize,
              ),
            ),
            // Badge
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
