import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/feature_flag_service.dart';
import '../models/reminder_category_model.dart';
import '../models/reminder_model.dart';
import 'category_management_screen.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final String? noteId;

  const AddReminderScreen({super.key, this.reminder, this.noteId});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _noteController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  RepeatType _repeatType = RepeatType.none;
  List<int> _customDays = [];
  int _snoozeDuration = 5;
  String _sound = 'default';
  ReminderPriority _priority = ReminderPriority.high;
  String? _selectedCategoryId;
  String? _selectedImagePath;
  bool _isLoading = false;
  bool _isPlayingPreview = false;

  // Sound options with categories and preview URLs
  static const Map<String, Map<String, String>> _soundOptions = {
    'default': {'label': 'Default', 'category': 'Classic', 'icon': 'notifications'},
    'gentle_chime': {'label': 'Gentle Chime', 'category': 'Gentle', 'icon': 'music_note'},
    'soft_bells': {'label': 'Soft Bells', 'category': 'Gentle', 'icon': 'notifications_active'},
    'morning_bird': {'label': 'Morning Bird', 'category': 'Nature', 'icon': 'flutter_dash'},
    'ocean_wave': {'label': 'Ocean Wave', 'category': 'Nature', 'icon': 'water'},
    'sunrise': {'label': 'Sunrise', 'category': 'Classic', 'icon': 'wb_sunny'},
    'galaxy': {'label': 'Galaxy', 'category': 'Classic', 'icon': 'star'},
    'urgent_alert': {'label': 'Urgent Alert', 'category': 'Alert', 'icon': 'warning'},
    'digital_alarm': {'label': 'Digital Alarm', 'category': 'Alert', 'icon': 'alarm'},
    'meditation': {'label': 'Meditation', 'category': 'Gentle', 'icon': 'self_improvement'},
  };

  // Preview sound URLs (using free sounds from Pixabay)
  static const Map<String, String> _previewUrls = {
    'default': 'https://cdn.pixabay.com/audio/2022/03/10/audio_d6a4c6a7f4.mp3',
    'gentle_chime': 'https://cdn.pixabay.com/audio/2022/03/15/audio_115b9c3c1a.mp3',
    'soft_bells': 'https://cdn.pixabay.com/audio/2022/01/18/audio_d0a13f69d2.mp3',
    'morning_bird': 'https://cdn.pixabay.com/audio/2022/02/07/audio_bc594618f0.mp3',
    'ocean_wave': 'https://cdn.pixabay.com/audio/2021/08/09/audio_dc39aae018.mp3',
    'sunrise': 'https://cdn.pixabay.com/audio/2022/07/08/audio_dc39bde808.mp3',
    'galaxy': 'https://cdn.pixabay.com/audio/2024/02/14/audio_8e0db3cf42.mp3',
    'urgent_alert': 'https://cdn.pixabay.com/audio/2022/03/24/audio_2e89e16de4.mp3',
    'digital_alarm': 'https://cdn.pixabay.com/audio/2022/10/30/audio_1c3fa4ed6a.mp3',
    'meditation': 'https://cdn.pixabay.com/audio/2023/06/14/audio_af7fc9b7f0.mp3',
  };

  @override
  void initState() {
    super.initState();
    
    if (widget.reminder != null) {
      _titleController.text = widget.reminder!.title;
      _bodyController.text = widget.reminder!.body;
      _noteController.text = widget.reminder!.note ?? ''; // Load note
      _selectedDate = widget.reminder!.scheduledTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.reminder!.scheduledTime);
      _repeatType = widget.reminder!.repeatType;
      _customDays = widget.reminder!.customDays != null 
          ? List<int>.from(widget.reminder!.customDays!) 
          : [];
      _snoozeDuration = widget.reminder?.snoozeDuration ?? 5;
      _sound = widget.reminder?.sound ?? 'default';
      _priority = widget.reminder?.priority ?? ReminderPriority.high;
      _selectedCategoryId = widget.reminder?.categoryId;
      _selectedImagePath = widget.reminder?.imagePath; // Load image path
    }
    
    // If creating new reminder, default time to next hour
    if (widget.reminder == null) {
      final now = DateTime.now();
      _selectedDate = now;
      _selectedTime = TimeOfDay(hour: now.hour + 1, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _noteController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _previewSound(String soundKey) async {
    try {
      final url = _previewUrls[soundKey];
      if (url == null) return;

      setState(() => _isPlayingPreview = true);
      
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(url);
      await _audioPlayer.setVolume(0.7);
      await _audioPlayer.play();
      
      // Stop after 3 seconds for preview
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _audioPlayer.stop();
          setState(() => _isPlayingPreview = false);
        }
      });
    } catch (e) {
      debugPrint('Sound preview error: $e');
      if (mounted) {
        setState(() => _isPlayingPreview = false);
      }
    }
  }

  void _stopPreview() {
    _audioPlayer.stop();
    setState(() => _isPlayingPreview = false);
  }

  IconData _getSoundIcon(String iconName) {
    switch (iconName) {
      case 'notifications': return Icons.notifications_rounded;
      case 'music_note': return Icons.music_note_rounded;
      case 'notifications_active': return Icons.notifications_active_rounded;
      case 'flutter_dash': return Icons.flutter_dash_rounded;
      case 'water': return Icons.water_rounded;
      case 'wb_sunny': return Icons.wb_sunny_rounded;
      case 'star': return Icons.star_rounded;
      case 'warning': return Icons.warning_rounded;
      case 'alarm': return Icons.alarm_rounded;
      case 'self_improvement': return Icons.self_improvement_rounded;
      default: return Icons.music_note_rounded;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final reminderId = widget.reminder?.id ?? const Uuid().v4();
      
      final reminder = Reminder(
        id: reminderId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        scheduledTime: scheduledDateTime,
        isCompleted: false, // Reset completed status on edit
        createdAt: widget.reminder?.createdAt,
        repeatType: _repeatType,
        customDays: _repeatType == RepeatType.custom ? _customDays : null,
        snoozeDuration: _snoozeDuration,
        sound: _sound,
        priority: _priority,
        categoryId: _selectedCategoryId,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        imagePath: _selectedImagePath,
        noteId: widget.noteId ?? widget.reminder?.noteId,
      );

      if (widget.reminder != null) {
        await StorageService.updateReminder(reminder);
      } else {
        await StorageService.addReminder(reminder);
      }

      // Schedule notification
      final notificationId = reminderId.hashCode;
      
      await NotificationService().scheduleGenericReminder(
        id: notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledTime: scheduledDateTime,
        repeatType: reminder.repeatType,
        customDays: reminder.customDays,
        snoozeDuration: reminder.snoozeDuration,
        sound: reminder.sound,
        priority: reminder.priority,
        payload: reminder.noteId != null ? 'note:${reminder.noteId}' : null,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reminder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, y');
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.reminder != null ? 'Edit Reminder' : 'New Reminder'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveReminder,
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'What needs to be done?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Add details...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CommonCard(
                child: Column(
                  children: [
                    _buildTimeRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateFormat.format(_selectedDate),
                      onTap: _selectDate,
                    ),
                    const Divider(height: 24),
                    _buildTimeRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: _selectedTime.format(context),
                      onTap: _selectTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Repeat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CommonCard(
                child: Column(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<RepeatType>(
                        value: _repeatType,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                        items: RepeatType.values
                            .where((type) {
                              if (type == RepeatType.custom) {
                                return FeatureFlagService().isAdvancedRepeatEnabled || _repeatType == RepeatType.custom;
                              }
                              return true;
                            })
                            .map((type) {
                          String label;
                          switch (type) {
                            case RepeatType.none: label = 'Does not repeat'; break;
                            case RepeatType.daily: label = 'Every Day'; break;
                            case RepeatType.weekly: label = 'Every Week'; break;
                            case RepeatType.weekdays: label = 'Every Weekday (Mon-Fri)'; break;
                            case RepeatType.weekends: label = 'Every Weekend (Sat-Sun)'; break;
                            case RepeatType.custom: label = 'Custom'; break;
                          }
                          return DropdownMenuItem(
                            value: type,
                            child: Text(label, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _repeatType = value;
                              if (value == RepeatType.custom && _customDays.isEmpty) {
                                // Default to today if empty
                                _customDays.add(_selectedDate.weekday);
                              }
                            });
                          }
                        },
                      ),
                    ),
                    if (_repeatType == RepeatType.custom) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDayToggle('M', 1),
                          _buildDayToggle('T', 2),
                          _buildDayToggle('W', 3),
                          _buildDayToggle('T', 4),
                          _buildDayToggle('F', 5),
                          _buildDayToggle('S', 6),
                          _buildDayToggle('S', 7),
                        ],
                      ),
                      const SizedBox(height: 8),
                  ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Snooze Duration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CommonCard(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _snoozeDuration,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                    items: [5, 10, 15, 30, 60].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          value >= 60 ? '${value ~/ 60} hour' : '$value minutes',
                           style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _snoozeDuration = newValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Alarm Sound',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_isPlayingPreview)
                    TextButton.icon(
                      onPressed: _stopPreview,
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Stop'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CommonCard(
                child: Column(
                  children: [
                    // Current selection with preview button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getSoundIcon(_soundOptions[_sound]?['icon'] ?? 'notifications'),
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _soundOptions[_sound]?['label'] ?? 'Default',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _soundOptions[_sound]?['category'] ?? 'Classic',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isPlayingPreview ? _stopPreview : () => _previewSound(_sound),
                            icon: Icon(
                              _isPlayingPreview ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                              color: _isPlayingPreview ? AppColors.error : AppColors.primary,
                              size: 32,
                            ),
                            tooltip: _isPlayingPreview ? 'Stop preview' : 'Preview sound',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Sound selection grid
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _soundOptions.entries.map((entry) {
                          final isSelected = _sound == entry.key;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _sound = entry.key);
                              _previewSound(entry.key);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppColors.primary 
                                    : AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected 
                                    ? null 
                                    : Border.all(color: AppColors.border.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getSoundIcon(entry.value['icon'] ?? 'notifications'),
                                    size: 16,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    entry.value['label'] ?? entry.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildPriorityOption(ReminderPriority.low, 'Low', AppColors.success)),
                    Expanded(child: _buildPriorityOption(ReminderPriority.medium, 'Medium', AppColors.warning)),
                    Expanded(child: _buildPriorityOption(ReminderPriority.high, 'High', AppColors.error)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                      );
                    },
                    child: const Text('Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<Box<ReminderCategory>>(
                valueListenable: StorageService.categoriesListenable,
                builder: (context, box, _) {
                  final categories = box.values.toList();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        hint: const Text('Select Category'),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...categories.map((category) {
                            return DropdownMenuItem<String?>(
                              value: category.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: category.colorObj,
                                    child: Icon(category.iconObj, size: 10, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(category.name),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Note Field
              const Text(
                'Note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add additional details...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              
              // Image Attachments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attachments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_selectedImagePath == null)
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Add Image'),
                    ),
                ],
              ),
              if (_selectedImagePath != null) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_selectedImagePath!),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Save the image to app directory for persistence
      final directory = await getApplicationDocumentsDirectory();
      final String path = directory.path;
      final String fileName = '${const Uuid().v4()}.jpg';
      final File newImage = await File(pickedFile.path).copy('$path/$fileName');

      setState(() {
        _selectedImagePath = newImage.path;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImagePath = null;
    });
  }

  Widget _buildPriorityOption(ReminderPriority priority, String label, Color color) {
    final isSelected = _priority == priority;
    return GestureDetector(
      onTap: () => setState(() => _priority = priority),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          children: [
            Icon(
              _getPriorityIcon(priority),
              color: isSelected ? color : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPriorityIcon(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high: return Icons.notifications_active_rounded;
      case ReminderPriority.medium: return Icons.notifications_rounded;
      case ReminderPriority.low: return Icons.notifications_none_rounded;
    }
  }

  Widget _buildTimeRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayToggle(String label, int day) {
    final isSelected = _customDays.contains(day);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _customDays.remove(day);
          } else {
            _customDays.add(day);
          }
        });
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
