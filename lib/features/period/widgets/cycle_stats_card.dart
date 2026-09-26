import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/cycle_prediction.dart';

/// Cycle statistics as a [StatTileRow]: median cycle length, median period
/// length, and the spread around them. Honest about a thin sample.
///
/// The tiles say MEDIAN because they show a median. They were labelled "Avg"
/// over [CycleStats.medianCycleLength] / [CycleStats.medianPeriodLength], so
/// the word and the number disagreed for anyone with an irregular cycle.
///
/// The label moved rather than the maths, because the median is the figure the
/// rest of the feature already runs on: `CyclePredictor._learnedCycleLength`
/// returns `medianCycleLength` and the predicted period length is
/// `medianPeriodLength`. Showing a mean here would put a number on screen that
/// nothing else in the app uses — "Day 12 of ~28" beside an "Avg cycle" of 31d
/// — and would let one 60-day cycle after an illness drag the headline figure
/// that outlier rejection exists to keep out. [CycleStats.avgCycleLength] and
/// [CycleStats.avgPeriodLength] are still computed and available if a future
/// surface genuinely wants a mean.
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
              label: 'Median cycle',
              accent: ext.period,
            ),
            StatTile(
              icon: Symbols.water_drop_rounded,
              value: periodVal,
              label: 'Median period',
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
