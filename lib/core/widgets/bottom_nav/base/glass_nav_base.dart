import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';

/// Base glassmorphic navigation foundation
/// All 12 feature navs extend from this base
abstract class GlassNavBase extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color featureColor;
  final List<GlassNavItem> items;
  final VoidCallback? onFabTap;
  final bool showFab;

  const GlassNavBase({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.featureColor,
    required this.items,
    this.onFabTap,
    this.showFab = false,
  });
}

/// Navigation item configuration
class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;

  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

/// Mixin providing shared glass effect functionality
mixin GlassNavMixin<T extends GlassNavBase> on State<T> {
  
  /// Check if dark mode
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  /// Clean surface color - NO borders
  Color get surfaceColor => isDark 
      ? const Color(0xFF1A1A1A) 
      : Colors.white;

  /// Subtle top shadow only (no container borders)
  List<BoxShadow> get topShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];

  /// Standard haptic feedback
  void hapticTap() => HapticFeedback.selectionClick();
  void hapticHeavy() => HapticFeedback.mediumImpact();

  /// Build EDGE-TO-EDGE wrapper - NO margins, NO borders, seamless blend
  Widget buildEdgeToEdgeWrapper({
    required Widget child,
    double height = 68,
    Color? backgroundColor,
    Gradient? backgroundGradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundGradient == null ? (backgroundColor ?? surfaceColor) : null,
        gradient: backgroundGradient,
        boxShadow: topShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: child,
        ),
      ),
    );
  }

  /// For navs with elevated center button extending above
  Widget buildElevatedCenterWrapper({
    required Widget child,
    required Widget elevatedCenter,
    double height = 68,
    double elevationHeight = 28,
    Color? backgroundColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? surfaceColor,
            boxShadow: topShadow,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: height,
              child: child,
            ),
          ),
        ),
        Positioned(
          top: -elevationHeight,
          left: 0,
          right: 0,
          child: Center(child: elevatedCenter),
        ),
      ],
    );
  }

  /// Build individual nav item with animation support
  Widget buildNavItem({
    required int index,
    required GlassNavItem item,
    required Animation<double>? scaleAnimation,
    double iconSize = 24,
    double fontSize = 10,
  }) {
    final isSelected = widget.currentIndex == index;
    final color = isSelected 
        ? widget.featureColor 
        : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6) 
            ?? Colors.grey;

    Widget iconWidget = Icon(
      isSelected ? item.activeIcon : item.icon,
      color: color,
      size: iconSize,
    );

    if (scaleAnimation != null && isSelected) {
      iconWidget = ScaleTransition(
        scale: scaleAnimation,
        child: iconWidget,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          hapticTap();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                iconWidget,
                if (item.badge != null && item.badge! > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.featureColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        item.badge! > 99 ? '99+' : '${item.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable animated selection indicator
class GlassSelectionIndicator extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const GlassSelectionIndicator({
    super.key,
    required this.color,
    this.width = 48,
    this.height = 3,
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Floating action button for center position
class GlassNavFab extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final double size;

  const GlassNavFab({
    super.key,
    required this.onTap,
    required this.color,
    this.icon = Symbols.add_rounded,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
