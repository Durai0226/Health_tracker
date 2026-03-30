import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wellness Navigation Bar - Health & Wellness Category
/// Inspired by: Apple Health, Calm, Headspace
/// 
/// Design Features:
/// - Floating pill with soft glassmorphism
/// - Teal gradient accent (#00897B → #26A69A)
/// - Soft glow bubble behind active icon
/// - Gentle breathing pulse animation on active item
class WellnessNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;

  const WellnessNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<WellnessNavBar> createState() => _WellnessNavBarState();
}

class _WellnessNavBarState extends State<WellnessNavBar>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  
  // Track previous index for slide animation
  int _previousIndex = 0;
  
  // Wellness theme colors
  static const Color _primaryTeal = Color(0xFF00897B);
  static const Color _glowColor = Color(0xFF00897B);
  
  // Design constants
  static const double _barHeight = 72.0;
  static const double _barMargin = 20.0;
  static const double _borderRadius = 28.0;
  static const double _iconSize = 26.0;
  static const double _glowRadius = 48.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Breathing pulse animation for active item
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Slide animation for indicator
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant WellnessNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _slideController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onItemTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: EdgeInsets.only(
        left: _barMargin,
        right: _barMargin,
        bottom: bottomPadding + 12,
      ),
      height: _barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ]
                    : [
                        Colors.white.withOpacity(0.85),
                        Colors.white.withOpacity(0.75),
                      ],
              ),
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : _primaryTeal.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryTeal.withOpacity(isDark ? 0.2 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Animated glow indicator
                    _buildGlowIndicator(constraints.maxWidth, isDark),
                    // Navigation items
                    _buildNavItems(isDark),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlowIndicator(double totalWidth, bool isDark) {
    final itemWidth = totalWidth / 4;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _pulseAnimation]),
      builder: (context, child) {
        // Interpolate position
        final startX = (_previousIndex * itemWidth) + (itemWidth / 2) - (_glowRadius / 2);
        final endX = (widget.currentIndex * itemWidth) + (itemWidth / 2) - (_glowRadius / 2);
        final currentX = lerpDouble(startX, endX, _slideAnimation.value)!;
        
        final pulseScale = _pulseAnimation.value;
        
        return Positioned(
          left: currentX,
          top: (_barHeight - _glowRadius) / 2,
          child: Transform.scale(
            scale: pulseScale,
            child: Container(
              width: _glowRadius,
              height: _glowRadius,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _glowColor.withOpacity(isDark ? 0.4 : 0.25),
                    _glowColor.withOpacity(isDark ? 0.15 : 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItems(bool isDark) {
    return Row(
      children: List.generate(4, (index) {
        final isSelected = widget.currentIndex == index;
        
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onItemTap(index),
            child: SizedBox(
              height: _barHeight,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = isSelected ? (0.95 + (_pulseAnimation.value * 0.1)) : 1.0;
                    
                    return Transform.scale(
                      scale: scale,
                      child: _WellnessNavIcon(
                        activeIcon: widget.activeIcons[index],
                        inactiveIcon: widget.inactiveIcons[index],
                        isSelected: isSelected,
                        isDark: isDark,
                        primaryColor: _primaryTeal,
                        iconSize: _iconSize,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WellnessNavIcon extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final bool isDark;
  final Color primaryColor;
  final double iconSize;

  const _WellnessNavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.isDark,
    required this.primaryColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = primaryColor;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.5)
        : Colors.black.withOpacity(0.4);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(
        begin: isSelected ? 0.0 : 1.0,
        end: isSelected ? 1.0 : 0.0,
      ),
      builder: (context, value, child) {
        final color = Color.lerp(inactiveColor, activeColor, value)!;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
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
            ),
            const SizedBox(height: 4),
            // Small dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 6 : 0,
              height: isSelected ? 6 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
