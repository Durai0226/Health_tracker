import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/design/app_colors_ext.dart';
import '../../../core/design/app_design.dart';
import '../../../core/health/sleep_score.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/sleep_session.dart';
import '../models/sleep_stage.dart';
import '../services/sleep_service.dart';

/// What a night's sleep score is made of: "Duration 52/60 · Efficiency 21/25 ·
/// Regularity 9/15", with a line on each saying what it measured.
class SleepScoreBreakdownSheet {
  const SleepScoreBreakdownSheet._();

  static Future<void> show(BuildContext context, SleepSession night) {
    return AppBottomSheet.show<void>(
      context,
      title: 'How this score is made',
      icon: Symbols.bedtime_rounded,
      accent: AppColorsExt.of(context).sleep,
      builder: (_) => SleepScoreBreakdownBody(
        night: night,
        parts: SleepService.scoreParts(night),
        targetMinutes: SleepService.getSchedule().targetMinutes,
        regularityNights: SleepService.regularitySampleSize(),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a service.
class SleepScoreBreakdownBody extends StatelessWidget {
  const SleepScoreBreakdownBody({
    super.key,
    required this.night,
    required this.parts,
    required this.targetMinutes,
    required this.regularityNights,
  });

  final SleepSession night;
  final SleepScoreParts parts;
  final int targetMinutes;

  /// How many recent nights feed the regularity part; under 3 it is a neutral
  /// placeholder rather than a measurement.
  final int regularityNights;

  static String _hm(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final target = targetMinutes <= 0 ? 480 : targetMinutes;
    final estimated = night.source == SleepSource.manual;

    Widget row(String name, int points, int max, String detail) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Semantics(
            label: '$name: $points out of $max points. $detail',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        style: tt.titleSmall?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                  ),
                  Text('$points/$max',
                      style: tt.titleSmall?.copyWith(
                          color: ext.textPrimary, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: AppRadius.brFull,
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : points / max,
                    minHeight: 6,
                    backgroundColor: ext.surfaceVariant,
                    color: ext.chartMark(ext.sleep),
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${parts.total} out of 100',
            style: tt.headlineSmall?.copyWith(
                color: ext.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.md),
        row(
          'Duration',
          parts.duration,
          SleepScore.maxDuration,
          '${_hm(night.asleepMinutes)} asleep of your ${_hm(target)} target.',
        ),
        row(
          'Efficiency',
          parts.efficiency,
          SleepScore.maxEfficiency,
          estimated
              ? '${night.efficiencyPercent}% of your time in bed asleep, '
                  'estimated from how you rated the night.'
              : '${night.efficiencyPercent}% of your time in bed was spent asleep.',
        ),
        row(
          'Regularity',
          parts.regularity,
          SleepScore.maxRegularity,
          regularityNights < 3
              ? 'How steady your bedtime is. It needs three nights to measure; '
                  'until then it counts as average.'
              : 'How steady your bedtime has been over your last '
                  '$regularityNights nights.',
        ),
      ],
    );
  }
}
