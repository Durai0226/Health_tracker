import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/mood_theme.dart';
import '../services/mood_firestore_service.dart';
import '../services/mood_notification_service.dart';
import '../widgets/bloom_glass_container.dart';

/// Settings screen for mood tracker notifications and preferences
class BloomMoodSettingsScreen extends StatefulWidget {
  const BloomMoodSettingsScreen({super.key});

  @override
  State<BloomMoodSettingsScreen> createState() =>
      _BloomMoodSettingsScreenState();
}

class _BloomMoodSettingsScreenState extends State<BloomMoodSettingsScreen> {
  final MoodFirestoreService _firestoreService = MoodFirestoreService();
  final MoodNotificationService _notificationService = MoodNotificationService();

  MoodSettings _settings = MoodSettings();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = await _firestoreService.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      await _notificationService.updateSettings(_settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved!'),
            backgroundColor: MoodTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: MoodTheme.borderRadiusMd,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save settings'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _updateSettings(MoodSettings newSettings) {
    setState(() => _settings = newSettings);
  }

  Future<void> _selectTime({
    required int currentHour,
    required int currentMinute,
    required Function(int hour, int minute) onSelected,
  }) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: MoodTheme.primary,
              onPrimary: Colors.white,
              surface: MoodTheme.surface,
              onSurface: MoodTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      onSelected(time.hour, time.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MoodTheme.themeData,
      child: Scaffold(
        backgroundColor: MoodTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Settings',
            style: MoodTheme.headingSm,
          ),
          centerTitle: true,
          actions: [
            if (!_isLoading)
              TextButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MoodTheme.primary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: MoodTheme.titleMd.copyWith(
                          color: MoodTheme.primary,
                        ),
                      ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: MoodTheme.primary),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(MoodTheme.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily reminder section
                    _buildSectionTitle(
                      'Daily Reminder',
                      Icons.notifications_rounded,
                    ),
                    const SizedBox(height: MoodTheme.spacingMd),
                    _buildDailyReminderCard(),

                    const SizedBox(height: MoodTheme.spacingXl),

                    // Multiple check-ins
                    _buildSectionTitle(
                      'Multiple Check-ins',
                      Icons.access_time_rounded,
                    ),
                    const SizedBox(height: MoodTheme.spacingMd),
                    _buildMultipleCheckInsCard(),

                    const SizedBox(height: MoodTheme.spacingXl),

                    // Smart features
                    _buildSectionTitle(
                      'Smart Features',
                      Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(height: MoodTheme.spacingMd),
                    _buildSmartFeaturesCard(),

                    const SizedBox(height: MoodTheme.spacingXl),

                    // Data section
                    _buildSectionTitle(
                      'Data',
                      Icons.storage_rounded,
                    ),
                    const SizedBox(height: MoodTheme.spacingMd),
                    _buildDataCard(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: MoodTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: MoodTheme.titleLg),
      ],
    );
  }

