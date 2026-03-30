import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fitness Navigation Bar - Fitness & Activity Category
/// Inspired by: Nike Training Club, Strava, Peloton
/// 
/// Design Features:
/// - Bold notched/curved bar with center FAB area
/// - Neon lime on dark (#CDFF00 on #0D0D0D)
/// - Electric glow effect with particle trail
/// - Energetic bounce, elastic curves
/// - Animated icon scale on tap
class FitnessNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final VoidCallback? onCenterTap;

  const FitnessNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
    this.onCenterTap,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<FitnessNavBar> createState() => _FitnessNavBarState();
}

class _FitnessNavBarState extends State<FitnessNavBar>
    with TickerProviderStateMixin {
  
  late AnimationController _glowController;
  late AnimationController _bounceController;
  late Animation<double> _glowAnimation;
  late List<AnimationController> _itemControllers;
  
  int _previousIndex = 0;
  
  // Fitness theme colors - Neon lime
  static const Color _primaryLime = Color(0xFFCDFF00);
  static const Color _primaryLimeDark = Color(0xFFB8E600);
  static const Color _darkBg = Color(0xFF0D0D0D);
  static const Color _darkSurface = Color(0xFF1A1A1A);
  
  // Design constants
  static const double _barHeight = 68.0;
  static const double _iconSize = 26.0;
  static const double _notchRadius = 36.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Bounce animation for transitions
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Individual item controllers
    _itemControllers = List.generate(4, (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    ));
  }

  @override
  void didUpdateWidget(covariant FitnessNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _bounceController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.mediumImpact();
    widget.onTap(index);
  }

  void _onItemTapDown(int index) {
    _itemControllers[index].forward();
  }

  void _onItemTapUp(int index) {
    _itemControllers[index].reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      height: _barHeight + bottomPadding,
      decoration: BoxDecoration(
        color: _darkBg,
        boxShadow: [
          BoxShadow(
            color: _primaryLime.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Custom painted notched background
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, _barHeight),
            painter: _NotchedNavPainter(
              color: _darkSurface,
              notchRadius: _notchRadius,
            ),
          ),
          // Navigation items
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: SizedBox(
              height: _barHeight,
              child: _buildNavItems(),
            ),
          ),
          // Center FAB (optional)
          if (widget.onCenterTap != null)
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: Center(
                child: _buildCenterFab(),
              ),
            ),
          // Glow indicator
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: SizedBox(
              height: _barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return _buildGlowIndicator(constraints.maxWidth);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterFab() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryLime, _primaryLimeDark],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primaryLime.withOpacity(0.5 * _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onCenterTap,
              customBorder: const CircleBorder(),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: _darkBg,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlowIndicator(double totalWidth) {
    final itemWidth = totalWidth / 4;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_bounceController, _glowAnimation]),
      builder: (context, child) {
        final bounceValue = Curves.elasticOut.transform(
          _bounceController.value.clamp(0.0, 1.0),
        );
        
        final startX = (_previousIndex * itemWidth) + (itemWidth / 2);
        final endX = (widget.currentIndex * itemWidth) + (itemWidth / 2);
        final currentX = lerpDouble(startX, endX, bounceValue)!;
        
        return Stack(
          children: [
            // Electric glow effect
            Positioned(
              left: currentX - 30,
              top: 8,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryLime.withOpacity(0.3 * _glowAnimation.value),
                      _primaryLime.withOpacity(0.1 * _glowAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavItems() {
    return Row(
      children: List.generate(4, (index) {
        final isSelected = widget.currentIndex == index;
        
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onItemTapDown(index),
            onTapUp: (_) => _onItemTapUp(index),
            onTapCancel: () => _onItemTapUp(index),
            onTap: () => _onItemTap(index),
            child: AnimatedBuilder(
              animation: _itemControllers[index],
              builder: (context, child) {
                final pressScale = 1.0 - (_itemControllers[index].value * 0.15);
                
                return Transform.scale(
                  scale: pressScale,
                  child: SizedBox(
                    height: _barHeight,
                    child: Center(
                      child: _FitnessNavIcon(
                        activeIcon: widget.activeIcons[index],
                        inactiveIcon: widget.inactiveIcons[index],
                        isSelected: isSelected,
                        primaryColor: _primaryLime,
                        iconSize: _iconSize,
                        glowAnimation: _glowAnimation,
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

class _FitnessNavIcon extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final Color primaryColor;
  final double iconSize;
  final Animation<double> glowAnimation;

  const _FitnessNavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.primaryColor,
    required this.iconSize,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Color(0xFF808080);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          tween: Tween<double>(
            begin: isSelected ? 0.0 : 1.0,
            end: isSelected ? 1.0 : 0.0,
          ),
          builder: (context, value, child) {
            final scale = 1.0 + (value * 0.15);
            final color = Color.lerp(inactiveColor, primaryColor, value)!;
            
            return Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with glow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: isSelected
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4 * glowAnimation.value),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          )
                        : null,
                    child: Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: color,
                      size: iconSize,
                    ),
                  ),
                  // Bottom bar indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(top: 4),
                    width: isSelected ? 20 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Custom painter for notched navigation bar background
class _NotchedNavPainter extends CustomPainter {
  final Color color;
  final double notchRadius;

  _NotchedNavPainter({
    required this.color,
    required this.notchRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final notchDepth = notchRadius * 0.6;
    
    path.moveTo(0, 0);
    path.lineTo(centerX - notchRadius - 10, 0);
    
    // Notch curve
    path.quadraticBezierTo(
      centerX - notchRadius,
      0,
      centerX - notchRadius + 5,
      notchDepth * 0.3,
    );
    path.arcTo(
      Rect.fromCircle(
        center: Offset(centerX, notchDepth * 0.3),
        radius: notchRadius - 5,
      ),
      math.pi,
      -math.pi,
      false,
    );
    path.quadraticBezierTo(
      centerX + notchRadius,
      0,
      centerX + notchRadius + 10,
      0,
    );
    
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedNavPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.notchRadius != notchRadius;
  }
}
