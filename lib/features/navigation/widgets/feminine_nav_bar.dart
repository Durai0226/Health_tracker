import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Feminine Navigation Bar - Period Tracking Category
/// Inspired by: Flo, Clue, Natural Cycles
/// 
/// Design Features:
/// - Soft rounded bar with organic flowing indicator
/// - Rose pink gradient (#EC4899 → #F472B6)
/// - Flowing blob/morph animation
/// - Soft, organic transitions with curves
/// - Gentle wave animation on background
class FeminineNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;

  const FeminineNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<FeminineNavBar> createState() => _FeminineNavBarState();
}

class _FeminineNavBarState extends State<FeminineNavBar>
    with TickerProviderStateMixin {
  
  late AnimationController _morphController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  late Animation<double> _morphAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;
  
  int _previousIndex = 0;
  
  // Feminine theme colors - Rose pink
  static const Color _primaryRose = Color(0xFFEC4899);
  static const Color _primaryRoseLight = Color(0xFFF472B6);
  static const Color _primaryRoseSoft = Color(0xFFFBCFE8);
  
  // Design constants
  static const double _barHeight = 72.0;
  static const double _barMargin = 16.0;
  static const double _borderRadius = 32.0;
  static const double _iconSize = 24.0;
  static const double _blobSize = 52.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Morph animation for blob transition
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutCubic,
    );
    
    // Gentle wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    
    _waveAnimation = CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    );
    
    // Soft glow pulse
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant FeminineNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _morphController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    _waveController.dispose();
    _glowController.dispose();
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
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _WaveBackgroundPainter(
                  progress: _waveAnimation.value,
                  isDark: isDark,
                  primaryColor: _primaryRose,
                ),
                child: child,
              );
            },
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
                          Colors.white.withOpacity(0.9),
                          _primaryRoseSoft.withOpacity(0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(_borderRadius),
                border: Border.all(
                  color: isDark
                      ? _primaryRose.withOpacity(0.2)
                      : _primaryRose.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryRose.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Organic blob indicator
                      _buildBlobIndicator(constraints.maxWidth, isDark),
                      // Navigation items
                      _buildNavItems(isDark),
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

  Widget _buildBlobIndicator(double totalWidth, bool isDark) {
    final itemWidth = totalWidth / 4;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_morphAnimation, _glowAnimation]),
      builder: (context, child) {
        final startX = (_previousIndex * itemWidth) + (itemWidth / 2) - (_blobSize / 2);
        final endX = (widget.currentIndex * itemWidth) + (itemWidth / 2) - (_blobSize / 2);
        final currentX = lerpDouble(startX, endX, _morphAnimation.value)!;
        
        // Organic morphing effect - blob stretches during transition
        final stretchFactor = math.sin(_morphAnimation.value * math.pi);
        final width = _blobSize + (stretchFactor * 20);
        final height = _blobSize - (stretchFactor * 8);
        
        return Positioned(
          left: currentX - (stretchFactor * 10),
          top: (_barHeight - height) / 2,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _primaryRose.withOpacity(0.35 * _glowAnimation.value),
                  _primaryRoseLight.withOpacity(0.2 * _glowAnimation.value),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.circular(height / 2),
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
                child: _FeminineNavIcon(
                  activeIcon: widget.activeIcons[index],
                  inactiveIcon: widget.inactiveIcons[index],
                  isSelected: isSelected,
                  isDark: isDark,
                  primaryColor: _primaryRose,
                  iconSize: _iconSize,
                  glowAnimation: _glowAnimation,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FeminineNavIcon extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final bool isDark;
  final Color primaryColor;
  final double iconSize;
  final Animation<double> glowAnimation;

  const _FeminineNavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.isDark,
    required this.primaryColor,
    required this.iconSize,
    required this.glowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = primaryColor;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.5)
        : Colors.black.withOpacity(0.4);

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(
            begin: isSelected ? 0.0 : 1.0,
            end: isSelected ? 1.0 : 0.0,
          ),
          builder: (context, value, child) {
            final color = Color.lerp(inactiveColor, activeColor, value)!;
            final scale = 1.0 + (value * 0.1);
            
            return Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with soft glow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: isSelected
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3 * glowAnimation.value),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          )
                        : null,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
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
                  ),
                  // Soft petal-shaped indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(top: 4),
                    width: isSelected ? 8 : 0,
                    height: isSelected ? 8 : 0,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
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

/// Custom painter for subtle wave background effect
class _WaveBackgroundPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color primaryColor;

  _WaveBackgroundPainter({
    required this.progress,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(isDark ? 0.05 : 0.03)
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 8.0;
    final waveLength = size.width / 2;
    
    path.moveTo(0, size.height);
    
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height - 20 + 
          math.sin((x / waveLength * 2 * math.pi) + (progress * 2 * math.pi)) * waveHeight;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
