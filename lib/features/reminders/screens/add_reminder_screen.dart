import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../models/reminder_category_model.dart';
import '../models/reminder_model.dart';
import 'category_management_screen.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final String? noteId;

  // Optional pre-fill values for a NEW reminder (e.g. from AI "Smart Add").
  // Applied only when [reminder] is null so the edit flow is unaffected.
  final String? initialTitle;
  final DateTime? initialTime;
  final RepeatType? initialRepeat;
  final String? initialCategoryId;
  final ReminderPriority? initialPriority;
  final List<int>? initialCustomDays;

  const AddReminderScreen({
    super.key,
    this.reminder,
    this.noteId,
    this.initialTitle,
    this.initialTime,
    this.initialRepeat,
    this.initialCategoryId,
    this.initialPriority,
    this.initialCustomDays,
  });

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
  List<ReminderCategory> _categories = [];

  // Built-in sounds — each maps to a bundled audio asset that plays instantly
  // on selection (offline, no network).
  static const Map<String, Map<String, String>> _soundOptions = {
    'default': {'label': 'Default', 'category': 'Classic', 'icon': 'notifications', 'asset': 'assets/sounds/chime.wav'},
    'gentle_chime': {'label': 'Gentle Chime', 'category': 'Gentle', 'icon': 'music_note', 'asset': 'assets/sounds/gentle_chime.wav'},
    'soft_bells': {'label': 'Soft Bells', 'category': 'Gentle', 'icon': 'notifications_active', 'asset': 'assets/sounds/soft_bells.wav'},
    'marimba': {'label': 'Marimba', 'category': 'Melodic', 'icon': 'music_note', 'asset': 'assets/sounds/marimba.wav'},
    'sunrise': {'label': 'Sunrise', 'category': 'Melodic', 'icon': 'wb_sunny', 'asset': 'assets/sounds/sunrise.wav'},
    'pulse': {'label': 'Pulse', 'category': 'Classic', 'icon': 'graphic_eq', 'asset': 'assets/sounds/pulse.wav'},
    'calm': {'label': 'Calm', 'category': 'Gentle', 'icon': 'self_improvement', 'asset': 'assets/sounds/calm.wav'},
    'digital_alarm': {'label': 'Digital Alarm', 'category': 'Alert', 'icon': 'alarm', 'asset': 'assets/sounds/digital_alarm.wav'},
    'urgent_alert': {'label': 'Urgent Alert', 'category': 'Alert', 'icon': 'warning', 'asset': 'assets/sounds/urgent_alert.wav'},
  };

  /// A custom sound is stored as an absolute file path (from the device audio
  /// picker); built-in presets are stored as their key ('default', etc.).
  bool get _isCustomSound => _sound.startsWith('/');
  String get _customSoundName =>
      _isCustomSound ? _sound.split('/').last : _sound;

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
      // Roll into the next day when created after 23:00 (hour 24 is invalid and
      // asserts in TimeOfDay).
      final next = now.add(const Duration(hours: 1));
      _selectedDate = DateTime(next.year, next.month, next.day, next.hour);
      _selectedTime = TimeOfDay(hour: next.hour, minute: 0);

      // Apply AI "Smart Add" pre-fill values (new reminders only).
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialTime != null) {
        _selectedDate = widget.initialTime!;
        _selectedTime = TimeOfDay.fromDateTime(widget.initialTime!);
      }
      if (widget.initialRepeat != null) {
        _repeatType = widget.initialRepeat!;
      }
      if (widget.initialCategoryId != null) {
        _selectedCategoryId = widget.initialCategoryId;
      }
      if (widget.initialPriority != null) {
        _priority = widget.initialPriority!;
      }
      if (widget.initialCustomDays != null &&
          widget.initialCustomDays!.isNotEmpty) {
        _customDays = List<int>.from(widget.initialCustomDays!);
      }
    }

    // Seed from the sync cache, then refresh from Drift.
    _categories = CleanStorageService.getAllCategories();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await CleanStorageService.getAllCategoriesAsync();
    if (mounted) {
      setState(() => _categories = categories);
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

  /// Let the user pick a sound from their device's audio files.
  Future<void> _pickCustomSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      if (path != null && mounted) {
        setState(() => _sound = path);
        _previewSound(); // instant confirmation it plays
      }
    } catch (e) {
      debugPrint('Pick sound error: $e');
      if (mounted) {
        final ext = AppColorsExt.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: ext.error.base,
          content: Text('Could not open audio files: $e',
              style: TextStyle(color: ext.error.on)),
        ));
      }
    }
  }

  /// Plays the currently-selected sound so the user hears it: a bundled asset
  /// for presets, or the picked file for a custom device sound. All local — no
  /// network.
  Future<void> _previewSound() async {
    try {
      setState(() => _isPlayingPreview = true);
      await _audioPlayer.stop();
      if (_isCustomSound) {
        await _audioPlayer.setFilePath(_sound);
      } else {
        final asset =
            _soundOptions[_sound]?['asset'] ?? 'assets/sounds/chime.wav';
        await _audioPlayer.setAsset(asset);
      }
      await _audioPlayer.setVolume(0.85);
      await _audioPlayer.play();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          _audioPlayer.stop();
          setState(() => _isPlayingPreview = false);
        }
      });
    } catch (e) {
      debugPrint('Sound preview error: $e');
      if (mounted) {
        setState(() => _isPlayingPreview = false);
        final ext = AppColorsExt.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: ext.error.base,
          content: Text('Could not play this audio file.',
              style: TextStyle(color: ext.error.on)),
        ));
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
      case 'graphic_eq': return Icons.graphic_eq_rounded;
      default: return Icons.music_note_rounded;
    }
  }

  Future<void> _selectDate() async {
    final lastDate = DateTime.now().add(const Duration(days: 365));
    final defaultFirst = DateTime.now().subtract(const Duration(days: 1));
    // An overdue reminder's date can be before defaultFirst; showDatePicker
    // asserts if initialDate < firstDate, so widen firstDate to include it and
    // clamp initialDate into [firstDate, lastDate] as a safety net.
    final firstDate =
        _selectedDate.isBefore(defaultFirst) ? _selectedDate : defaultFirst;
    final initialDate =
        _selectedDate.isAfter(lastDate) ? lastDate : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
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

      // Save reminder using Drift storage
      await CleanStorageService.saveReminder(reminder);

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
        final ext = AppColorsExt.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ext.error.base,
            content: Text(
              'Error saving reminder: $e',
              style: TextStyle(color: ext.error.on),
            ),
          ),
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
    final ext = AppColorsExt.of(context);
    final rem = ext.reminders;
    final tt = Theme.of(context).textTheme;
    final dateFormat = DateFormat('EEE, MMM d, y');
    final isEditing = widget.reminder != null;

    return AccentScope(
      feature: FeatureAccent.reminders,
      child: AppScaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: isEditing ? 'Edit Reminder' : 'New Reminder',
              icon: Icons.notifications_active_rounded,
              accent: rem,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, color: ext.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppButton(
                  label: 'Save',
                  size: AppButtonSize.sm,
                  accent: rem,
                  loading: _isLoading,
                  onPressed: _saveReminder,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Details ----
                      AppTextField(
                        controller: _titleController,
                        label: 'Title',
                        hint: 'What needs to be done?',
                        accent: rem,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _bodyController,
                        label: 'Description (Optional)',
                        hint: 'Add details...',
                        accent: rem,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Schedule ----
                      SectionHeader(
                        title: 'Schedule',
                        icon: Icons.event_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        child: Column(
                          children: [
                            _buildTimeRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date',
                              value: dateFormat.format(_selectedDate),
                              onTap: _selectDate,
                            ),
                            Divider(height: AppSpacing.xl, color: ext.outline),
                            _buildTimeRow(
                              icon: Icons.access_time_rounded,
                              label: 'Time',
                              value: _selectedTime.format(context),
                              onTap: _selectTime,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Repeat ----
                      SectionHeader(
                        title: 'Repeat',
                        icon: Icons.repeat_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownShell(
                        ext: ext,
                        rem: rem,
                        child: DropdownButton<RepeatType>(
                          value: _repeatType,
                          isExpanded: true,
                          borderRadius: AppRadius.brMd,
                          dropdownColor: ext.surface,
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: ext.mark(rem)),
                          items: RepeatType.values.where((type) {
                            if (type == RepeatType.custom) {
                              return FeatureFlagService().isAdvancedRepeatEnabled ||
                                  _repeatType == RepeatType.custom;
                            }
                            return true;
                          }).map((type) {
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
                              child: Text(label),
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
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
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
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Snooze ----
                      SectionHeader(
                        title: 'Snooze Duration',
                        icon: Icons.snooze_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownShell(
                        ext: ext,
                        rem: rem,
                        child: DropdownButton<int>(
                          value: _snoozeDuration,
                          isExpanded: true,
                          borderRadius: AppRadius.brMd,
                          dropdownColor: ext.surface,
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: ext.mark(rem)),
                          items: [5, 10, 15, 30, 60].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value >= 60 ? '${value ~/ 60} hour' : '$value minutes',
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
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Alarm Sound ----
                      SectionHeader(
                        title: 'Alarm Sound',
                        icon: Icons.music_note_rounded,
                        accent: rem,
                        actionLabel: _isPlayingPreview ? 'Stop' : null,
                        onAction: _isPlayingPreview ? _stopPreview : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Current selection with preview button
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: rem.container,
                                      borderRadius: AppRadius.brSm,
                                    ),
                                    child: Icon(
                                      _isCustomSound
                                          ? Icons.audiotrack_rounded
                                          : _getSoundIcon(_soundOptions[_sound]
                                                  ?['icon'] ??
                                              'notifications'),
                                      color: rem.onContainer,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isCustomSound
                                              ? _customSoundName
                                              : (_soundOptions[_sound]?['label'] ??
                                                  'Default'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.titleLarge
                                              ?.copyWith(color: ext.textPrimary),
                                        ),
                                        Text(
                                          _isCustomSound
                                              ? 'Custom sound from device'
                                              : (_soundOptions[_sound]
                                                      ?['category'] ??
                                                  'Classic'),
                                          style: tt.bodyMedium
                                              ?.copyWith(color: ext.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Every sound is playable (bundled asset or
                                  // picked file) — tap to hear it.
                                  IconButton(
                                    onPressed: _isPlayingPreview
                                        ? _stopPreview
                                        : _previewSound,
                                    icon: Icon(
                                      _isPlayingPreview
                                          ? Icons.stop_circle_rounded
                                          : Icons.play_circle_rounded,
                                      color: _isPlayingPreview
                                          ? ext.mark(ext.error)
                                          : ext.mark(rem),
                                      size: 32,
                                    ),
                                    tooltip: _isPlayingPreview
                                        ? 'Stop preview'
                                        : 'Preview sound',
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: ext.outline),
                            // Sound selection grid
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  // Pick any audio file from the device.
                                  AppChip(
                                    label: 'Choose from device',
                                    icon: Icons.folder_open_rounded,
                                    selected: _isCustomSound,
                                    accent: rem,
                                    onTap: _pickCustomSound,
                                  ),
                                  ..._soundOptions.entries.map((entry) {
                                    return AppChip(
                                      label: entry.value['label'] ?? entry.key,
                                      icon: _getSoundIcon(
                                          entry.value['icon'] ?? 'notifications'),
                                      selected: _sound == entry.key,
                                      accent: rem,
                                      // Select AND play the bundled sound so the
                                      // user hears what they picked.
                                      onTap: () {
                                        setState(() => _sound = entry.key);
                                        _previewSound();
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Priority ----
                      SectionHeader(
                        title: 'Priority',
                        icon: Icons.flag_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriorityOption(
                                ReminderPriority.low, 'Low', ext.success, ext),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildPriorityOption(
                                ReminderPriority.medium, 'Medium', ext.warning, ext),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildPriorityOption(
                                ReminderPriority.high, 'High', ext.error, ext),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Category ----
                      SectionHeader(
                        title: 'Category',
                        icon: Icons.label_rounded,
                        accent: rem,
                        actionLabel: 'Manage',
                        onAction: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CategoryManagementScreen()),
                          );
                          _loadCategories();
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownShell(
                        ext: ext,
                        rem: rem,
                        child: DropdownButton<String?>(
                          value: _categories.any((c) => c.id == _selectedCategoryId)
                              ? _selectedCategoryId
                              : null,
                          isExpanded: true,
                          borderRadius: AppRadius.brMd,
                          dropdownColor: ext.surface,
                          style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
                          hint: Text('Select Category',
                              style: tt.bodyLarge?.copyWith(color: ext.textTertiary)),
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: ext.mark(rem)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('None',
                                  style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
                            ),
                            ..._categories.map((category) {
                              return DropdownMenuItem<String?>(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: category.colorObj,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(category.iconObj, size: 18, color: category.colorObj),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategoryId = value);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Note ----
                      SectionHeader(
                        title: 'Note',
                        icon: Icons.sticky_note_2_rounded,
                        accent: rem,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _noteController,
                        hint: 'Add additional details...',
                        accent: rem,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Attachments ----
                      SectionHeader(
                        title: 'Attachments',
                        icon: Icons.attach_file_rounded,
                        accent: rem,
                        actionLabel: _selectedImagePath == null ? 'Add Image' : null,
                        onAction: _selectedImagePath == null ? _pickImage : null,
                      ),
                      if (_selectedImagePath != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.brCard,
                              child: Image.file(
                                File(_selectedImagePath!),
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: Material(
                                color: ext.surface,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _removeImage,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.close_rounded,
                                        color: ext.mark(ext.error), size: 20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      // ---- Save ----
                      AppButton(
                        label: isEditing ? 'Save Changes' : 'Create Reminder',
                        accent: rem,
                        fullWidth: true,
                        size: AppButtonSize.lg,
                        loading: _isLoading,
                        leadingIcon: Icons.check_rounded,
                        onPressed: _saveReminder,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

  /// Token-styled shell for the native DropdownButton.
  Widget _buildDropdownShell({
    required AppColorsExt ext,
    required AccentSwatch rem,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: ext.outline),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _buildPriorityOption(
      ReminderPriority priority, String label, AccentSwatch swatch, AppColorsExt ext) {
    final isSelected = _priority == priority;
    return GestureDetector(
      onTap: () => setState(() => _priority = priority),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? swatch.container : ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: isSelected ? ext.mark(swatch) : ext.outline,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _getPriorityIcon(priority),
              color: isSelected ? ext.mark(swatch) : ext.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? ext.mark(swatch) : ext.textSecondary,
                    fontWeight: FontWeight.w700,
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
    final ext = AppColorsExt.of(context);
    final rem = ext.reminders;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: rem.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, color: rem.onContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              label,
              style: tt.titleLarge?.copyWith(color: ext.textPrimary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ext.surfaceVariant,
                borderRadius: AppRadius.brSm,
              ),
              child: Text(
                value,
                style: tt.labelLarge?.copyWith(color: ext.mark(rem)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayToggle(String label, int day) {
    final ext = AppColorsExt.of(context);
    final rem = ext.reminders;
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
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? rem.container : ext.surfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? ext.mark(rem) : ext.outline,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? rem.onContainer : ext.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
