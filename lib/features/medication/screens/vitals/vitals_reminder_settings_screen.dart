import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/widgets/app/app_widgets.dart';
import '../../services/vitals_reminder_service.dart';

/// A clear, labeled home for the blood-pressure & blood-sugar "time to measure"
/// reminders — the same daily nudges the vitals screens' header button sets,
/// now discoverable from Settings / the Reminders hub. Instant-apply via
/// [VitalsReminderService] (one shared source of truth).
class VitalsReminderSettingsScreen extends StatefulWidget {
  const VitalsReminderSettingsScreen({super.key});

  @override
  State<VitalsReminderSettingsScreen> createState() =>
      _VitalsReminderSettingsScreenState();
}

class _VitalsReminderSettingsScreenState
    extends State<VitalsReminderSettingsScreen> {
  Future<void> _toggle(VitalsReminderSpec s, bool v) async {
    await VitalsReminderService.apply(s, enabled: v);
    if (mounted) setState(() {});
  }

  Future<void> _pickTime(VitalsReminderSpec s, AccentSwatch acc) async {
    final picked = await AppTimePicker.show(
      context,
      initial: VitalsReminderService.timeOf(s),
      accent: acc,
      minuteInterval: 5,
      title: 'Reminder time',
    );
    if (picked != null) {
      await VitalsReminderService.apply(s,
          enabled: true, hour: picked.hour, minute: picked.minute);
      if (mounted) setState(() {});
    }
  }

  List<Widget> _rows(
    VitalsReminderSpec s, {
    required IconData icon,
    required String title,
    required AccentSwatch acc,
  }) {
    final on = VitalsReminderService.isEnabled(s);
    return [
      SettingsTile(
        icon: icon,
        accent: acc,
        title: title,
        subtitle: 'A daily nudge to measure & log a reading',
        switchValue: on,
        onSwitchChanged: (v) => _toggle(s, v),
      ),
      if (on)
        SettingsTile(
          icon: Symbols.schedule_rounded,
          accent: acc,
          title: 'Reminder time',
          value: VitalsReminderService.timeOf(s).format(context),
          onTap: () => _pickTime(s, acc),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final acc = ext.medicine;
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Vitals reminders',
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
                  title: 'Measurement reminders',
                  footer:
                      'A gentle daily reminder to take and log a reading, so your trends stay complete. Respects your notification settings.',
                  children: [
                    ..._rows(VitalsReminderService.bp,
                        icon: Symbols.favorite_rounded,
                        title: 'Blood pressure',
                        acc: acc),
                    ..._rows(VitalsReminderService.glucose,
                        icon: Symbols.bloodtype_rounded,
                        title: 'Blood sugar',
                        acc: acc),
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
