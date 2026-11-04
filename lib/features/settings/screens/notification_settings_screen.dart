import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/background_alarm_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/daily_check_in.dart';
import '../../../core/services/reminder_reschedule_service.dart';
import '../../../core/models/user_settings.dart';
import '../../../core/health/quiet_window.dart';
import '../../reminders/services/quiet_hours.dart';
import '../../sleep/services/sleep_service.dart';

/// Notifications settings — an Apple-tier, instant-apply grouped-settings list.
/// Calm Clarity: one interactive color (brand teal), a neutral chrome bed, and
/// amber reserved for the single semantic permission warning. Every toggle /
/// duration persists immediately (no Save button); a quiet "Saved" affordance
/// fades in the header.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  /// Arms every reminder again. Stands apart so a test can watch for it instead of
  /// running the whole app's scheduling.
  @visibleForTesting
  static Future<void> Function() rearmReminders =
      ReminderRescheduleService.rearmReminders;

  /// Opens this app's page in the phone's settings, where each kind of reminder
  /// has its own sound. Stands apart because it leaves the app.
  @visibleForTesting
  static Future<bool> Function() openPhoneSettings = openAppSettings;

  /// Whether the phone lets a person pick a notification's sound per category.
  /// Android does; an iPhone offers only on/off, which Sound above already is.
  static bool get _canPickSoundInPhoneSettings =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Whether [after] differs from [before] in how an alert presents itself.
  ///
  /// Vibration, Keep on screen, Full-screen alerts, Show on lock screen and Sound are
  /// fixed into a scheduled notification when it is armed — the channel and the flags
  /// travel with it — so one already waiting keeps the old look until something arms
  /// it again. The lock screen is the one that matters most: a reminder armed while
  /// its text was allowed there ("Take sertraline") went on showing it after the
  /// person had turned that off.
  @visibleForTesting
  static bool alertLookChanged(UserSettings before, UserSettings after) =>
      before.vibrationEnabled != after.vibrationEnabled ||
      before.persistentNotification != after.persistentNotification ||
      before.fullScreenNotification != after.fullScreenNotification ||
      before.showOnLockScreen != after.showOnLockScreen ||
      before.soundEnabled != after.soundEnabled;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Settings state
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showOnLockScreen = true;
  bool _persistentNotification = true;
  bool _fullScreenNotification = true;
  bool _snoozeEnabled = true;
  int _snoozeMinutes = 5;
  int _maxSnoozes = 3;
  bool _autoMarkMissed = true;
  int _missedMinutes = 60;
  int _alarmDurationSeconds = 30;
  String _notificationSound = 'default';

  // The daily check-in: applied the moment it is changed, not behind the
  // debounce the rest of this screen uses — it arms or withdraws a notification.
  bool _checkInEnabled = false;
  TimeOfDay _checkInTime = DailyCheckIn.defaultTime;
  bool _checkInBusy = false;

  // Quiet hours: applied the moment they change, like the check-in, because
  // reminders already armed inside the window have to move.
  bool _quietOn = false;
  QuietWindow _quietWindow = const QuietWindow(
      startMinute: QuietHours.defaultStartMinute,
      endMinute: QuietHours.defaultEndMinute);
  bool _quietBusy = false;

  // UI state
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _showSaved = false;

  Timer? _debounce;
  Timer? _savedTimer;

  static const List<int> _snoozeOptions = [1, 5, 10, 15, 30];
  static const List<int> _maxSnoozeOptions = [1, 2, 3, 5];
  static const List<int> _missedOptions = [30, 60, 120, 240];
  static const List<int> _alarmOptions = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _savedTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      // Small delay to prevent UI blocking
      await Future.delayed(const Duration(milliseconds: 100));

      final settings = CleanStorageService.getUserSettings();

      // Check whether OS notifications are enabled so we can surface a warning
      // banner when medicine/reminder alerts would silently never fire.
      final notificationsEnabled =
          await NotificationService().areNotificationsEnabled();
      final checkIn = await DailyCheckIn.isEnabled();

      if (mounted) {
        setState(() {
          _checkInEnabled = checkIn;
          _checkInTime = DailyCheckIn.time;
          _quietOn = QuietHours.enabled;
          _quietWindow = QuietHours.window;
          _notificationsEnabled = notificationsEnabled;
          _soundEnabled = settings.soundEnabled;
          _vibrationEnabled = settings.vibrationEnabled;
          _showOnLockScreen = settings.showOnLockScreen;
          _persistentNotification = settings.persistentNotification;
          _fullScreenNotification = settings.fullScreenNotification;
          _snoozeEnabled = settings.snoozeEnabled;
          _snoozeMinutes = settings.snoozeIntervalMinutes;
          _maxSnoozes = settings.maxSnoozeCount;
          _autoMarkMissed = settings.autoMarkMissed;
          _missedMinutes = settings.missedThresholdMinutes;
          _alarmDurationSeconds = settings.alarmRingDurationSeconds;
          _notificationSound = settings.notificationSound;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Instant-apply write. Runs behind [_persistDebounced] on every toggle /
  /// duration change — no Save button, no success SnackBar.
  Future<void> _persist() async {
    try {
      // copyWith on the persisted settings — building a fresh UserSettings here
      // reset every unlisted field (notably the user's theme preference) to its
      // default, silently wiping their dark/light choice on every save.
      final before = CleanStorageService.getUserSettings();
      final settings = before.copyWith(
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        showOnLockScreen: _showOnLockScreen,
        persistentNotification: _persistentNotification,
        fullScreenNotification: _fullScreenNotification,
        snoozeEnabled: _snoozeEnabled,
        snoozeIntervalMinutes: _snoozeMinutes,
        maxSnoozeCount: _maxSnoozes,
        autoMarkMissed: _autoMarkMissed,
        missedThresholdMinutes: _missedMinutes,
        alarmRingDurationSeconds: _alarmDurationSeconds,
        notificationSound: _notificationSound,
      );

      // saveUserSettings mirrors every alarm-isolate key itself now (see
      // CleanStorageService.mirrorSettingsForAlarmIsolate). This used to mirror
      // two of them here by hand and miss `max_snooze_count` entirely, so the
      // snooze cap the alarm isolate enforced was never the one the user chose.
      await CleanStorageService.saveUserSettings(settings);

      // Reminders already armed carry the look they were armed with, so a changed
      // switch only reaches them once they are armed again. At the next start, as
      // it was — which reads as the switch doing nothing, until then. A new
      // alarm reads the preferences when it rings and needs none of this.
      if (NotificationSettingsScreen.alertLookChanged(before, settings)) {
        unawaited(_rearmReminders());
      }

      if (mounted) {
        // Quiet, non-blocking "Saved" affordance in the header — fades away.
        setState(() => _showSaved = true);
        _savedTimer?.cancel();
        _savedTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showSaved = false);
        });
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      // Silence here is indistinguishable from success: the switch stays where
      // the user put it, and the only other signal — the "Saved" check — just
      // never appears. Reachable, not theoretical: `getUserSettings()` casts
      // every stored value, and a restored backup can leave a non-int in an
      // int preference, at which point EVERY save on this screen throws and
      // the user is never told any of them were lost.
      if (!mounted) return;
      _savedTimer?.cancel();
      setState(() => _showSaved = false);
      context.toastError("Couldn't save that change. Try again.");
    }
  }

  Future<void> _setCheckIn(bool on) async {
    if (_checkInBusy) return;
    setState(() => _checkInBusy = true);
    try {
      // Turning it on arms a notification, and one scheduled without the
      // permission is never shown while this screen says it is on. A person who
      // skipped the first-run step, or declined it, meets the question here.
      if (on && !await NotificationService().ensurePermission()) {
        if (mounted) {
          context.toastInfo('Notifications are off for DlyMinder, so the daily '
              "check-in would never appear. Allow them in your phone's settings.");
        }
        return;
      }
      await DailyCheckIn.apply(enabled: on, time: _checkInTime);
      if (!mounted) return;
      setState(() => _checkInEnabled = on);
    } catch (e) {
      debugPrint('Daily check-in could not be changed: $e');
      if (mounted) context.toastError("Couldn't change the daily check-in. Try again.");
    } finally {
      if (mounted) setState(() => _checkInBusy = false);
    }
  }

  Future<void> _pickCheckInTime() async {
    final picked = await AppTimePicker.show(
      context,
      initial: _checkInTime,
      accent: AppColorsExt.of(context).reminders,
      minuteInterval: 5,
      title: 'Check-in time',
    );
    if (picked == null || !mounted) return;
    try {
      await DailyCheckIn.apply(enabled: true, time: picked);
      if (!mounted) return;
      setState(() {
        _checkInTime = picked;
        _checkInEnabled = true;
      });
    } catch (e) {
      debugPrint('Daily check-in time could not be changed: $e');
      if (mounted) context.toastError("Couldn't change the time. Try again.");
    }
  }

  TimeOfDay _timeOf(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

  /// Save quiet hours and move what is already armed. The choice is kept even if
  /// re-arming fails: the next start of the app arms every reminder again.
  Future<void> _applyQuietHours(bool on, QuietWindow window) async {
    setState(() => _quietBusy = true);
    try {
      await QuietHours.save(enabled: on, window: window);
      if (!mounted) return;
      setState(() {
        _quietOn = on;
        _quietWindow = window;
      });
      await _rearmReminders();
    } catch (e) {
      debugPrint('Quiet hours could not be changed: $e');
      if (mounted) context.toastError("Couldn't change quiet hours. Try again.");
    } finally {
      if (mounted) setState(() => _quietBusy = false);
    }
  }

  Future<void> _pickQuietTime({required bool start}) async {
    final picked = await AppTimePicker.show(
      context,
      initial: _timeOf(start ? _quietWindow.startMinute : _quietWindow.endMinute),
      accent: AppColorsExt.of(context).reminders,
      minuteInterval: 5,
      title: start ? 'Quiet hours start' : 'Quiet hours end',
    );
    if (picked == null || !mounted) return;
    final minute = picked.hour * 60 + picked.minute;
    final next = start
        ? QuietWindow(startMinute: minute, endMinute: _quietWindow.endMinute)
        : QuietWindow(startMinute: _quietWindow.startMinute, endMinute: minute);
    if (next.isEmpty) {
      context.toastError('Quiet hours need a start and an end that differ.');
      return;
    }
    await _applyQuietHours(_quietOn, next);
  }

  /// Offered, never applied unasked: the sleep schedule's bedtime and wake time.
  Future<void> _quietFromSleepSchedule() async {
    final schedule = SleepService.getSchedule();
    final next = QuietWindow(
        startMinute: schedule.bedtimeHour * 60 + schedule.bedtimeMinute,
        endMinute: schedule.wakeHour * 60 + schedule.wakeMinute);
    if (next.isEmpty) {
      context.toastError('Your sleep schedule has the same bedtime and wake time.');
      return;
    }
    await _applyQuietHours(_quietOn, next);
  }

  Future<void> _rearmReminders() async {
    try {
      await NotificationSettingsScreen.rearmReminders();
    } catch (e) {
      debugPrint('Re-arming reminders after a change of alert look failed: $e');
    }
  }

  /// Debounces rapid toggles/selections into a single write.
  void _persistDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService().showImmediateNotification(
        title: '🔔 Test Notification',
        body: 'Your notifications are working correctly!',
        // Alarm-grade on purpose: this button exists to prove the alarm path
        // works end to end, so it must exercise that path and not a nudge.
        kind: ReminderKind.alarm,
      );

      if (mounted) {
        context.toastSuccess('Test notification sent');
      }
    } catch (e) {
      debugPrint('Test notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Notifications',
              leading: AppHeader.backButton(context),
              actions: [
                // Quiet fading "Saved" check — replaces the Save button/pill.
                AnimatedOpacity(
                  opacity: _showSaved ? 1 : 0,
                  duration: AppMotion.base,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.check_circle_rounded,
                          size: 18, color: ext.mark(ext.success)),
                      const SizedBox(width: 4),
                      Text('Saved',
                          style: tt.labelMedium
                              ?.copyWith(color: ext.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                          AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                      children: [
                        // Permission warning banner — the one amber moment.
                        // Shows only when OS notifications are disabled and
                        // self-hides once the user enables them.
                        if (!_notificationsEnabled) ...[
                          NotificationPermissionBanner(
                            onStatusChanged: (enabled) {
                              if (mounted &&
                                  enabled != _notificationsEnabled) {
                                setState(
                                    () => _notificationsEnabled = enabled);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],

                        // The one nudge a day the first-run setup offered. It had
                        // no home after that: no way to move it, no way to stop
                        // it but the phone's own settings.
                        SettingsSection(
                          title: 'Daily check-in',
                          footer: 'One gentle nudge a day for your medicine, '
                              'water and to-dos.',
                          children: [
                            SettingsTile(
                              icon: Symbols.event_available_rounded,
                              title: 'Daily check-in',
                              switchValue: _checkInEnabled,
                              onSwitchChanged: _checkInBusy ? null : _setCheckIn,
                            ),
                            if (_checkInEnabled)
                              SettingsTile(
                                icon: Symbols.schedule_rounded,
                                title: 'Time',
                                value: _checkInTime.format(context),
                                onTap: _pickCheckInTime,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Quiet hours: the reminders you made, held until morning.
                        SettingsSection(
                          title: 'Quiet hours',
                          footer: 'Reminders you made, set to Normal, wait until '
                              'quiet hours end. Quiet ones make no sound anyway; '
                              'Insistent and Critical reminders and medicines '
                              'always arrive on time.',
                          children: [
                            SettingsTile(
                              icon: Symbols.bedtime_rounded,
                              title: 'Quiet hours',
                              switchValue: _quietOn,
                              onSwitchChanged: _quietBusy
                                  ? null
                                  : (on) => _applyQuietHours(on, _quietWindow),
                            ),
                            if (_quietOn) ...[
                              SettingsTile(
                                icon: Symbols.schedule_rounded,
                                title: 'From',
                                value: _timeOf(_quietWindow.startMinute)
                                    .format(context),
                                onTap: () => _pickQuietTime(start: true),
                              ),
                              SettingsTile(
                                icon: Symbols.alarm_rounded,
                                title: 'Until',
                                value: _timeOf(_quietWindow.endMinute)
                                    .format(context),
                                onTap: () => _pickQuietTime(start: false),
                              ),
                              SettingsTile(
                                icon: Symbols.bed_rounded,
                                title: 'Use my sleep schedule',
                                onTap: _quietFromSleepSchedule,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Alerts
                        SettingsSection(
                          title: 'Alerts',
                          footer:
                              'Play a sound and vibrate your device when a reminder fires. '
                              'Medicine and alarm-style reminders ring on your phone\'s '
                              'alarm sound whatever Sound says; Vibration applies to them too. '
                              'Turning Vibration off moves them to a separate "(no vibration)" '
                              'entry in your phone\'s notification settings, which starts with '
                              'the app\'s own settings rather than any you changed on the original.'
                              '${NotificationSettingsScreen._canPickSoundInPhoneSettings ? ' To pick which sound each kind of reminder uses, open your phone\'s settings for DlyMinder, then Notifications.' : ''}',
                          children: [
                            SettingsTile(
                              icon: Symbols.volume_up_rounded,
                              title: 'Sound',
                              switchValue: _soundEnabled,
                              onSwitchChanged: (v) {
                                setState(() => _soundEnabled = v);
                                _persistDebounced();
                              },
                            ),
                            if (NotificationSettingsScreen
                                ._canPickSoundInPhoneSettings)
                              SettingsTile(
                                icon: Symbols.music_note_rounded,
                                title: 'Choose sounds',
                                onTap: () =>
                                    NotificationSettingsScreen.openPhoneSettings(),
                              ),
                            SettingsTile(
                              icon: Symbols.vibration_rounded,
                              title: 'Vibration',
                              switchValue: _vibrationEnabled,
                              onSwitchChanged: (v) {
                                setState(() => _vibrationEnabled = v);
                                _persistDebounced();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Display
                        SettingsSection(
                          title: 'Display',
                          footer:
                              'Full-screen alerts take over the screen for time-critical reminders. '
                              'Keep on screen stops them being swiped away until you answer.',
                          children: [
                            SettingsTile(
                              icon: Symbols.lock_rounded,
                              // "Show on Lock Screen" wanted 3 lines in a
                              // 134pt column at 320pt. The section is titled
                              // "Display", so the row does not need to repeat
                              // that it is about showing something.
                              title: 'Lock screen',
                              switchValue: _showOnLockScreen,
                              onSwitchChanged: (v) {
                                setState(() => _showOnLockScreen = v);
                                _persistDebounced();
                              },
                            ),
                            SettingsTile(
                              icon: Symbols.push_pin_rounded,
                              title: 'Keep on screen',
                              switchValue: _persistentNotification,
                              onSwitchChanged: (v) {
                                setState(() => _persistentNotification = v);
                                _persistDebounced();
                              },
                            ),
                            SettingsTile(
                              icon: Symbols.fullscreen_rounded,
                              title: 'Full-screen alerts',
                              switchValue: _fullScreenNotification,
                              onSwitchChanged: (v) {
                                setState(() => _fullScreenNotification = v);
                                _persistDebounced();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Snooze
                        SettingsSection(
                          title: 'Snooze',
                          footer:
                              'How long a reminder waits before alerting you again, and how many times you can put it off. After the last snooze there is no button to put it off again.',
                          children: [
                            SettingsTile(
                              icon: Symbols.snooze_rounded,
                              title: 'Snooze',
                              switchValue: _snoozeEnabled,
                              onSwitchChanged: (v) {
                                setState(() => _snoozeEnabled = v);
                                _persistDebounced();
                              },
                            ),
                            if (_snoozeEnabled)
                              _durationRow(
                                ext,
                                tt,
                                label: 'Snooze duration (minutes)',
                                options: _snoozeOptions,
                                value: _snoozeMinutes,
                                onSelected: (v) {
                                  setState(() => _snoozeMinutes = v);
                                  _persistDebounced();
                                },
                              ),
                            if (_snoozeEnabled)
                              _durationRow(
                                ext,
                                tt,
                                label: 'Snoozes allowed',
                                options: _maxSnoozeOptions,
                                value: _maxSnoozes,
                                onSelected: (v) {
                                  setState(() => _maxSnoozes = v);
                                  _persistDebounced();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Missed
                        SettingsSection(
                          title: 'Missed reminders',
                          footer:
                              'A reminder you have not answered is counted as missed after this long. It stays on your list; only your reminder history changes.',
                          children: [
                            SettingsTile(
                              icon: Symbols.event_busy_rounded,
                              title: 'Mark as missed',
                              switchValue: _autoMarkMissed,
                              onSwitchChanged: (v) {
                                setState(() => _autoMarkMissed = v);
                                _persistDebounced();
                              },
                            ),
                            if (_autoMarkMissed)
                              _durationRow(
                                ext,
                                tt,
                                label: 'After (minutes)',
                                options: _missedOptions,
                                value: _missedMinutes,
                                onSelected: (v) {
                                  setState(() => _missedMinutes = v);
                                  _persistDebounced();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Alarm
                        SettingsSection(
                          title: 'Alarm',
                          footer:
                              'How long an alarm rings before it dismisses itself.',
                          children: [
                            _durationRow(
                              ext,
                              tt,
                              label: 'Ring duration (seconds)',
                              options: _alarmOptions,
                              value: _alarmDurationSeconds,
                              onSelected: (v) {
                                setState(() => _alarmDurationSeconds = v);
                                _persistDebounced();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Testing
                        SettingsSection(
                          title: 'Testing',
                          children: [
                            SettingsTile(
                              icon: Symbols.notifications_active_rounded,
                              title: 'Send a test notification',
                              onTap: _testNotification,
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

  /// Full-width label-only duration picker inside a group card.
  Widget _durationRow(
    AppColorsExt ext,
    TextTheme tt, {
    required String label,
    required List<int> options,
    required int value,
    required ValueChanged<int> onSelected,
  }) {
    // A stored value the picker does not offer (a restored backup, an older
    // build) is shown as itself, not as the first option it was never set to.
    if (!options.contains(value)) {
      options = [...options, value]..sort();
    }
    final index = options.indexOf(value);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedToggle(
            accent: ext.brand,
            index: index,
            items: [for (final o in options) SegmentItem(label: '$o')],
            onChanged: (i) => onSelected(options[i]),
          ),
        ],
      ),
    );
  }
}
