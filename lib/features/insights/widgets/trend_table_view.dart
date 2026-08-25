/// The accessible twin of every chart in this app.
///
/// Two of the six chart accents sit below 3:1 against the card surface (water
/// #06B6D4 at 2.36, steps #22C55E at 2.22 — measured, not estimated). That is
/// fine for a *mark*, but it means those series must never be colour-only. A
/// contrast shortfall is not dismissable: it obligates either a visible label
/// on every point — which is the "number on every data point" anti-pattern, and
/// unreadable at seven points in a 128pt box — or a table view. This is the
/// table view.
///
/// It is deliberately one widget shared by all three card types rather than a
/// per-card implementation. Every value on screen is reachable here, so a
/// touch tooltip stays an enhancement instead of being the only way to read a
/// number.
library;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/trends_data_service.dart';


/// A gap day. `TrendPoint.value == null` means nothing was logged, which is not
/// the same fact as logging zero, and the table must not blur them — a `0` row
/// on a day with no entry reads as "drank nothing", which the app cannot know.
const String kNotLogged = 'Not logged';

/// Renders a [TrendSeries] as a two- or three-column table.
///
/// Tabular figures are correct here and only here: these are columns of numbers
/// that must align vertically. (On a large standalone figure they are wrong —
/// equal-width digits make a hero number read loose.)
class TrendTableView extends StatelessWidget {
  final TrendSeries series;

  /// Column heading for [TrendPoint.value].
  final String valueLabel;

  /// Column heading for [TrendPoint.value2]. Non-null only for the one genuine
  /// two-series case (blood pressure), where both columns are the same unit.
  final String? secondaryLabel;

  final String Function(double) formatValue;

  /// Newest-first. Charts read left-to-right oldest-first, but a table is
  /// scanned from the top and the most recent day is what a reader wants first.
  final bool newestFirst;

  const TrendTableView({
    super.key,
    required this.series,
    required this.valueLabel,
    required this.formatValue,
    this.secondaryLabel,
    this.newestFirst = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final points = newestFirst
        ? series.points.reversed.toList(growable: false)
        : series.points;

    final headStyle = tt.labelMedium?.copyWith(
      color: ext.textSecondary,
      fontWeight: FontWeight.w700,
    );
    final cellStyle = tt.bodyMedium?.copyWith(
      color: ext.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final gapStyle = tt.bodyMedium?.copyWith(color: ext.textTertiary);

    Widget numberCell(double? v, TextStyle? logged) => Expanded(
          child: Text(
            v == null ? kNotLogged : formatValue(v),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: v == null ? gapStyle : logged,
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Day', style: headStyle)),
              Expanded(
                child: Text(valueLabel,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: headStyle),
              ),
              if (secondaryLabel != null)
                Expanded(
                  child: Text(secondaryLabel!,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: headStyle),
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: ext.outline),
        // Bounded so a 30-day range scrolls inside the sheet instead of
        // overflowing it, and shrink-wrapped so a 7-day range doesn't leave a
        // half-empty box.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: points.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, thickness: 1, color: ext.outline),
            itemBuilder: (context, i) {
              final p = points[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormats.weekdayDayMonthShort.format(p.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                            color: p.hasData
                                ? ext.textPrimary
                                : ext.textTertiary),
                      ),
                    ),
                    numberCell(p.value, cellStyle),
                    if (secondaryLabel != null)
                      numberCell(p.value2, cellStyle),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Opens this table in a sheet. Every card's "View as table" control routes
  /// here, so the presentation cannot drift between card types.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required AccentSwatch accent,
    required TrendSeries series,
    required String valueLabel,
    required String Function(double) formatValue,
    String? secondaryLabel,
  }) {
    return AppBottomSheet.show<void>(
      context,
      title: title,
      icon: Symbols.table_rows_rounded,
      accent: accent,
      builder: (_) => TrendTableView(
        series: series,
        valueLabel: valueLabel,
        formatValue: formatValue,
        secondaryLabel: secondaryLabel,
      ),
    );
  }
}

/// The "View as table" control. Low-emphasis on purpose — it must be findable
/// without competing with the chart it annotates.
///
/// [AppButtonSize.sm] is 44pt tall, the Apple/Material tap minimum, so this
/// cannot become the thing that fails the touch-target audit on a screen that
/// adopts it.
class TrendTableButton extends StatelessWidget {
  final String title;
  final AccentSwatch accent;
  final TrendSeries series;
  final String valueLabel;
  final String Function(double) formatValue;
  final String? secondaryLabel;

  const TrendTableButton({
    super.key,
    required this.title,
    required this.accent,
    required this.series,
    required this.valueLabel,
    required this.formatValue,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppButton(
        label: 'View as table',
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.sm,
        accent: accent,
        leadingIcon: Symbols.table_rows_rounded,
        onPressed: () => TrendTableView.show(
          context,
          title: title,
          accent: accent,
          series: series,
          valueLabel: valueLabel,
          formatValue: formatValue,
          secondaryLabel: secondaryLabel,
        ),
      ),
    );
  }
}

/// A spoken summary of a chart, so a screen reader gets the shape of the data
/// rather than "chart" or nothing at all.
///
/// Deliberately factual: counts, average, and the two extremes with their dates.
/// It states no direction and no judgement — `TrendSeries.direction` exists and
/// is rendered as an arrow only where the card's caller has established that
/// "up is good", which this function cannot know.
String trendSeriesSummary({
  required String title,
  required TrendSeries series,
  required int rangeDays,
  required String Function(double) formatValue,
  String? valueLabel,
  String? secondaryLabel,
}) {
  final parts = <String>[];
  if (!series.hasData) {
    return '$title chart. Nothing logged in the last $rangeDays days.';
  }

  parts.add('$title chart, last $rangeDays days.');
  parts.add('${series.loggedDays} of ${series.points.length} days logged.');

  // No unit is appended anywhere below: every caller's `formatValue` already
  // renders one ("2100 ml", "8500 steps", "72%"). Adding `valueLabel` on top
  // would speak "Average 2100 ml Water", which is how a summary starts sounding
  // like a machine reading a spreadsheet.
  final avg = series.average;
  if (avg != null) {
    parts.add(secondaryLabel == null
        ? 'Average ${formatValue(avg)}.'
        : 'Average ${valueLabel ?? 'primary'} ${formatValue(avg)}.');
  }

  if (secondaryLabel != null) {
    final second = series.points
        .where((p) => p.value2 != null)
        .map((p) => p.value2!)
        .toList(growable: false);
    if (second.isNotEmpty) {
      final a = second.reduce((x, y) => x + y) / second.length;
      parts.add('Average $secondaryLabel ${formatValue(a)}.');
    }
  } else {
    TrendPoint? lo;
    TrendPoint? hi;
    for (final p in series.points) {
      if (p.value == null) continue;
      if (lo == null || p.value! < lo.value!) lo = p;
      if (hi == null || p.value! > hi.value!) hi = p;
    }
    // With one logged day the low and the high are the same row; saying it
    // twice reads as a stutter.
    if (lo != null && hi != null && lo != hi) {
      final loDay = DateFormats.weekdayDayMonthShort.format(lo.date);
      final hiDay = DateFormats.weekdayDayMonthShort.format(hi.date);
      parts.add('Lowest ${formatValue(lo.value!)} on $loDay, '
          'highest ${formatValue(hi.value!)} on $hiDay.');
    }
  }

  return parts.join(' ');
}
