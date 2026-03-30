import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

/// Premium Edge-to-Edge Bottom Navigation Bar - 2025/2026 Design
/// Inspired by: Instagram, Spotify, Apple Music, Twitter/X, TikTok
/// 
/// Design Principles:
/// - Edge-to-edge (no margins) - flush with screen edges
/// - Aligned with home indicator/notch
/// - Minimal dot indicator instead of bulky pill
/// - Subtle glassmorphism with thin separator line
/// - Refined micro-interactions and haptics
/// - Performance optimized with RepaintBoundary
class SlidingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final Color? accentColor; // Custom accent color for feature-specific theming

  const SlidingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
    this.accentColor,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<SlidingNavBar> createState() => _SlidingNavBarState();
}

class _SlidingNavBarState extends State<SlidingNavBar>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late List<AnimationController> _scaleControllers;
  late List<Animation<double>> _scaleAnimations;
  late AnimationController _indicatorController;
  late Animation<double> _indicatorAnimation;
  
  // Track previous index for indicator animation
  int _previousIndex = 0;
  
  // Design constants - Instagram/Spotify inspired
  static const double _barHeight = 52.0;
  static const double _iconSize = 26.0;
  static const double _indicatorSize = 5.0;
  static const double _indicatorSpacing = 6.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Indicator slide animation
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOutCubic,
    );
    
    // Individual scale controllers for each nav item - snappy response
    _scaleControllers = List.generate(4, (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    ));
    _scaleAnimations = _scaleControllers.map((controller) =>
      Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
      ),
    ).toList();
  }

  @override
  void didUpdateWidget(covariant SlidingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _indicatorController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
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

  void _onItemTapCancel(int index) {
    _scaleControllers[index].reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = AppColors.isDark(context);
    
    // Background colors
    final bgColor = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final separatorColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            // Edge-to-edge - no horizontal margins
            padding: EdgeInsets.only(bottom: bottomPadding),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: isDark ? 0.85 : 0.92),
              border: Border(
                top: BorderSide(
                  color: separatorColor,
                  width: 0.5,
                ),
              ),
            ),
            child: SizedBox(
              height: _barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Navigation items
                      _buildNavItems(isDark, constraints.maxWidth),
                      // Animated dot indicator
                      _buildDotIndicator(constraints.maxWidth, isDark),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicator(double totalWidth, bool isDark) {
    final itemWidth = totalWidth / 4;
    final indicatorColor = widget.accentColor ?? AppColors.primary;
    
    return AnimatedBuilder(
      animation: _indicatorAnimation,
      builder: (context, child) {
        // Interpolate position from previous to current
        final startX = (_previousIndex * itemWidth) + (itemWidth / 2) - (_indicatorSize / 2);
        final endX = (widget.currentIndex * itemWidth) + (itemWidth / 2) - (_indicatorSize / 2);
        final currentX = lerpDouble(startX, endX, _indicatorAnimation.value)!;
        
        // Scale animation - dot grows slightly during transition
        final scale = 1.0 + (0.3 * (1 - (2 * (_indicatorAnimation.value - 0.5)).abs()));
        
        return Positioned(
          left: currentX,
          bottom: _indicatorSpacing,
          child: Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _indicatorSize,
              height: _indicatorSize,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: indicatorColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItems(bool isDark, double totalWidth) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.35);

    return Row(
      children: List.generate(4, (index) {
        final isSelected = widget.currentIndex == index;
        
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onItemTapDown(index),
            onTapUp: (_) => _onItemTapUp(index),
            onTapCancel: () => _onItemTapCancel(index),
            onTap: () => _onItemTap(index),
            child: AnimatedBuilder(
              animation: _scaleAnimations[index],
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimations[index].value,
                  child: Container(
                    height: _barHeight,
                    padding: const EdgeInsets.only(bottom: _indicatorSpacing + _indicatorSize + 2),
                    child: Center(
                      child: _NavIcon(
                        activeIcon: widget.activeIcons[index],
                        inactiveIcon: widget.inactiveIcons[index],
                        isSelected: isSelected,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        iconSize: _iconSize,
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

/// Navigation icon with smooth color and icon morphing
class _NavIcon extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final double iconSize;

  const _NavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: isSelected ? 0.0 : 1.0,
        end: isSelected ? 1.0 : 0.0,
      ),
      builder: (context, value, child) {
        final color = Color.lerp(inactiveColor, activeColor, value)!;
        
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
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
            key: ValueKey(isSelected),
            color: color,
            size: iconSize,
          ),
        );
      },
    );
  }
}
