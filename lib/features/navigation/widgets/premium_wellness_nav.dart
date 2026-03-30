import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium Wellness Navigation Bar - Health & Wellness Category
/// Fixed: Using same pattern as working Fitness nav
/// 
/// Design Features:
/// - Teal gradient glow (#00897B)
/// - Glassmorphism background with blur
/// - Pulse animation synced with "heartbeat" feel
/// - Proper safe area handling (no overflow)
class PremiumWellnessNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> activeIcons;
  final List<IconData> inactiveIcons;

  const PremiumWellnessNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcons,
    required this.inactiveIcons,
  });

  @override
  State<PremiumWellnessNav> createState() => _PremiumWellnessNavState();
}

class _PremiumWellnessNavState extends State<PremiumWellnessNav>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Wellness theme colors
  static const Color _primaryTeal = Color(0xFF00897B);
  static const Color _surfaceColor = Color(0xFFF0FDFA);
  static const Color _surfaceColorDark = Color(0xFF0D1F1C);
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? _surfaceColorDark : _surfaceColor;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = 0.15 + (_pulseAnimation.value * 0.1);
        
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: _primaryTeal.withValues(alpha: glowOpacity),
                blurRadius: 20 + (_pulseAnimation.value * 10),
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main nav bar
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(
                      color: _primaryTeal.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (index) => _buildNavItem(index, isDark)),
                ),
              ),
              // Safe area padding
              Container(
                height: bottomPadding,
                color: bgColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, bool isDark) {
    final isSelected = widget.currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: _primaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected
                    ? widget.activeIcons[index]
                    : widget.inactiveIcons[index],
                size: 26,
                color: isSelected
                    ? _primaryTeal
                    : isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.4),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _primaryTeal,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryTeal.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
