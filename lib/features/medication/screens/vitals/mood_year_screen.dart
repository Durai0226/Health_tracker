import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/health/year_in_pixels.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../../../core/services/active_profile_service.dart';
import '../../../period/services/period_service.dart';
import '../../models/medicine_log.dart' show moodRatingLabels;
import '../../services/vitals_storage_service.dart';

/// A year of moods, one square a day: a row per month, a column per day, a
/// colour for how the day felt and a dot on the days of a period.
class MoodYearScreen extends StatefulWidget {
  const MoodYearScreen({super.key});

  @override
  State<MoodYearScreen> createState() => _MoodYearScreenState();
}

class _MoodYearScreenState extends State<MoodYearScreen> {
  List<PixelMood> _moods = const [];
  late int _year = clock.now().year;
  bool _loading = true;

  static const _monthInitials = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await VitalsStorageService.getAllMood();
    if (!mounted) return;
    setState(() {
      _moods = [for (final e in all) PixelMood(e.takenAt, e.moodIndex)];
      _loading = false;
    });
  }

  /// Period days belong to the account holder; showing them beside a family
  /// member's moods would put one person's cycle on another's year.
  List<DateTime> get _periodDays => !ActiveProfileService().isSelfActive
      ? const []
      : [
          for (final d in PeriodService.days.values)
            if (d.isBleeding) d.date,
        ];

  List<int> get _years =>
      YearInPixels.yearsWith(_moods, current: clock.now().year);

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.moodAccent(ext.isDark);
    final years = _years;
    final older = years.where((y) => y < _year).toList();
    final newer = years.where((y) => y > _year).toList();

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Year in pixels',
            leading: AppHeader.backButton(context),
            actions: [
              AppIconButton(
                icon: Symbols.chevron_left_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Earlier year',
                onPressed: older.isEmpty ? null : () => setState(() => _year = older.first),
              ),
              AppIconButton(
                icon: Symbols.chevron_right_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Later year',
                onPressed: newer.isEmpty ? null : () => setState(() => _year = newer.last),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : _body(ext),
          ),
        ],
      ),
    );
  }

  Widget _body(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    final pixels = YearInPixels.build(
        year: _year, moods: _moods, periodDays: _periodDays);
    final today = clock.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        Text('$_year',
            style: tt.headlineSmall?.copyWith(
                color: ext.textPrimary, fontWeight: FontWeight.w800)),
        Text(
          pixels.loggedDays == 0
              ? 'Nothing logged this year yet.'
              : '${pixels.loggedDays} ${pixels.loggedDays == 1 ? 'day' : 'days'} logged',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        _grid(ext, pixels, today),
        const SizedBox(height: AppSpacing.lg),
        _legend(ext, pixels),
      ],
    );
  }

  static const double _labelWidth = 18.0;
  static const double _gap = 1.5;

  Widget _grid(AppColorsExt ext, PixelYear pixels, DateTime today) {
    return LayoutBuilder(builder: (context, c) {
      final cell = ((c.maxWidth - _labelWidth) / 31 - _gap).clamp(6.0, 16.0);
      final step = cell + _gap;

      // One tap target for the whole grid, resolving the nearest day. The
      // squares are 6-16pt: no finger lands on one reliably, and 372 separate
      // 10pt targets would each be below the touch minimum. Every row is
      // exactly `cell` tall (see the month initial below), so the pitch is the
      // same in both directions and the maths here is the layout's own.
      void tapAt(Offset p) {
        final m = (p.dy / step).floor();
        final d = ((p.dx - _labelWidth) / step).floor();
        if (m < 0 || m > 11 || d < 0 || d > 30) return;
        final day = pixels.months[m][d];
        if (day != null && (day.logged || day.period)) {
          context.toastInfo(_label(day));
        }
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The squares announce themselves; a second, unlabelled "button" over
        // the whole grid would only get in a screen reader's way.
        excludeFromSemantics: true,
        onTapUp: (details) => tapAt(details.localPosition),
        child: Column(
          children: [
            for (var m = 0; m < 12; m++)
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: Row(
                  children: [
                    // The initial is taller than a square, so it overhangs its row
                    // rather than stretching it; a taller row would put every
                    // square below it out of step with the tap maths.
                    SizedBox(
                      width: _labelWidth,
                      height: cell,
                      child: OverflowBox(
                        minHeight: 0,
                        maxHeight: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: Text(_monthInitials[m],
                            textScaler: MediaQuery.textScalerOf(context)
                                .clamp(maxScaleFactor: 1.2),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: ext.textTertiary)),
                      ),
                    ),
                    for (var d = 0; d < 31; d++)
                      Padding(
                        padding: const EdgeInsets.only(right: _gap),
                        child: _cell(ext, pixels.months[m][d], cell, today),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  /// "Mar 4, Good, period" — what a square announces and what tapping says.
  String _label(PixelDay day) => [
        DateFormats.dayMonth.format(day.date),
        if (day.logged) moodRatingLabels[day.mood!],
        if (day.period) 'period',
      ].join(', ');

  Widget _cell(AppColorsExt ext, PixelDay? day, double size, DateTime today) {
    if (day == null) return SizedBox(width: size, height: size);
    final future = YearInPixels.isFuture(day.date, today);
    final color = day.logged
        ? VitalsColors.moodBand(ext.isDark, day.mood!)
        : ext.surfaceVariant.withValues(alpha: future ? 0.25 : 0.7);

    // Square on purpose: it is a pixel grid.
    final box = Container(
      width: size,
      height: size,
      color: color,
      child: day.period
          ? Center(
              child: Container(
                width: size * 0.4,
                height: size * 0.4,
                decoration: BoxDecoration(
                  color: ext.mark(ext.period),
                  shape: BoxShape.circle,
                  border: Border.all(color: ext.surface, width: 0.75),
                ),
              ),
            )
          : null,
    );

    if (!day.logged && !day.period) return box;
    // Its own node, so a screen reader walks the logged days one at a time
    // instead of reading the grid as one long run. Touch goes through the
    // grid's single target above.
    return Semantics(
      container: true,
      label: _label(day),
      excludeSemantics: true,
      child: box,
    );
  }

  Widget _legend(AppColorsExt ext, PixelYear pixels) {
    final tt = Theme.of(context).textTheme;
    final counts = pixels.distribution;
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: color),
            const SizedBox(width: 6),
            // Flexible: at a large text size a label can be wider than the
            // line, and a Wrap gives its children no way to shrink otherwise.
            Flexible(
              child: Text(label,
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            ),
          ],
        );
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < 5; i++)
          item(VitalsColors.moodBand(ext.isDark, i),
              '${moodRatingLabels[i]} · ${counts[i]}'),
        if (pixels.hasPeriod) item(ext.mark(ext.period), 'Period'),
      ],
    );
  }
}
