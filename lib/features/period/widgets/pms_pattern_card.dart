import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../services/pms_pattern.dart';
import 'prediction_card.dart' show fmtPeriodShort;

/// "Before your period: Cramps: usually from 3 days before (4 of 5 cycles)",
/// with when it is likely to start again, from the person's own log.
class PmsPatternCard extends StatelessWidget {
  const PmsPatternCard({super.key, required this.symptoms, this.nextPeriod});

  final List<PmsSymptom> symptoms;

  /// The predicted start of the next period, when there is one.
  final DateTime? nextPeriod;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // The earliest any of them tends to start, counted back from the prediction.
    DateTime? from;
    if (nextPeriod != null && symptoms.isNotEmpty) {
      final earliest = symptoms
          .map((s) => s.typicalDaysBefore)
          .reduce((a, b) => a > b ? a : b);
      from = DateTime(
          nextPeriod!.year, nextPeriod!.month, nextPeriod!.day - earliest);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: ext.period.container, borderRadius: AppRadius.brSm),
                child: Icon(Symbols.event_upcoming_rounded,
                    size: 16, color: ext.period.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Before your period',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final s in symptoms)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(s.line,
                  style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
            ),
          if (from != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Next, you may notice it from about ${fmtPeriodShort(from)}.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Worked out from the days you logged, not a diagnosis. The more '
              'days you log, the more this can say.',
              style:
                  tt.bodySmall?.copyWith(color: ext.textSecondary, height: 1.3)),
        ],
      ),
    );
  }
}
