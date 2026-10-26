import 'package:clock/clock.dart';
import '../../utils/calendar_day.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import '../../utils/date_formats.dart';
import 'app_pickers.dart';

/// "When did this happen" — a date box and a time box side by side, each
/// opening the branded [AppDatePicker] / [AppTimePicker] sheet.
///
/// Lifted from the four vitals screens (mood, weight, blood sugar, blood
/// pressure), which each carried a byte-identical private `_TakenAtField`
/// except for the two picker-sheet titles — so [noun] is the only thing that
/// ever varied between the copies ('Entry' on mood, 'Reading' on the other
/// three), and it stays a parameter rather than being flattened to one word.
///
/// It is what lets an entry be back-dated: every caller keeps its own
/// `_takenAt` and seeds [value] with the entry's own time (or now), so the
/// common case still costs zero taps and only a deliberate tap moves it.
///
/// The future is never selectable: these fields record something that has
/// already happened.
class AppDateTimeField extends StatelessWidget {
  /// The currently-recorded moment. Date and time are edited separately but
  /// carried together — picking a date keeps the time, and vice versa.
  final DateTime value;

  final AccentSwatch accent;

  /// Titles the two picker sheets: '$noun date' and '$noun time'.
  final String noun;

  final ValueChanged<DateTime> onChanged;

  const AppDateTimeField({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
    this.noun = 'Entry',
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = clock.now();
    final picked = await AppDatePicker.show(
      context,
      initial: value,
      first: DateTime(now.year - 5),
      // A reading can't have been taken in the future.
      last: DateTime(now.year, now.month, now.day),
      accent: accent,
      title: '$noun date',
    );
    if (picked == null) return;
    onChanged(DateTime(
        picked.year, picked.month, picked.day, value.hour, value.minute));
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await AppTimePicker.show(
      context,
      initial: TimeOfDay.fromDateTime(value),
      accent: accent,
      title: '$noun time',
    );
    if (picked == null) return;
    onChanged(DateTime(
        value.year, value.month, value.day, picked.hour, picked.minute));
  }

  /// `clock.now()` rather than `DateTime.now()` so a test can pin what "Today"
  /// means — the label is relative, and the copies this replaced could only be
  /// checked against whatever day the test happened to run on.
  String _dateLabel() {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    // Calendar days, not elapsed ones. A civil day containing a
    // spring-forward transition is 23 hours, so `difference().inDays`
    // truncates to one short on the day after — verified under
    // TZ=America/New_York, where a reading dated the 8th read "Today" on the
    // 9th. This field is the shared Date & time input on every vitals screen.
    final diff = calendarDaysBetween(day, today);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormats.dayLabel(day, reference: today);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date & time',
            style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _box(context, Symbols.calendar_today_rounded, _dateLabel(),
                  () => _pickDate(context)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _box(
                  context,
                  Symbols.schedule_rounded,
                  TimeOfDay.fromDateTime(value).format(context),
                  () => _pickTime(context)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _box(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: ext.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ext.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            // scaleDown only: a long date shrinks to fit on a 320pt screen,
            // nothing is ever enlarged and no font size is hardcoded.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
