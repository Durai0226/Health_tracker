import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_consistency.dart';

/// The Sleep hero metric: bedtime **consistency** framed as "your rhythm".
///
/// Without a wearable we can't win on measurement accuracy, so we lead with the
/// one thing a manual logger genuinely controls — a steady bedtime. This is
/// deliberately qualitative (never a naked % or "poor"), colour-capped so the
/// worst reading is a calm "Variable", and shows an honest "building" state
/// until there are enough logged nights to say anything real.
class SleepConsistencyCard extends StatelessWidget {
  final SleepConsistency consistency;

  /// Raw regularity index 0..1 — only drives the meter fill when we have data.
  final double index;

  /// Nights logged in the last 7 (0..7) for the dot strip.
  final int nightsLoggedThisWeek;

  const SleepConsistencyCard({
    super.key,
    required this.consistency,
    required this.index,
    required this.nightsLoggedThisWeek,
  });

  AccentSwatch _accent(AppColorsExt ext) {
    switch (consistency) {
      case SleepConsistency.veryRegular:
        return ext.success;
      case SleepConsistency.fairlyRegular:
        return ext.sleep;
      case SleepConsistency.variable:
        return ext.warning; // softest downside — never error/red
      case SleepConsistency.building:
        return ext.sleep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = _accent(ext);
    final showMeter = consistency.hasEnoughData;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.schedule_rounded,
                    size: 20, color: accent.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR RHYTHM',
                      style: tt.labelSmall
                          ?.copyWith(color: ext.textTertiary, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      consistency.label,
                      style: tt.titleLarge?.copyWith(
                        color:
                            showMeter ? ext.mark(accent) : ext.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  WeekDotStrip(
                    filled: nightsLoggedThisWeek,
                    accent: ext.sleep,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$nightsLoggedThisWeek/7 logged',
                    style: tt.labelSmall?.copyWith(color: ext.textTertiary),
                  ),
                ],
              ),
            ],
          ),
          if (showMeter) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.brFull,
              child: Stack(
                children: [
                  Container(height: 8, color: ext.surfaceVariant),
                  FractionallySizedBox(
                    widthFactor: index.clamp(0.0, 1.0),
                    child: Container(height: 8, color: ext.mark(accent)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            consistency.why,
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }
}
