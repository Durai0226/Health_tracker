import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Mood feature - Organic blob indicator with soft gradient
/// Edge-to-edge, borderless, warm coral design
class MoodBottomNav extends GlassNavBase {
  const MoodBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFFFF6B9D),
  });

  @override
  State<MoodBottomNav> createState() => _MoodBottomNavState();
}

class _MoodBottomNavState extends State<MoodBottomNav>
    with SingleTickerProviderStateMixin, GlassNavMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didUpdateWidget(MoodBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _scaleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected ? RadialGradient(
              colors: [
                activeColor.withValues(alpha: 0.22),
                activeColor.withValues(alpha: 0.06),
              ],
            ) : null,
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
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
        ),
      ),
    );
  }
}
