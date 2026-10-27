import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/sleep_session.dart';
import '../models/sleep_stage.dart';

/// One night a health app recorded, in full — read-only, and honest about it.
///
/// A night a device wrote is the device's to correct, so there is no edit here:
/// the sheet says where to change it. (A night the person logged by hand opens
/// the log form instead.)
class SleepNightDetailSheet {
  const SleepNightDetailSheet._();

  static Future<void> show(BuildContext context, SleepSession night) {
    return AppBottomSheet.show<void>(
      context,
      title: DateFormats.weekdayDayMonthShort.format(night.wakeTime),
      icon: Symbols.nightlight_round_rounded,
      accent: AppColorsExt.of(context).sleep,
      builder: (ctx) => SleepNightDetailBody(
        night: night,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class SleepNightDetailBody extends StatelessWidget {
  const SleepNightDetailBody({super.key, required this.night, required this.onClose});

  final SleepSession night;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final n = night;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            children: [
              Text(label, style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              Text(value,
                  style: tt.bodyMedium?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    final staged = n.lightMinutes != null || n.deepMinutes != null || n.remMinutes != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('In bed', '${DateFormats.time.format(n.bedtime)} – ${DateFormats.time.format(n.wakeTime)}'),
        row('Asleep', SleepSession.formatMinutes(n.asleepMinutes)),
        row('Time in bed', SleepSession.formatMinutes(n.inBedMinutes)),
        row('Efficiency', '${n.efficiencyPercent}%'),
        if (staged) ...[
          if (n.deepMinutes != null) row('Deep', SleepSession.formatMinutes(n.deepMinutes!)),
          if (n.remMinutes != null) row('REM', SleepSession.formatMinutes(n.remMinutes!)),
          if (n.lightMinutes != null) row('Light', SleepSession.formatMinutes(n.lightMinutes!)),
        ],
        if (n.sleepScore > 0) row('Score', '${n.sleepScore}'),
        row('Source', n.source.label),
        if (n.note != null && n.note!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(n.note!, style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'This night came from your health app. To change it, change it there.',
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Close',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: onClose,
        ),
      ],
    );
  }
}
