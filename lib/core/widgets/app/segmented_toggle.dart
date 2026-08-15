import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

class SegmentItem {
  /// Optional leading glyph. Omit for short label-only segments (e.g. numeric
  /// duration/ring choices) so they render with no phantom leading gap.
  final IconData? icon;
  final String label;
  const SegmentItem({this.icon, required this.label});
}

/// Accent-aware segmented control (e.g. Medicine | Water in the Health hub).
class SegmentedToggle extends StatelessWidget {
  final List<SegmentItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final AccentSwatch? accent;

  const SegmentedToggle({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i != index) {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  }
                },
                // Container, not AnimatedContainer.
                //
                // This used to lerp both the fill AND `AppShadows.resting` over
                // 260ms, which meant that on every switch a blurred shadow was
                // animating OUT on the old segment while another animated IN on
                // the new one — two shadows re-rasterizing every frame for a
                // quarter of a second, on 12+ screens. Selection now changes on
                // the same frame as the tap. The haptic below and the instant
                // colour change are the feedback.
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: i == index ? ext.surface : Colors.transparent,
                    borderRadius: AppRadius.brMd,
                    boxShadow: i == index ? AppShadows.resting(context) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (items[i].icon != null) ...[
                        Icon(items[i].icon,
                            size: 18,
                            color:
                                i == index ? ext.mark(s) : ext.textSecondary),
                        const SizedBox(width: 8),
                      ],
                      // Flexible + ellipsis: segments split the width evenly,
                      // so at 320px a 3-up toggle gives each label ~90px. An
                      // unflexed Text overflowed the segment there.
                      Flexible(
                        child: Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(
                            color: i == index ? ext.mark(s) : ext.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
