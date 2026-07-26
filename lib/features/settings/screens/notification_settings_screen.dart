import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/clean_storage_service.dart';

/// Notifications settings — an Apple-tier, instant-apply grouped-settings list.
/// Calm Clarity: one interactive color (brand teal), a neutral chrome bed, and
/// amber reserved for the single semantic permission warning. Every toggle /
/// duration persists immediately (no Save button); a quiet "Saved" affordance
/// fades in the header.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

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
  int _alarmDurationSeconds = 30;
  String _notificationSound = 'default';

  // UI state
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _showSaved = false;

  Timer? _debounce;
  Timer? _savedTimer;

  static const List<int> _snoozeOptions = [1, 5, 10, 15, 30];
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

      if (mounted) {
        setState(() {
          _notificationsEnabled = notificationsEnabled;
          _soundEnabled = settings.soundEnabled;
          _vibrationEnabled = settings.vibrationEnabled;
          _showOnLockScreen = settings.showOnLockScreen;
          _persistentNotification = settings.persistentNotification;
          _fullScreenNotification = settings.fullScreenNotification;
          _snoozeEnabled = settings.snoozeEnabled;
          _snoozeMinutes = settings.snoozeIntervalMinutes;
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
      final settings = CleanStorageService.getUserSettings().copyWith(
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        showOnLockScreen: _showOnLockScreen,
        persistentNotification: _persistentNotification,
        fullScreenNotification: _fullScreenNotification,
        snoozeEnabled: _snoozeEnabled,
        snoozeIntervalMinutes: _snoozeMinutes,
        alarmRingDurationSeconds: _alarmDurationSeconds,
        notificationSound: _notificationSound,
      );

      await CleanStorageService.saveUserSettings(settings);

      // Sync snooze settings to SharedPreferences for background alarm service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snooze_interval_minutes', _snoozeMinutes);
      await prefs.setBool('snooze_enabled', _snoozeEnabled);

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
        channelId: 'test_channel',
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
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: ext.brand,
                onPressed: () => Navigator.pop(context),
              ),
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

                        // Alerts
                        SettingsSection(
                          title: 'Alerts',
                          footer:
                              'Play a sound and vibrate your device when a reminder fires.',
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
                              'Full-screen alerts take over the screen for time-critical reminders.',
                          children: [
                            SettingsTile(
                              icon: Symbols.lock_rounded,
                              title: 'Show on Lock Screen',
                              switchValue: _showOnLockScreen,
                              onSwitchChanged: (v) {
                                setState(() => _showOnLockScreen = v);
                                _persistDebounced();
                              },
                            ),
                            SettingsTile(
                              icon: Symbols.push_pin_rounded,
                              title: 'Persistent Notifications',
                              switchValue: _persistentNotification,
                              onSwitchChanged: (v) {
                                setState(() => _persistentNotification = v);
                                _persistDebounced();
                              },
                            ),
                            SettingsTile(
                              icon: Symbols.fullscreen_rounded,
                              title: 'Full-Screen Alerts',
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
                              'How long a reminder waits before alerting you again.',
                          children: [
                            SettingsTile(
                              icon: Symbols.snooze_rounded,
                              title: 'Enable Snooze',
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
    final index = options.indexOf(value).clamp(0, options.length - 1);
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
