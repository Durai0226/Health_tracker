import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/day_rhythm.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "A typical day from your wake time": groggy, warming up, often best for focus,
/// the afternoon dip, a second wind, wind down.
///
/// A general pattern laid against the person's own wake time and bedtime — NOT
/// measured from them, and the card says so on its face. It names no score and
/// no verdict: a day that does not look like this is not a fault.
class DayRhythmCard extends StatelessWidget {
  const DayRhythmCard({
    super.key,
    required this.spans,
    required this.wakeMinute,
    required this.fromNights,
    this.nowMinute,
  });

  /// The phases, as [DayRhythm.of] made them.
  final List<RhythmSpan> spans;

  /// When the person wakes, as minutes since midnight.
  final int wakeMinute;

  /// Whether that wake time is the average of their recent nights (true) or the
  /// one they set in their sleep schedule (false).
  final bool fromNights;

  /// Where in the day it is, to say which phase is now.
  final int? nowMinute;

  static String _time(BuildContext context, int minutes) {
    final m = DayRhythm.clock(minutes);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);
  }

  /// The phase [nowMinute] falls in, or null between phases or outside the day.
  /// [nowMinute] is a time of day; a phase past midnight is also matched a day on.
  static RhythmSpan? phaseAt(List<RhythmSpan> spans, int nowMinute) {
    for (final s in spans) {
      for (final t in [nowMinute, nowMinute + 1440]) {
        if (t >= s.start && t < s.end) return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final focus = spans.where((s) => s.phase == RhythmPhase.focus).firstOrNull;
    final now = nowMinute == null ? null : phaseAt(spans, nowMinute!);

    Color tint(RhythmPhase p) {
      switch (p) {
        case RhythmPhase.focus:
          return ext.mark(ext.sleep);
        case RhythmPhase.dip:
          return ext.surfaceVariant;
        default:
          return ext.sleep.container;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ext.sleep.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.wb_twilight_rounded,
                    size: 22, color: ext.sleep.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppEyebrow("A TYPICAL DAY"),
                    const SizedBox(height: 2),
                    Text(
                      focus == null
                          ? 'From your wake time'
                          : 'Often best for focus ${_time(context, focus.start)} – ${_time(context, focus.end)}',
                      style: tt.titleMedium,
                    ),
                    if (now != null) ...[
                      const SizedBox(height: 2),
                      Text('Right now: ${DayRhythm.label(now.phase).toLowerCase()}',
                          style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // The day as a bar: each phase as wide as it lasts. Decorative — the
          // list beneath says the same in words.
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: AppRadius.brSm,
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (var i = 0; i < spans.length; i++) ...[
                      if (i > 0 && spans[i].start > spans[i - 1].end)
                        Expanded(
                          flex: spans[i].start - spans[i - 1].end,
                          child: ColoredBox(color: ext.surfaceVariant),
                        ),
                      Expanded(
                        flex: spans[i].minutes,
                        child: ColoredBox(color: tint(spans[i].phase)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in spans) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              // A Wrap, not a Row: at a large text size the time range drops
              // beneath its label instead of overflowing beside it.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  Text(DayRhythm.label(s.phase),
                      style: tt.bodyMedium?.copyWith(
                          color: ext.textPrimary,
                          fontWeight: s == now ? FontWeight.w700 : null)),
                  Text('${_time(context, s.start)} – ${_time(context, s.end)}',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A general pattern for the hours after waking, fitted to your wake '
            'time of ${_time(context, wakeMinute)} '
            '(${fromNights ? 'from your recent nights' : 'from your sleep schedule'}). '
            'It is not measured from you, and everyone\'s differs.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
        ],
      ),
    );
  }
}
