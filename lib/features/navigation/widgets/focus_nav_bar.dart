import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Focus Navigation Bar - Productivity Category
/// Inspired by: Notion, Linear, Todoist
/// 
/// Design Features:
/// - Minimal edge-to-edge with thin underline indicator
/// - Purple/Violet gradient (#8B5CF6 → #7C3AED)
/// - Sliding underline with subtle glow
/// - Sharp, precise 200ms transitions
/// - Text labels appear on selection
class FocusNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;
  final List<String>? labels;

  const FocusNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
    this.labels,
  }) : assert(activeIcons.length == 4 && inactiveIcons.length == 4);

  @override
  State<FocusNavBar> createState() => _FocusNavBarState();
}

class _FocusNavBarState extends State<FocusNavBar>
    with TickerProviderStateMixin {
  
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late List<AnimationController> _scaleControllers;
  
  int _previousIndex = 0;
  
  // Focus theme colors
  static const Color _primaryPurple = Color(0xFF8B5CF6);
  static const Color _primaryPurpleDark = Color(0xFF7C3AED);
  
  // Design constants
  static const double _barHeight = 56.0;
  static const double _iconSize = 24.0;
  static const double _underlineHeight = 3.0;
  static const double _underlineWidth = 32.0;
  
  // Default labels
  static const List<String> _defaultLabels = ['Home', 'Focus', 'Relax', 'Settings'];

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _initAnimationControllers();
  }

  void _initAnimationControllers() {
    // Slide animation for underline
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    
    // Scale controllers for tap feedback
    _scaleControllers = List.generate(4, (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    ));
  }

  @override
  void didUpdateWidget(covariant FocusNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _slideController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    for (final controller in _scaleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.lightImpact();
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
    
    // Background colors
    final bgColor = isDark
        ? const Color(0xFF0A0A0A)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);
    
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SizedBox(
        height: _barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Navigation items
                _buildNavItems(isDark),
                // Animated underline indicator
                _buildUnderlineIndicator(constraints.maxWidth, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnderlineIndicator(double totalWidth, bool isDark) {
    final itemWidth = totalWidth / 4;
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        final startX = (_previousIndex * itemWidth) + (itemWidth / 2) - (_underlineWidth / 2);
        final endX = (widget.currentIndex * itemWidth) + (itemWidth / 2) - (_underlineWidth / 2);
        final currentX = lerpDouble(startX, endX, _slideAnimation.value)!;
        
        return Positioned(
          left: currentX,
          bottom: 8,
          child: Container(
            width: _underlineWidth,
            height: _underlineHeight,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryPurple, _primaryPurpleDark],
              ),
              borderRadius: BorderRadius.circular(_underlineHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: _primaryPurple.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItems(bool isDark) {
    final labels = widget.labels ?? _defaultLabels;
    final activeColor = _primaryPurple;
    final inactiveColor = isDark
        ? Colors.white.withOpacity(0.4)
        : Colors.black.withOpacity(0.35);

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
              animation: _scaleControllers[index],
              builder: (context, child) {
                final scale = 1.0 - (_scaleControllers[index].value * 0.1);
                
                return Transform.scale(
                  scale: scale,
                  child: SizedBox(
                    height: _barHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with morph transition
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
                            isSelected ? widget.activeIcons[index] : widget.inactiveIcons[index],
                            key: ValueKey('${index}_$isSelected'),
                            color: isSelected ? activeColor : inactiveColor,
                            size: _iconSize,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Animated label
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? activeColor : inactiveColor,
                            letterSpacing: 0.3,
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: isSelected ? 1.0 : 0.7,
                            child: Text(labels[index]),
                          ),
                        ),
                      ],
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
