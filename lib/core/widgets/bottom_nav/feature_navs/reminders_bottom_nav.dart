import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Reminders feature - Bell highlight indicator with badge support
/// Edge-to-edge, borderless, amber design
class RemindersBottomNav extends GlassNavBase {
  const RemindersBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFFF59E0B),
  });

  @override
  State<RemindersBottomNav> createState() => _RemindersBottomNavState();
}

class _RemindersBottomNavState extends State<RemindersBottomNav>
    with SingleTickerProviderStateMixin, GlassNavMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(RemindersBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
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
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                  // Badge
                  if (item.badge != null && item.badge! > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          item.badge! > 99 ? '99+' : '${item.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
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
