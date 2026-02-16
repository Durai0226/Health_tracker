import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/user_settings.dart';

/// Clean, simple notification settings screen
/// Inspired by Fitbit, Strava, Apple Health, Google Fit best practices
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
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
      
      final settings = StorageService.getUserSettings();
      
      if (mounted) {
        setState(() {
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
      final settings = UserSettings(
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
      
      await StorageService.saveUserSettings(settings);
      
      // Sync snooze settings to SharedPreferences for background alarm service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snooze_interval_minutes', _snoozeMinutes);
      await prefs.setBool('snooze_enabled', _snoozeEnabled);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Settings saved successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: AppColors.error,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card
                _buildHeaderCard(),
                const SizedBox(height: 20),
                
                // Sound & Vibration Section
                _buildSectionTitle('Sound & Haptics'),
                _buildSettingCard(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.volume_up_rounded,
                      iconColor: AppColors.primary,
                      title: 'Sound',
                      subtitle: 'Play sound for notifications',
                      value: _soundEnabled,
                      onChanged: (v) {
                        setState(() => _soundEnabled = v);
                        _markChanged();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      icon: Icons.vibration_rounded,
                      iconColor: AppColors.warning,
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
                const SizedBox(height: 20),
                
                // Display Section
                _buildSectionTitle('Display'),
                _buildSettingCard(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: AppColors.info,
                      title: 'Show on Lock Screen',
                      subtitle: 'Display notifications when locked',
                      value: _showOnLockScreen,
                      onChanged: (v) {
                        setState(() => _showOnLockScreen = v);
                        _markChanged();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      icon: Icons.push_pin_rounded,
                      iconColor: AppColors.success,
                      title: 'Persistent Notifications',
                      subtitle: 'Keep until manually dismissed',
                      value: _persistentNotification,
                      onChanged: (v) {
                        setState(() => _persistentNotification = v);
                        _markChanged();
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      icon: Icons.fullscreen_rounded,
                      iconColor: AppColors.error,
                      title: 'Full Screen Alerts',
                      subtitle: 'Show full screen for important reminders',
                      value: _fullScreenNotification,
                      onChanged: (v) {
                        setState(() => _fullScreenNotification = v);
                        _markChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Snooze Section
                _buildSectionTitle('Snooze'),
                _buildSettingCard(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.snooze_rounded,
                      iconColor: Colors.purple,
                      title: 'Enable Snooze',
                      subtitle: 'Allow snoozing reminders',
                      value: _snoozeEnabled,
                      onChanged: (v) {
                        setState(() => _snoozeEnabled = v);
                        _markChanged();
                      },
                    ),
                    if (_snoozeEnabled) ...[
                      const Divider(height: 1),
                      _buildOptionSelector(
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
                const SizedBox(height: 20),
                
                // Alarm Duration Section
                _buildSectionTitle('Alarm'),
                _buildSettingCard(
                  children: [
                    _buildOptionSelector(
                      title: 'Alarm Ring Duration',
                      options: const [15, 30, 45, 60],
                      selectedValue: _alarmDurationSeconds,
                      suffix: 'sec',
                      onSelected: (v) {
                        setState(() => _alarmDurationSeconds = v);
                        _markChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Test Notification
                _buildTestButton(),
                const SizedBox(height: 20),
                
                // Save Button
                _buildSaveButton(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Customize how you receive reminders',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSelector({
    required String title,
    required List<int> options,
    required int selectedValue,
    required String suffix,
    required ValueChanged<int> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((value) {
              final isSelected = selectedValue == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(value),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: value != options.last ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$value$suffix',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return GestureDetector(
      onTap: _testNotification,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_active, color: AppColors.primary),
            SizedBox(width: 12),
            Text(
              'Send Test Notification',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveSettings,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Save Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
