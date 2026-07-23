import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/cycle_prediction.dart';

const List<String> _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
];
const List<String> _kWeekdays = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' //
];

String fmtPeriodDate(DateTime d) =>
    '${_kWeekdays[d.weekday - 1]}, ${_kMonths[d.month - 1]} ${d.day}';

String fmtPeriodShort(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}';

/// The honest prediction summary: next period estimate + fertile-window estimate
/// + confidence, always carrying the "estimate, not for contraception" caveat.
class PredictionCard extends StatelessWidget {
  final CyclePrediction prediction;

  /// TTC mode emphasises the fertile window.
  final bool emphasizeFertile;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.emphasizeFertile = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final p = prediction;

    if (p.predictedStart == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Symbols.timeline_rounded, color: ext.mark(ext.period), size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Log a few more cycles and DailyMinder will estimate your next '
                'period and fertile window here.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final days = p.daysUntilNextPeriod ?? 0;
    final String countdown;
    if (p.state == CycleState.late) {
      countdown = '${days.abs()} day${days.abs() == 1 ? '' : 's'} late';
    } else if (days <= 0) {
      countdown = 'Due today';
    } else {
      countdown = 'in $days day${days == 1 ? '' : 's'}';
    }

    final periodAccent = ext.period;
    final fertileAccent = ext.reminders;

    final fertile = (p.fertileStart != null && p.fertileEnd != null)
        ? '${fmtPeriodShort(p.fertileStart!)} – ${fmtPeriodShort(p.fertileEnd!)}'
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PREDICTION',
                  style: tt.labelSmall
                      ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6)),
              const Spacer(),
              _ConfidenceMeter(confidence: p.confidence),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Next period hero.
          _MetricRow(
            icon: Symbols.water_drop_rounded,
            accent: periodAccent,
            label: 'Next period',
            value: fmtPeriodDate(p.predictedStart!),
            trailing: countdown,
            trailingColor: p.state == CycleState.late
                ? ext.mark(ext.warning)
                : ext.mark(periodAccent),
            emphasize: !emphasizeFertile,
          ),

          if (p.windowStart != null && p.windowEnd != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                'Likely ${fmtPeriodShort(p.windowStart!)} – ${fmtPeriodShort(p.windowEnd!)}',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
            ),
          ],

          if (fertile != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: ext.outline),
            const SizedBox(height: AppSpacing.md),
            _MetricRow(
              icon: Symbols.spa_rounded,
              accent: fertileAccent,
              label: 'Fertile window (estimate)',
              value: fertile,
              trailing: p.ovulationDay != null
                  ? 'Ovul. ${fmtPeriodShort(p.ovulationDay!)}'
                  : null,
              trailingColor: ext.mark(fertileAccent),
              emphasize: emphasizeFertile,
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          _CaveatBar(),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final AccentSwatch accent;
  final String label;
  final String value;
  final String? trailing;
  final Color? trailingColor;
  final bool emphasize;

  const _MetricRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    this.trailing,
    this.trailingColor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration:
              BoxDecoration(color: accent.container, borderRadius: AppRadius.brSm),
          child: Icon(icon, size: 16, color: accent.onContainer),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: (emphasize ? tt.headlineSmall : tt.titleLarge)?.copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            trailing!,
            textAlign: TextAlign.right,
            style: tt.labelLarge?.copyWith(
              color: trailingColor ?? ext.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Three bars filled by confidence level + label. Honest, glanceable.
class _ConfidenceMeter extends StatelessWidget {
  final PredictionConfidence confidence;
  const _ConfidenceMeter({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final filled = switch (confidence) {
      PredictionConfidence.low => 1,
      PredictionConfidence.medium => 2,
      PredictionConfidence.high => 3,
    };
    final color = switch (confidence) {
      PredictionConfidence.low => ext.mark(ext.warning),
      PredictionConfidence.medium => ext.mark(ext.info),
      PredictionConfidence.high => ext.mark(ext.success),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 4,
              height: 10 + i * 3,
              decoration: BoxDecoration(
                color: i < filled ? color : ext.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(confidence.label,
            style: tt.labelSmall?.copyWith(color: ext.textSecondary)),
      ],
    );
  }
}

/// The mandatory fertility caveat — styled like the shared SafetyDisclaimerBar
/// but with the cycle-specific "estimate, not for contraception" wording.
class _CaveatBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: ext.outline),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Symbols.shield_rounded, size: 14, color: ext.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'These are estimates from your logged data — not a diagnosis, '
                'and not reliable for contraception or conception.',
                style:
                    tt.bodySmall?.copyWith(color: ext.textTertiary, height: 1.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
