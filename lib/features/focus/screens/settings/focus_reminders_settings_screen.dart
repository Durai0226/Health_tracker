import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Focus Reminders Settings Screen
class FocusRemindersSettingsScreen extends StatefulWidget {
  const FocusRemindersSettingsScreen({super.key});

  @override
  State<FocusRemindersSettingsScreen> createState() => _FocusRemindersSettingsScreenState();
}

class _FocusRemindersSettingsScreenState extends State<FocusRemindersSettingsScreen> {
  bool _dailyReminder = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _streakReminder = true;
  bool _breakReminder = true;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dailyReminder = prefs.getBool('focus_daily_reminder') ?? true;
        final timeStr = prefs.getString('focus_reminder_time') ?? '9:0';
        final parts = timeStr.split(':');
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        _streakReminder = prefs.getBool('focus_streak_reminder') ?? true;
        _breakReminder = prefs.getBool('focus_break_reminder') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('focus_daily_reminder', _dailyReminder);
    await prefs.setString('focus_reminder_time', '${_reminderTime.hour}:${_reminderTime.minute}');
    await prefs.setBool('focus_streak_reminder', _streakReminder);
    await prefs.setBool('focus_break_reminder', _breakReminder);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Reminders saved!'), backgroundColor: _primaryColor, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: _primaryColor)), child: child!),
    );
    if (picked != null) {
      HapticFeedback.lightImpact();
      setState(() => _reminderTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Focus Reminders', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDailyReminderCard(),
                  const SizedBox(height: 12),
                  _buildToggleCard(Icons.local_fire_department, 'Streak Reminder', 'Alert when streak is at risk', _streakReminder, (v) => setState(() => _streakReminder = v)),
                  const SizedBox(height: 12),
                  _buildToggleCard(Icons.coffee, 'Break Reminder', 'Remind to take breaks', _breakReminder, (v) => setState(() => _breakReminder = v)),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDailyReminderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _dailyReminder ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.notifications, color: _dailyReminder ? _primaryColor : Colors.grey)),
              const SizedBox(width: 16),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Daily Focus Reminder', style: TextStyle(fontWeight: FontWeight.w600)), Text('Get reminded to focus each day', style: TextStyle(color: Colors.grey, fontSize: 13))])),
              Switch.adaptive(value: _dailyReminder, onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _dailyReminder = v); }, activeColor: _primaryColor),
            ],
          ),
          if (_dailyReminder) ...[
            const Divider(height: 24),
            GestureDetector(
              onTap: _selectTime,
              child: Row(
                children: [
                  Icon(Icons.access_time, color: _primaryColor, size: 20),
                  const SizedBox(width: 12),
                  const Text('Reminder Time', style: TextStyle(color: Colors.grey)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(_reminderTime.format(context), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleCard(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: value ? _primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: value ? _primaryColor : Colors.grey)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13))])),
          Switch.adaptive(value: value, onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); }, activeColor: _primaryColor),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Save Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
    );
  }
}
