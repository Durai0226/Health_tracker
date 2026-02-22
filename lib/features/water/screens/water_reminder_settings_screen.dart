import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/water_reminder.dart';

class WaterReminderSettingsScreen extends StatefulWidget {
  const WaterReminderSettingsScreen({super.key});

  @override
  State<WaterReminderSettingsScreen> createState() => _WaterReminderSettingsScreenState();
}

class _WaterReminderSettingsScreenState extends State<WaterReminderSettingsScreen> {
  bool _isEnabled = false;
  List<TimeOfDay> _reminderTimes = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  int _intervalMinutes = 120;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final existing = StorageService.getWaterReminder();
    if (existing != null) {
      setState(() {
        _isEnabled = existing.isEnabled;
        _reminderTimes = existing.reminderTimes.map((dt) => TimeOfDay(hour: dt.hour, minute: dt.minute)).toList();
        _startTime = existing.startTime != null ? TimeOfDay(hour: existing.startTime!.hour, minute: existing.startTime!.minute) : _startTime;
        _endTime = existing.endTime != null ? TimeOfDay(hour: existing.endTime!.hour, minute: existing.endTime!.minute) : _endTime;
        _intervalMinutes = existing.intervalMinutes;
      });
    }
  }

  void _generateIntervalReminders() {
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;

    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final times = <TimeOfDay>[];
    for (int minutes = start; minutes <= end; minutes += _intervalMinutes) {
      times.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    }

    setState(() {
      _reminderTimes = times;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated ${times.length} reminder times'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addCustomTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _reminderTimes.add(time);
        _reminderTimes.sort((a, b) {
          final aMinutes = a.hour * 60 + a.minute;
          final bMinutes = b.hour * 60 + b.minute;
          return aMinutes.compareTo(bMinutes);
        });
      });
    }
  }

  void _removeTime(int index) {
    setState(() {
      _reminderTimes.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one reminder time'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final reminderDateTimes = _reminderTimes.map((time) {
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    }).toList();

    final reminder = WaterReminder(
      id: const Uuid().v4(),
      reminderTimes: reminderDateTimes,
      intervalMinutes: _intervalMinutes,
      isEnabled: _isEnabled,
      startTime: DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute),
      endTime: DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute),
    );

    await StorageService.saveWaterReminder(reminder);

    final notificationService = NotificationService();
    if (_isEnabled) {
      int successCount = 0;
      for (int i = 0; i < _reminderTimes.length; i++) {
        final time = _reminderTimes[i];
        final scheduled = await notificationService.scheduleWaterReminder(
          id: 900000 + i,
          hour: time.hour,
          minute: time.minute,
        );
        if (scheduled) successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount water reminders scheduled'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      final ids = List.generate(_reminderTimes.length, (i) => 900000 + i);
      await notificationService.cancelWaterReminders(ids);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Water Reminders'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnableToggle(),
            const SizedBox(height: 24),
            const Text(
              'Reminder Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildIntervalControls(),
            const SizedBox(height: 24),
            _buildReminderTimesList(),
            const SizedBox(height: 16),
            _buildAddTimeButton(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.water_drop_rounded, color: AppColors.info),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water Reminders', style: TextStyle(fontWeight: FontWeight.w600)),
                Text('Get reminded to stay hydrated', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: _isEnabled,
            onChanged: (val) => setState(() => _isEnabled = val),
            activeThumbColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Auto-generate by interval', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: _startTime);
                    if (time != null) setState(() => _startTime = time);
                  },
                  child: _buildTimeField('Start', _startTime),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: _endTime);
                    if (time != null) setState(() => _endTime = time);
                  },
                  child: _buildTimeField('End', _endTime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Every $_intervalMinutes minutes', style: const TextStyle(color: AppColors.textSecondary)),
          Slider(
            value: _intervalMinutes.toDouble(),
            min: 30,
            max: 240,
            divisions: 21,
            activeColor: AppColors.info,
            onChanged: (val) => setState(() => _intervalMinutes = val.toInt()),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CommonButton(
              text: 'Generate Times',
              icon: Icons.auto_fix_high_rounded,
              variant: ButtonVariant.primary,
              backgroundColor: AppColors.info,
              onPressed: _generateIntervalReminders,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, TimeOfDay time) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            time.format(context),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTimesList() {
    if (_reminderTimes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.schedule_rounded, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No reminder times set',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: _reminderTimes.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alarm_rounded, color: AppColors.info, size: 20),
            ),
            title: Text(
              time.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.error),
              onPressed: () => _removeTime(index),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddTimeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addCustomTime,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Custom Time'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.info),
          foregroundColor: AppColors.info,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.info,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Save Water Reminders'),
      ),
    );
  }
}
