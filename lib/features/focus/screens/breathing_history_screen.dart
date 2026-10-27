import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/calendar_day.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/breathing_exercise.dart';
import '../models/breathing_record.dart';
import '../services/breathing_history.dart';

/// The breathing exercises that were finished: how many, for how long, which
/// patterns, and each one by day.
///
/// The only trace of a breathing exercise was a counter behind an achievement, so
/// what had been practised could not be looked back on.
class BreathingHistoryScreen extends StatelessWidget {
  const BreathingHistoryScreen({super.key, this.records});

  /// The records to show. Null reads the saved history; a test hands its own.
  final List<BreathingRecord>? records;

  /// "Today", "Yesterday", "Sep 26".
  static String dayHeading(DateTime day, DateTime now) {
    if (isSameCalendarDay(day, now)) return 'Today';
    if (isSameCalendarDay(day, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormats.dayLabel(day, reference: now);
  }

  /// "4 cycles · 1 min".
  static String detail(BreathingRecord r) {
    final minutes = (r.seconds / 60).round();
    final cycles = '${r.cycles} ${r.cycles == 1 ? 'cycle' : 'cycles'}';
    return minutes < 1 ? cycles : '$cycles · $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final list = records ?? BreathingHistory.all();
    final summary = BreathingHistory.summarize(list);
    final now = clock.now();

    final children = <Widget>[];
    DateTime? day;
    var group = <BreathingRecord>[];
    void flush() {
      if (day == null || group.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        child: Text(dayHeading(day, now),
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
      ));
      children.add(AppCard(
        child: Column(children: [for (final r in group) _RecordRow(record: r)]),
      ));
      group = [];
    }

    for (final r in list) {
      final d = startOfDay(r.completedAt);
      if (day != null && d != day) flush();
      day = d;
      group.add(r);
    }
    flush();

    return AccentScope(
      feature: FeatureAccent.focus,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Breathing history',
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                children: [
                  if (list.isEmpty)
                    EmptyState(
                      icon: Symbols.air_rounded,
                      title: 'No breathing yet',
                      message: 'Each exercise you finish is listed here.',
                      accent: ext.focus,
                      action: AppButton(
                        label: 'Back to Focus',
                        accent: ext.focus,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    )
                  else ...[
                    StatTileRow(
                      tiles: [
                        StatTile(
                          icon: Symbols.air_rounded,
                          value: '${summary.sessions}',
                          label: 'Sessions',
                          accent: ext.focus,
                        ),
                        StatTile(
                          icon: Symbols.timer_rounded,
                          value: '${summary.minutes}',
                          label: 'Minutes',
                          accent: ext.info,
                        ),
                        StatTile(
                          icon: Symbols.calendar_view_week_rounded,
                          value: '${summary.thisWeek}',
                          label: 'This week',
                          accent: ext.success,
                        ),
                      ],
                    ),
                    if (summary.mostUsed != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Most often: ${summary.mostUsed!.name}',
                        style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                      ),
                    ],
                    ...children,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final BreathingRecord record;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final color = record.pattern.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: ext.isDark ? 0.24 : 0.14),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(record.pattern.icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.pattern.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(color: ext.textPrimary)),
                Text(BreathingHistoryScreen.detail(record),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(DateFormats.time.format(record.completedAt),
              maxLines: 1,
              style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
        ],
      ),
    );
  }
}
