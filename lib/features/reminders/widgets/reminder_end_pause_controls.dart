import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';

DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59);

/// How a repeating reminder stops: never, on a date, or after N times.
///
/// The three states are two nullable fields on [Reminder] (`endsAt`,
/// `occurrenceLimit`) that the engine has honoured for a while and the form had
/// no way to set. Choosing a mode clears the other field, so the form can never
/// hold both and the label can never disagree with what is saved.
class ReminderEndsControl extends StatelessWidget {
  const ReminderEndsControl({
    super.key,
    required this.endsAt,
    required this.limit,
    required this.firstDate,
    required this.onChanged,
    required this.accent,
  });

  final DateTime? endsAt;
  final int? limit;

  /// The earliest sensible end: the day of the first reminder. An end date
  /// before the reminder starts would mean it never fires at all.
  final DateTime firstDate;
  final void Function(DateTime? endsAt, int? limit) onChanged;
  final AccentSwatch accent;

  static const int defaultCount = 10;
  static const int maxCount = 999;

  /// Which of the three the stored fields describe. A date wins if somehow both
  /// are set (Smart Add can parse both), and neither is lost until the user
  /// changes the mode.
  static String modeOf(DateTime? endsAt, int? limit) =>
      endsAt != null ? 'date' : (limit != null ? 'count' : 'never');

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final mode = modeOf(endsAt, limit);

    Widget dropdown() => Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: ext.surfaceVariant,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: ext.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: mode,
              isExpanded: true,
              borderRadius: AppRadius.brMd,
              dropdownColor: ext.surface,
              style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
              icon: Icon(Symbols.keyboard_arrow_down_rounded,
                  color: ext.mark(accent)),
              items: const [
                DropdownMenuItem(value: 'never', child: Text('Never')),
                DropdownMenuItem(value: 'date', child: Text('On a date')),
                DropdownMenuItem(value: 'count', child: Text('After a number')),
              ],
              onChanged: (v) {
                switch (v) {
                  case 'never':
                    onChanged(null, null);
                  case 'date':
                    onChanged(
                        _endOfDay(endsAt ??
                            DateTime(firstDate.year, firstDate.month + 1,
                                firstDate.day)),
                        null);
                  case 'count':
                    onChanged(null, limit ?? defaultCount);
                }
              },
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dropdown(),
        if (mode == 'date') ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            onTap: () async {
              final picked = await AppDatePicker.show(
                context,
                initial: endsAt!.isBefore(firstDate) ? firstDate : endsAt,
                first: firstDate,
                last: DateTime(firstDate.year + 5, firstDate.month, firstDate.day),
                accent: accent,
                title: 'Last reminder on',
              );
              if (picked != null) onChanged(_endOfDay(picked), null);
            },
            child: Row(children: [
              Icon(Symbols.event_busy_rounded, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Last on ${DateFormats.dayMonthYear.format(endsAt!)}',
                    style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
              ),
              Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
            ]),
          ),
        ],
        if (mode == 'count') ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Row(children: [
              Expanded(
                child: Text(
                    'Stops after $limit ${limit == 1 ? 'time' : 'times'}',
                    style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
              ),
              IconButton(
                tooltip: 'Fewer',
                onPressed: limit! > 1 ? () => onChanged(null, limit! - 1) : null,
                icon: const Icon(Symbols.remove_rounded),
              ),
              IconButton(
                tooltip: 'More',
                onPressed:
                    limit! < maxCount ? () => onChanged(null, limit! + 1) : null,
                icon: const Icon(Symbols.add_rounded),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// "Pause this reminder", optionally until a date.
///
/// A paused reminder is kept but not armed; with a date it comes back by itself
/// (see `ReminderPauseUntil`). Without one it stays paused until switched back.
class ReminderPauseControl extends StatelessWidget {
  const ReminderPauseControl({
    super.key,
    required this.paused,
    required this.until,
    required this.onChanged,
    required this.accent,
  });

  final bool paused;
  final DateTime? until;
  final void Function(bool paused, DateTime? until) onChanged;
  final AccentSwatch accent;

  /// Finds the switch (the word "Pause" is also the section header above it).
  static const pauseSwitchKey = ValueKey('reminder_pause_switch');

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final firstPick = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(children: [
            Icon(Symbols.pause_circle_rounded, color: ext.mark(accent)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Pause',
                  style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
            ),
            AppSwitch(
              key: pauseSwitchKey,
              value: paused,
              accent: accent,
              onChanged: (v) => onChanged(v, v ? until : null),
            ),
          ]),
        ),
        if (paused) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            onTap: () async {
              final picked = await AppDatePicker.show(
                context,
                initial: until != null && !until!.isBefore(firstPick)
                    ? until
                    : firstPick,
                first: firstPick,
                last: DateTime(firstPick.year + 2, firstPick.month, firstPick.day),
                accent: accent,
                title: 'Resume on',
              );
              if (picked != null) onChanged(true, picked);
            },
            child: Row(children: [
              Icon(Symbols.event_available_rounded, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                    until == null
                        ? 'Resume on a date (optional)'
                        : 'Back on ${DateFormats.dayMonthYear.format(until!)}',
                    style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
              ),
              if (until != null)
                IconButton(
                  tooltip: 'Clear the resume date',
                  onPressed: () => onChanged(true, null),
                  icon: const Icon(Symbols.close_rounded),
                )
              else
                Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
            ]),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            until == null
                ? 'Stays paused until you switch it back on.'
                : 'Comes back by itself the first time you open the app on '
                    'or after that day.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
        ],
      ],
    );
  }
}
