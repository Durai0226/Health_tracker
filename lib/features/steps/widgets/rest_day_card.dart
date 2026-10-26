import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/design/app_colors_ext.dart';
import '../../../core/design/app_design.dart';
import '../../../core/health/rest_days.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "Taking it easy today?" — mark today as a rest or unwell day, or undo it.
///
/// Once marked it says the goal is paused rather than vanishing, so the person
/// can see what the app did with their day and take it back.
class RestDayCard extends StatelessWidget {
  const RestDayCard({
    super.key,
    required this.marked,
    required this.onMark,
    required this.onUndo,
  });

  /// How today is marked, or null.
  final RestKind? marked;
  final ValueChanged<RestKind> onMark;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.steps;

    if (marked != null) {
      return AppCard(
        child: Row(
          children: [
            Icon(
                marked == RestKind.unwell
                    ? Symbols.healing_rounded
                    : Symbols.self_improvement_rounded,
                color: ext.mark(accent)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(marked!.label,
                      style: tt.titleSmall?.copyWith(
                          color: ext.textPrimary, fontWeight: FontWeight.w700)),
                  Text('Your goal is paused today and your streak holds.',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                ],
              ),
            ),
            AppButton(
              label: 'Undo',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              accent: accent,
              onPressed: onUndo,
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Taking it easy today?',
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Pause the goal. Your streak holds and the reminder stays quiet.',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppChip(
                label: RestKind.rest.label,
                icon: Symbols.self_improvement_rounded,
                accent: accent,
                onTap: () => onMark(RestKind.rest),
              ),
              AppChip(
                label: RestKind.unwell.label,
                icon: Symbols.healing_rounded,
                accent: accent,
                onTap: () => onMark(RestKind.unwell),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
