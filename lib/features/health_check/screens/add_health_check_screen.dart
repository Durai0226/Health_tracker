
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../models/health_check.dart';
import 'package:uuid/uuid.dart';

class AddHealthCheckScreen extends StatefulWidget {
  final HealthCheck? existingCheck; // null for new, pass existing for edit

  const AddHealthCheckScreen({super.key, this.existingCheck});

  @override
  State<AddHealthCheckScreen> createState() => _AddHealthCheckScreenState();
}

class _AddHealthCheckScreenState extends State<AddHealthCheckScreen> {
  String _selectedType = 'sugar'; // 'sugar' or 'pressure'
  String _title = '';
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String _frequency = 'Once a day';
  bool _enableReminder = true;
  bool _isSaving = false;

  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingCheck != null) {
      _selectedType = widget.existingCheck!.type;
      _title = widget.existingCheck!.title;
      _titleController.text = _title;
      _time = TimeOfDay.fromDateTime(widget.existingCheck!.reminderTime);
      _frequency = widget.existingCheck!.frequency;
      _enableReminder = widget.existingCheck!.enableReminder;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final notificationService = NotificationService();
      final isEditing = widget.existingCheck != null;
      final wasReminderEnabled = widget.existingCheck?.enableReminder ?? false;
      
      final title = _title.isEmpty
          ? (_selectedType == 'sugar' ? 'Blood Sugar Check' : 'Blood Pressure Check')
          : _title;

      final check = HealthCheck(
        id: widget.existingCheck?.id ?? const Uuid().v4(),
        type: _selectedType,
        title: title,
        reminderTime: DateTime(2024, 1, 1, _time.hour, _time.minute),
        frequency: _frequency,
        enableReminder: _enableReminder,
      );

      // Save to storage first
      if (isEditing) {
        await StorageService.updateHealthCheck(check);
      } else {
        await StorageService.addHealthCheck(check);
      }

      bool scheduled = false;
      String message = '';
      
      if (_enableReminder) {
        // Cancel old notification first (non-blocking)
        if (isEditing) {
          unawaited(notificationService.cancelNotification(widget.existingCheck!.id.hashCode)
              .catchError((e) => debugPrint('Cancel error: $e')));
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        scheduled = await notificationService.scheduleHealthCheckReminder(
          id: check.id.hashCode,
          checkType: _selectedType,
          hour: _time.hour,
          minute: _time.minute,
          frequency: _frequency,
        );

        if (scheduled) {
          message = 'Reminder set for ${_time.format(context)}';
          // Show confirmation (non-blocking)
          unawaited(notificationService.showImmediateNotification(
            title: _selectedType == 'sugar' ? 'Sugar Check 🩸' : 'BP Check ❤️',
            body: '${isEditing ? "Updated" : "Added"} - ${_time.format(context)}',
            channelId: 'health_channel',
          ).catchError((e) { debugPrint('Notification error: $e'); return false; }));
        } else {
          message = 'Saved but reminder failed. Check permissions.';
        }
      } else {
        if (isEditing && wasReminderEnabled) {
          unawaited(notificationService.cancelNotification(widget.existingCheck!.id.hashCode)
              .catchError((e) => debugPrint('Cancel error: $e')));
        }
        message = 'Health check saved';
        scheduled = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: scheduled ? AppColors.success : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving health check: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCheck != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isEditing ? 'Edit Health Check' : 'Add Health Check'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selection
              Text('Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeCard(
                    type: 'sugar',
                    title: 'Blood Sugar',
                    emoji: '🩸',
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 16),
                  _buildTypeCard(
                    type: 'pressure',
                    title: 'Blood Pressure',
                    emoji: '❤️',
                    color: AppColors.periodPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Custom Title
              Text('Title (Optional)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                onChanged: (val) => setState(() => _title = val),
                decoration: InputDecoration(
                  hintText: _selectedType == 'sugar' ? 'e.g., Morning Sugar Check' : 'e.g., Evening BP Check',
                  prefixIcon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // Reminder Time
              Text('Reminder Time', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: _selectedType == 'sugar'
                        ? LinearGradient(colors: [AppColors.error, AppColors.error.withOpacity(0.7)])
                        : AppColors.periodGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedType == 'sugar' ? AppColors.error : AppColors.periodPrimary).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        _time.format(context),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Frequency
              Text('Frequency', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                items: ['Once a day', 'Twice a day', 'Every week']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _frequency = val!),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.repeat_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 32),

              // Enable Reminder Toggle
              Container(
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
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('Get reminded with custom ringtone', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
              ),
              const SizedBox(height: 48),

              // Save Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _selectedType == 'sugar'
                      ? LinearGradient(colors: [AppColors.error, AppColors.error.withOpacity(0.8)])
                      : AppColors.periodGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_selectedType == 'sugar' ? AppColors.error : AppColors.periodPrimary).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded),
                            const SizedBox(width: 8),
                            Text(isEditing ? 'Update Health Check' : 'Save Health Check'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required String type,
    required String title,
    required String emoji,
    required Color color,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
