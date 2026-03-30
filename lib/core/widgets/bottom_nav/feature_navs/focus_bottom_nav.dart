import 'package:flutter/material.dart';
import '../base/glass_nav_base.dart';

/// Focus feature - Elevated circle extending above nav (Image 2 style)
/// Edge-to-edge, borderless, large glowing active circle
class FocusBottomNav extends GlassNavBase {
  const FocusBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFF8B5CF6),
  });

  @override
  State<FocusBottomNav> createState() => _FocusBottomNavState();
}

class _FocusBottomNavState extends State<FocusBottomNav>
    with SingleTickerProviderStateMixin, GlassNavMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nav items row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: widget.items.asMap().entries.map((entry) {
                return _buildNavItem(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
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
          hapticHeavy();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            final glowValue = _glowController.value;
            
            // Elevated large circle for selected item (Image 2 style)
            if (isSelected) {
              return Transform.translate(
                offset: const Offset(0, -12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.4 + (glowValue * 0.2)),
                            blurRadius: 16 + (glowValue * 8),
                            spreadRadius: 2 + (glowValue * 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        item.activeIcon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: activeColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              );
            }

            // Regular inactive item
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: inactiveColor,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: inactiveColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
