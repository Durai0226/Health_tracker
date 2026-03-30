import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base/glass_nav_base.dart';

/// Fitness feature - Modern dark nav with floating center progress button
/// Neon lime green accent with smooth glow animations
class FitnessBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;
  final Color featureColor;

  const FitnessBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.featureColor = const Color(0xFFCDFF00), // Neon lime green
  });

  @override
  State<FitnessBottomNav> createState() => _FitnessBottomNavState();
}

class _FitnessBottomNavState extends State<FitnessBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabGlowAnimation;

  // Fixed nav items with center floating button
  static const int _centerIndex = 2;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack),
    );
    _fabGlowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );

    if (widget.currentIndex == _centerIndex) {
      _fabController.forward();
    }
  }

  @override
  void didUpdateWidget(FitnessBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex == _centerIndex && oldWidget.currentIndex != _centerIndex) {
      _fabController.forward();
    } else if (widget.currentIndex != _centerIndex && oldWidget.currentIndex == _centerIndex) {
      _fabController.reverse();
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.lightImpact();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : const Color(0xFF1A1A1A);
    final activeColor = widget.featureColor;
    final inactiveColor = isDark ? Colors.grey.shade600 : Colors.grey.shade500;

    return Container(
      height: 80 + bottomPadding,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Top glow line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    activeColor.withValues(alpha: 0.2),
                    activeColor.withValues(alpha: 0.4),
                    activeColor.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Navigation items
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: bottomPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _buildNavItems(activeColor, inactiveColor),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(Color activeColor, Color inactiveColor) {
    final items = <Widget>[];
    
    for (int i = 0; i < widget.items.length; i++) {
      if (i == _centerIndex) {
        // Center floating button
        items.add(_buildCenterButton(activeColor));
      } else {
        items.add(_buildNavItem(
          index: i,
          item: widget.items[i],
          isSelected: widget.currentIndex == i,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        ));
      }
    }
    
    return items;
  }

  Widget _buildCenterButton(Color activeColor) {
    final isSelected = widget.currentIndex == _centerIndex;
    final item = widget.items[_centerIndex];

    return GestureDetector(
      onTap: () => _handleTap(_centerIndex),
      child: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor,
                    activeColor.withValues(alpha: 0.85),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: _fabGlowAnimation.value),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: const Color(0xFF0D0D0D),
                size: 26,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required GlassNavItem item,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with background highlight
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.all(isSelected ? 8 : 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
              // Active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(top: 4),
                width: isSelected ? 4 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
