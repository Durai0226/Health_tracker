import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/aqua_theme.dart';

/// Water Reminders Settings Screen
class WaterRemindersSettingsScreen extends StatefulWidget {
  const WaterRemindersSettingsScreen({super.key});

  @override
  State<WaterRemindersSettingsScreen> createState() => _WaterRemindersSettingsScreenState();
}

class _WaterRemindersSettingsScreenState extends State<WaterRemindersSettingsScreen> {
  bool _remindersEnabled = true;
  int _intervalMinutes = 60;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  bool _smartReminders = true;
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
        _remindersEnabled = prefs.getBool('water_reminders_enabled') ?? true;
        _intervalMinutes = prefs.getInt('water_interval') ?? 60;
        _startTime = _parseTime(prefs.getString('water_start_time')) ?? const TimeOfDay(hour: 8, minute: 0);
        _endTime = _parseTime(prefs.getString('water_end_time')) ?? const TimeOfDay(hour: 22, minute: 0);
        _smartReminders = prefs.getBool('water_smart_reminders') ?? true;
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

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('water_reminders_enabled', _remindersEnabled);
    await prefs.setInt('water_interval', _intervalMinutes);
    await prefs.setString('water_start_time', '${_startTime.hour}:${_startTime.minute}');
    await prefs.setString('water_end_time', '${_endTime.hour}:${_endTime.minute}');
    await prefs.setBool('water_smart_reminders', _smartReminders);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminders saved!'),
          backgroundColor: AquaTheme.waterPrimary,
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AquaTheme.waterPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      HapticFeedback.lightImpact();
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AquaTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AquaTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AquaTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reminders', style: TextStyle(color: AquaTheme.textPrimary, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AquaTheme.waterPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildMainToggle(),
                  if (_remindersEnabled) ...[
                    const SizedBox(height: 16),
                    _buildIntervalCard(),
                    const SizedBox(height: 16),
                    _buildTimeRangeCard(),
                    const SizedBox(height: 16),
                    _buildSmartRemindersCard(),
                  ],
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildMainToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _remindersEnabled ? AquaTheme.waterPrimary.withValues(alpha: 0.1) : AquaTheme.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_outlined, color: _remindersEnabled ? AquaTheme.waterPrimary : AquaTheme.textTertiary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Drink Reminders', style: TextStyle(fontWeight: FontWeight.w600, color: AquaTheme.textPrimary)),
                Text('Get notified to stay hydrated', style: TextStyle(color: AquaTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _remindersEnabled,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              setState(() => _remindersEnabled = v);
            },
            activeColor: AquaTheme.waterPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reminder Interval', style: TextStyle(fontWeight: FontWeight.w600, color: AquaTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Every $_intervalMinutes minutes', style: TextStyle(color: AquaTheme.waterPrimary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Slider(
            value: _intervalMinutes.toDouble(),
            min: 15,
            max: 180,
            divisions: 11,
            activeColor: AquaTheme.waterPrimary,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _intervalMinutes = v.round());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Active Hours', style: TextStyle(fontWeight: FontWeight.w600, color: AquaTheme.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTimeButton('Start', _startTime, (t) => setState(() => _startTime = t))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('to', style: TextStyle(color: AquaTheme.textSecondary))),
              Expanded(child: _buildTimeButton('End', _endTime, (t) => setState(() => _endTime = t))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return GestureDetector(
      onTap: () => _selectTime(time, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AquaTheme.waterPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: AquaTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(time.format(context), style: const TextStyle(color: AquaTheme.waterPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRemindersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _smartReminders ? AquaTheme.waterPrimary.withValues(alpha: 0.1) : AquaTheme.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome, color: _smartReminders ? AquaTheme.waterPrimary : AquaTheme.textTertiary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smart Reminders', style: TextStyle(fontWeight: FontWeight.w600, color: AquaTheme.textPrimary)),
                Text('Adjust based on your activity', style: TextStyle(color: AquaTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _smartReminders,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              setState(() => _smartReminders = v);
            },
            activeColor: AquaTheme.waterPrimary,
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
          backgroundColor: AquaTheme.waterPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Save Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
