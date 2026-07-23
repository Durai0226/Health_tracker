import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/widgets/app/app_pickers.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/haptic_service.dart';
import '../theme/manrope_theme.dart';
import '../models/meditation_activity.dart';
import '../models/focus_reminder.dart';
import '../services/manrope_wellness_service.dart';

class ManropeRemindersScreen extends StatefulWidget {
  const ManropeRemindersScreen({super.key});

  @override
  State<ManropeRemindersScreen> createState() => _ManropeRemindersScreenState();
}

class _ManropeRemindersScreenState extends State<ManropeRemindersScreen>
    with TickerProviderStateMixin {
  final ManropeWellnessService _wellnessService = ManropeWellnessService();
  final HapticService _hapticService = HapticService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: ManropeTheme.durationMedium,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: ManropeTheme.curveDefault,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ManropeTheme.isDark(context);

    return ListenableBuilder(
      listenable: _wellnessService,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark
              ? ManropeTheme.backgroundDark
              : ManropeTheme.background,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddReminderSheet(context, isDark),
            backgroundColor: ManropeTheme.primaryOrange,
            child: const Icon(Symbols.add_rounded, color: Colors.white),
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: _wellnessService.reminders.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildRemindersList(isDark),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Symbols.arrow_back_rounded,
              color: isDark
                  ? ManropeTheme.textPrimaryDark
                  : ManropeTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminders',
                  style: ManropeTheme.titleLarge.copyWith(
                    color: isDark
                        ? ManropeTheme.textPrimaryDark
                        : ManropeTheme.textPrimary,
                  ),
                ),
                Text(
                  'Stay consistent with your practice',
                  style: ManropeTheme.bodySmall.copyWith(
                    color: isDark
                        ? ManropeTheme.textTertiaryDark
                        : ManropeTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: ManropeTheme.primaryGradient,
              borderRadius: ManropeTheme.borderRadiusMedium,
            ),
            child: const Icon(
              Symbols.notifications_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ManropeTheme.primaryOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.notifications_off_rounded,
                size: 48,
                color: ManropeTheme.primaryOrange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Reminders Set',
              style: ManropeTheme.titleMedium.copyWith(
                color: isDark
                    ? ManropeTheme.textPrimaryDark
                    : ManropeTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create reminders to stay consistent with your wellness practice',
              textAlign: TextAlign.center,
              style: ManropeTheme.bodyMedium.copyWith(
                color: isDark
                    ? ManropeTheme.textTertiaryDark
                    : ManropeTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddReminderSheet(context, isDark),
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Add Reminder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ManropeTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: ManropeTheme.borderRadiusRound,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersList(bool isDark) {
    final reminders = _wellnessService.reminders;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return _buildReminderCard(reminder, isDark);
      },
    );
  }

  Widget _buildReminderCard(FocusReminder reminder, bool isDark) {
    final activity = reminder.activityType;
    final color = activity?.primaryColor ?? ManropeTheme.primaryOrange;

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ManropeTheme.error,
          borderRadius: ManropeTheme.borderRadiusLarge,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Symbols.delete_rounded,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) {
        _wellnessService.deleteReminder(reminder.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reminder deleted'),
            // Without persist:false the Undo action pins the toast open forever
            // (SnackBar.persist defaults to `action != null`).
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _wellnessService.addReminder(reminder),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? ManropeTheme.backgroundDarkCard : Colors.white,
          borderRadius: ManropeTheme.borderRadiusLarge,
          boxShadow: ManropeTheme.shadowSmall,
          border: reminder.isEnabled
              ? Border.all(color: color.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: ManropeTheme.borderRadiusLarge,
            onTap: () => _showEditReminderSheet(context, reminder, isDark),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: activity?.gradient ??
                          ManropeTheme.primaryGradient,
                      borderRadius: ManropeTheme.borderRadiusMedium,
                    ),
                    child: Icon(
                      activity?.icon ?? Symbols.notifications_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: ManropeTheme.titleSmall.copyWith(
                            color: isDark
                                ? ManropeTheme.textPrimaryDark
                                : ManropeTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Symbols.schedule_rounded,
                              size: 14,
                              color: isDark
                                  ? ManropeTheme.textTertiaryDark
                                  : ManropeTheme.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reminder.timeDisplay,
                              style: ManropeTheme.bodySmall.copyWith(
                                color: isDark
                                    ? ManropeTheme.textTertiaryDark
                                    : ManropeTheme.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: ManropeTheme.borderRadiusSmall,
                              ),
                              child: Text(
                                reminder.frequency.displayName,
                                style: ManropeTheme.labelSmall.copyWith(
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: reminder.isEnabled,
                    onChanged: (value) {
                      _hapticService.selection();
                      _wellnessService.toggleReminder(reminder.id, value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddReminderSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReminderEditorSheet(
        isDark: isDark,
        onSave: (reminder) {
          _wellnessService.addReminder(reminder);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditReminderSheet(
    BuildContext context,
    FocusReminder reminder,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReminderEditorSheet(
        isDark: isDark,
        reminder: reminder,
        onSave: (updated) {
          _wellnessService.updateReminder(updated);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _ReminderEditorSheet extends StatefulWidget {
  final bool isDark;
  final FocusReminder? reminder;
  final Function(FocusReminder) onSave;

  const _ReminderEditorSheet({
    required this.isDark,
    this.reminder,
    required this.onSave,
  });

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late WellnessActivityType? _selectedActivity;
  late ReminderFrequency _frequency;
  late TimeOfDay _time;
  late List<int> _customDays;

  @override
  void initState() {
    super.initState();
    _selectedActivity = widget.reminder?.activityType;
    _frequency = widget.reminder?.frequency ?? ReminderFrequency.daily;
    _time = widget.reminder != null
        ? TimeOfDay(hour: widget.reminder!.hour, minute: widget.reminder!.minute)
        : const TimeOfDay(hour: 8, minute: 0);
    _customDays = List.from(widget.reminder?.customDays ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.isDark
            ? ManropeTheme.backgroundDarkCard
            : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? ManropeTheme.textTertiaryDark
                      : ManropeTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.reminder != null ? 'Edit Reminder' : 'New Reminder',
              style: ManropeTheme.titleLarge.copyWith(
                color: widget.isDark
                    ? ManropeTheme.textPrimaryDark
                    : ManropeTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Activity selector
            Text(
              'Activity',
              style: ManropeTheme.labelLarge.copyWith(
                color: widget.isDark
                    ? ManropeTheme.textSecondaryDark
                    : ManropeTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: WellnessActivityType.values.length,
                itemBuilder: (context, index) {
                  final activity = WellnessActivityType.values[index];
                  final isSelected = _selectedActivity == activity;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedActivity = activity),
                    child: AnimatedContainer(
                      duration: ManropeTheme.durationFast,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      width: 80,
                      decoration: BoxDecoration(
                        gradient: isSelected ? activity.gradient : null,
                        color: isSelected
                            ? null
                            : (widget.isDark
                                ? ManropeTheme.backgroundDarkElevated
                                : ManropeTheme.surfaceLight),
                        borderRadius: ManropeTheme.borderRadiusLarge,
                        border: isSelected
                            ? null
                            : Border.all(
                                color: widget.isDark
                                    ? ManropeTheme.dividerDark
                                    : ManropeTheme.divider,
                              ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            activity.icon,
                            color: isSelected
                                ? Colors.white
                                : activity.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity.displayName,
                            style: ManropeTheme.labelSmall.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : (widget.isDark
                                      ? ManropeTheme.textSecondaryDark
                                      : ManropeTheme.textSecondary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Time picker
            Text(
              'Time',
              style: ManropeTheme.labelLarge.copyWith(
                color: widget.isDark
                    ? ManropeTheme.textSecondaryDark
                    : ManropeTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final picked = await AppTimePicker.show(context, initial: _time);
                if (picked != null) {
                  setState(() => _time = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? ManropeTheme.backgroundDarkElevated
                      : ManropeTheme.surfaceLight,
                  borderRadius: ManropeTheme.borderRadiusLarge,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.schedule_rounded,
                      color: ManropeTheme.primaryOrange,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _time.format(context),
                      style: ManropeTheme.titleMedium.copyWith(
                        color: widget.isDark
                            ? ManropeTheme.textPrimaryDark
                            : ManropeTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Symbols.arrow_forward_ios_rounded,
                      size: 16,
                      color: widget.isDark
                          ? ManropeTheme.textTertiaryDark
                          : ManropeTheme.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Frequency selector
            Text(
              'Repeat',
              style: ManropeTheme.labelLarge.copyWith(
                color: widget.isDark
                    ? ManropeTheme.textSecondaryDark
                    : ManropeTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReminderFrequency.values.map((freq) {
                final isSelected = _frequency == freq;
                return GestureDetector(
                  onTap: () => setState(() => _frequency = freq),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? ManropeTheme.primaryGradient
                          : null,
                      color: isSelected
                          ? null
                          : (widget.isDark
                              ? ManropeTheme.backgroundDarkElevated
                              : ManropeTheme.surfaceLight),
                      borderRadius: ManropeTheme.borderRadiusRound,
                    ),
                    child: Text(
                      freq.displayName,
                      style: ManropeTheme.labelMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : (widget.isDark
                                ? ManropeTheme.textSecondaryDark
                                : ManropeTheme.textSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            if (_frequency == ReminderFrequency.custom) ...[
              const SizedBox(height: 16),
              _buildDaySelector(),
            ],

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedActivity == null
                    ? null
                    : () {
                        final reminder = FocusReminder.createActivityReminder(
                          activityType: _selectedActivity!,
                          hour: _time.hour,
                          minute: _time.minute,
                          frequency: _frequency,
                          customDays: _customDays,
                        );
                        widget.onSave(
                          widget.reminder != null
                              ? reminder.copyWith(id: widget.reminder!.id)
                              : reminder,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ManropeTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ManropeTheme.primaryOrange.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: ManropeTheme.borderRadiusLarge,
                  ),
                ),
                child: Text(
                  widget.reminder != null ? 'Update Reminder' : 'Create Reminder',
                  style: ManropeTheme.titleSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.asMap().entries.map((entry) {
        final dayNum = entry.key + 1;
        final dayName = entry.value;
        final isSelected = _customDays.contains(dayNum);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _customDays.remove(dayNum);
              } else {
                _customDays.add(dayNum);
              }
            });
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isSelected ? ManropeTheme.primaryGradient : null,
              color: isSelected
                  ? null
                  : (widget.isDark
                      ? ManropeTheme.backgroundDarkElevated
                      : ManropeTheme.surfaceLight),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                dayName.substring(0, 1),
                style: ManropeTheme.labelMedium.copyWith(
                  color: isSelected
                      ? Colors.white
                      : (widget.isDark
                          ? ManropeTheme.textSecondaryDark
                          : ManropeTheme.textSecondary),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