  Widget _buildDailyReminderCard() {
    return BloomGlassContainer(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Enable Daily Reminder',
            subtitle: 'Get reminded to log your mood',
            value: _settings.dailyReminderEnabled,
            onChanged: (value) {
              _updateSettings(_settings.copyWith(dailyReminderEnabled: value));
            },
          ),
          if (_settings.dailyReminderEnabled) ...[
            const Divider(height: 24),
            _buildTimeTile(
              title: 'Reminder Time',
              hour: _settings.dailyReminderHour,
              minute: _settings.dailyReminderMinute,
              onTap: () => _selectTime(
                currentHour: _settings.dailyReminderHour,
                currentMinute: _settings.dailyReminderMinute,
                onSelected: (hour, minute) {
                  _updateSettings(_settings.copyWith(
                    dailyReminderHour: hour,
                    dailyReminderMinute: minute,
                  ));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultipleCheckInsCard() {
    return BloomGlassContainer(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Column(
        children: [
          // Morning
          _buildCheckInTile(
            title: 'Morning Check-in',
            subtitle: 'Start your day mindfully',
            emoji: '🌅',
            enabled: _settings.morningCheckInEnabled,
            hour: _settings.morningCheckInHour,
            onEnabledChanged: (value) {
              _updateSettings(_settings.copyWith(morningCheckInEnabled: value));
            },
            onTimeTap: () => _selectTime(
              currentHour: _settings.morningCheckInHour,
              currentMinute: 0,
              onSelected: (hour, _) {
                _updateSettings(_settings.copyWith(morningCheckInHour: hour));
              },
            ),
          ),
          const Divider(height: 24),

          // Afternoon
          _buildCheckInTile(
            title: 'Afternoon Check-in',
            subtitle: 'Pause and reflect',
            emoji: '☀️',
            enabled: _settings.afternoonCheckInEnabled,
            hour: _settings.afternoonCheckInHour,
            onEnabledChanged: (value) {
              _updateSettings(
                  _settings.copyWith(afternoonCheckInEnabled: value));
            },
            onTimeTap: () => _selectTime(
              currentHour: _settings.afternoonCheckInHour,
              currentMinute: 0,
              onSelected: (hour, _) {
                _updateSettings(_settings.copyWith(afternoonCheckInHour: hour));
              },
            ),
          ),
          const Divider(height: 24),

          // Evening
          _buildCheckInTile(
            title: 'Evening Check-in',
            subtitle: 'Reflect on your day',
            emoji: '🌙',
            enabled: _settings.eveningCheckInEnabled,
            hour: _settings.eveningCheckInHour,
            onEnabledChanged: (value) {
              _updateSettings(_settings.copyWith(eveningCheckInEnabled: value));
            },
            onTimeTap: () => _selectTime(
              currentHour: _settings.eveningCheckInHour,
              currentMinute: 0,
              onSelected: (hour, _) {
                _updateSettings(_settings.copyWith(eveningCheckInHour: hour));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartFeaturesCard() {
    return BloomGlassContainer(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Streak Notifications',
            subtitle: 'Celebrate milestones and stay motivated',
            value: _settings.streakNotificationsEnabled,
            onChanged: (value) {
              _updateSettings(
                  _settings.copyWith(streakNotificationsEnabled: value));
            },
          ),
          const Divider(height: 24),
          _buildSwitchTile(
            title: 'Smart Reminders',
            subtitle: 'Adaptive reminders based on your patterns',
            value: _settings.smartRemindersEnabled,
            onChanged: (value) {
              _updateSettings(_settings.copyWith(smartRemindersEnabled: value));
            },
          ),
          const Divider(height: 24),
          _buildSwitchTile(
            title: 'Mood Trend Alerts',
            subtitle: 'Get notified about significant mood changes',
            value: _settings.moodTrendAlertsEnabled,
            onChanged: (value) {
              _updateSettings(
                  _settings.copyWith(moodTrendAlertsEnabled: value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard() {
    return BloomGlassContainer(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      child: Column(
        children: [
          _buildActionTile(
            title: 'Export Data',
            subtitle: 'Download your mood history',
            icon: Icons.download_rounded,
            onTap: () {
              // TODO: Implement export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const Divider(height: 24),
          _buildActionTile(
            title: 'Sync Data',
            subtitle: 'Sync with cloud storage',
            icon: Icons.cloud_sync_rounded,
            onTap: () async {
              await _firestoreService.syncData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Data synced!'),
                    backgroundColor: MoodTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MoodTheme.titleMd),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: MoodTheme.bodySm.copyWith(
                  color: MoodTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: (newValue) {
            HapticFeedback.lightImpact();
            onChanged(newValue);
          },
          activeColor: MoodTheme.primary,
        ),
      ],
    );
  }

  Widget _buildTimeTile({
    required String title,
    required int hour,
    required int minute,
    required VoidCallback onTap,
  }) {
    final time = TimeOfDay(hour: hour, minute: minute);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: MoodTheme.titleMd),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: MoodTheme.primarySoft,
              borderRadius: MoodTheme.borderRadiusMd,
            ),
            child: Text(
              time.format(context),
              style: MoodTheme.titleMd.copyWith(
                color: MoodTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInTile({
    required String title,
    required String subtitle,
    required String emoji,
    required bool enabled,
    required int hour,
    required ValueChanged<bool> onEnabledChanged,
    required VoidCallback onTimeTap,
  }) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MoodTheme.titleMd),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    subtitle,
                    style: MoodTheme.bodySm.copyWith(
                      color: MoodTheme.textSecondary,
                    ),
                  ),
                  if (enabled) ...[
                    const Text(' • '),
                    GestureDetector(
                      onTap: onTimeTap,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: MoodTheme.bodySm.copyWith(
                          color: MoodTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: enabled,
          onChanged: (newValue) {
            HapticFeedback.lightImpact();
            onEnabledChanged(newValue);
          },
          activeColor: MoodTheme.primary,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MoodTheme.primarySoft,
              borderRadius: MoodTheme.borderRadiusSm,
            ),
            child: Icon(icon, color: MoodTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MoodTheme.titleMd),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: MoodTheme.bodySm.copyWith(
                    color: MoodTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: MoodTheme.textMuted,
          ),
        ],
      ),
    );
  }
}
