import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/sleep_schedule.dart';
import '../models/sleep_session.dart';

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

  static Future<SleepManualLogResult?> show(
    BuildContext context, {
    required SleepSchedule schedule,
  }) {
    return AppBottomSheet.show<SleepManualLogResult>(
      context,
      title: 'Log sleep',
      icon: Symbols.nightlight_round_rounded,
      accent: AppColorsExt.of(context).sleep,
      builder: (ctx) => _ManualLogForm(schedule: schedule),
    );
  }
}

class _ManualLogForm extends StatefulWidget {
  final SleepSchedule schedule;
  const _ManualLogForm({required this.schedule});

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
    final now = DateTime.now();
    _wakeDate = DateTime(now.year, now.month, now.day);
    _bed = widget.schedule.bedtime;
    _wake = widget.schedule.wake;
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
      bed = bed.subtract(const Duration(days: 1));
    }
    return bed;
  }

  int get _durationMinutes =>
      _wakeDateTime().difference(_bedDateTime()).inMinutes;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await AppDatePicker.show(
      context,
      initial: _wakeDate,
      first: now.subtract(const Duration(days: 90)),
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
          label: 'Save sleep',
          leadingIcon: Symbols.check_rounded,
          fullWidth: true,
          accent: sleep,
          onPressed: _durationMinutes > 0 ? _save : null,
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
    final now = DateTime.now();
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
          GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Icon(
                i <= value ? Symbols.star_rounded : Symbols.star_rounded,
                size: 34,
                color: i <= value ? ext.mark(accent) : ext.outlineStrong,
              ),
            ),
          ),
      ],
    );
  }
}
