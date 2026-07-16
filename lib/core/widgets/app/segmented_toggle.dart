import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

class SegmentItem {
  final IconData icon;
  final String label;
  const SegmentItem({required this.icon, required this.label});
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
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: i == index ? ext.surface : Colors.transparent,
                    borderRadius: AppRadius.brMd,
                    boxShadow: i == index ? AppShadows.resting(context) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].icon,
                          size: 18,
                          color: i == index ? ext.mark(s) : ext.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        items[i].label,
                        style: tt.labelLarge?.copyWith(
                          color: i == index ? ext.mark(s) : ext.textSecondary,
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
