import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_schedule.dart';
import '../models/sleep_session.dart';
import '../../../core/utils/calendar_day.dart';

/// The result of the manual-log sheet — resolved bed/wake [DateTime]s (the sheet
/// handles the midnight wrap), a 1–5 quality rating, and an optional note.
class SleepManualLogResult {
  final DateTime bedtime;
  final DateTime wakeTime;
  final int quality;
  final String? note;

  const SleepManualLogResult({
    required this.bedtime,
    required this.wakeTime,
    required this.quality,
    this.note,
  });
}

/// Manual sleep entry — the always-available path (works with zero health
/// permissions, i.e. on the Simulator). Bed/wake time pickers + a 1–5 quality
/// rating + a note, on the flat [AppBottomSheet].
class SleepManualLogSheet {
  const SleepManualLogSheet._();

  /// Why this night cannot be logged, or null when it is sound.
  ///
  /// Both rejections used to be silent acceptances. Bed == wake fell straight
  /// through the midnight wrap in [_ManualLogFormState._bedDateTime] — the
  /// bedtime was pushed to the previous evening and the sheet cheerfully
  /// recorded a 24-hour "night". A wake time later today was recorded as
  /// sleep that has not happened yet. Either one is then averaged into the
  /// sleep-debt total and the regularity index, so one careless tap moves a
  /// health figure the user has no way to reconcile.
  ///
  /// Works on the RESOLVED bed/wake instants rather than on the two pickers,
  /// so the 24-hour case is caught by its duration regardless of how the wrap
  /// produced it. 20 hours is comfortably past any real night — the longest a
  /// human could mean here is an early-evening bedtime and a late-afternoon
  /// wake, still under 20.
  static String? validate({
    required DateTime bedtime,
    required DateTime wakeTime,
    required DateTime now,
  }) {
    final minutes = wakeTime.difference(bedtime).inMinutes;
    if (minutes <= 0) {
      return 'Wake time has to be after bedtime.';
    }
    if (minutes >= 20 * 60) {
      return 'That is a ${(minutes / 60).round()}-hour night. Check the '
          'bedtime and wake time — they may be set to the same moment.';
    }
    if (wakeTime.isAfter(now)) {
      return 'That wake time has not happened yet. Pick a time that is already past.';
    }
    return null;
  }

  /// [editing] opens the sheet on a night already logged, to change it.
  static Future<SleepManualLogResult?> show(
    BuildContext context, {
    required SleepSchedule schedule,
    SleepSession? editing,
  }) {
    return AppBottomSheet.show<SleepManualLogResult>(
      context,
      title: editing == null ? 'Log sleep' : 'Edit night',
      icon: Symbols.nightlight_round_rounded,
      accent: AppColorsExt.of(context).sleep,
      builder: (ctx) => _ManualLogForm(schedule: schedule, editing: editing),
    );
  }
}

class _ManualLogForm extends StatefulWidget {
  final SleepSchedule schedule;
  final SleepSession? editing;
  const _ManualLogForm({required this.schedule, this.editing});

  @override
  State<_ManualLogForm> createState() => _ManualLogFormState();
}

class _ManualLogFormState extends State<_ManualLogForm> {
  late DateTime _wakeDate;
  late TimeOfDay _bed;
  late TimeOfDay _wake;
  int _quality = 4;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // `clock.now()` rather than `DateTime.now()` throughout: the future-wake
    // check below is only testable if "now" can be pinned.
    final now = clock.now();
    _bed = widget.schedule.bedtime;
    _wake = widget.schedule.wake;
    // The night to log is the one that has already ended. Between midnight and
    // the usual wake time, "today's" wake is still hours away, so defaulting to it
    // opened the sheet on "That wake time has not happened yet" with Save
    // disabled, for the one person likely to be logging a night at that hour.
    var wakeDate = DateTime(now.year, now.month, now.day);
    final wakeToday = DateTime(
        wakeDate.year, wakeDate.month, wakeDate.day, _wake.hour, _wake.minute);
    if (wakeToday.isAfter(now)) wakeDate = shiftCalendarDays(wakeDate, -1);
    _wakeDate = wakeDate;

