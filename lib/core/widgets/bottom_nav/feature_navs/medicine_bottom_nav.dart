import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Medicine feature - Floating capsule pill indicator with pulse glow
/// Edge-to-edge, borderless, seamless from bottom
class MedicineBottomNav extends GlassNavBase {
  const MedicineBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFF6366F1),
  });

  @override
  State<MedicineBottomNav> createState() => _MedicineBottomNavState();
}

class _MedicineBottomNavState extends State<MedicineBottomNav>
    with SingleTickerProviderStateMixin, GlassNavMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildEdgeToEdgeWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
          animation: _pulseController,
          builder: (context, child) {
            final glowIntensity = isSelected ? 0.15 + (_pulseController.value * 0.1) : 0.0;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: glowIntensity) : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.2 * _pulseController.value),
                    blurRadius: 12,
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
