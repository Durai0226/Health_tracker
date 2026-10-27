import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/overnight_body.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "2 of 5 overnight signals are outside your usual range", which ones, how far
/// the heart rate dropped, and — when it has been two nights — the offer to take
/// the day easy.
class OvernightBodyCard extends StatelessWidget {
  const OvernightBodyCard({
    super.key,
    required this.accent,
    this.check,
    this.dip,
    this.offerRest = false,
    this.restMarked = false,
    this.onRest,
    this.onUndoRest,
  });

  final AccentSwatch accent;
  final OvernightBodyCheck? check;
  final NightHeartDip? dip;

  /// Offer to mark today a rest day.
  final bool offerRest;

  /// Today is already marked, from this card.
  final bool restMarked;
  final VoidCallback? onRest;
  final VoidCallback? onUndoRest;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final c = check;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.monitor_heart_rounded, size: 18, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Overnight body check',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (c != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(c.headline,
                style: tt.bodyMedium?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w600)),
            for (final s in c.outsideSignals)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                    '${s.signal.label}: ${s.valueText} (${s.usualText}, '
                    '${s.status.name})',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              ),
          ],
          if (dip case final d?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(d.line, style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Compared with your own recent nights, not with anyone else. Wellness '
              'context, not a diagnosis.',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary, height: 1.3)),
          if (restMarked) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text('Today is marked as a rest day.',
                      style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
                ),
                TextButton(
                  onPressed: onUndoRest,
                  style: TextButton.styleFrom(
                      foregroundColor: ext.mark(accent),
                      minimumSize: const Size(0, 44)),
                  child: const Text('Undo'),
                ),
              ],
            ),
          ] else if (offerRest) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
                'That is two nights in a row. If you are feeling it too, a rest '
                'day pauses today\'s step goal and keeps your streak.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Take a rest day',
                leadingIcon: Symbols.hotel_rounded,
                accent: accent,
                onPressed: onRest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
