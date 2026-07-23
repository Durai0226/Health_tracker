import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/cycle_phase.dart';
import '../models/flow_intensity.dart';
import '../models/period_day.dart';
import '../theme/period_theme.dart';

/// A month heatmap: bleeding days as filled flow-tinted cells, fertile window as
/// a soft band, predicted period window outlined, symptom days marked with a
/// dot. Tapping a day opens the log sheet for it.
class PeriodCalendarHeatmap extends StatelessWidget {
  final DateTime month;
  final Map<String, PeriodDay> days;
  final CyclePhase? Function(DateTime) phaseOf;
  final DateTime? predictedWindowStart;
  final DateTime? predictedWindowEnd;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;
  final void Function(DateTime) onTapDay;

  const PeriodCalendarHeatmap({
    super.key,
    required this.month,
    required this.days,
    required this.phaseOf,
    this.predictedWindowStart,
    this.predictedWindowEnd,
    this.fertileStart,
    this.fertileEnd,
    required this.onTapDay,
  });

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool _inRange(DateTime d, DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final x = DateTime(d.year, d.month, d.day);
    final lo = DateTime(a.year, a.month, a.day);
    final hi = DateTime(b.year, b.month, b.day);
    return !x.isBefore(lo) && !x.isAfter(hi);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final today = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1; // Mon-based

    final cells = <Widget>[];
    for (final w in _weekdayLabels) {
      cells.add(Center(
        child: Text(w,
            style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
      ));
    }
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_cell(context, ext, tt, date, today));
    }

    return AppCard(
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: cells,
      ),
    );
  }

  Widget _cell(BuildContext context, AppColorsExt ext, TextTheme tt,
      DateTime date, DateTime today) {
    final key = PeriodDay.keyFor(date);
    final entry = days[key];
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    Color? bg;
    Color fg = ext.textPrimary;
    Border? border;

    final flow = entry?.flow ?? FlowIntensity.none;
    final inFertile = _inRange(date, fertileStart, fertileEnd);
    final inPredicted = _inRange(date, predictedWindowStart, predictedWindowEnd);

    if (flow.isBleeding) {
      final swatch = PeriodTheme.phaseSwatch(ext, CyclePhase.menstrual);
      bg = ext.mark(swatch).withValues(alpha: 0.35 + 0.55 * flow.intensity);
      fg = ext.isDark ? Colors.white : Colors.white;
    } else if (inFertile) {
      final swatch = PeriodTheme.fertileSwatch(ext);
      bg = swatch.container;
      fg = swatch.onContainer;
    } else if (inPredicted) {
      final swatch = PeriodTheme.phaseSwatch(ext, CyclePhase.menstrual);
      border =
          Border.all(color: ext.mark(swatch).withValues(alpha: 0.6), width: 1.4);
    }

    if (isToday) {
      border = Border.all(color: ext.mark(ext.brand), width: 1.8);
    }

    final hasSymptoms = (entry?.symptomIds.isNotEmpty ?? false);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapDay(date),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.brSm,
          border: border,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: tt.labelMedium?.copyWith(
                color: bg != null ? fg : ext.textSecondary,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
            if (hasSymptoms)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bg != null ? fg : ext.mark(ext.focus),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
