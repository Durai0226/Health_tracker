import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/active_hours.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "6 of 9 active hours": the hours of today with real walking in them, as a row
/// of 24 slim marks and a count. Renders nothing when there is no honest figure
/// to give (see [ActiveHoursCalc.compute]).
class ActiveHoursCard extends StatelessWidget {
  const ActiveHoursCard({super.key, required this.result});

  final ActiveHours? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.steps;
    final summary = '${r.count} of ${r.target} active hours so far today';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Semantics(
        container: true,
        label: summary,
        child: AppCard(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.container,
                        borderRadius: AppRadius.brMd,
                      ),
                      child: Icon(Symbols.schedule_rounded,
                          size: 22, color: accent.onContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.count} of ${r.target} active hours',
                              style: tt.titleMedium?.copyWith(
                                  color: ext.textPrimary,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            r.reached
                                ? 'You have moved through enough of the day.'
                                : 'Hours with at least ${ActiveHoursCalc.threshold} steps.',
                            style: tt.bodySmall
                                ?.copyWith(color: ext.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    for (var h = 0; h < r.hours.length; h++) ...[
                      Expanded(
                        child: Container(
                          key: ValueKey('active-hour-$h'),
                          height: 14,
                          decoration: BoxDecoration(
                            color: r.hours[h]
                                ? ext.mark(accent)
                                : ext.textTertiary.withValues(alpha: 0.25),
                            borderRadius: AppRadius.brSm,
                          ),
                        ),
                      ),
                      if (h < r.hours.length - 1) const SizedBox(width: 2),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final label in const ['12 am', '6 am', '12 pm', '6 pm'])
                      Text(label,
                          style: tt.labelSmall
                              ?.copyWith(color: ext.textTertiary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'A rule of thumb, not a target you have to hit.',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
