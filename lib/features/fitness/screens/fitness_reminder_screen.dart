import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/fitness_theme.dart';
import '../widgets/fitness_card.dart';
import '../widgets/fitness_button.dart';
import '../models/fitness_reminder.dart';
import '../../../core/services/fitness_reminder_service.dart';
import '../../../core/services/clean_storage_service.dart';

class FitnessReminderScreen extends StatefulWidget {
  const FitnessReminderScreen({super.key});

  @override
  State<FitnessReminderScreen> createState() => _FitnessReminderScreenState();
}

class _FitnessReminderScreenState extends State<FitnessReminderScreen> {
  final FitnessReminderService _reminderService = FitnessReminderService();
  List<FitnessReminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = CleanStorageService.getAllFitnessReminders();
      if (mounted) {
        setState(() {
          _reminders = reminders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      if (mounted) setState(() => _isLoading = false);
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
          title: const Text('Workout Reminders', style: FitnessTheme.headingSm),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FitnessTheme.primary),
              )
            : _reminders.isEmpty
                ? _buildEmptyState()
                : _buildReminderList(),
        floatingActionButton: FitnessFloatingButton(
          icon: Icons.add,
          label: 'Add Reminder',
          onPressed: () => _showAddReminderSheet(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FitnessTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: FitnessTheme.primary,
            ),
          ),
          const SizedBox(height: FitnessTheme.spacingLg),
          Text(
            'No Reminders Yet',
            style: FitnessTheme.headingSm,
          ),
          const SizedBox(height: FitnessTheme.spacingSm),
          Text(
            'Set up reminders to stay consistent\nwith your workout routine',
            style: FitnessTheme.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList() {
    return ListView.builder(
      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final reminder = _reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(FitnessReminder reminder) {
    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: FitnessTheme.spacingMd),
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        decoration: BoxDecoration(
          color: FitnessTheme.error,
          borderRadius: FitnessTheme.borderRadiusMd,
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteReminder(reminder),
      child: FitnessCard(
        margin: const EdgeInsets.only(bottom: FitnessTheme.spacingSm),
        onTap: () => _showEditReminderSheet(reminder),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FitnessTheme.primary.withOpacity(0.2),
                borderRadius: FitnessTheme.borderRadiusSm,
              ),
              child: Center(
                child: Text(
                  reminder.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: FitnessTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reminder.title, style: FitnessTheme.titleMd),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: FitnessTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(reminder.reminderTime),
                        style: FitnessTheme.bodySm,
                      ),
                      const SizedBox(width: FitnessTheme.spacingSm),
                      Icon(
                        Icons.repeat,
                        size: 14,
                        color: FitnessTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatFrequency(reminder.frequency),
                        style: FitnessTheme.bodySm,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: reminder.isEnabled,
              onChanged: (value) => _toggleReminder(reminder, value),
              activeColor: FitnessTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatFrequency(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Every day';
      case 'weekdays':
        return 'Weekdays';
      case 'weekends':
        return 'Weekends';
      case 'custom':
        return 'Custom';
      default:
        return frequency;
    }
  }

  void _showAddReminderSheet() {
    _showReminderSheet(null);
  }

  void _showEditReminderSheet(FitnessReminder reminder) {
    _showReminderSheet(reminder);
  }

  void _showReminderSheet(FitnessReminder? existingReminder) {
    String type = existingReminder?.type ?? 'workout';
    TimeOfDay selectedTime = existingReminder != null
        ? TimeOfDay(
            hour: existingReminder.reminderTime.hour,
            minute: existingReminder.reminderTime.minute,
          )
        : const TimeOfDay(hour: 7, minute: 0);
    String frequency = existingReminder?.frequency ?? 'daily';
    int duration = existingReminder?.durationMinutes ?? 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: FitnessTheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(FitnessTheme.radiusLg),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(FitnessTheme.spacingLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingReminder != null ? 'Edit Reminder' : 'Add Reminder',
                        style: FitnessTheme.headingSm,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),

                  // Workout type
                  Text('Workout Type', style: FitnessTheme.titleSm),
                  const SizedBox(height: FitnessTheme.spacingSm),
                  Wrap(
                    spacing: FitnessTheme.spacingSm,
                    children: [
                      _buildTypeChip('workout', '💪 Workout', type, (t) {
                        setSheetState(() => type = t);
                      }),
                      _buildTypeChip('cardio', '❤️ Cardio', type, (t) {
                        setSheetState(() => type = t);
                      }),
                      _buildTypeChip('yoga', '🧘 Yoga', type, (t) {
                        setSheetState(() => type = t);
                      }),
                      _buildTypeChip('stretching', '🤸 Stretch', type, (t) {
                        setSheetState(() => type = t);
                      }),
                    ],
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),

                  // Time
                  Text('Time', style: FitnessTheme.titleSm),
                  const SizedBox(height: FitnessTheme.spacingSm),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: FitnessTheme.themeData.copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: FitnessTheme.primary,
                                surface: FitnessTheme.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(FitnessTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: FitnessTheme.cardBackground,
                        borderRadius: FitnessTheme.borderRadiusMd,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: FitnessTheme.primary),
                          const SizedBox(width: FitnessTheme.spacingMd),
                          Text(
                            selectedTime.format(context),
                            style: FitnessTheme.titleMd,
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, color: FitnessTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),

                  // Frequency
                  Text('Repeat', style: FitnessTheme.titleSm),
                  const SizedBox(height: FitnessTheme.spacingSm),
                  Wrap(
                    spacing: FitnessTheme.spacingSm,
                    children: [
                      _buildFrequencyChip('daily', 'Daily', frequency, (f) {
                        setSheetState(() => frequency = f);
                      }),
                      _buildFrequencyChip('weekdays', 'Weekdays', frequency, (f) {
                        setSheetState(() => frequency = f);
                      }),
                      _buildFrequencyChip('weekends', 'Weekends', frequency, (f) {
                        setSheetState(() => frequency = f);
                      }),
                    ],
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),

                  // Duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Duration', style: FitnessTheme.titleSm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FitnessTheme.spacingSm,
                          vertical: FitnessTheme.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: FitnessTheme.primary.withOpacity(0.2),
                          borderRadius: FitnessTheme.borderRadiusSm,
                        ),
                        child: Text(
                          '$duration min',
                          style: FitnessTheme.titleSm.copyWith(
                            color: FitnessTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: duration.toDouble(),
                    min: 5,
                    max: 90,
                    divisions: 17,
                    activeColor: FitnessTheme.primary,
                    inactiveColor: FitnessTheme.surface,
                    onChanged: (value) {
                      setSheetState(() => duration = value.toInt());
                    },
                  ),
                  const SizedBox(height: FitnessTheme.spacingLg),

                  // Save button
                  FitnessPrimaryButton(
                    text: existingReminder != null ? 'Save Changes' : 'Add Reminder',
                    onPressed: () {
                      _saveReminder(
                        existingReminder?.id,
                        type,
                        selectedTime,
                        frequency,
                        duration,
                      );
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: FitnessTheme.spacingMd),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(
    String value,
    String label,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? FitnessTheme.primary : FitnessTheme.cardBackground,
          borderRadius: FitnessTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: FitnessTheme.titleSm.copyWith(
            color: isSelected ? FitnessTheme.textOnPrimary : FitnessTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(
    String value,
    String label,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FitnessTheme.spacingMd,
          vertical: FitnessTheme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? FitnessTheme.primary : FitnessTheme.cardBackground,
          borderRadius: FitnessTheme.borderRadiusRound,
          border: Border.all(
            color: isSelected ? FitnessTheme.primary : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: FitnessTheme.titleSm.copyWith(
            color: isSelected ? FitnessTheme.textOnPrimary : FitnessTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Future<void> _saveReminder(
    String? existingId,
    String type,
    TimeOfDay time,
    String frequency,
    int duration,
  ) async {
    final now = DateTime.now();
    final reminderTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    
    final reminder = FitnessReminder(
      id: existingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: _getTypeTitle(type),
      reminderTime: reminderTime,
      frequency: frequency,
      durationMinutes: duration,
      isEnabled: true,
    );

    await CleanStorageService.saveFitnessReminder(reminder);
    await _reminderService.scheduleReminder(reminder);
    _loadReminders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingId != null ? 'Reminder updated' : 'Reminder added'),
          backgroundColor: FitnessTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusSm),
        ),
      );
    }
  }

  String _getTypeTitle(String type) {
    switch (type) {
      case 'workout':
        return 'Workout';
      case 'cardio':
        return 'Cardio';
      case 'yoga':
        return 'Yoga';
      case 'stretching':
        return 'Stretching';
      default:
        return 'Workout';
    }
  }

  Future<void> _toggleReminder(FitnessReminder reminder, bool enabled) async {
    HapticFeedback.selectionClick();
    final updated = FitnessReminder(
      id: reminder.id,
      type: reminder.type,
      title: reminder.title,
      reminderTime: reminder.reminderTime,
      frequency: reminder.frequency,
      durationMinutes: reminder.durationMinutes,
      isEnabled: enabled,
      customDays: reminder.customDays,
    );

    await CleanStorageService.saveFitnessReminder(updated);
    
    if (enabled) {
      await _reminderService.scheduleReminder(updated);
    } else {
      await _reminderService.cancelReminder(updated);
    }
    
    _loadReminders();
  }

  Future<void> _deleteReminder(FitnessReminder reminder) async {
    await _reminderService.deleteReminder(reminder);
    _loadReminders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reminder deleted'),
          backgroundColor: FitnessTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: FitnessTheme.borderRadiusSm),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await CleanStorageService.saveFitnessReminder(reminder);
              if (reminder.isEnabled) {
                await _reminderService.scheduleReminder(reminder);
              }
              _loadReminders();
            },
          ),
        ),
      );
    }
  }
}
