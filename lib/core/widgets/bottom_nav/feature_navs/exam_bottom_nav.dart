import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Exam Prep feature - Bookmark ribbon indicator
/// Edge-to-edge, borderless, study blue design
class ExamBottomNav extends GlassNavBase {
  const ExamBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFF3B82F6),
  });

  @override
  State<ExamBottomNav> createState() => _ExamBottomNavState();
}

class _ExamBottomNavState extends State<ExamBottomNav>
    with SingleTickerProviderStateMixin, GlassNavMixin {
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(ExamBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _slideController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
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
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
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
        ),
      ),
    );
  }
}
