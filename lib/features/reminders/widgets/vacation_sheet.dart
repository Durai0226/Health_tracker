import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/vacation_periods.dart';
import '../../../core/services/reminder_reschedule_service.dart';
import '../../../core/services/vacation_mode.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Start or end vacation mode.
///
/// Starting it pauses everyday reminders and freezes the water, steps, focus and
/// reminder streaks. It leaves medicines alone — said on the sheet, because
/// "I'm away" is exactly when someone might assume everything has been paused.
class VacationSheet {
  const VacationSheet._();

  /// Resolves `true` when vacation mode was started or ended.
  static Future<bool> show(BuildContext context) async {
    final changed = await AppBottomSheet.show<bool>(
      context,
      title: 'Vacation mode',
      icon: Symbols.beach_access_rounded,
      accent: AppColorsExt.of(context).reminders,
      builder: (ctx) => VacationSheetBody(
        onDone: (changed) => Navigator.of(ctx).pop(changed),
      ),
    );
    return changed == true;
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class VacationSheetBody extends StatelessWidget {
  const VacationSheetBody({super.key, required this.onDone, this.reArm});

  final ValueChanged<bool> onDone;

  /// Re-arms generic reminders after the mode changes. Injected so a test does
  /// not reach for the notification platform; the real one is the default.
  final Future<void> Function()? reArm;

  static Future<void> _defaultReArm() async {
    await ReminderRescheduleService.rescheduleGenericReminders();
  }

  Future<void> _start(DateTime until) async {
    await VacationMode.start(until: until);
    await (reArm ?? _defaultReArm)();
    onDone(true);
  }

  Future<void> _end() async {
    await VacationMode.endNow();
    await (reArm ?? _defaultReArm)();
    onDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final active = VacationMode.active();
    final today = clock.now();

    DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n - 1);

    Widget option(String label, DateTime until) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () => _start(until),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
              ),
              Text('to ${DateFormats.dayMonth.format(until)}',
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            ]),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pauses your everyday reminders and freezes your water, steps, focus '
          'and reminder streaks while you are away. Medicine reminders and '
          'medicine streaks are not touched.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (active != null) ...[
          Text('On vacation until ${DateFormats.dayMonthYear.format(active.end)}.',
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'End vacation now',
            fullWidth: true,
            onPressed: _end,
          ),
        ] else ...[
          option('3 days', inDays(3)),
          option('1 week', inDays(7)),
          option('2 weeks', inDays(14)),
          AppButton(
            label: 'Choose the last day',
            variant: AppButtonVariant.tonal,
            fullWidth: true,
            onPressed: () async {
              final picked = await AppDatePicker.show(
                context,
                initial: inDays(7),
                first: DateTime(today.year, today.month, today.day),
                last: DateTime(today.year + 1, today.month, today.day),
                accent: ext.reminders,
                title: 'Back on',
              );
              if (picked != null) await _start(picked);
            },
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Close',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: () => onDone(false),
        ),
      ],
    );
  }
}

/// "On vacation until 20 Mar" with the one action that matters. Renders nothing
/// when vacation mode is off.
class VacationBanner extends StatelessWidget {
  const VacationBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final VacationPeriod? p = VacationMode.active();
    if (p == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.xs, AppSpacing.gutter, AppSpacing.xs),
      child: AppCard(
        onTap: onTap,
        child: Row(children: [
          Icon(Symbols.beach_access_rounded, color: ext.mark(ext.reminders)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('On vacation until ${DateFormats.dayMonth.format(p.end)}',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
                Text('Reminders paused · streaks frozen · medicines unaffected',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
        ]),
      ),
    );
  }
}
