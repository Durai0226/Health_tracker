import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../services/temperature_shift.dart';
import 'prediction_card.dart' show fmtPeriodShort;

/// "Your temperature rose on day 16 and stayed up: ovulation likely around
/// day 15", from the person's own temperature log. Looks back — a shift is only
/// visible three days after it begins — and says it is an estimate.
class TemperatureShiftCard extends StatelessWidget {
  const TemperatureShiftCard({
    super.key,
    required this.latest,
    this.earlier = const [],
  });

  /// The most recent shift found.
  final TemperatureShift latest;

  /// Shifts from the cycles before it, oldest first.
  final List<TemperatureShift> earlier;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    final days = [for (final s in earlier) s.ovulationCycleDay];
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
                child: Icon(Symbols.device_thermostat_rounded,
                    size: 16, color: ext.period.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Temperature shift',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Your temperature rose on day ${latest.riseCycleDay} '
              '(${fmtPeriodShort(latest.firstHighDay)}) and stayed up for three '
              'days: ovulation was likely around day ${latest.ovulationCycleDay} '
              '(${fmtPeriodShort(latest.ovulationDay)}).',
              style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
          if (days.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('In earlier cycles with a shift, ovulation was around day '
                '${days.join(', ')}.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
              'An estimate from your own readings. Illness, alcohol and a short '
              'night can all move your temperature, and it only shows after '
              'ovulation has happened, so it is not a basis for contraception.',
              style:
                  tt.bodySmall?.copyWith(color: ext.textSecondary, height: 1.3)),
        ],
      ),
    );
  }
}
