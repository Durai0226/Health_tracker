import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/mood_theme.dart';

/// Mood Check-in Reminders Settings Screen
class MoodRemindersSettingsScreen extends StatefulWidget {
  const MoodRemindersSettingsScreen({super.key});

  @override
  State<MoodRemindersSettingsScreen> createState() => _MoodRemindersSettingsScreenState();
}

class _MoodRemindersSettingsScreenState extends State<MoodRemindersSettingsScreen> {
  bool _dailyReminder = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _weeklyInsights = true;
  bool _streakReminder = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dailyReminder = prefs.getBool('mood_daily_reminder') ?? true;
        final timeStr = prefs.getString('mood_reminder_time') ?? '20:00';
        final parts = timeStr.split(':');
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        _weeklyInsights = prefs.getBool('mood_weekly_insights') ?? true;
        _streakReminder = prefs.getBool('mood_streak_reminder') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mood_daily_reminder', _dailyReminder);
    await prefs.setString('mood_reminder_time', '${_reminderTime.hour}:${_reminderTime.minute}');
    await prefs.setBool('mood_weekly_insights', _weeklyInsights);
    await prefs.setBool('mood_streak_reminder', _streakReminder);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminders saved!'),
          backgroundColor: MoodTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
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
    if (picked != null) {
      HapticFeedback.lightImpact();
      setState(() => _reminderTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoodTheme.background,
      appBar: AppBar(
        backgroundColor: MoodTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: MoodTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Check-in Reminders', style: MoodTheme.headingSm.copyWith(color: MoodTheme.textPrimary)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: MoodTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(MoodTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReminderCard(),
                  const SizedBox(height: MoodTheme.spacingMd),
                  _buildInsightsCard(),
                  const SizedBox(height: MoodTheme.spacingLg),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildReminderCard() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: MoodTheme.borderRadiusLg,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _dailyReminder ? MoodTheme.purple50 : MoodTheme.beige50,
                  borderRadius: MoodTheme.borderRadiusSm,
                ),
                child: Icon(Icons.notifications_outlined, 
                  color: _dailyReminder ? MoodTheme.primary : MoodTheme.textMuted),
              ),
              const SizedBox(width: MoodTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Check-in', style: MoodTheme.titleMd.copyWith(color: MoodTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Remind me to log my mood', style: MoodTheme.bodySm.copyWith(color: MoodTheme.textMuted)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _dailyReminder,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _dailyReminder = v);
                },
                activeColor: MoodTheme.primary,
              ),
            ],
          ),
          if (_dailyReminder) ...[
            const SizedBox(height: MoodTheme.spacingMd),
            Divider(color: MoodTheme.beige100),
            const SizedBox(height: MoodTheme.spacingSm),
            GestureDetector(
              onTap: _selectTime,
              child: Row(
                children: [
                  Icon(Icons.access_time, color: MoodTheme.primary, size: 20),
                  const SizedBox(width: MoodTheme.spacingSm),
                  Text('Reminder Time', style: MoodTheme.bodySm.copyWith(color: MoodTheme.textSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: MoodTheme.purple50,
                      borderRadius: MoodTheme.borderRadiusSm,
                    ),
                    child: Text(
                      _reminderTime.format(context),
                      style: MoodTheme.titleSm.copyWith(color: MoodTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(MoodTheme.spacingMd),
      decoration: BoxDecoration(
        color: MoodTheme.surface,
        borderRadius: MoodTheme.borderRadiusLg,
        boxShadow: MoodTheme.softShadow,
      ),
      child: Column(
        children: [
          _buildToggleRow(
            icon: Icons.insights_outlined,
            title: 'Weekly Insights',
            subtitle: 'Get mood pattern summary',
            value: _weeklyInsights,
            onChanged: (v) => setState(() => _weeklyInsights = v),
          ),
          Divider(color: MoodTheme.beige100, height: MoodTheme.spacingLg),
          _buildToggleRow(
            icon: Icons.local_fire_department_outlined,
            title: 'Streak Reminder',
            subtitle: 'Alert when streak is at risk',
            value: _streakReminder,
            onChanged: (v) => setState(() => _streakReminder = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: value ? MoodTheme.purple50 : MoodTheme.beige50,
            borderRadius: MoodTheme.borderRadiusSm,
          ),
          child: Icon(icon, color: value ? MoodTheme.primary : MoodTheme.textMuted),
        ),
        const SizedBox(width: MoodTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MoodTheme.titleMd.copyWith(color: MoodTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: MoodTheme.bodySm.copyWith(color: MoodTheme.textMuted)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: (v) {
            HapticFeedback.lightImpact();
            onChanged(v);
          },
          activeColor: MoodTheme.primary,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: MoodTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: MoodTheme.borderRadiusLg),
        ),
        child: Text('Save Reminders', style: MoodTheme.titleMd.copyWith(color: Colors.white)),
      ),
    );
  }
}
