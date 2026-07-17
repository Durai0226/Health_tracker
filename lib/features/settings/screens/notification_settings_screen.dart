import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/clean_storage_service.dart';

/// Clean, simple notification settings screen — Calm Clarity, dark-aware.
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
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

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
        final ext = AppColorsExt.of(context);
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle,
                    color: ext.fillFg(ext.success), size: 20),
                const SizedBox(width: 12),
                Text('Settings saved successfully',
                    style: TextStyle(color: ext.fillFg(ext.success))),
              ],
            ),
            backgroundColor: ext.fillBg(ext.success),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        final ext = AppColorsExt.of(context);
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save settings'),
            backgroundColor: ext.fillBg(ext.error),
          ),
        );
      }
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService().showImmediateNotification(
        title: '🔔 Test Notification',
        body: 'Your notifications are working correctly!',
        channelId: 'test_channel',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Test notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.reminders,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Notifications',
              accent: ext.reminders,
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                filled: false,
                accent: ext.reminders,
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (_hasChanges)
                  AppButton(
                    label: 'Save',
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.tonal,
                    accent: ext.reminders,
                    loading: _isSaving,
                    onPressed: _isSaving ? null : _saveSettings,
                  ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                          AppSpacing.sm, AppSpacing.gutter, 40),
                      children: [
                        // Permission warning banner — shows only when OS
                        // notifications are disabled (self-hides otherwise).
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
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Header Card
                        _buildHeaderCard(ext),
                        const SizedBox(height: AppSpacing.lg),

                        // Sound & Vibration Section
                        SectionHeader(
                            title: 'Sound & Haptics', accent: ext.reminders),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                ext,
                                icon: Icons.volume_up_rounded,
                                accent: ext.brand,
                                title: 'Sound',
                                subtitle: 'Play sound for notifications',
                                value: _soundEnabled,
                                onChanged: (v) {
                                  setState(() => _soundEnabled = v);
                                  _markChanged();
                                },
                              ),
                              _divider(ext),
                              _buildSwitchTile(
                                ext,
                                icon: Icons.vibration_rounded,
                                accent: ext.warning,
                                title: 'Vibration',
                                subtitle: 'Vibrate for notifications',
                                value: _vibrationEnabled,
                                onChanged: (v) {
                                  setState(() => _vibrationEnabled = v);
                                  _markChanged();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Display Section
                        SectionHeader(
                            title: 'Display', accent: ext.reminders),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                ext,
                                icon: Icons.lock_outline_rounded,
                                accent: ext.info,
                                title: 'Show on Lock Screen',
                                subtitle: 'Display notifications when locked',
                                value: _showOnLockScreen,
                                onChanged: (v) {
                                  setState(() => _showOnLockScreen = v);
                                  _markChanged();
                                },
                              ),
                              _divider(ext),
                              _buildSwitchTile(
                                ext,
                                icon: Icons.push_pin_rounded,
                                accent: ext.success,
                                title: 'Persistent Notifications',
                                subtitle: 'Keep until manually dismissed',
                                value: _persistentNotification,
                                onChanged: (v) {
                                  setState(() => _persistentNotification = v);
                                  _markChanged();
                                },
                              ),
                              _divider(ext),
                              _buildSwitchTile(
                                ext,
                                icon: Icons.fullscreen_rounded,
                                accent: ext.error,
                                title: 'Full Screen Alerts',
                                subtitle:
                                    'Show full screen for important reminders',
                                value: _fullScreenNotification,
                                onChanged: (v) {
                                  setState(() => _fullScreenNotification = v);
                                  _markChanged();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Snooze Section
                        SectionHeader(
                            title: 'Snooze', accent: ext.reminders),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                ext,
                                icon: Icons.snooze_rounded,
                                accent: ext.focus,
                                title: 'Enable Snooze',
                                subtitle: 'Allow snoozing reminders',
                                value: _snoozeEnabled,
                                onChanged: (v) {
                                  setState(() => _snoozeEnabled = v);
                                  _markChanged();
                                },
                              ),
                              if (_snoozeEnabled) ...[
                                _divider(ext),
                                _buildOptionSelector(
                                  ext,
                                  title: 'Snooze Duration',
                                  options: const [1, 5, 10, 15, 30],
                                  selectedValue: _snoozeMinutes,
                                  suffix: 'min',
                                  onSelected: (v) {
                                    setState(() => _snoozeMinutes = v);
                                    _markChanged();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Alarm Duration Section
                        SectionHeader(title: 'Alarm', accent: ext.reminders),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: _buildOptionSelector(
                            ext,
                            title: 'Alarm Ring Duration',
                            options: const [15, 30, 45, 60],
                            selectedValue: _alarmDurationSeconds,
                            suffix: 'sec',
                            onSelected: (v) {
                              setState(() => _alarmDurationSeconds = v);
                              _markChanged();
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Test Notification
                        AppButton(
                          label: 'Send Test Notification',
                          leadingIcon: Icons.notifications_active_rounded,
                          variant: AppButtonVariant.secondary,
                          accent: ext.reminders,
                          fullWidth: true,
                          onPressed: _testNotification,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Save Button
                        AppButton(
                          label: 'Save Settings',
                          leadingIcon: Icons.save_rounded,
                          accent: ext.reminders,
                          fullWidth: true,
                          size: AppButtonSize.lg,
                          loading: _isSaving,
                          onPressed: _isSaving ? null : _saveSettings,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColorsExt ext) => Divider(
        height: 1,
        indent: 52,
        endIndent: 8,
        color: ext.outline,
      );

  Widget _buildHeaderCard(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      color: ext.reminders.container,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ext.reminders.base.withOpacity(0.18),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: ext.reminders.onContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Preferences',
                  style: tt.titleLarge
                      ?.copyWith(color: ext.reminders.onContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customize how you receive reminders',
                  style: tt.bodyMedium?.copyWith(
                    color: ext.reminders.onContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    AppColorsExt ext, {
    required IconData icon,
    required AccentSwatch accent,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppListTile(
      icon: icon,
      iconColor: ext.mark(accent),
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildOptionSelector(
    AppColorsExt ext, {
    required String title,
    required List<int> options,
    required int selectedValue,
    required String suffix,
    required ValueChanged<int> onSelected,
  }) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: options.map((value) {
              return AppChip(
                label: '$value$suffix',
                selected: selectedValue == value,
                accent: ext.reminders,
                onTap: () => onSelected(value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
