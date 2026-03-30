/// Exam Prep Notification Settings Screen
/// Configure all 8 notification types

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/exam_notification_service.dart';
import '../models/exam_notification_model.dart';
import '../theme/exam_prep_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late ExamNotificationSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final service = context.read<ExamNotificationService>();
    setState(() {
      _settings = service.settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final service = context.read<ExamNotificationService>();
    await service.updateSettings(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification settings saved'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ExamPrepTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ExamPrepTheme.getTextPrimary(context),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: TextStyle(
                color: ExamPrepTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Daily Reminders', Icons.today),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Daily Practice Reminder',
                subtitle: 'Get reminded to practice every day',
                icon: Icons.school,
                value: _settings.dailyPracticeEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(dailyPracticeEnabled: value);
                  });
                },
              ),
              if (_settings.dailyPracticeEnabled)
                _buildTimeTile(
                  title: 'Reminder Time',
                  time: _settings.dailyPracticeTime,
                  onChanged: (time) {
                    setState(() {
                      _settings = _settings.copyWith(dailyPracticeTime: time);
                    });
                  },
                ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Streak Alerts', Icons.local_fire_department),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Streak Protection Alerts',
                subtitle: 'Get notified before losing your streak',
                icon: Icons.whatshot,
                value: _settings.streakAlertsEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(streakAlertsEnabled: value);
                  });
                },
              ),
              if (_settings.streakAlertsEnabled)
                _buildTimeTile(
                  title: 'Alert Time',
                  time: _settings.streakAlertTime,
                  onChanged: (time) {
                    setState(() {
                      _settings = _settings.copyWith(streakAlertTime: time);
                    });
                  },
                ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Mock Tests', Icons.quiz),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Mock Test Reminders',
                subtitle: 'Get reminded before scheduled tests',
                icon: Icons.alarm,
                value: _settings.mockTestRemindersEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(mockTestRemindersEnabled: value);
                  });
                },
              ),
              if (_settings.mockTestRemindersEnabled)
                _buildDropdownTile(
                  title: 'Remind Before',
                  value: _settings.mockTestReminderMinutesBefore,
                  items: const [15, 30, 45, 60],
                  labels: const ['15 minutes', '30 minutes', '45 minutes', '1 hour'],
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(mockTestReminderMinutesBefore: value);
                    });
                  },
                ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Current Affairs', Icons.newspaper),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Current Affairs Updates',
                subtitle: 'Weekly current affairs digest',
                icon: Icons.article,
                value: _settings.currentAffairsEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(currentAffairsEnabled: value);
                  });
                },
              ),
              if (_settings.currentAffairsEnabled)
                _buildDropdownTile(
                  title: 'Update Day',
                  value: _settings.currentAffairsDay,
                  items: const [0, 1, 2, 3, 4, 5, 6],
                  labels: const ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(currentAffairsDay: value);
                    });
                  },
                ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Exam Date Alerts', Icons.event),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Exam Date Reminders',
                subtitle: 'Get countdown reminders for your exams',
                icon: Icons.calendar_today,
                value: _settings.examDateAlertsEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(examDateAlertsEnabled: value);
                  });
                },
              ),
              if (_settings.examDateAlertsEnabled)
                _buildMultiSelectTile(
                  title: 'Remind Before',
                  values: _settings.examDateAlertDaysBefore,
                  allOptions: const [1, 7, 15, 30, 60, 90],
                  labels: const ['1 day', '1 week', '15 days', '1 month', '2 months', '3 months'],
                  onChanged: (values) {
                    setState(() {
                      _settings = _settings.copyWith(examDateAlertDaysBefore: values);
                    });
                  },
                ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Performance & Progress', Icons.analytics),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Performance Alerts',
                subtitle: 'Get insights on weak areas',
                icon: Icons.insights,
                value: _settings.performanceAlertsEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(performanceAlertsEnabled: value);
                  });
                },
              ),
              const Divider(),
              _buildSwitchTile(
                title: 'Weekly Progress Report',
                subtitle: 'Get a summary of your weekly progress',
                icon: Icons.bar_chart,
                value: _settings.weeklyProgressEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(weeklyProgressEnabled: value);
                  });
                },
              ),
              if (_settings.weeklyProgressEnabled) ...[
                _buildDropdownTile(
                  title: 'Report Day',
                  value: _settings.weeklyProgressDay,
                  items: const [0, 1, 2, 3, 4, 5, 6],
                  labels: const ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
                  onChanged: (value) {
                    setState(() {
                      _settings = _settings.copyWith(weeklyProgressDay: value);
                    });
                  },
                ),
                _buildTimeTile(
                  title: 'Report Time',
                  time: _settings.weeklyProgressTime,
                  onChanged: (time) {
                    setState(() {
                      _settings = _settings.copyWith(weeklyProgressTime: time);
                    });
                  },
                ),
              ],
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Achievements', Icons.emoji_events),
            _buildSettingsCard([
              _buildSwitchTile(
                title: 'Achievement Notifications',
                subtitle: 'Get notified when you unlock achievements',
                icon: Icons.celebration,
                value: _settings.achievementsEnabled,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(achievementsEnabled: value);
                  });
                },
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: ExamPrepTheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: ExamPrepTheme.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: ExamPrepTheme.getCardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          color: ExamPrepTheme.getTextPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: ExamPrepTheme.getTextSecondary(context),
          fontSize: 12,
        ),
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value 
              ? ExamPrepTheme.primary.withOpacity(0.1) 
              : ExamPrepTheme.getTextSecondary(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: value ? ExamPrepTheme.primary : ExamPrepTheme.getTextSecondary(context),
          size: 20,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: ExamPrepTheme.primary,
    );
  }

  Widget _buildTimeTile({
    required String title,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: ExamPrepTheme.getTextPrimary(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: TextButton(
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        child: Text(
          time.format(context),
          style: TextStyle(
            color: ExamPrepTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required T value,
    required List<T> items,
    required List<String> labels,
    required ValueChanged<T> onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: ExamPrepTheme.getTextPrimary(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: DropdownButton<T>(
        value: value,
        items: List.generate(items.length, (index) {
          return DropdownMenuItem<T>(
            value: items[index],
            child: Text(labels[index]),
          );
        }),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
        underline: const SizedBox(),
        style: TextStyle(
          color: ExamPrepTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        dropdownColor: ExamPrepTheme.getCardBg(context),
      ),
    );
  }

  Widget _buildMultiSelectTile({
    required String title,
    required List<int> values,
    required List<int> allOptions,
    required List<String> labels,
    required ValueChanged<List<int>> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ExamPrepTheme.getTextPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(allOptions.length, (index) {
              final option = allOptions[index];
              final isSelected = values.contains(option);
              return FilterChip(
                label: Text(labels[index]),
                selected: isSelected,
                onSelected: (selected) {
                  final newValues = List<int>.from(values);
                  if (selected) {
                    newValues.add(option);
                  } else {
                    newValues.remove(option);
                  }
                  newValues.sort();
                  onChanged(newValues);
                },
                selectedColor: ExamPrepTheme.primary.withOpacity(0.2),
                checkmarkColor: ExamPrepTheme.primary,
                labelStyle: TextStyle(
                  color: isSelected 
                      ? ExamPrepTheme.primary 
                      : ExamPrepTheme.getTextSecondary(context),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
