import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/habit_theme.dart';
import '../../services/habit_service.dart';

/// Habit Reminders Settings Screen
/// Configure habit check-in alerts and notification preferences
class HabitRemindersSettingsScreen extends StatefulWidget {
  const HabitRemindersSettingsScreen({super.key});

  @override
  State<HabitRemindersSettingsScreen> createState() => _HabitRemindersSettingsScreenState();
}

class _HabitRemindersSettingsScreenState extends State<HabitRemindersSettingsScreen> {
  final HabitService _habitService = HabitService();
  
  bool _morningReminder = true;
  bool _afternoonReminder = false;
  bool _eveningReminder = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _afternoonTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 20, minute: 0);
  bool _streakAtRiskReminder = true;
  bool _weeklyProgressReminder = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _habitService.getReminderSettings();
    if (mounted) {
      setState(() {
        _morningReminder = settings['morningReminder'] ?? true;
        _afternoonReminder = settings['afternoonReminder'] ?? false;
        _eveningReminder = settings['eveningReminder'] ?? true;
        _morningTime = _parseTime(settings['morningTime']) ?? const TimeOfDay(hour: 8, minute: 0);
        _afternoonTime = _parseTime(settings['afternoonTime']) ?? const TimeOfDay(hour: 14, minute: 0);
        _eveningTime = _parseTime(settings['eveningTime']) ?? const TimeOfDay(hour: 20, minute: 0);
        _streakAtRiskReminder = settings['streakAtRisk'] ?? true;
        _weeklyProgressReminder = settings['weeklyProgress'] ?? true;
        _isLoading = false;
      });
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    await _habitService.saveReminderSettings({
      'morningReminder': _morningReminder,
      'afternoonReminder': _afternoonReminder,
      'eveningReminder': _eveningReminder,
      'morningTime': _formatTime(_morningTime),
      'afternoonTime': _formatTime(_afternoonTime),
      'eveningTime': _formatTime(_eveningTime),
      'streakAtRisk': _streakAtRiskReminder,
      'weeklyProgress': _weeklyProgressReminder,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminders saved successfully!'),
          backgroundColor: HabitTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _selectTime(TimeOfDay current, ValueChanged<TimeOfDay> onChanged) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: HabitTheme.primary,
              onPrimary: HabitTheme.white,
              surface: HabitTheme.white,
              onSurface: HabitTheme.dark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      HapticFeedback.lightImpact();
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: HabitTheme.dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reminders',
          style: HabitTheme.h2.copyWith(color: HabitTheme.dark),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: HabitTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(HabitTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Daily Check-ins'),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildReminderCard(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Morning Reminder',
                    time: _morningTime,
                    enabled: _morningReminder,
                    onToggle: (v) => setState(() => _morningReminder = v),
                    onTimeChanged: (t) => setState(() => _morningTime = t),
                  ),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildReminderCard(
                    icon: Icons.wb_cloudy_outlined,
                    title: 'Afternoon Reminder',
                    time: _afternoonTime,
                    enabled: _afternoonReminder,
                    onToggle: (v) => setState(() => _afternoonReminder = v),
                    onTimeChanged: (t) => setState(() => _afternoonTime = t),
                  ),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildReminderCard(
                    icon: Icons.nights_stay_outlined,
                    title: 'Evening Reminder',
                    time: _eveningTime,
                    enabled: _eveningReminder,
                    onToggle: (v) => setState(() => _eveningReminder = v),
                    onTimeChanged: (t) => setState(() => _eveningTime = t),
                  ),
                  const SizedBox(height: HabitTheme.spacingL),
                  
                  _buildSectionTitle('Progress Alerts'),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildToggleCard(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Streak at Risk',
                    subtitle: 'Alert when you might lose your streak',
                    value: _streakAtRiskReminder,
                    onChanged: (v) => setState(() => _streakAtRiskReminder = v),
                  ),
                  const SizedBox(height: HabitTheme.spacingS),
                  _buildToggleCard(
                    icon: Icons.insights_outlined,
                    title: 'Weekly Progress',
                    subtitle: 'Get your weekly habit summary',
                    value: _weeklyProgressReminder,
                    onChanged: (v) => setState(() => _weeklyProgressReminder = v),
                  ),
                  const SizedBox(height: HabitTheme.spacingXL),
                  
                  _buildSaveButton(),
                  const SizedBox(height: HabitTheme.spacingL),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: HabitTheme.label.copyWith(
          color: HabitTheme.dark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReminderCard({
    required IconData icon,
    required String title,
    required TimeOfDay time,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(HabitTheme.spacingM),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? HabitTheme.primarySoft : HabitTheme.grayLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: enabled ? HabitTheme.primary : HabitTheme.gray,
              size: 24,
            ),
          ),
          const SizedBox(width: HabitTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HabitTheme.label.copyWith(color: HabitTheme.dark),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: enabled ? () => _selectTime(time, onTimeChanged) : null,
                  child: Text(
                    time.format(context),
                    style: HabitTheme.b3.copyWith(
                      color: enabled ? HabitTheme.primary : HabitTheme.gray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onToggle(v);
            },
            activeColor: HabitTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(HabitTheme.spacingM),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: HabitTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: value ? HabitTheme.primarySoft : HabitTheme.grayLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? HabitTheme.primary : HabitTheme.gray,
              size: 24,
            ),
          ),
          const SizedBox(width: HabitTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HabitTheme.label.copyWith(color: HabitTheme.dark)),
                const SizedBox(height: 4),
                Text(subtitle, style: HabitTheme.b3.copyWith(color: HabitTheme.gray)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeColor: HabitTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: HabitTheme.primary,
          foregroundColor: HabitTheme.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Save Reminders',
          style: HabitTheme.label.copyWith(
            color: HabitTheme.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
