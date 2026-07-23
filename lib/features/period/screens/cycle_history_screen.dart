import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/menstrual_cycle.dart';
import '../services/period_service.dart';
import '../widgets/cycle_stats_card.dart';
import '../widgets/prediction_card.dart' show fmtPeriodDate, fmtPeriodShort;

/// Cycle history: stats summary + a reverse-chronological list of detected
/// cycles with their length and period length.
class CycleHistoryScreen extends StatelessWidget {
  const CycleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.period,
      child: AppScaffold(
        safeTop: true,
        body: ValueListenableBuilder(
          valueListenable: PeriodService.listenToDays(),
          builder: (context, _, _) => _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final cycles = PeriodService.getCycles().reversed.toList();
    final stats = PeriodService.getStats();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Symbols.arrow_back_rounded, size: 18),
              color: ext.textPrimary,
            ),
            Expanded(child: Text('Cycle history', style: tt.headlineMedium)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        CycleStatsCard(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Detected cycles',
          icon: Symbols.history_rounded,
          accent: ext.period,
        ),
        if (cycles.isEmpty)
          EmptyState(
            icon: Symbols.timeline_rounded,
            accent: ext.period,
            title: 'No cycles yet',
            message:
                'Once you log a couple of periods, each detected cycle will '
                'appear here with its length.',
          )
        else
          ...cycles.map((c) => _cycleTile(context, c)),
        const SizedBox(height: AppSpacing.xl),
        const SafetyDisclaimerBar(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _cycleTile(BuildContext context, MenstrualCycle c) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final range = c.endDate != null
        ? '${fmtPeriodShort(c.startDate)} – ${fmtPeriodShort(c.endDate!)}'
        : 'Since ${fmtPeriodShort(c.startDate)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: ext.period.container, borderRadius: AppRadius.brMd),
              child: Icon(Symbols.water_drop_rounded,
                  color: ext.period.onContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtPeriodDate(c.startDate),
                      style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
                  const SizedBox(height: 2),
                  Text(range,
                      style:
                          tt.bodySmall?.copyWith(color: ext.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  c.cycleLengthDays != null ? '${c.cycleLengthDays}d' : 'Open',
                  style: tt.titleMedium?.copyWith(
                      color: c.cycleLengthDays != null
                          ? ext.mark(ext.period)
                          : ext.textTertiary,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  'period ${c.periodLengthDays}d',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
