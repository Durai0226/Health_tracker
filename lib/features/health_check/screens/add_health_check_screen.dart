
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
  TimeOfDay _time = TimeOfDay(hour: 8, minute: 0);
  String _frequency = 'Once a day';
  bool _enableReminder = true;

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

    if (widget.existingCheck != null) {
      await StorageService.updateHealthCheck(check);
    } else {
      await StorageService.addHealthCheck(check);
    }

    // Schedule notification if enabled
    if (_enableReminder) {
      await NotificationService().scheduleHealthCheckReminder(
        id: check.id.hashCode,
        checkType: _selectedType,
        hour: _time.hour,
        minute: _time.minute,
        frequency: _frequency,
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCheck != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isEditing ? 'Edit Health Check' : 'Add Health Check'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selection
              Text('Type', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeCard(
                    type: 'sugar',
                    title: 'Blood Sugar',
                    emoji: '🩸',
                    color: AppColors.error,
                  ),
                  SizedBox(width: 16),
                  _buildTypeCard(
                    type: 'pressure',
                    title: 'Blood Pressure',
                    emoji: '❤️',
                    color: AppColors.periodPrimary,
                  ),
                ],
              ),
              SizedBox(height: 32),

              // Custom Title
              Text('Title (Optional)', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 12),
              TextField(
                controller: _titleController,
                onChanged: (val) => setState(() => _title = val),
                decoration: InputDecoration(
                  hintText: _selectedType == 'sugar' ? 'e.g., Morning Sugar Check' : 'e.g., Evening BP Check',
                  prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary),
                ),
              ),
              SizedBox(height: 32),

              // Reminder Time
              Text('Reminder Time', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time);
                  if (t != null) setState(() => _time = t);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: _selectedType == 'sugar'
                        ? LinearGradient(colors: [AppColors.error, AppColors.error.withOpacity(0.7)])
                        : AppColors.periodGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedType == 'sugar' ? AppColors.error : AppColors.periodPrimary).withOpacity(0.3),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        _time.format(context),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),

              // Frequency
              Text('Frequency', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _frequency,
                items: ['Once a day', 'Twice a day', 'Every week']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => _frequency = val!),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.repeat_rounded, color: AppColors.primary),
                ),
              ),
              SizedBox(height: 32),

              // Enable Reminder Toggle
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    ),
                    SizedBox(width: 16),
                    Expanded(
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
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 48),

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
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded),
                      SizedBox(width: 8),
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
          padding: EdgeInsets.all(20),
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
              Text(emoji, style: TextStyle(fontSize: 32)),
              SizedBox(height: 8),
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
