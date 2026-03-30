import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base/glass_nav_base.dart';

/// Luna Cycle feature - Crescent moon indicator with center FAB
/// Edge-to-edge, borderless, soft pink glow
class LunaBottomNav extends GlassNavBase {
  const LunaBottomNav({
    super.key,
    required super.currentIndex,
    required super.onTap,
    required super.items,
    super.featureColor = const Color(0xFFEC4899),
    super.onFabTap,
    super.showFab = true,
  });

  @override
  State<LunaBottomNav> createState() => _LunaBottomNavState();
}

class _LunaBottomNavState extends State<LunaBottomNav>
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
    final hasFab = widget.showFab && widget.onFabTap != null;
    
    return buildEdgeToEdgeWrapper(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left items (first 2)
                ...widget.items.take(2).toList().asMap().entries.map((e) {
                  return _buildNavItem(e.key, e.value);
                }),
                // Space for FAB
                if (hasFab) const SizedBox(width: 56),
                // Right items (remaining)
                ...widget.items.skip(2).take(2).toList().asMap().entries.map((e) {
                  return _buildNavItem(e.key + 2, widget.items[e.key + 2]);
                }),
              ],
            ),
          ),
          // Center FAB
          if (hasFab)
            Positioned(
              top: -20,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onFabTap!();
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.featureColor,
                              widget.featureColor.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.featureColor.withValues(alpha: 0.3 + (_glowController.value * 0.2)),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      ),
                    );
                  },
                ),
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
          hapticTap();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
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
