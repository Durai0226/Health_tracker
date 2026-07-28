import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../../focus/screens/settings/focus_reminders_settings_screen.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../period/screens/period_reminder_settings_screen.dart';
import '../../period/services/period_reminder_service.dart';
import '../../sleep/screens/sleep_schedule_settings_screen.dart';
import '../../steps/screens/steps_goal_settings_screen.dart';
import '../../water/screens/water_reminder_settings_screen.dart';

/// One place to find and manage every feature's reminders — so a user never has
/// to hunt through each feature's own settings to start getting nudged toward
/// their goals. Each row deep-links to that feature's own reminder settings.
class RemindersHubScreen extends StatelessWidget {
  const RemindersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final acc = ext.reminders;
    final periodOn = PeriodReminderService.getConfig().anyEnabled;

    void go(Widget dest) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => dest));

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Reminders',
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
                  title: 'Your reminders',
                  footer:
                      'Turn on gentle nudges for the things you want to stay on top of. Each one respects your notification settings.',
                  children: [
                    SettingsTile(
                      icon: Symbols.medication_rounded,
                      accent: ext.medicine,
                      title: 'Medicines',
                      subtitle: 'Dose alarms — set per medicine',
                      onTap: () => go(const NunitoMedicationDashboard()),
                    ),
                    SettingsTile(
                      icon: Symbols.water_drop_rounded,
                      accent: ext.water,
                      title: 'Water',
                      subtitle: 'Hydration reminders through the day',
                      onTap: () => go(const WaterReminderSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.bedtime_rounded,
                      accent: ext.sleep,
                      title: 'Sleep',
                      subtitle: 'Bedtime wind-down & wake alarm',
                      onTap: () => go(const SleepScheduleSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.directions_walk_rounded,
                      accent: ext.steps,
                      title: 'Steps',
                      subtitle: 'A nudge toward your daily goal',
                      onTap: () => go(const StepsGoalSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.self_improvement_rounded,
                      accent: ext.focus,
                      title: 'Focus',
                      subtitle: 'Reminders to start a focus session',
                      onTap: () => go(const FocusRemindersSettingsScreen()),
                    ),
                    SettingsTile(
                      icon: Symbols.calendar_month_rounded,
                      accent: ext.period,
                      title: 'Period',
                      subtitle: 'Cycle heads-ups & log nudges',
                      value: periodOn ? 'On' : 'Off',
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
