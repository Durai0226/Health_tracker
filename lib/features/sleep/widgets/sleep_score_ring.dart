import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/health/insight.dart' show InsightSeverity;
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

/// A [ProgressRing]-based 0–100 sleep score. The fill band colour comes from the
/// shared [InsightVisuals.severityColor] scale (good / info / attention / urgent)
/// so a good night reads green and a poor one reads amber/red — consistent with
/// every other insight surface. Carries an honest Measured / Estimated pill.
class SleepScoreRing extends StatelessWidget {
  final int score; // 0..100
  final bool measured;
  final double size;

  const SleepScoreRing({
    super.key,
    required this.score,
    this.measured = false,
    this.size = 128,
  });

  static InsightSeverity _band(int s) {
    if (s >= 85) return InsightSeverity.good;
    if (s >= 70) return InsightSeverity.info;
    if (s >= 50) return InsightSeverity.attention;
    return InsightSeverity.urgent;
  }

  static String _word(int s) {
    if (s <= 0) return 'No data';
    if (s >= 85) return 'Excellent';
    if (s >= 70) return 'Good';
    if (s >= 50) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final s = score.clamp(0, 100);
    final band = InsightVisuals.severityColor(ext, _band(s));
    final hasData = s > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          progress: s / 100,
          size: size,
          stroke: 10,
          accent: ext.sleep,
          fillColor: hasData ? band : ext.outline,
          trackColor: ext.sleep.container,
          animate: !MediaQuery.of(context).disableAnimations,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasData ? '$s' : '--',
                style: tt.displaySmall?.copyWith(
                  color: hasData ? ext.textPrimary : ext.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabular,
                  letterSpacing: -1,
                ),
              ),
              Text(
                _word(s).toUpperCase(),
                style: tt.labelSmall?.copyWith(
                  color: hasData ? band : ext.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _MeasurementPill(measured: measured),
      ],
    );
  }
}

/// The honest provenance chip beneath the ring.
class _MeasurementPill extends StatelessWidget {
  final bool measured;
  const _MeasurementPill({required this.measured});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final icon = measured ? Symbols.verified_rounded : Symbols.edit_note_rounded;
    // Confident, not apologetic: a manual score is honestly "from your log"
    // (timing + quality), not a guess to be embarrassed about.
    final label = measured ? 'Measured' : 'From your log';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ext.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: ext.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
