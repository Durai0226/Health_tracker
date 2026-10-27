import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/reminder_model.dart';
import '../services/overdue_triage.dart';

/// What the person chose to do with the whole heap.
enum TriageChoice { tonight, tomorrow, skip }

/// "Catch up": one sheet for a pile of overdue reminders — move the one-offs to
/// later, or let everything go. The list underneath stays the place for one
/// card at a time.
class OverdueTriageSheet {
  const OverdueTriageSheet._();

  static Future<TriageChoice?> show(
    BuildContext context, {
    required List<Reminder> overdue,
  }) {
    return AppBottomSheet.show<TriageChoice>(
      context,
      title: 'Catch up',
      icon: Symbols.checklist_rounded,
      accent: AppColorsExt.of(context).reminders,
      builder: (ctx) => OverdueTriageBody(
        overdue: overdue,
        onChoose: (c) => Navigator.of(ctx).pop(c),
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class OverdueTriageBody extends StatelessWidget {
  const OverdueTriageBody({
    super.key,
    required this.overdue,
    required this.onChoose,
    required this.onClose,
  });

  final List<Reminder> overdue;
  final ValueChanged<TriageChoice> onChoose;
  final VoidCallback onClose;

  /// Titles shown before "and N more".
  static const int previewCount = 4;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final now = clock.now();

    final movable = overdue.where(OverdueTriage.canMove).length;
    final repeating = overdue.length - movable;
    final tonight = OverdueTriage.tonight(now);
    final tomorrow = OverdueTriage.tomorrowMorning(now);

    String reminders(int n) => n == 1 ? '1 reminder' : '$n reminders';

    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required TriageChoice choice,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () => onChoose(choice),
            child: Row(children: [
              Icon(icon, color: ext.mark(ext.reminders)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleSmall?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style:
                            tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
            ]),
          ),
        );

    final moveNote = repeating == 0
        ? 'Moves all ${reminders(movable)}'
        : 'Moves ${reminders(movable)}; repeating ones keep their schedule';

    final String skipNote;
    if (repeating == 0) {
      skipNote = 'Closes all ${reminders(overdue.length)}';
    } else if (movable == 0) {
      skipNote = 'Repeating reminders jump to their next time';
    } else {
      skipNote = 'Closes ${reminders(movable)}; repeating ones jump to '
          'their next time';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${reminders(overdue.length)} overdue.',
            style: tt.titleSmall?.copyWith(
                color: ext.textPrimary, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        for (final r in overdue.take(previewCount))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${r.title} · ${_when(r.scheduledTime, now)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary),
            ),
          ),
        if (overdue.length > previewCount)
          Text('and ${overdue.length - previewCount} more',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
        const SizedBox(height: AppSpacing.lg),
        if (movable > 0 && tonight != null)
          option(
            icon: Symbols.wb_twilight_rounded,
            title:
                '${OverdueTriage.tonightLabel(tonight)} · ${DateFormats.time.format(tonight)}',
            subtitle: moveNote,
            choice: TriageChoice.tonight,
          ),
        if (movable > 0)
          option(
            icon: Symbols.wb_sunny_rounded,
            title: 'Tomorrow morning · ${DateFormats.time.format(tomorrow)}',
            subtitle: moveNote,
            choice: TriageChoice.tomorrow,
          ),
        option(
          icon: Symbols.done_all_rounded,
          title: 'Skip all',
          subtitle: skipNote,
          choice: TriageChoice.skip,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Close',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: onClose,
        ),
      ],
    );
  }

  /// "9:00 AM" for today, "Mar 3 · 9:00 AM" for an earlier day.
  static String _when(DateTime t, DateTime now) =>
      DateUtils.isSameDay(t, now)
          ? DateFormats.time.format(t)
          : DateFormats.dayMonthDotTime.format(t);
}
