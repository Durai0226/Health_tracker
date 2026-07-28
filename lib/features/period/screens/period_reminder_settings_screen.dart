import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/period_reminder_config.dart';
import '../models/period_settings.dart';
import '../services/period_reminder_service.dart';
import '../services/period_service.dart';

/// Opt-in, discreet period reminders. Every change persists instantly and
/// re-arms the notifications via [PeriodReminderService.saveConfig].
class PeriodReminderSettingsScreen extends StatefulWidget {
  const PeriodReminderSettingsScreen({super.key});

  @override
  State<PeriodReminderSettingsScreen> createState() =>
      _PeriodReminderSettingsScreenState();
}

class _PeriodReminderSettingsScreenState
    extends State<PeriodReminderSettingsScreen> {
  PeriodReminderConfig _cfg = PeriodReminderService.getConfig();

  bool get _isTtc =>
      PeriodService.getSettings().trackingMode == TrackingMode.ttc;

  Future<void> _update(PeriodReminderConfig next) async {
    setState(() => _cfg = next);
    await PeriodReminderService.saveConfig(next); // persists + reschedules
  }

  String _plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

  Future<void> _pickTime() async {
    final acc = AppColorsExt.of(context).period;
    final picked = await AppTimePicker.show(
      context,
      initial: TimeOfDay(hour: _cfg.reminderHour, minute: _cfg.reminderMinute),
      accent: acc,
      minuteInterval: 5,
      title: 'Reminder time',
    );
    if (picked != null) {
      await _update(_cfg.copyWith(
          reminderHour: picked.hour, reminderMinute: picked.minute));
    }
  }

  Future<void> _pickDaysBefore() async {
    final acc = AppColorsExt.of(context).period;
    final picked = await AppBottomSheet.show<int>(
      context,
      title: 'Days before',
      icon: Symbols.date_range_rounded,
      accent: acc,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in const [1, 2, 3, 4, 5])
            AppListTile(
              icon: _cfg.daysBefore == o
                  ? Symbols.radio_button_checked_rounded
                  : Symbols.radio_button_unchecked_rounded,
              title: '${_plural(o, 'day')} before',
              onTap: () => Navigator.pop(context, o),
            ),
        ],
      ),
    );
    if (picked != null) await _update(_cfg.copyWith(daysBefore: picked));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final acc = ext.period;
    final time = TimeOfDay(hour: _cfg.reminderHour, minute: _cfg.reminderMinute);

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Period reminders',
            accent: acc,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: acc,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xl),
              children: [
                SettingsSection(
                  title: 'Reminders',
                  children: [
                    SettingsTile(
                      icon: Symbols.event_upcoming_rounded,
                      accent: acc,
                      title: 'Cycle coming up',
                      subtitle:
                          'A heads-up ~${_plural(_cfg.daysBefore, 'day')} before your predicted start',
                      switchValue: _cfg.periodSoonEnabled,
                      onSwitchChanged: (v) =>
                          _update(_cfg.copyWith(periodSoonEnabled: v)),
                    ),
                    if (_cfg.periodSoonEnabled)
                      SettingsTile(
                        icon: Symbols.date_range_rounded,
                        accent: acc,
                        title: 'Days before',
                        value: '${_cfg.daysBefore}',
                        onTap: _pickDaysBefore,
                      ),
                    SettingsTile(
                      icon: Symbols.self_improvement_rounded,
                      accent: acc,
                      title: 'PMS heads-up',
                      subtitle:
                          'A gentle note ~${_plural(_cfg.pmsDaysBefore, 'day')} before',
                      switchValue: _cfg.pmsEnabled,
                      onSwitchChanged: (v) =>
                          _update(_cfg.copyWith(pmsEnabled: v)),
                    ),
                    SettingsTile(
                      icon: Symbols.edit_calendar_rounded,
                      accent: acc,
                      title: 'Time to log',
                      subtitle:
                          'A nudge on your predicted start — logging sharpens future predictions',
                      switchValue: _cfg.logReminderEnabled,
                      onSwitchChanged: (v) =>
                          _update(_cfg.copyWith(logReminderEnabled: v)),
                    ),
                    if (_isTtc)
                      SettingsTile(
                        icon: Symbols.spa_rounded,
                        accent: acc,
                        title: 'Fertile window',
                        subtitle: 'An estimate — not medical advice',
                        switchValue: _cfg.fertileEnabled,
                        onSwitchChanged: (v) =>
                            _update(_cfg.copyWith(fertileEnabled: v)),
                      ),
                  ],
                ),
                SettingsSection(
                  title: 'Timing',
                  footer:
                      'Reminders are private and gently worded, and update automatically as your predictions change. They only appear once you’ve logged enough to predict a cycle.',
                  children: [
                    SettingsTile(
                      icon: Symbols.schedule_rounded,
                      accent: acc,
                      title: 'Reminder time',
                      value: time.format(context),
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
