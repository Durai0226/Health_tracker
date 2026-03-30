import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Notes feature - Paper tab indicator with underline
/// Edge-to-edge, borderless, clean emerald design
class NotesBottomNav extends GlassNavBase {
  const NotesBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFF10B981),
  });

  @override
  State<NotesBottomNav> createState() => _NotesBottomNavState();
}

class _NotesBottomNavState extends State<NotesBottomNav>
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
  void didUpdateWidget(NotesBottomNav oldWidget) {
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
              // Underline indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 14 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(1),
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
