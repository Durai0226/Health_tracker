
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/fitness_reminder.dart';

class AddFitnessScreen extends StatefulWidget {
  final FitnessReminder? existingReminder;

  const AddFitnessScreen({super.key, this.existingReminder});

  @override
  State<AddFitnessScreen> createState() => _AddFitnessScreenState();
}

class _AddFitnessScreenState extends State<AddFitnessScreen> {
  String _selectedType = 'walk';
  TimeOfDay _selectedTime = TimeOfDay(hour: 7, minute: 0);
  String _selectedFrequency = 'daily';
  int _duration = 30;
  bool _enableReminder = true;

  final List<Map<String, dynamic>> _workoutTypes = [
    {'type': 'walk', 'emoji': '🚶', 'label': 'Walking'},
    {'type': 'run', 'emoji': '🏃', 'label': 'Running'},
    {'type': 'gym', 'emoji': '🏋️', 'label': 'Gym'},
    {'type': 'yoga', 'emoji': '🧘', 'label': 'Yoga'},
    {'type': 'cycling', 'emoji': '🚴', 'label': 'Cycling'},
    {'type': 'swimming', 'emoji': '🏊', 'label': 'Swimming'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingReminder != null) {
      final r = widget.existingReminder!;
      _selectedType = r.type;
      _selectedTime = TimeOfDay(
        hour: r.reminderTime.hour,
        minute: r.reminderTime.minute,
      );
      _selectedFrequency = r.frequency;
      _duration = r.durationMinutes;
      _enableReminder = r.isEnabled;
    }
  }

  void _save() async {
    final now = DateTime.now();
    final String id = widget.existingReminder?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Generate a safe 32-bit ID for notifications (last 9 digits of timestamp)
    final int notificationId = int.parse(id.substring(id.length - 9));

    final reminder = FitnessReminder(
      id: id,
      type: _selectedType,
      title: _workoutTypes.firstWhere((w) => w['type'] == _selectedType)['label'],
      reminderTime: DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute),
      frequency: _selectedFrequency,
      durationMinutes: _duration,
      isEnabled: _enableReminder,
    );

    // Cancel old notification if editing
    final notificationService = NotificationService();
    if (widget.existingReminder != null) {
      final oldId = int.parse(widget.existingReminder!.id.substring(widget.existingReminder!.id.length - 9));
      await notificationService.cancelFitnessNotification(oldId, widget.existingReminder!.frequency);
    }

    await StorageService.addFitnessReminder(reminder);

    if (_enableReminder) {
      await notificationService.scheduleFitnessReminder(
        id: notificationId,
        title: '${reminder.emoji} ${reminder.title}',
        body: 'Time for your ${reminder.durationMinutes} min workout! 💪',
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        frequency: _selectedFrequency,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingReminder != null ? 'Edit Workout' : 'Add Workout',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workout Type Selection
              Text(
                'Workout Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16),
              _buildWorkoutTypeGrid(),
              SizedBox(height: 28),

              // Time Picker
              Text(
                'Reminder Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              _buildTimePicker(),
              SizedBox(height: 28),

              // Duration
              Text(
                'Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              _buildDurationSelector(),
              SizedBox(height: 28),

              // Frequency
              Text(
                'Frequency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              _buildFrequencySelector(),
              SizedBox(height: 28),

              // Reminder Toggle
              _buildReminderToggle(),
              SizedBox(height: 40),

              // Save Button
              _buildSaveButton(),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _workoutTypes.length,
      itemBuilder: (context, index) {
        final workout = _workoutTypes[index];
        final isSelected = _selectedType == workout['type'];

        return GestureDetector(
          onTap: () => setState(() => _selectedType = workout['type']),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(workout['emoji'], style: TextStyle(fontSize: 32)),
                SizedBox(height: 8),
                Text(
                  workout['label'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
        );
        if (time != null) {
          setState(() => _selectedTime = time);
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.access_time_rounded, color: AppColors.primary),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedTime.format(context),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    final durations = [15, 30, 45, 60, 90];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: durations.map((d) {
          final isSelected = _duration == d;
          return Padding(
            padding: EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _duration = d),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  '$d min',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    final frequencies = ['daily', 'weekdays', 'weekends'];

    return Row(
      children: frequencies.map((f) {
        final isSelected = _selectedFrequency == f;
        final label = f[0].toUpperCase() + f.substring(1);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFrequency = f),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReminderToggle() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active_rounded, color: AppColors.warning),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Get notified when it\'s time',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableReminder,
            onChanged: (val) => setState(() => _enableReminder = val),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _save,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.existingReminder != null ? 'Update Workout' : 'Add Workout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
