import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/services/haptic_service.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/features/focus/services/focus_reminder_scheduler.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
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
  bool _isLoading = true;

  /// Whether this device can store mindfulness sessions at all.
  ///
  /// Probed once and used to HIDE the row rather than disable it.
  /// `MindfulnessSessionRecord` is an experimental Health Connect API delivered
  /// by a Play System Update, so plenty of devices cannot — and a switch that
  /// cannot be switched on is worse than an absent one. Critically, the probe has
  /// to happen before the permission is ever requested: Health Connect refuses
  /// the WHOLE permission sheet if any requested type is unsupported, which would
  /// break the health permissions the app genuinely needs.
  bool _mindfulnessAvailable = false;
  bool _mindfulnessBusy = false;

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
      _isLoading = false;
    });
    // Re-evaluate on every visit, not only on a toggle. "At risk" is a fact about
    // today, so a nudge scheduled yesterday has to be re-decided rather than left
    // standing.
    await _applySchedule();
    final available = await MindfulnessChannel.instance.isAvailable();
    if (!mounted) return;
    setState(() => _mindfulnessAvailable = available);
  }

  /// Toggle mindfulness write-back.
  ///
  /// `setMindfulnessSync` re-checks the real OS grant, so a user who revoked the
  /// permission in the Health Connect app gets the switch bounced back off rather
  /// than left stuck on, silently writing nothing. The busy flag stops a double
  /// tap racing two permission checks.
  Future<void> _toggleMindfulness(bool value) async {
    if (_mindfulnessBusy) return;
    setState(() => _mindfulnessBusy = true);
    HapticService().toggle();
    await FocusService().setMindfulnessSync(value);
    if (!mounted) return;
    setState(() => _mindfulnessBusy = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focus_daily_reminder', _dailyReminder);
    await prefs.setString(
      'focus_reminder_time',
      '${_reminderTime.hour}:${_reminderTime.minute}',
    );
    await prefs.setBool('focus_streak_reminder', _streakReminder);
    await _applySchedule();
  }

  /// Make the switches mean something.
  ///
  /// Every toggle on this screen used to be write-only: three `setBool` calls and
  /// nothing else. `NotificationService` was not even imported, so
  /// *"Alert when your streak is at risk"* promised a notification the app had no
  /// code to send. A switch that does nothing is worse than an absent feature —
  /// the user believes they are covered.
  ///
  /// The scheduling itself lives in [FocusReminderScheduler] because a second
  /// caller needs it: the startup migration that takes these two ids off
  /// AlarmManager for installs that already had reminders switched on. It reads
  /// the same prefs [_persist] has just written, so this runs after that, never
  /// before.
  ///
  /// The streak nudge is re-decided on every visit and only while the streak is
  /// ACTUALLY at risk. That works because the streak can only be advanced by
  /// using the app: if a session was completed, the app was open, and this ran
  /// again. So the nudge is never sent to somebody who has already focused today.
  Future<void> _applySchedule() => FocusReminderScheduler.apply();

  void _update(VoidCallback change) {
    HapticService().toggle();
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
              leading: AppHeader.backButton(context),
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
                              title: 'Daily reminder',
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
                              title: 'Streak at risk',
                              accent: accent,
                              switchValue: _streakReminder,
                              onSwitchChanged: (v) =>
                                  _update(() => _streakReminder = v),
                            ),
                            // "Break reminder" used to sit here. It was removed
                            // rather than wired: it wrote a preference and
                            // scheduled nothing, and there is no correct thing
                            // for it to schedule. Breaks are a within-session
                            // concern, and Pomodoro mode already starts them
                            // automatically at the end of each work interval
                            // (`FocusService._startBreak`). A push notification
                            // telling somebody to take a break, sent at a fixed
                            // hour with no idea whether they are mid-session,
                            // would be noise — so the honest options were wire it
                            // correctly or drop it.
                          ],
                        ),
                        // Hidden, not disabled, when the platform cannot store
                        // mindfulness sessions. A switch that cannot be switched
                        // on is worse than an absent one — and the probe has to
                        // run BEFORE any permission request, because Health
                        // Connect refuses the whole sheet if one requested type
                        // is unsupported.
                        if (_mindfulnessAvailable)
                          SettingsSection(
                            title: 'Health Connect',
                            footer: 'Only breathing and meditation are written. '
                                'A work session is not a mindfulness session, so '
                                'it is never saved as one.',
                            children: [
                              SettingsTile(
                                icon: Symbols.self_improvement_rounded,
                                title: 'Save mindful minutes',
                                subtitle: 'Write completed breathing and '
                                    'meditation to Health Connect',
                                accent: accent,
                                switchValue: FocusService().mindfulnessSync,
                                onSwitchChanged:
                                    _mindfulnessBusy ? null : _toggleMindfulness,
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
