import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/fitness_theme.dart';

/// Fitness Reminders Settings Screen
class FitnessRemindersSettingsScreen extends StatefulWidget {
  const FitnessRemindersSettingsScreen({super.key});

  @override
  State<FitnessRemindersSettingsScreen> createState() => _FitnessRemindersSettingsScreenState();
}

class _FitnessRemindersSettingsScreenState extends State<FitnessRemindersSettingsScreen> {
  bool _workoutReminders = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 0);
  List<bool> _selectedDays = [true, true, true, true, true, false, false];
  bool _restDayReminders = true;
  bool _goalReminders = true;
  bool _isLoading = true;

  final _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _workoutReminders = prefs.getBool('fitness_workout_reminders') ?? true;
        final timeStr = prefs.getString('fitness_reminder_time') ?? '7:0';
        final parts = timeStr.split(':');
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        final daysStr = prefs.getString('fitness_reminder_days') ?? '1,1,1,1,1,0,0';
        _selectedDays = daysStr.split(',').map((e) => e == '1').toList();
        _restDayReminders = prefs.getBool('fitness_rest_reminders') ?? true;
        _goalReminders = prefs.getBool('fitness_goal_reminders') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fitness_workout_reminders', _workoutReminders);
    await prefs.setString('fitness_reminder_time', '${_reminderTime.hour}:${_reminderTime.minute}');
    await prefs.setString('fitness_reminder_days', _selectedDays.map((e) => e ? '1' : '0').join(','));
    await prefs.setBool('fitness_rest_reminders', _restDayReminders);
    await prefs.setBool('fitness_goal_reminders', _goalReminders);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminders saved!'),
          backgroundColor: FitnessTheme.primary,
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
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: FitnessTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      HapticFeedback.lightImpact();
      setState(() => _reminderTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FitnessTheme.themeData,
      child: Scaffold(
        backgroundColor: FitnessTheme.background,
        appBar: AppBar(
          backgroundColor: FitnessTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Workout Reminders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: FitnessTheme.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                child: Column(
                  children: [
                    _buildMainToggle(),
                    if (_workoutReminders) ...[
                      const SizedBox(height: FitnessTheme.spacingMd),
                      _buildTimeCard(),
                      const SizedBox(height: FitnessTheme.spacingMd),
                      _buildDaysCard(),
                    ],
                    const SizedBox(height: FitnessTheme.spacingMd),
                    _buildOtherReminders(),
                    const SizedBox(height: FitnessTheme.spacingLg),
                    _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _workoutReminders ? FitnessTheme.primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications, color: _workoutReminders ? FitnessTheme.primary : Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Workout Reminders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('Get notified for scheduled workouts', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          ),
          Switch.adaptive(value: _workoutReminders, onChanged: (v) { HapticFeedback.lightImpact(); setState(() => _workoutReminders = v); }, activeColor: FitnessTheme.primary),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: GestureDetector(
        onTap: _selectTime,
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: FitnessTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.access_time, color: FitnessTheme.primary),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Reminder Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: FitnessTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text(_reminderTime.format(context), style: TextStyle(color: FitnessTheme.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysCard() {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Workout Days', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isSelected = _selectedDays[index];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedDays[index] = !isSelected);
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? FitnessTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? FitnessTheme.primary : Colors.grey),
                  ),
                  child: Center(child: Text(_dayNames[index][0], style: TextStyle(color: isSelected ? FitnessTheme.background : Colors.grey, fontWeight: FontWeight.w600))),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherReminders() {
    return Container(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      decoration: BoxDecoration(color: FitnessTheme.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildToggleRow(Icons.hotel, 'Rest Day Reminders', 'Remind to take rest days', _restDayReminders, (v) => setState(() => _restDayReminders = v)),
          Divider(color: Colors.grey[800], height: 24),
          _buildToggleRow(Icons.emoji_events, 'Goal Reminders', 'Alert when close to goals', _goalReminders, (v) => setState(() => _goalReminders = v)),
        ],
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: value ? FitnessTheme.primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: value ? FitnessTheme.primary : Colors.grey, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); }, activeColor: FitnessTheme.primary),
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
          backgroundColor: FitnessTheme.primary,
          foregroundColor: FitnessTheme.background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
