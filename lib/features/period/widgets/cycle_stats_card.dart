import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/cycle_prediction.dart';

/// Cycle statistics as a [StatTileRow]: average cycle length, average period
/// length, and count of cycles tracked. Honest about a thin sample.
class CycleStatsCard extends StatelessWidget {
  final CycleStats stats;
  final VoidCallback? onTap;

  const CycleStatsCard({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    String cycleVal;
    if (stats.medianCycleLength != null) {
      cycleVal = '${stats.medianCycleLength}d';
    } else {
      cycleVal = '—';
    }
    final periodVal =
        stats.medianPeriodLength != null ? '${stats.medianPeriodLength}d' : '—';
    final variation =
        stats.cycleCount >= 2 ? '±${stats.cycleLengthStd.toStringAsFixed(1)}' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatTileRow(
          tiles: [
            StatTile(
              icon: Symbols.autorenew_rounded,
              value: cycleVal,
              label: 'Avg cycle',
              accent: ext.period,
            ),
            StatTile(
              icon: Symbols.water_drop_rounded,
              value: periodVal,
              label: 'Avg period',
              accent: ext.info,
            ),
            StatTile(
              icon: Symbols.show_chart_rounded,
              value: variation,
              label: 'Variation',
              accent: ext.focus,
            ),
          ],
        ),
        if (stats.cycleCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              stats.isIrregular
                  ? 'Based on ${stats.cycleCount} cycles — your lengths vary, so estimates are wide.'
                  : 'Based on ${stats.cycleCount} cycle${stats.cycleCount == 1 ? '' : 's'} tracked.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ext.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}
