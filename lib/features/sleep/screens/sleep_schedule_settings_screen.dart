import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_schedule.dart';
import '../services/sleep_service.dart';

/// Edit the nightly sleep schedule: target duration, bedtime, wake time,
/// wind-down lead, and a (placeholder) bedtime-reminder toggle. Changes persist
/// immediately to the shared health profile.
class SleepScheduleSettingsScreen extends StatefulWidget {
  const SleepScheduleSettingsScreen({super.key});

  @override
  State<SleepScheduleSettingsScreen> createState() =>
      _SleepScheduleSettingsScreenState();
}

class _SleepScheduleSettingsScreenState
    extends State<SleepScheduleSettingsScreen> {
  late SleepSchedule _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = SleepService.getSchedule();
  }

  void _update(SleepSchedule next) {
    setState(() => _schedule = next);
    // Fire-and-forget persist (the service holds the canonical copy).
    SleepService.saveSchedule(next);
    // Keep the daily wind-down reminder + wake alarm in sync with the schedule.
    NotificationService().scheduleBedtimeReminder(
      enabled: next.reminderEnabled,
      minuteOfDay: next.reminderMinuteOfDay,
    );
    NotificationService().scheduleWakeAlarm(
      enabled: next.alarmEnabled,
      hour: next.wakeHour,
      minute: next.wakeMinute,
    );
  }

  String _reminderSubtitle(BuildContext context) {
    if (!_schedule.reminderEnabled) {
      return 'A gentle nudge a little before bedtime';
    }
    final m = _schedule.reminderMinuteOfDay;
    final t = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    return 'At ${t.format(context)} · ${_schedule.windDownMinutes}m before bed';
  }

  Future<void> _pickBedtime() async {
    final picked =
        await AppTimePicker.show(context, initial: _schedule.bedtime);
    if (picked != null) {
      _update(_schedule.copyWith(
          bedtimeHour: picked.hour, bedtimeMinute: picked.minute));
    }
  }

  Future<void> _pickWake() async {
    final picked =
        await AppTimePicker.show(context, initial: _schedule.wake);
    if (picked != null) {
      _update(_schedule.copyWith(
          wakeHour: picked.hour, wakeMinute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final sleep = ext.sleep;

    return AccentScope(
      feature: FeatureAccent.sleep,
      child: AppScaffold(
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            AppHeader(
              title: 'Sleep schedule',
              icon: Symbols.tune_rounded,
              accent: sleep,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                tooltip: 'Back',
                accent: sleep,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _StepperRow(
                          icon: Symbols.timelapse_rounded,
                          title: 'Sleep target',
                          subtitle: 'Nightly goal',
                          valueLabel: _schedule.targetLabel,
                          onMinus: _schedule.targetMinutes > 240
                              ? () => _update(_schedule.copyWith(
                                  targetMinutes: _schedule.targetMinutes - 15))
                              : null,
                          onPlus: _schedule.targetMinutes < 720
                              ? () => _update(_schedule.copyWith(
                                  targetMinutes: _schedule.targetMinutes + 15))
                              : null,
                        ),
                        Divider(height: 1, color: ext.outline),
                        _StepperRow(
                          icon: Symbols.self_improvement_rounded,
                          title: 'Wind-down',
                          subtitle: 'Lead time before bed',
                          valueLabel: '${_schedule.windDownMinutes}m',
                          onMinus: _schedule.windDownMinutes > 0
                              ? () => _update(_schedule.copyWith(
                                  windDownMinutes:
                                      _schedule.windDownMinutes - 5))
                              : null,
                          onPlus: _schedule.windDownMinutes < 90
                              ? () => _update(_schedule.copyWith(
                                  windDownMinutes:
                                      _schedule.windDownMinutes + 5))
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        AppListTile(
                          icon: Symbols.bedtime_rounded,
                          title: 'Bedtime',
                          accent: sleep,
                          trailing: _timeValue(context, _schedule.bedtime),
                          onTap: _pickBedtime,
                        ),
                        Divider(height: 1, color: ext.outline),
                        AppListTile(
                          icon: Symbols.wb_sunny_rounded,
                          title: 'Wake time',
                          accent: sleep,
                          trailing: _timeValue(context, _schedule.wake),
                          onTap: _pickWake,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppListTile(
                      icon: Symbols.notifications_active_rounded,
                      title: 'Bedtime reminder',
                      subtitle: _reminderSubtitle(context),
                      accent: sleep,
                      trailing: AppSwitch(
                        value: _schedule.reminderEnabled,
                        onChanged: (v) =>
                            _update(_schedule.copyWith(reminderEnabled: v)),
                        accent: sleep,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppListTile(
                      icon: Symbols.alarm_rounded,
                      title: 'Wake alarm',
                      subtitle: _schedule.alarmEnabled
                          ? 'Rings at ${_schedule.wake.format(context)}'
                          : 'A daily alarm at your wake time',
                      accent: sleep,
                      trailing: AppSwitch(
                        value: _schedule.alarmEnabled,
                        onChanged: (v) =>
                            _update(_schedule.copyWith(alarmEnabled: v)),
                        accent: sleep,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    child: Text(
                      _formatWindow(_schedule),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: ext.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeValue(BuildContext context, TimeOfDay t) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.format(context),
            style: tt.titleMedium?.copyWith(color: ext.mark(ext.sleep))),
        const SizedBox(width: 4),
        Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
      ],
    );
  }

  static String _formatWindow(SleepSchedule s) {
    final inBed = s.scheduledInBedMinutes;
    final h = inBed ~/ 60;
    final m = inBed % 60;
    final dur = m == 0 ? '${h}h' : '${h}h ${m}m';
    return 'This schedule allows $dur in bed.';
  }
}

/// A settings row with a −/value/+ stepper on the right.
class _StepperRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String valueLabel;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _StepperRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.valueLabel,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final sleep = ext.sleep;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sleep.base.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 20, color: sleep.onContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: tt.bodyMedium
                          ?.copyWith(color: ext.textSecondary)),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: Symbols.remove_rounded,
            size: 36,
            accent: sleep,
            onPressed: onMinus,
          ),
          SizedBox(
            width: 64,
            child: Text(
              valueLabel,
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: kTabular,
              ),
            ),
          ),
          AppIconButton(
            icon: Symbols.add_rounded,
            size: 36,
            accent: sleep,
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}
