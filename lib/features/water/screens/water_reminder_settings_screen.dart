import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/reminder_reschedule_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../sleep/services/sleep_service.dart';
import '../models/water_reminder_config.dart';
import '../services/water_service.dart';

class WaterReminderSettingsScreen extends StatefulWidget {
  const WaterReminderSettingsScreen({super.key});

  @override
  State<WaterReminderSettingsScreen> createState() =>
      _WaterReminderSettingsScreenState();
}

class _WaterReminderSettingsScreenState
    extends State<WaterReminderSettingsScreen> {
  bool _isEnabled = false;
  List<TimeOfDay> _reminderTimes = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  int _intervalMinutes = 120;
  String _sound = 'default';
  bool _pauseWhenGoalReached = true;
  bool _respectQuietHours = true;
  bool _useSleepSchedule = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    final existing = CleanStorageService.getWaterReminderConfig();
    if (existing == null) return;
    setState(() {
      _isEnabled = existing.enabled;
      _startTime =
          TimeOfDay(hour: existing.startHour, minute: existing.startMinute);
      _endTime = TimeOfDay(hour: existing.endHour, minute: existing.endMinute);
      _intervalMinutes = existing.intervalMinutes;
      _sound = existing.sound;
      _pauseWhenGoalReached = existing.pauseWhenGoalReached;
      _respectQuietHours = existing.respectQuietHours;
      _useSleepSchedule = existing.useSleepSchedule;
      _reminderTimes = existing.reminderMinutes
          .map((m) => TimeOfDay(hour: m ~/ 60, minute: m % 60))
          .toList()
        ..sort(_compareTimes);
    });
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) =>
      (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

  void _snack(String message, {bool error = false, bool success = false}) {
    if (error) {
      context.toastError(message);
    } else if (success) {
      context.toastSuccess(message);
    } else {
      context.toastInfo(message);
    }
  }

  void _generateIntervalReminders() {
    final start = _startTime.hour * 60 + _startTime.minute;
    final end = _endTime.hour * 60 + _endTime.minute;

    if (end <= start) {
      _snack('End time must be after start time', error: true);
      return;
    }

    final times = <TimeOfDay>[];
    for (int minutes = start; minutes <= end; minutes += _intervalMinutes) {
      times.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    }

    setState(() => _reminderTimes = times);
    _snack('Generated ${times.length} reminder times', success: true);
  }

  Future<void> _addCustomTime() async {
    final time = await AppTimePicker.show(context, initial: TimeOfDay.now());
    if (time != null) {
      setState(() {
        _reminderTimes.add(time);
        _reminderTimes.sort(_compareTimes);
      });
    }
  }

  void _removeTime(int index) {
    setState(() => _reminderTimes.removeAt(index));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_isEnabled && _reminderTimes.isEmpty) {
      _snack('Please add at least one reminder time', error: true);
      return;
    }

    setState(() => _isSaving = true);

    final config = WaterReminderConfig(
      enabled: _isEnabled,
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      intervalMinutes: _intervalMinutes,
      reminderMinutes: _reminderTimes
          .map((t) => t.hour * 60 + t.minute)
          .toList()
        ..sort(),
      sound: _sound,
      pauseWhenGoalReached: _pauseWhenGoalReached,
      respectQuietHours: _respectQuietHours,
      useSleepSchedule: _useSleepSchedule,
    );

    // Persist first so the reschedule pass reads the fresh config.
    await CleanStorageService.saveWaterReminderConfig(config);

    // (Re)establish notifications with the adaptive quiet-hours / goal-reached
    // rules applied centrally.
    final scheduled = await ReminderRescheduleService.rescheduleWaterReminders();

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!_isEnabled) {
      _snack('Water reminders turned off', success: true);
    } else if (scheduled == 0 &&
        _pauseWhenGoalReached &&
        WaterService.getTodayData().goalReached) {
      _snack('Saved — paused until tomorrow (goal reached)', success: true);
    } else {
      _snack('$scheduled water reminders scheduled', success: true);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.water,
      child: Builder(builder: _buildContent),
    );
  }

  Widget _buildContent(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Water Reminders',
            icon: Symbols.water_drop_rounded,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0,
                  AppSpacing.gutter, AppSpacing.xxl),
              children: [
                _buildEnableCard(ext),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Reminder Schedule',
                  icon: Symbols.schedule_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildIntervalCard(ext),
                const SizedBox(height: AppSpacing.lg),
                _buildReminderTimesList(ext),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Add Custom Time',
                  variant: AppButtonVariant.secondary,
                  leadingIcon: Symbols.add_rounded,
                  fullWidth: true,
                  onPressed: _addCustomTime,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Adaptive Behavior',
                  icon: Symbols.auto_awesome_rounded,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildAdaptiveCard(ext),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save Water Reminders',
                  variant: AppButtonVariant.primary,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnableCard(AppColorsExt ext) {
    final s = ext.water;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Symbols.water_drop_rounded, color: s.onContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water Reminders',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text('Get reminded to stay hydrated',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          AppSwitch(
            value: _isEnabled,
            onChanged: (val) => setState(() => _isEnabled = val),
            accent: s,
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalCard(AppColorsExt ext) {
    final s = ext.water;
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Auto-generate by interval',
              style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildTimeField(ext, 'Start', _startTime, () async {
                  final time = await AppTimePicker.show(context, initial: _startTime);
                  if (time != null) setState(() => _startTime = time);
                }),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildTimeField(ext, 'End', _endTime, () async {
                  final time = await AppTimePicker.show(context, initial: _endTime);
                  if (time != null) setState(() => _endTime = time);
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Every $_intervalMinutes minutes',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          Slider(
            value: _intervalMinutes.toDouble(),
            min: 30,
            max: 240,
            divisions: 21,
            activeColor: ext.mark(s),
            inactiveColor: ext.outline,
            onChanged: (val) => setState(() => _intervalMinutes = val.toInt()),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Generate Times',
            variant: AppButtonVariant.tonal,
            leadingIcon: Symbols.auto_fix_high_rounded,
            fullWidth: true,
            onPressed: _generateIntervalReminders,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField(
      AppColorsExt ext, String label, TimeOfDay time, VoidCallback onTap) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            Text(time.format(context),
                style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderTimesList(AppColorsExt ext) {
    final s = ext.water;
    final tt = Theme.of(context).textTheme;
    if (_reminderTimes.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Symbols.schedule_rounded,
          title: 'No reminder times set',
          message: 'Generate times by interval or add a custom time.',
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: _reminderTimes.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(Symbols.alarm_rounded, color: s.onContainer, size: 20),
            ),
            title: Text(time.format(context),
                style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
            trailing: IconButton(
              icon: Icon(Symbols.close_rounded, color: ext.mark(ext.error)),
              onPressed: () => _removeTime(index),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// The wake/bed window actually driving quiet hours right now, plus where
  /// it came from. Mirrors `ReminderRescheduleService.rescheduleWaterReminders`'s
  /// fallback order: a real sleep average (enough nights) → the stated sleep
  /// schedule → the hydration profile's fixed hours.
  ({int wakeHour, int wakeMinute, int bedHour, int bedMinute, String source})
      _resolvedQuietWindow() {
    if (_useSleepSchedule) {
      final avg = SleepService.averageActualSchedule();
      if (avg != null) {
        return (
          wakeHour: avg.wakeHour,
          wakeMinute: avg.wakeMinute,
          bedHour: avg.bedHour,
          bedMinute: avg.bedMinute,
          source: 'nights',
        );
      }
      final schedule = SleepService.getSchedule();
      return (
        wakeHour: schedule.wakeHour,
        wakeMinute: schedule.wakeMinute,
        bedHour: schedule.bedtimeHour,
        bedMinute: schedule.bedtimeMinute,
        source: 'schedule',
      );
    }
    final profile = WaterService.getProfile();
    return (
      wakeHour: profile.wakeUpHour ?? 7,
      wakeMinute: 0,
      bedHour: profile.bedtimeHour ?? 22,
      bedMinute: 0,
      source: 'static',
    );
  }

  Widget _buildAdaptiveCard(AppColorsExt ext) {
    final window = _resolvedQuietWindow();
    final rangeLabel =
        '${_formatTime(window.wakeHour, window.wakeMinute)}–${_formatTime(window.bedHour, window.bedMinute)}';

    // Same wording regardless of source — the "where the window came from"
    // detail belongs to the sleep-schedule toggle's own subtitle below.
    final quietSubtitle = 'Skip reminders outside $rangeLabel';

    String sleepSubtitle;
    switch (window.source) {
      case 'nights':
        sleepSubtitle =
            'Based on your last ${SleepService.regularitySampleSize()} nights ($rangeLabel)';
        break;
      case 'schedule':
        sleepSubtitle = 'Based on your sleep schedule ($rangeLabel)';
        break;
      default:
        sleepSubtitle = 'Uses your fixed hours ($rangeLabel) when off';
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _buildToggleRow(
            ext,
            icon: Symbols.emoji_events_rounded,
            title: 'Pause when goal reached',
            subtitle: "Stop today's reminders once you hit your goal",
            value: _pauseWhenGoalReached,
            onChanged: (v) => setState(() => _pauseWhenGoalReached = v),
          ),
          Divider(height: 1, color: ext.outline),
          _buildToggleRow(
            ext,
            icon: Symbols.bedtime_rounded,
            title: 'Respect quiet hours',
            subtitle: quietSubtitle,
            value: _respectQuietHours,
            onChanged: (v) => setState(() => _respectQuietHours = v),
          ),
          Divider(height: 1, color: ext.outline),
          _buildToggleRow(
            ext,
            icon: Symbols.nights_stay_rounded,
            title: 'Use my sleep schedule',
            subtitle: sleepSubtitle,
            value: _useSleepSchedule,
            onChanged: (v) => setState(() => _useSleepSchedule = v),
          ),
        ],
      ),
    );
  }

  String _formatTime(int hour24, int minute) {
    return TimeOfDay(hour: hour24, minute: minute).format(context);
  }

  Widget _buildToggleRow(
    AppColorsExt ext, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final s = ext.water;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: s.container,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, color: s.onContainer, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: onChanged,
            accent: s,
          ),
        ],
      ),
    );
  }
}
