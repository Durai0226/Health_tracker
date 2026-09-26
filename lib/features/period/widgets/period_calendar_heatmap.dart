import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:tablet_remainder/core/utils/date_formats.dart';
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

  /// Apple's comfort minimum. Seven columns cannot all reach it on the 320pt
  /// floor — 7 x 44 = 308pt against the 272pt the screen gutter leaves — so it
  /// is applied where the grid can always honour it (the row height) and is
  /// reached on the width from about 355pt up, i.e. every mainstream phone.
  /// The cells were 41x41 on a 390pt screen before this.
  static const double _minTarget = 44.0;

  /// The visual gap between cells, held INSIDE the tappable slot instead of in
  /// `crossAxisSpacing`/`mainAxisSpacing`. Grid spacing comes off the target
  /// itself; an inset does not, so the whole grid pitch answers a tap.
  static const double _cellInset = 2.0;

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
    final today = clock.now();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1; // Mon-based

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_cell(context, ext, tt, date, today));
    }

    return AppCard(
      // Narrower than the 20pt default on the horizontal axis: every point of
      // card padding is taken off all seven columns at once, and the columns
      // are what has to clear [_minTarget]. The cells' own [_cellInset]
      // supplies the breathing room the padding was providing.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          // The weekday letters were grid children, which pinned them to the
          // same row extent as a day cell — 48pt of header for seven letters
          // once the cells grew. They are not tappable, so they do not need
          // the target height.
          Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: tt.labelSmall?.copyWith(color: ext.textTertiary)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = constraints.maxWidth / 7;
              // Same floor the water calendar derives: a square cell clips the
              // day number once Dynamic Type is scaled up, so the row extent is
              // the largest of the square, the comfort minimum and the text.
              final textExtent =
                  MediaQuery.textScalerOf(context).scale(13) * 1.4 + 8;
              final rowExtent =
                  math.max(cellWidth, math.max(_minTarget, textExtent));

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: rowExtent,
                ),
                itemCount: cells.length,
                itemBuilder: (_, i) => cells[i],
              );
            },
          ),
        ],
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
    Color fg = ext.textSecondary;
    Border? border;

    final flow = entry?.flow ?? FlowIntensity.none;
    final inFertile = _inRange(date, fertileStart, fertileEnd);
    final inPredicted = _inRange(date, predictedWindowStart, predictedWindowEnd);

    if (flow.isBleeding) {
      final swatch = PeriodTheme.phaseSwatch(ext, CyclePhase.menstrual);
      // Two AA-verified token pairs, not a four-step alpha ramp under white.
      //
      // The ramp was `mark(period)` at alpha 0.49..0.90 with a hardcoded white
      // on top in BOTH themes. Measured, five of the eight (level x theme)
      // combinations failed AA — spotting was 2.43:1 in light, heavy 3.14:1 in
      // dark — and the two themes failed at opposite ends of the ramp, so no
      // single foreground could have rescued it.
      //
      // Four alpha steps were not decodable anyway: the legend has always had
      // one "Period" entry, never four. The level is now carried by the
      // semantic label, which says it in words, and by a two-step fill the
      // legend names.
      final heavy = flow.index >= FlowIntensity.medium.index;
      bg = heavy ? ext.fillBg(swatch) : swatch.container;
      fg = heavy ? ext.fillFg(swatch) : swatch.onContainer;
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

    return Semantics(
      button: true,
      // The cell draws a day number and says everything else in colour: flow
      // level, fertile window, predicted window, symptoms. Without a label the
      // whole month announced as a list of bare numbers.
      //
      // `excludeSemantics` drops the inner day-number node, which would
      // otherwise repeat the date this label already opens with.
      label: _semanticLabel(
        date: date,
        flow: flow,
        isToday: isToday,
        inFertile: inFertile,
        inPredicted: inPredicted,
        hasSymptoms: hasSymptoms,
      ),
      // The tap action has to be declared HERE, not inherited.
      // `excludeSemantics` drops the whole child subtree from the semantics
      // tree, and the `GestureDetector`'s own tap action goes with it — so
      // without this the cell announced itself beautifully as a button and
      // then did nothing when a screen reader activated it. Same callback,
      // same day.
      onTap: () => onTapDay(date),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTapDay(date),
        child: Padding(
          padding: const EdgeInsets.all(_cellInset),
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
                    color: fg,
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
        ),
      ),
    );
  }

  /// What the cell MEANS, in words: the date first, so swiping through the
  /// month still reads as a date list, then the state it carries.
  ///
  /// "Today" is spoken alongside the rest rather than instead of it. The paint
  /// cannot do that — a today-and-predicted cell has only one border to give,
  /// and the today ring wins it — so this is one place the label says more
  /// than the colour can.
  String _semanticLabel({
    required DateTime date,
    required FlowIntensity flow,
    required bool isToday,
    required bool inFertile,
    required bool inPredicted,
    required bool hasSymptoms,
  }) {
    final parts = <String>[DateFormats.weekdayDayMonthLong.format(date)];
    if (isToday) parts.add('Today');
    // Same order, and same exclusivity, as the fill branches above: flow wins
    // over fertile wins over predicted, so the label cannot name a fill the
    // cell is not painting.
    if (flow.isBleeding) {
      parts.add(_flowPhrase(flow));
    } else if (inFertile) {
      parts.add('Fertile window');
    } else if (inPredicted) {
      parts.add('Period predicted');
    }
    if (hasSymptoms) parts.add('Symptoms logged');
    return parts.join(', ');
  }

  /// "Spotting" stands alone; the other levels read as "`<level>` flow".
  static String _flowPhrase(FlowIntensity flow) =>
      flow == FlowIntensity.spotting ? 'Spotting' : '${flow.label} flow';
}
