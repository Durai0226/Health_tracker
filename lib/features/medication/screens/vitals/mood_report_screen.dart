import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../models/medicine_log.dart' show moodRatingLabels;
import '../../models/mood_entry.dart';
import '../../services/medicine_storage_service.dart';
import '../../services/mood_report_service.dart';
import '../../services/vitals_storage_service.dart';
import 'vitals_trend_chart.dart';

/// Mood report: how a stretch of days went, and a PDF to bring to a check-up.
///
/// Says what was logged — an average of the days, how many were hard ones, what
/// the tags went with — and does not interpret it. The PDF leaves the notes out.
class MoodReportScreen extends StatefulWidget {
  const MoodReportScreen({super.key, this.onShare});

  /// Hands the finished PDF to the platform's share sheet. The default is
  /// `Printing.sharePdf`; a test passes its own because the plugin cannot run
  /// headless.
  final Future<void> Function(Uint8List bytes, String filename)? onShare;

  @override
  State<MoodReportScreen> createState() => _MoodReportScreenState();
}

class _MoodReportScreenState extends State<MoodReportScreen> {
  static const _windows = [7, 30, 90];
  int _windowIndex = 1; // 30 days
  List<MoodEntry> _all = const [];
  bool _loading = true;
  bool _sharing = false;

  int get _days => _windows[_windowIndex];

