import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../focus/screens/settings/focus_reminders_settings_screen.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../medication/screens/vitals/vitals_reminder_settings_screen.dart';
import '../../medication/services/vitals_reminder_service.dart';
import '../../period/screens/period_reminder_settings_screen.dart';
import '../../period/services/period_reminder_service.dart';
import '../../sleep/screens/sleep_schedule_settings_screen.dart';
import '../../steps/screens/steps_goal_settings_screen.dart';
import '../../water/screens/water_reminder_settings_screen.dart';
import '../../reminders/screens/reminders_screen.dart';

/// One place to find and manage every feature's reminders — so a user never has
/// to hunt through each feature's own settings to start getting nudged toward
/// their goals. Each row deep-links to that feature's own reminder settings.
class RemindersHubScreen extends StatelessWidget {
  const RemindersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The status line for a vitals row: the time it fires, or "Off".
    //
    // `VitalsReminderService.timeOf` is a synchronous static and this file
    // already imported the service — it was just never called. The screen was
    // spending its subtitle on "A daily nudge to measure & log", which is a
    // gloss on the title, and its trailing on a cramped "On", while the one
    // fact a reminder row exists to report sat one function call away.
    String vitalsStatus(VitalsReminderSpec spec) =>
        VitalsReminderService.isEnabled(spec)
            ? 'Daily at ${VitalsReminderService.timeOf(spec).format(context)}'
            : 'Off';

    // Same shape for Period. `getConfig()` was already being called here and
    // the object thrown away after reading one bool off it.
    final period = PeriodReminderService.getConfig();
    final periodStatus = period.anyEnabled
        ? 'Daily at ${TimeOfDay(hour: period.reminderHour, minute: period.reminderMinute).format(context)}'
        : 'Off';

    void go(Widget dest) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => dest));

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Reminders',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xl),
              children: [
                SettingsSection(
                  title: 'Your reminders',
                  footer: 'Each one respects your notification settings.',
                  children: [
                    // Your own reminders come first: this hub listed ten
                    // per-feature families and not the one the user creates
                    // themselves, so the generic reminders screen was reachable
                    // only from the Today dashboard card.
                    SettingsTile(
                      icon: Symbols.notifications_active_rounded,
                      title: 'Your own reminders',
                      subtitle: 'Ones you set yourself',
                      onTap: () => go(const RemindersScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.medication_rounded,
                      title: 'Medicines',
                      subtitle: 'Set per medicine',
                      onTap: () => go(const NunitoMedicationDashboard()),
                    ),
                    SettingsTile(
                      icon: Symbols.water_drop_rounded,
                      title: 'Water',
                      subtitle: 'Through the day',
                      onTap: () => go(const WaterReminderSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.bedtime_rounded,
                      title: 'Sleep',
                      subtitle: 'Bedtime & wake alarm',
                      onTap: () => go(const SleepScheduleSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.directions_walk_rounded,
                      title: 'Steps',
                      subtitle: 'A nudge toward your goal',
                      onTap: () => go(const StepsGoalSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.favorite_rounded,
                      title: 'Blood pressure',
                      subtitle: vitalsStatus(VitalsReminderService.bp),
                      onTap: () => go(const VitalsReminderSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.bloodtype_rounded,
                      title: 'Blood sugar',
                      subtitle: vitalsStatus(VitalsReminderService.glucose),
                      onTap: () => go(const VitalsReminderSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.monitor_weight_rounded,
                      title: 'Weight',
                      subtitle: vitalsStatus(VitalsReminderService.weight),
                      onTap: () => go(const VitalsReminderSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.mood_rounded,
                      title: 'Mood',
                      subtitle: vitalsStatus(VitalsReminderService.mood),
                      onTap: () => go(const VitalsReminderSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.self_improvement_rounded,
                      title: 'Focus',
                      subtitle: 'To start a session',
                      onTap: () => go(const FocusRemindersSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.calendar_month_rounded,
                      title: 'Period',
                      subtitle: periodStatus,
                      onTap: () => go(const PeriodReminderSettingsScreen()),
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
