import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/period_settings.dart';
import '../services/period_storage_service.dart';

class PeriodSettingsScreen extends StatefulWidget {
  const PeriodSettingsScreen({super.key});

  @override
  State<PeriodSettingsScreen> createState() => _PeriodSettingsScreenState();
}

class _PeriodSettingsScreenState extends State<PeriodSettingsScreen> {
  late PeriodSettings _settings;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _settings = PeriodStorageService.getSettings();
    if (_settings.reminderTime != null) {
      _reminderTime = TimeOfDay(
        hour: _settings.reminderTime!.hour,
        minute: _settings.reminderTime!.minute,
      );
    }
  }

  Future<void> _saveSettings() async {
    final now = DateTime.now();
    final reminderDateTime = DateTime(
      now.year, now.month, now.day,
      _reminderTime.hour, _reminderTime.minute,
    );
    
    await PeriodStorageService.saveSettings(
      _settings.copyWith(reminderTime: reminderDateTime),
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppColors.periodPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.periodPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Period Settings', style: TextStyle(color: AppColors.periodPrimary)),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(color: AppColors.periodPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Cycle Defaults',
              Icons.loop_rounded,
              [
                _buildStepperTile(
                  'Default Cycle Length',
                  '${_settings.defaultCycleLength} days',
                  () {
                    if (_settings.defaultCycleLength > 21) {
                      setState(() {
                        _settings = _settings.copyWith(
                          defaultCycleLength: _settings.defaultCycleLength - 1,
                        );
                      });
                    }
                  },
                  () {
                    if (_settings.defaultCycleLength < 45) {
                      setState(() {
                        _settings = _settings.copyWith(
                          defaultCycleLength: _settings.defaultCycleLength + 1,
                        );
                      });
                    }
                  },
                ),
                _buildStepperTile(
                  'Default Period Duration',
                  '${_settings.defaultPeriodDuration} days',
                  () {
                    if (_settings.defaultPeriodDuration > 2) {
                      setState(() {
                        _settings = _settings.copyWith(
                          defaultPeriodDuration: _settings.defaultPeriodDuration - 1,
                        );
                      });
                    }
                  },
                  () {
                    if (_settings.defaultPeriodDuration < 10) {
                      setState(() {
                        _settings = _settings.copyWith(
                          defaultPeriodDuration: _settings.defaultPeriodDuration + 1,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Tracking Options',
              Icons.checklist_rounded,
              [
                _buildSwitchTile(
                  'Track Ovulation',
                  'Predict ovulation dates',
                  _settings.trackOvulation,
                  (value) => setState(() {
                    _settings = _settings.copyWith(trackOvulation: value);
                  }),
                ),
                _buildSwitchTile(
                  'Track Fertility',
                  'Show fertile window predictions',
                  _settings.trackFertility,
                  (value) => setState(() {
                    _settings = _settings.copyWith(trackFertility: value);
                  }),
                ),
                _buildSwitchTile(
                  'Track Symptoms',
                  'Log physical symptoms',
                  _settings.trackSymptoms,
                  (value) => setState(() {
                    _settings = _settings.copyWith(trackSymptoms: value);
                  }),
                ),
                _buildSwitchTile(
                  'Track Mood',
                  'Log mood and emotions',
                  _settings.trackMood,
                  (value) => setState(() {
                    _settings = _settings.copyWith(trackMood: value);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Reminders',
              Icons.notifications_rounded,
              [
                _buildSwitchTile(
                  'Period Reminders',
                  'Get notified before your period',
                  _settings.enablePeriodReminders,
                  (value) => setState(() {
                    _settings = _settings.copyWith(enablePeriodReminders: value);
                  }),
                ),
                if (_settings.enablePeriodReminders)
                  _buildStepperTile(
                    'Days Before Period',
                    '${_settings.periodReminderDaysBefore} days',
                    () {
                      if (_settings.periodReminderDaysBefore > 1) {
                        setState(() {
                          _settings = _settings.copyWith(
                            periodReminderDaysBefore: _settings.periodReminderDaysBefore - 1,
                          );
                        });
                      }
                    },
                    () {
                      if (_settings.periodReminderDaysBefore < 7) {
                        setState(() {
                          _settings = _settings.copyWith(
                            periodReminderDaysBefore: _settings.periodReminderDaysBefore + 1,
                          );
                        });
                      }
                    },
                  ),
                _buildSwitchTile(
                  'Ovulation Reminders',
                  'Get notified on ovulation day',
                  _settings.enableOvulationReminders,
                  (value) => setState(() {
                    _settings = _settings.copyWith(enableOvulationReminders: value);
                  }),
                ),
                _buildSwitchTile(
                  'Fertile Window Reminders',
                  'Get notified when fertile window starts',
                  _settings.enableFertileWindowReminders,
                  (value) => setState(() {
                    _settings = _settings.copyWith(enableFertileWindowReminders: value);
                  }),
                ),
                _buildSwitchTile(
                  'PMS Reminders',
                  'Get notified before PMS phase',
                  _settings.enablePMSReminders,
                  (value) => setState(() {
                    _settings = _settings.copyWith(enablePMSReminders: value);
                  }),
                ),
                if (_settings.enablePMSReminders)
                  _buildStepperTile(
                    'Days Before PMS',
                    '${_settings.pmsReminderDaysBefore} days',
                    () {
                      if (_settings.pmsReminderDaysBefore > 3) {
                        setState(() {
                          _settings = _settings.copyWith(
                            pmsReminderDaysBefore: _settings.pmsReminderDaysBefore - 1,
                          );
                        });
                      }
                    },
                    () {
                      if (_settings.pmsReminderDaysBefore < 10) {
                        setState(() {
                          _settings = _settings.copyWith(
                            pmsReminderDaysBefore: _settings.pmsReminderDaysBefore + 1,
                          );
                        });
                      }
                    },
                  ),
                _buildTimePicker(),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Content',
              Icons.article_rounded,
              [
                _buildSwitchTile(
                  'Motivational Messages',
                  'Show encouraging messages',
                  _settings.showMotivationalMessages,
                  (value) => setState(() {
                    _settings = _settings.copyWith(showMotivationalMessages: value);
                  }),
                ),
                _buildSwitchTile(
                  'Health Tips',
                  'Show daily health tips based on cycle phase',
                  _settings.enableHealthTips,
                  (value) => setState(() {
                    _settings = _settings.copyWith(enableHealthTips: value);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Privacy',
              Icons.lock_rounded,
              [
                _buildSwitchTile(
                  'Privacy Mode',
                  'Hide sensitive info on lock screen notifications',
                  _settings.privacyMode,
                  (value) => setState(() {
                    _settings = _settings.copyWith(privacyMode: value);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data',
              Icons.storage_rounded,
              [
                _buildActionTile(
                  'Export Data',
                  'Download your period data',
                  Icons.download_rounded,
                  _exportData,
                ),
                _buildActionTile(
                  'Clear All Data',
                  'Delete all period tracking data',
                  Icons.delete_forever_rounded,
                  _showClearDataDialog,
                  isDestructive: true,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.periodPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      activeThumbColor: AppColors.periodPrimary,
      onChanged: onChanged,
    );
  }

  Widget _buildStepperTile(String title, String value, VoidCallback onMinus, VoidCallback onPlus) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.periodPrimary,
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: AppColors.periodPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    return ListTile(
      title: const Text('Reminder Time', style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: const Text('When to receive daily reminders', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: TextButton(
        onPressed: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: _reminderTime,
            builder: (context, child) => Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: AppColors.periodPrimary),
              ),
              child: child!,
            ),
          );
          if (time != null) {
            setState(() => _reminderTime = time);
          }
        },
        child: Text(
          _reminderTime.format(context),
          style: const TextStyle(
            color: AppColors.periodPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.periodPrimary),
      title: Text(title, style: TextStyle(
        fontWeight: FontWeight.w500,
        color: isDestructive ? Colors.red : AppColors.textPrimary,
      )),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _exportData() {
    final data = PeriodStorageService.exportData();
    // In a real app, you would save this to a file or share it
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Data exported: ${data['cycles']?.length ?? 0} cycles, ${data['symptomLogs']?.length ?? 0} symptom logs'),
        backgroundColor: AppColors.periodPrimary,
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will permanently delete all your period tracking data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await PeriodStorageService.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data cleared'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