    // Changing a night: open on what was logged, not on tonight's defaults.
    final e = widget.editing;
    if (e != null) {
      _wakeDate = DateTime(e.wakeTime.year, e.wakeTime.month, e.wakeTime.day);
      _bed = TimeOfDay.fromDateTime(e.bedtime);
      _wake = TimeOfDay.fromDateTime(e.wakeTime);
      _quality = e.qualityIndex ?? 4;
      _noteController.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime _wakeDateTime() => DateTime(
      _wakeDate.year, _wakeDate.month, _wakeDate.day, _wake.hour, _wake.minute);

  DateTime _bedDateTime() {
    var bed = DateTime(
        _wakeDate.year, _wakeDate.month, _wakeDate.day, _bed.hour, _bed.minute);
    // Bedtime is the evening before wake when it lands at/after the wake time.
    if (!bed.isBefore(_wakeDateTime())) {
      bed = shiftCalendarDays(bed, -1);
    }
    return bed;
  }

  int get _durationMinutes =>
      _wakeDateTime().difference(_bedDateTime()).inMinutes;

  String? get _validationError => SleepManualLogSheet.validate(
        bedtime: _bedDateTime(),
        wakeTime: _wakeDateTime(),
        now: clock.now(),
      );

  Future<void> _pickDate() async {
    final now = clock.now();
    final picked = await AppDatePicker.show(
      context,
      initial: _wakeDate,
      // A night being changed may be a year old; a new one is for the last three
      // months.
      first: now.subtract(Duration(days: widget.editing == null ? 90 : 365 * 3)),
      last: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _wakeDate = picked);
  }

  Future<void> _pickTime({required bool bed}) async {
    final picked = await AppTimePicker.show(
      context,
      initial: bed ? _bed : _wake,
    );
    if (picked != null) {
      setState(() {
        if (bed) {
          _bed = picked;
        } else {
          _wake = picked;
        }
      });
    }
  }

  void _save() {
    Navigator.pop(
      context,
      SleepManualLogResult(
        bedtime: _bedDateTime(),
        wakeTime: _wakeDateTime(),
        quality: _quality,
        note: _noteController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final sleep = ext.sleep;
    final error = _validationError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppListTile(
          icon: Symbols.event_rounded,
          title: 'Wake-up date',
          accent: sleep,
          trailing: _valueText(context, _dateLabel(_wakeDate)),
          onTap: _pickDate,
        ),
        AppListTile(
          icon: Symbols.bedtime_rounded,
          title: 'Bedtime',
          accent: sleep,
          trailing: _valueText(context, _bed.format(context)),
          onTap: () => _pickTime(bed: true),
        ),
        AppListTile(
          icon: Symbols.wb_sunny_rounded,
          title: 'Wake time',
          accent: sleep,
          trailing: _valueText(context, _wake.format(context)),
          onTap: () => _pickTime(bed: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: sleep.container,
            borderRadius: AppRadius.brMd,
          ),
          child: Row(
            children: [
              Icon(Symbols.nightlight_round_rounded, size: 18, color: sleep.onContainer),
              const SizedBox(width: 10),
              Text('Time in bed',
                  style:
                      tt.bodyMedium?.copyWith(color: sleep.onContainer)),
              const Spacer(),
              Text(
                SleepSession.formatMinutes(_durationMinutes),
                style: tt.titleMedium?.copyWith(
                  color: sleep.onContainer,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabular,
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.error_rounded, size: 16, color: ext.mark(ext.error)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  error,
                  style: tt.bodySmall?.copyWith(color: ext.mark(ext.error)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('How rested do you feel?',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        _QualitySelector(
          value: _quality,
          accent: sleep,
          onChanged: (v) => setState(() => _quality = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _noteController,
          label: 'Note (optional)',
          hint: 'e.g. woke up twice, warm room',
          accent: sleep,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: widget.editing == null ? 'Save sleep' : 'Save changes',
          leadingIcon: Symbols.check_rounded,
          fullWidth: true,
          accent: sleep,
          // `_durationMinutes > 0` is subsumed by [SleepManualLogSheet.validate],
          // which rejects the zero-length night the old guard let through as a
          // 24-hour one.
          onPressed: error == null ? _save : null,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _valueText(BuildContext context, String value) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: tt.titleMedium?.copyWith(color: ext.mark(ext.sleep))),
        const SizedBox(width: 4),
        Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
      ],
    );
  }

  static String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// A 1–5 quality rating rendered as tappable stars.
class _QualitySelector extends StatelessWidget {
  final int value;
  final AccentSwatch accent;
  final ValueChanged<int> onChanged;

  const _QualitySelector({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            // Every star up to the current rating reads as selected, which is
            // how a screen-reader user hears the value back: five unlabelled
            // taps with no state told them nothing at all. Same wrapper the
            // refill stepper carries (nunito_medication_detail_screen.dart) —
            // an icon-only GestureDetector reaches the semantics tree with an
            // EMPTY label otherwise.
            selected: i <= value,
            label: 'Rate $i of 5',
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              // 44pt, not the 34pt glyph plus 4pt of vertical padding: these
              // are the control that sets the rating, and they were 8pt under
              // the floor in both axes.
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    Symbols.star_rounded,
                    // The two arms of this used to be the SAME constant, so
                    // the only thing separating a filled star from an empty
                    // one was its colour — unreadable to anyone who cannot
                    // distinguish the accent from the outline, and invisible
                    // to a screen reader either way. `fill` is the variable
                    // font axis the theme already drives (app_theme.dart).
                    fill: i <= value ? 1 : 0,
                    size: 34,
                    color: i <= value ? ext.mark(accent) : ext.outlineStrong,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
