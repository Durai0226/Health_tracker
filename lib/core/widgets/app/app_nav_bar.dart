import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final AccentSwatch accent;

  /// An action slot (e.g. a center "+ Log") — rendered as a permanently-raised
  /// FAB-shaped button that never enters the selection, and whose tap always
  /// fires (even when another destination is selected).
  ///
  /// M3 allows exactly one active indicator, so an action slot must never wear
  /// the selected treatment (round indicator + accent label + w700): it is a
  /// rounded-square FAB with a neutral elevation shadow and a plain label.
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
///
/// Exactly one active indicator is ever drawn (M3): an [AppNavItem.isAction]
/// slot renders as a docked FAB (rounded-square, neutral shadow, plain label)
/// so it stays prominent without impersonating the current destination.
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
                      Expanded(child: _slot(context, i)),
                  ],
                ),
              ),

              // Fixed center ACTION button (e.g. "+ Log") — a docked FAB, NOT a
              // destination. M3 allows one active indicator, so this deliberately
              // avoids the selection's language: rounded-square instead of round,
              // smaller than the selection orb, and a neutral elevation shadow
              // instead of the accent glow.
              //
              // Drawn BEFORE the sliding orb so the selection orb glides cleanly
              // OVER it during a cross-centre tab switch instead of vanishing
              // behind it (the old ordering caused a flicker as the orb slid
              // past the centre).
              if (actionIndex != -1)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment(_alignX(actionIndex, n), -1),
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: items[actionIndex].accent.base,
                          borderRadius: AppRadius.brLg,
                          border: Border.all(color: ext.surface, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(ext.isDark ? 0.4 : 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(items[actionIndex].activeIcon,
                            color: items[actionIndex].accent.on, size: 26),
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

  /// One tap target in the bar: the flat icon (inactive only) + its label.
  ///
  /// Only the current destination wears the selected treatment (accent label at
  /// w700, icon hoisted into the round orb). The action slot is prominent via
  /// its docked FAB, but its label stays neutral so the bar never presents two
  /// selected-looking destinations.
  Widget _slot(BuildContext context, int i) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final item = items[i];
    final isSelected = i == currentIndex;
    final isAction = item.isAction;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Action slots always fire (they don't get selected); destinations
          // only fire when not already selected.
          if (isAction || !isSelected) {
            HapticFeedback.selectionClick();
            onTap(i);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The raised orb (selection) and the docked FAB (action) each draw
            // their own icon, so the flat icon is hidden for both.
            SizedBox(
              height: 26,
              child: (isSelected || isAction)
                  ? null
                  // Outline-at-rest: inactive tabs render the Symbols glyph
                  // unfilled; the selected tab sits filled inside the orb.
                  : Icon(item.icon, size: 24, fill: 0, color: ext.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(
                color: isSelected
                    ? item.accent.strong
                    : isAction
                        ? ext.textPrimary
                        : ext.textSecondary,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : isAction
                        ? FontWeight.w600
                        : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
