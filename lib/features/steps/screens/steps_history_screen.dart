import 'package:flutter/material.dart';
import '../../../core/utils/calendar_day.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/step_daily_data.dart';
import '../models/step_source.dart';
import '../services/step_service.dart';
import '../utils/step_format.dart';
import 'package:clock/clock.dart';

/// Scrollable history of recent days — a mini goal ring, the day's steps,
/// distance and calories, and a reached badge. Reactive to service changes.
class StepsHistoryScreen extends StatelessWidget {
  const StepsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.steps,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final listenable = StepService.listenToDailyData();
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Step history',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: listenable == null
                ? _buildList(context)
                : ValueListenableBuilder(
                    valueListenable: listenable,
                    builder: (context, _, _) => _buildList(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final now = clock.now();
    final days = StepService.getDataForRange(
      now.subtract(const Duration(days: 30)),
      now,
    )..sort((a, b) => b.date.compareTo(a.date)); // newest first

    if (days.isEmpty) {
      return const EmptyState(
        icon: Symbols.directions_walk_rounded,
        title: 'No history yet',
        message: 'Your logged and synced days will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _DayCard(day: days[i]),
    );
  }
}

class _DayCard extends StatelessWidget {
  final StepDailyData day;
  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final pct = (day.progress * 100).round();

    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: day.clampedProgress,
            size: 54,
            stroke: 6,
            accent: day.goalReached ? ext.success : ext.steps,
            animate: !MediaQuery.of(context).disableAnimations,
            center: Text(
              '$pct%',
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateLabel(day.date), style: tt.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '${formatThousands(day.effectiveSteps)} steps · '
                  '${day.distanceKm.toStringAsFixed(day.distanceKm >= 10 ? 0 : 1)} km · '
                  '${formatThousands(day.activeCalories.round())} kcal',
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  day.source.label,
                  style: tt.labelSmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ),
          if (day.goalReached)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ext.success.container,
                shape: BoxShape.circle,
              ),
              child: Icon(Symbols.check_rounded,
                  size: 16, color: ext.success.onContainer),
            ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime d) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    // Calendar days — see the same fix in `app_date_time_field`. Across a
    // spring-forward boundary the truncated elapsed diff came back 0 for
    // BOTH the 8th and the 9th, so the history list rendered two consecutive
    // rows headed "Today".
    final diff = calendarDaysBetween(that, today);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}
