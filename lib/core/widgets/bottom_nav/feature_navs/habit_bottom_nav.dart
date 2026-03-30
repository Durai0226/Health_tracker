import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Habit feature - Flame badge indicator with subtle glow
/// Edge-to-edge, borderless, indigo motivational design
class HabitBottomNav extends GlassNavBase {
  const HabitBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFF7C91F4),
  });

  @override
  State<HabitBottomNav> createState() => _HabitBottomNavState();
}

class _HabitBottomNavState extends State<HabitBottomNav>
    with SingleTickerProviderStateMixin, GlassNavMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildEdgeToEdgeWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: widget.items.asMap().entries.map((entry) {
            return _buildNavItem(entry.key, entry.value);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, GlassNavItem item) {
    final isSelected = widget.currentIndex == index;
    final activeColor = widget.featureColor;
    final inactiveColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    return Flexible(
      child: GestureDetector(
        onTap: () {
          hapticTap();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowValue = isSelected ? _glowController.value : 0.0;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected ? RadialGradient(
                  colors: [
                    activeColor.withValues(alpha: 0.18 + (glowValue * 0.08)),
                    activeColor.withValues(alpha: 0.05),
                  ],
                ) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15 * glowValue),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ] : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
