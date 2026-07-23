import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final AccentSwatch accent;

  /// An action slot (e.g. a center "+ Log") — rendered as a permanently-raised
  /// orb that never enters the selection, and whose tap always fires (even when
  /// another destination is selected).
  final bool isAction;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.accent,
    this.isAction = false,
  });
}

/// A floating dock with a raised "orb" for the active destination.
///
/// The active tab lifts into an accent-filled orb that physically **slides**
/// between tabs and **morphs to the feature's color** as you switch; the other
/// tabs stay as quiet icons + labels below. Distinct, tactile, and calm — no
/// glass, per-feature color built in.
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  double _alignX(int i, int n) => -1 + 2 * (i + 0.5) / n;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final active = items[currentIndex];
    final n = items.length;
    final actionIndex = items.indexWhere((e) => e.isAction);

    // Docked to the bottom edge (not floating): full-width, rounded top,
    // upward shadow to separate from content, safe-area padding.
    return Container(
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: ext.isDark
            ? Border(top: BorderSide(color: ext.outline))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Destinations.
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == currentIndex,
                          label: items[i].label,
                          excludeSemantics: true,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            // Action slots always fire (they don't get selected);
                            // destinations only fire when not already selected.
                            if (items[i].isAction || i != currentIndex) {
                              HapticFeedback.selectionClick();
                              onTap(i);
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // The raised orb (sliding for the selection, fixed
                              // for the action slot) shows the icon, so the flat
                              // icon is hidden for both.
                              SizedBox(
                                height: 26,
                                child: (i == currentIndex || items[i].isAction)
                                    ? null
                                    // Outline-at-rest: inactive tabs render the
                                    // Symbols glyph unfilled; the selected tab
                                    // sits filled inside the orb.
                                    : Icon(items[i].icon,
                                        size: 24,
                                        fill: 0,
                                        color: ext.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                items[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelSmall?.copyWith(
                                  color: (i == currentIndex || items[i].isAction)
                                      ? items[i].accent.strong
                                      : ext.textSecondary,
                                  fontWeight:
                                      (i == currentIndex || items[i].isAction)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      ),
                  ],
                ),
              ),

              // Fixed center ACTION orb (e.g. "+ Log"). Drawn BEFORE the sliding
              // orb so the selection orb glides cleanly OVER it during a
              // cross-centre tab switch instead of vanishing behind it (the old
              // ordering caused a flicker as the orb slid past the centre).
              if (actionIndex != -1)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment(_alignX(actionIndex, n), -1),
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: items[actionIndex].accent.base,
                          shape: BoxShape.circle,
                          border: Border.all(color: ext.surface, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: items[actionIndex]
                                  .accent
                                  .base
                                  .withOpacity(0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(items[actionIndex].activeIcon,
                            color: items[actionIndex].accent.on, size: 30),
                      ),
                    ),
                  ),
                ),

              // The raised, sliding, color-morphing selection orb — on top, so
              // it reads continuously as it slides across the bar.
              IgnorePointer(
                child: AnimatedAlign(
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  alignment: Alignment(_alignX(currentIndex, n), -1),
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.emphasized,
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: active.accent.base,
                        shape: BoxShape.circle,
                        border: Border.all(color: ext.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: active.accent.base.withOpacity(0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(active.activeIcon,
                          color: active.accent.on, size: 25),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