  /// The report for the window, worked out once — and again only when what it
  /// depends on changes, the rounds loaded or the window chosen. It was worked out
  /// in `build`, so Share, which rebuilds the screen twice, summed ninety days and
  /// their tags twice as well.
  MoodReportSummary? _summary;
  MoodReportSummary get _currentSummary =>
      _summary ??= MoodReportService.summarize(_all, windowDays: _days);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllMood();
    if (!mounted) return;
    setState(() {
      _all = data;
      _summary = null;
      _loading = false;
    });
  }

  Future<void> _share(MoodReportSummary summary) async {
    if (_sharing) return;
    if (summary.isEmpty) {
      context.toastInfo('Nothing logged in this period to share.');
      return;
    }
    setState(() => _sharing = true);
    try {
      final bytes = await MoodReportService.buildPdf(
        summary,
        patientName: await MedicineCleanStorageService.activePatientName(),
      );
      final share = widget.onShare ??
          (b, name) => Printing.sharePdf(bytes: b, filename: name);
      await share(bytes, 'mood-report.pdf');
    } catch (e) {
      debugPrint('⚠️ Sharing the mood report failed: $e');
      if (mounted) context.toastError('Could not create the report. Try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.moodAccent(ext.isDark);
    final summary = _currentSummary;

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Mood report',
            leading: AppHeader.backButton(context),
            actions: [
              AppIconButton(
                icon: Symbols.ios_share_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Share report as PDF',
                onPressed: _loading ? null : () => _share(summary),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : ListView(
                    padding: EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppInsets.pushed(context)),
                    children: [
                      SegmentedToggle(
                        index: _windowIndex,
                        accent: accent,
                        items: const [
                          SegmentItem(icon: Symbols.calendar_view_week_rounded, label: '7d'),
                          SegmentItem(icon: Symbols.calendar_view_month_rounded, label: '30d'),
                          SegmentItem(icon: Symbols.calendar_today_rounded, label: '90d'),
                        ],
                        onChanged: (i) => setState(() {
                          _windowIndex = i;
                          _summary = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Text(
                          '${DateFormats.dayMonth.format(summary.start)} – '
                          '${DateFormats.dayMonth.format(summary.end)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: ext.textTertiary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (summary.isEmpty)
                        EmptyState(
                          icon: Symbols.mood_rounded,
                          accent: accent,
                          title: 'Nothing logged in this period',
                          message: 'Log how you feel on the Mood screen and the '
                              'report fills in.',
                        )
                      else
                        ..._report(ext, accent, summary),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _report(
      AppColorsExt ext, AccentSwatch accent, MoodReportSummary s) {
    final tt = Theme.of(context).textTheme;
    return [
      StatTileRow(tiles: [
        StatTile(
          value: s.averageLabel ?? '—',
          label: 'Average',
          icon: Symbols.mood_rounded,
          accent: accent,
        ),
        StatTile(
          value: '${s.daysLogged}/${s.windowDays}',
          label: 'Days logged',
          icon: Symbols.calendar_month_rounded,
          accent: accent,
        ),
        StatTile(
          value: '${s.entries}',
          label: s.entries == 1 ? 'Entry' : 'Entries',
          icon: Symbols.checklist_rounded,
          accent: accent,
        ),
      ]),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'The average is of the days logged: each day counts once, however many '
        'times it was logged.',
        style: tt.bodySmall?.copyWith(color: ext.textTertiary),
      ),
      if (s.daysLogged >= 2) ...[
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: 'Trend', icon: Symbols.show_chart_rounded, accent: accent),
        const SizedBox(height: 4),
        Text('Higher = better mood',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: VitalsTrendChart(
            series: [
              VitalsSeries(
                  values: [for (final d in s.days) d.score],
                  times: [for (final d in s.days) d.day],
                  color: ext.chartMark(accent),
                  label: 'Mood'),
            ],
            minY: 0,
            maxY: (moodRatingLabels.length - 1).toDouble(),
            bandColor: ext.mark(accent),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      SectionHeader(
          title: 'How the entries felt',
          icon: Symbols.donut_small_rounded,
          accent: accent),
      const SizedBox(height: AppSpacing.sm),
      _levels(ext, s),
      if (s.weeks.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
            title: 'Week by week',
            icon: Symbols.calendar_view_week_rounded,
            accent: accent),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [for (final w in s.weeks) _weekRow(ext, w)],
          ),
        ),
      ],
      if (s.hardDays.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
            title: 'Harder days', icon: Symbols.cloud_rounded, accent: accent),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.hardDays.length} of ${s.daysLogged} days logged were '
                'rated Bad or Terrible.',
                style: tt.bodyMedium?.copyWith(color: ext.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.hardDays
                    .take(8)
                    .map((d) => DateFormats.dayMonth.format(d.day))
                    .join(' · '),
                style: tt.bodySmall?.copyWith(color: ext.textSecondary),
              ),
            ],
          ),
        ),
      ],
      if (s.patterns.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
            title: 'What goes with better days',
            icon: Symbols.insights_rounded,
            accent: accent),
        const SizedBox(height: AppSpacing.sm),
        for (final p in s.patterns) ...[
          InsightCard(insight: p),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        label: 'Share as PDF',
        leadingIcon: Symbols.ios_share_rounded,
        accent: accent,
        fullWidth: true,
        size: AppButtonSize.lg,
        loading: _sharing,
        onPressed: () => _share(s),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'The PDF has the levels, dates and tags, and leaves your notes out.',
        textAlign: TextAlign.center,
        style: tt.bodySmall?.copyWith(color: ext.textTertiary),
      ),
    ];
  }

  Widget _levels(AppColorsExt ext, MoodReportSummary s) {
    final tt = Theme.of(context).textTheme;
    final total = s.levelEntries.fold<int>(0, (a, b) => a + b);
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < moodRatingLabels.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 108,
                    child: Row(children: [
                      Icon(VitalsColors.moodIcon(i),
                          size: 14, color: VitalsColors.moodBand(ext.isDark, i)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(moodRatingLabels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.brFull,
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : s.levelEntries[i] / total,
                        minHeight: 8,
                        backgroundColor: ext.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(
                            VitalsColors.moodBand(ext.isDark, i)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 26,
                    child: Text('${s.levelEntries[i]}',
                        textAlign: TextAlign.right,
                        style: tt.bodySmall?.copyWith(color: ext.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _weekRow(AppColorsExt ext, MoodWeekScore w) {
    final tt = Theme.of(context).textTheme;
    final label = w.score == null ? 'Nothing logged' : MoodReportService.labelForScore(w.score!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      // Both sides may wrap: at large text on a narrow phone the date range and
      // the verdict cannot share one line, and a fixed-width trailing label
      // overflowed by a hundred pixels.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${DateFormats.dayMonth.format(w.start)} – ${DateFormats.dayMonth.format(w.end)}',
              style: tt.bodyMedium?.copyWith(color: ext.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              w.score == null
                  ? label
                  : '$label · ${w.daysLogged} ${w.daysLogged == 1 ? 'day' : 'days'}',
              textAlign: TextAlign.end,
              style: tt.bodySmall?.copyWith(
                  color: w.score == null ? ext.textTertiary : ext.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
