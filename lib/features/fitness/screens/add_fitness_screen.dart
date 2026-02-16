
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/fitness_reminder_service.dart';
import '../models/fitness_reminder.dart';

class AddFitnessScreen extends StatefulWidget {
  final FitnessReminder? existingReminder;

  const AddFitnessScreen({super.key, this.existingReminder});

  @override
  State<AddFitnessScreen> createState() => _AddFitnessScreenState();
}

class _AddFitnessScreenState extends State<AddFitnessScreen> {
  String _selectedType = 'walk';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  String _selectedFrequency = 'daily';
  int _duration = 30;
  bool _enableReminder = true;
  bool _isSaving = false;

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

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final reminderService = FitnessReminderService();
      final isEditing = widget.existingReminder != null;
      
      final now = DateTime.now();
      final String id = widget.existingReminder?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final reminder = FitnessReminder(
        id: id,
        type: _selectedType,
        title: _workoutTypes.firstWhere((w) => w['type'] == _selectedType)['label'],
        reminderTime: DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute),
        frequency: _selectedFrequency,
        durationMinutes: _duration,
        isEnabled: _enableReminder,
      );

      bool success = false;
      String message = '';
      
      if (isEditing) {
        // Use the service to update (handles cancellation and rescheduling)
        success = await reminderService.updateReminder(
          widget.existingReminder!,
          reminder,
        );
        message = success 
            ? (_enableReminder 
                ? 'Updated! Reminder set for ${_selectedTime.format(context)}'
                : 'Workout updated')
            : 'Saved but reminder may not work. Check permissions.';
      } else {
        // Save to storage first
        await StorageService.addFitnessReminder(reminder);
        
        if (_enableReminder) {
          // Schedule with retry logic
          success = await reminderService.scheduleReminder(reminder);
          message = success 
              ? 'Reminder set for ${_selectedTime.format(context)}'
              : 'Saved but reminder failed. Check permissions.';
        } else {
          success = true;
          message = 'Workout saved';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: success ? AppColors.success : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving fitness reminder: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Failed to save. Please try again.'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingReminder != null ? 'Edit Workout' : 'Add Workout',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Workout Type Selection
              const Text(
                'Workout Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildWorkoutTypeGrid(),
              const SizedBox(height: 28),

              // Time Picker
              const Text(
                'Reminder Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildTimePicker(),
              const SizedBox(height: 28),

              // Duration
              const Text(
                'Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildDurationSelector(),
              const SizedBox(height: 28),

              // Frequency
              const Text(
                'Frequency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildFrequencySelector(),
              const SizedBox(height: 28),

              // Reminder Toggle
              _buildReminderToggle(),
              const SizedBox(height: 40),

              // Save Button
              _buildSaveButton(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            duration: const Duration(milliseconds: 200),
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
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(workout['emoji'], style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.access_time_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _selectedTime.format(context),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _duration = d),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFrequency = f),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
          ),
          const SizedBox(width: 16),
          const Expanded(
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
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: _isSaving ? null : AppColors.primaryGradient,
          color: _isSaving ? AppColors.primary.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSaving ? [] : [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.existingReminder != null ? 'Update Workout' : 'Add Workout',
                  style: const TextStyle(
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
