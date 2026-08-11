import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/widgets/app/app_pickers.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Focus reminder settings.
///
/// Rebuilt on the modern design system. The previous version pinned
/// `Color(0xFFF5F5F5)` as the scaffold background and `Colors.white` on every
/// card, so the whole screen stayed light regardless of theme — a blinding
/// white sheet in dark mode. Settings now persist on change (matching the
/// other settings screens) instead of requiring an explicit Save that silently
/// discarded edits when the user backed out.
class FocusRemindersSettingsScreen extends StatefulWidget {
  const FocusRemindersSettingsScreen({super.key});

  @override
  State<FocusRemindersSettingsScreen> createState() =>
      _FocusRemindersSettingsScreenState();
}

class _FocusRemindersSettingsScreenState
    extends State<FocusRemindersSettingsScreen> {
  bool _dailyReminder = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _streakReminder = true;
  bool _breakReminder = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyReminder = prefs.getBool('focus_daily_reminder') ?? true;
      final timeStr = prefs.getString('focus_reminder_time') ?? '9:0';
      final parts = timeStr.split(':');
      _reminderTime = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 9,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
      _streakReminder = prefs.getBool('focus_streak_reminder') ?? true;
      _breakReminder = prefs.getBool('focus_break_reminder') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focus_daily_reminder', _dailyReminder);
    await prefs.setString(
      'focus_reminder_time',
      '${_reminderTime.hour}:${_reminderTime.minute}',
    );
    await prefs.setBool('focus_streak_reminder', _streakReminder);
    await prefs.setBool('focus_break_reminder', _breakReminder);
  }

  void _update(VoidCallback change) {
    HapticFeedback.lightImpact();
    setState(change);
    _persist();
  }

  Future<void> _selectTime() async {
    final picked = await AppTimePicker.show(context, initial: _reminderTime);
    if (picked != null) {
      _update(() => _reminderTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.focus;

    return AccentScope(
      feature: FeatureAccent.focus,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Focus reminders',
              icon: Symbols.notifications_rounded,
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: ext.mark(accent)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: [
                        SettingsSection(
                          title: 'Daily',
                          footer: 'Changes are saved automatically.',
                          children: [
                            SettingsTile(
                              icon: Symbols.notifications_rounded,
                              title: 'Daily focus reminder',
                              subtitle: 'Get reminded to focus each day',
                              accent: accent,
                              switchValue: _dailyReminder,
                              onSwitchChanged: (v) =>
                                  _update(() => _dailyReminder = v),
                            ),
                            if (_dailyReminder)
                              SettingsTile(
                                icon: Symbols.access_time_rounded,
                                title: 'Reminder time',
                                value: _reminderTime.format(context),
                                accent: accent,
                                onTap: _selectTime,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SettingsSection(
                          title: 'Nudges',
                          children: [
                            SettingsTile(
                              icon: Symbols.local_fire_department_rounded,
                              title: 'Streak reminder',
                              subtitle: 'Alert when your streak is at risk',
                              accent: accent,
                              switchValue: _streakReminder,
                              onSwitchChanged: (v) =>
                                  _update(() => _streakReminder = v),
                            ),
                            SettingsTile(
                              icon: Symbols.coffee_rounded,
                              title: 'Break reminder',
                              subtitle: 'Remind me to take breaks',
                              accent: accent,
                              switchValue: _breakReminder,
                              onSwitchChanged: (v) =>
                                  _update(() => _breakReminder = v),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
