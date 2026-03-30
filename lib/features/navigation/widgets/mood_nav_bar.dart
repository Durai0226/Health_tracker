import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mood Navigation Bar - Mood Tracker Feature
/// Inspired by: Behance iOS Wellness App, Calm, Reflectly
/// 
/// Design Features:
/// - Soft lavender/cream glassmorphism
/// - Floating pill with organic curves
/// - Emoji-style glow effect on active item
/// - Gentle pulse animation matching mood theme
class MoodNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;

  const MoodNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<MoodNavBar> createState() => _MoodNavBarState();
}

class _MoodNavBarState extends State<MoodNavBar>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  
  // Track previous index for slide animation
  int _previousIndex = 0;
  
  // Mood theme colors - Lavender palette from Behance design
  static const Color _primaryLavender = Color(0xFFB8A5FF);
  static const Color _primaryLavenderDark = Color(0xFF9D8AE5);
  static const Color _glowColor = Color(0xFFB8A5FF);
  static const Color _cream = Color(0xFFFFF8F0);
  
  // Design constants
  static const double _barHeight = 72.0;
  static const double _barMargin = 20.0;
  static const double _borderRadius = 32.0;
  static const double _iconSize = 26.0;
  static const double _glowRadius = 50.0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Gentle breathing pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Smooth slide animation for indicator
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant MoodNavBar oldWidget) {
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
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF2A2A38).withOpacity(0.95),
                        const Color(0xFF1A1A24).withOpacity(0.9),
                      ]
                    : [
                        _cream.withOpacity(0.95),
                        Colors.white.withOpacity(0.9),
                      ],
              ),
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(
                color: isDark
                    ? _primaryLavender.withOpacity(0.2)
                    : _primaryLavender.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryLavender.withOpacity(isDark ? 0.15 : 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Animated glow indicator behind active item
                _buildGlowIndicator(),
                // Navigation items
                _buildNavItems(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlowIndicator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 4;
        
        return AnimatedBuilder(
          animation: Listenable.merge([_slideAnimation, _pulseAnimation]),
          builder: (context, child) {
            // Interpolate position
            final startX = (_previousIndex * itemWidth) + (itemWidth / 2);
            final endX = (widget.currentIndex * itemWidth) + (itemWidth / 2);
            final currentX = lerpDouble(startX, endX, _slideAnimation.value)!;
            
            return Positioned(
              left: currentX - (_glowRadius / 2),
              top: (_barHeight / 2) - (_glowRadius / 2),
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: _glowRadius,
                  height: _glowRadius,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _glowColor.withOpacity(0.5),
                        _glowColor.withOpacity(0.2),
                        _glowColor.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            );
          },
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
                    final scale = isSelected ? _pulseAnimation.value : 1.0;
                    
                    return Transform.scale(
                      scale: scale,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: EdgeInsets.all(isSelected ? 12 : 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? _primaryLavenderDark : _primaryLavender)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _primaryLavender.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isSelected
                              ? widget.activeIcons[index]
                              : widget.inactiveIcons[index],
                          size: _iconSize,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : _primaryLavenderDark.withOpacity(0.6)),
                        ),
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
