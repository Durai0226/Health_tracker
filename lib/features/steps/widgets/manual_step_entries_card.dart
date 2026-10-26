import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/design/app_colors_ext.dart';
import '../../../core/design/app_design.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/step_manual_entry.dart';
import '../utils/step_format.dart';

/// "Added by hand" — the manual entries behind today's total, each removable.
///
/// Manual steps were written, summed into the day and shown nowhere: a mistyped
/// 10,000 could only be corrected by typing a second, negative entry. Shows
/// nothing when there are none.
class ManualStepEntriesCard extends StatelessWidget {
  const ManualStepEntriesCard({
    super.key,
    required this.entries,
    required this.onRemove,
  });

  final List<StepManualEntry> entries;
  final ValueChanged<StepManualEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.steps;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Symbols.edit_note_rounded, color: ext.mark(accent)),
            const SizedBox(width: AppSpacing.sm),
            // Expanded: at large text sizes the title has to wrap, not push the
            // row wider than the card.
            Expanded(
              child: Text('Added by hand',
                  style: tt.titleSmall?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          for (final e in entries)
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.steps >= 0 ? '+' : '−'}${formatThousands(e.steps.abs())} steps',
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                        ),
                        Text(
                          [
                            DateFormats.time.format(e.time),
                            if ((e.note ?? '').trim().isNotEmpty) e.note!.trim(),
                          ].join(' · '),
                          style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                AppIconButton(
                  icon: Symbols.delete_rounded,
                  filled: false,
                  accent: accent,
                  tooltip: 'Remove this entry',
                  onPressed: () => onRemove(e),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
