import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/calendar_day.dart';
import '../../../../core/utils/date_formats.dart';
import '../../models/enhanced_medicine.dart';
import '../../models/medicine_log.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/services/haptic_service.dart';
import '../../widgets/adherence_export_sheet.dart';

class NunitoAdherenceReportScreen extends StatefulWidget {
  const NunitoAdherenceReportScreen({super.key});

  @override
  State<NunitoAdherenceReportScreen> createState() => _NunitoAdherenceReportScreenState();
}

class _NunitoAdherenceReportScreenState extends State<NunitoAdherenceReportScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year

  _AdherenceSummary _summary = _AdherenceSummary.empty;
  int _streak = 0;
  List<_DayStats> _dailyStats = [];
  List<EnhancedMedicine> _medicines = [];
  // Per-medicine adherence stats for the selected period, keyed by medicine id.
  final Map<String, Map<String, dynamic>> _medStats = {};

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final HapticService _hapticService = HapticService();

  /// Trailing-window length in days for the currently selected period.
  int get _periodDays {
    switch (_selectedPeriod) {
      case 0:
        return 7;
      case 1:
        return 30;
      default:
        return 365;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Read each table ONCE for the whole screen.
      //
      // This used to fetch the medicine list, then call getAdherenceStats
      // (which re-read it), then getCurrentStreak (which read medicines AND
      // logs again), then loop getAdherenceStatsForMedicine over every active
      // medicine — two more reads each. Measured, a 5-medicine user paid ~17
      // SELECTs to open this screen, and it grew by 2 per medicine added.
      final now = clock.now();
      _medicines = await MedicineCleanStorageService.getAllMedicines();

      // ONE ranged read of `medicine_logs`, sized to the WIDEST consumer.
      //
      // The summary, the per-medicine rows and the daily chart all want the
      // selected period; the streak looks back to the oldest active medicine's
      // creation day (capped at 180), which for Week and Month reaches further.
      // Every consumer re-applies its own window to what it is handed, so the
      // union is safe — and sizing it to the union rather than a flat 180 days
      // is what keeps Week from fetching six months of rows it would discard.
      final windowStart = now.subtract(Duration(days: _periodDays));
      final streakStart =
          MedicineCleanStorageService.streakWindowStart(_medicines, now);
      final logs = await MedicineCleanStorageService.getLogsForDateRange(
        streakStart.isBefore(windowStart) ? streakStart : windowStart,
        now,
      );

      _summary = _AdherenceSummary.fromMap(
        await MedicineCleanStorageService.getAdherenceStats(
            days: _periodDays, medicines: _medicines, logs: logs),
      );
      _streak = await MedicineCleanStorageService.getCurrentStreak(
          medicines: _medicines, logs: logs);

      _medStats.clear();
      for (final m in _medicines.where((m) => m.isActive && !m.isArchived)) {
        _medStats[m.id] =
            await MedicineCleanStorageService.getAdherenceStatsForMedicine(
          m.id,
          days: _periodDays,
          medicine: m,
          allLogs: logs,
        );
      }

      _calculateDailyStats(now, logs);

      _controller.forward(from: 0);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Builds honest per-day adherence over the selected window. Each day's
  /// adherence is taken / scheduled slots (non-PRN, active meds, due-only).
  /// Days with no scheduled doses are flagged [_DayStats.hasData] = false so
  /// the chart can render them as empty rather than a misleading full bar.
  ///
  /// [allLogs] is the screen's single read; this narrows it to the chart's own
  /// window rather than issuing a fourth query for the same rows. [now] is the
  /// caller's instant, so every panel on the screen agrees on where "now" is.
  void _calculateDailyStats(DateTime now, List<MedicineLog> allLogs) {
    _dailyStats = [];

    final startDay = dayOffset(now, -(_periodDays - 1));
    final today = startOfDay(now);

    // Reuse the list already loaded by _loadData() rather than re-reading it.
    final medicines = _medicines
        .where((m) => m.isActive && !m.isArchived && !m.schedule.isPRN)
        .toList();
    // The numerator MUST be drawn from the same population the denominator is
    // built from — the eligible set (active, non-archived, non-PRN) that
    // MedicineCleanStorageService.getAdherenceStats uses. Counting taken logs
    // from PRN / archived / inactive medicines against a schedule-only
    // denominator made a day's adherence exceed 100% (it only *looked* sane
    // because the clamp pinned the bar to full height).
    final eligibleIds = medicines.map((m) => m.id).toSet();
    // Deduped per slot for the same reason getAdherenceStats does it: installs
    // written before the deterministic-log-id fix can hold both a `missed` and
    // a `taken` row for one dose, which would double-count here.
    //
    // The [startDay, now) bound is what this method's own query used to apply,
    // and it is restated here because what arrives now is the screen's WIDER
    // shared read. Today's shared read happens to end at `now` too, so the
    // upper bound is belt-and-braces — but it is the half that matters: a dose
    // PRE-LOGGED for later today counts as taken while its slot is not yet
    // due, so the denominator below excludes it and counting it would put a
    // day over 100% (which the clamp would then hide, not fix).
    final logs = MedicineCleanStorageService.dedupeByDose(
      allLogs.where((l) =>
          eligibleIds.contains(l.medicineId) &&
          !l.scheduledTime.isBefore(startDay) &&
          l.scheduledTime.isBefore(now)),
    );

    for (var day = startDay;
        !day.isAfter(today);
        day = dayOffset(day, 1)) {
      int scheduled = 0;
      for (final m in medicines) {
        final createdDay =
            DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
        if (day.isBefore(createdDay)) continue;
        for (final slot in m.schedule.getScheduledTimesForDate(day)) {
          if (slot.isBefore(m.createdAt)) continue;
          if (slot.isAfter(now)) continue;
          scheduled++;
        }
      }

      final taken = logs
          .where((l) =>
              l.countsAsTaken &&
              l.scheduledTime.year == day.year &&
              l.scheduledTime.month == day.month &&
              l.scheduledTime.day == day.day)
          .length;

      _dailyStats.add(_DayStats(
        date: day,
        taken: taken,
        scheduled: scheduled,
        adherence: scheduled > 0 ? (taken / scheduled).clamp(0.0, 1.0) : 0.0,
        hasData: scheduled > 0,
      ));
    }
  }

  void _onPeriodChanged(int index) {
    _hapticService.selection();
    setState(() => _selectedPeriod = index);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Adherence',
              leading: AppHeader.backButton(context),
              actions: [
                // The numbers someone would hand over are on this screen; the
                // export used to live only on All medicines.
                AppIconButton(
                  icon: Symbols.ios_share_rounded,
                  filled: false,
                  accent: ext.medicine,
                  tooltip: 'Share with your doctor',
                  onPressed: () => AdherenceExportSheet.show(context),
                ),
              ],
              bottom: SegmentedToggle(
                index: _selectedPeriod,
                onChanged: _onPeriodChanged,
                accent: ext.medicine,
                items: const [
                  SegmentItem(icon: Symbols.view_week_rounded, label: 'Week'),
                  SegmentItem(icon: Symbols.calendar_month_rounded, label: 'Month'),
                  SegmentItem(icon: Symbols.calendar_today_rounded, label: 'Year'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ext.mark(ext.medicine),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.sm,
                          AppSpacing.gutter,
                          AppSpacing.huge,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOverallStats(),
                            const SizedBox(height: AppSpacing.lg),
                            _buildAdherenceChart(),
                            const SizedBox(height: AppSpacing.lg),
                            _buildMedicineBreakdown(),
                            const SizedBox(height: AppSpacing.lg),
                            _buildInsights(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStats() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final adherenceRate = _summary.adherenceRate;
    // With nothing due yet the rate defaults to 100% — showing a full ring +
    // "Excellent" would be misleading. Render a neutral no-data state instead.
    final noData = _summary.scheduled == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Overview',
          icon: Symbols.donut_large_rounded,
          accent: ext.medicine,
        ),
        // Every other section on this screen contains a Row/Expanded and so
        // fills the column for free. This card's contents are all intrinsically
        // sized -- a fixed-diameter ring and two centred labels -- so under the
        // parent's loose constraints it shrank to the ring's width and sat at
        // ~60%, out of line with the SectionHeader and StatTileRow around it.
        SizedBox(
          width: double.infinity,
          child: AppCard(
          child: Column(
            children: [
              ProgressRing(
                progress: noData ? 0 : adherenceRate / 100,
                size: 148,
                stroke: 13,
                accent: ext.medicine,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      noData ? '—' : '$adherenceRate%',
                      style: tt.displaySmall?.copyWith(
                        color: ext.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Adherence',
                      style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                noData
                    ? 'No doses due yet in this period'
                    : '${_summary.taken} of ${_summary.scheduled} scheduled doses taken',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StatTileRow(
          tiles: [
            StatTile(
              icon: Symbols.local_fire_department_rounded,
              value: '$_streak',
              label: 'Day streak',
              accent: ext.warning,
            ),
            StatTile(
              icon: Symbols.check_circle_rounded,
              value: '${_summary.taken}',
              label: 'Taken',
              accent: ext.success,
            ),
            StatTile(
              icon: Symbols.cancel_rounded,
              value: '${_summary.missed}',
              label: 'Missed',
              accent: ext.error,
            ),
            // Only when there ARE skipped doses.
            //
            // `_AdherenceSummary` has parsed `skipped` all along and nothing
            // rendered it, while the headline right above counts it in the
            // denominator. So "17 of 36 scheduled doses taken" sat above tiles
            // reading 17 and 16, and the three the user had deliberately
            // skipped were unaccounted for — on the screen whose whole job is
            // explaining that percentage. The doctor-facing PDF has always
            // listed them.
            //
            // Conditional so the ordinary case stays three tiles rather than
            // carrying a permanent "0 Skipped".
            if (_summary.skipped > 0)
              StatTile(
                icon: Symbols.next_plan_rounded,
                value: '${_summary.skipped}',
                label: 'Skipped',
                accent: ext.warning,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdherenceChart() {
    final c = AppColorsExt.of(context);
    final bars = _buildChartBars();
    final hasAnyData = bars.any((b) => b.hasData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Daily adherence',
          icon: Symbols.bar_chart_rounded,
          accent: c.medicine,
        ),
        AppCard(
          child: hasAnyData
              ? _buildChartBody(c, bars)
              : _buildChartEmptyState(c),
        ),
      ],
    );
  }

  Widget _buildChartEmptyState(AppColorsExt c) {
    final tt = Theme.of(context).textTheme;
    // Min-height, not a fixed 150: the message wraps to more lines as Dynamic
    // Type grows and a hard height simply clipped it (bottom overflow at 200%
    // on narrow phones). A minimum keeps the 150px chart-sized placeholder at
    // default sizes and lets the box grow only when the text needs it.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.bar_chart_rounded, size: 36, color: c.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No doses scheduled in this period',
              style: tt.bodySmall?.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBody(AppColorsExt c, List<_ChartBar> bars) {
    final tt = Theme.of(context).textTheme;
    // Subtle gridlines at 0% / 50% / 100% behind the bars.
    Widget gridline() => Container(height: 1, color: c.outline.withOpacity(0.5));

    // Min-height, not a fixed 170: only the plot area is a fixed 140px band —
    // the axis labels underneath grow with Dynamic Type, and a hard height
    // clipped them. The minimum keeps the default chart exactly 170 tall.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 170),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                // Baseline + midline gridlines.
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [gridline(), gridline(), gridline()],
                  ),
                ),
                // Bars over their tracks.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.map((bar) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildBar(c, bar),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: bars.map((bar) {
              return Expanded(
                // Up to 12 labels share the card's width, so each cell is only
                // ~25pt wide. Shrink-to-fit keeps "Mon"/"MMM ''yy" legible at
                // large Dynamic Type instead of clipping it mid-glyph;
                // scaleDown never enlarges, so default sizes are untouched.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    bar.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: tt.labelSmall?.copyWith(color: c.textTertiary),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(AppColorsExt c, _ChartBar bar) {
    final trackColor = c.surfaceVariant;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              color: trackColor,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  // No minimum clamp: empty/zero days read as empty tracks.
                  heightFactor: bar.hasData ? bar.adherence : 0.0,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      // Flat solid fill — Calm Clarity has no gradients.
                      color: _adherenceColor(c, bar.adherence),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reduce the raw daily stats to a display-appropriate, honest bar set that
  /// covers the whole selected range:
  /// - Week  -> 7 daily bars
  /// - Month -> weekly buckets (~5 bars)
  /// - Year  -> monthly buckets (up to 12 bars)
  List<_ChartBar> _buildChartBars() {
    if (_dailyStats.isEmpty) return const [];

    if (_selectedPeriod == 0) {
      return _dailyStats
          .map((d) => _ChartBar(
                label: DateFormats.weekdayNarrow.format(d.date),
                adherence: d.adherence,
                hasData: d.hasData,
              ))
          .toList();
    }

    if (_selectedPeriod == 1) {
      // Weekly buckets across the 30-day window.
      final bars = <_ChartBar>[];
      for (var i = 0; i < _dailyStats.length; i += 7) {
        final chunk = _dailyStats.sublist(
            i, (i + 7 > _dailyStats.length) ? _dailyStats.length : i + 7);
        bars.add(_aggregate(chunk, DateFormats.numericShort.format(chunk.first.date)));
      }
      return bars;
    }

    // Year -> calendar-month buckets, chronological.
    final byMonth = <String, List<_DayStats>>{};
    for (final d in _dailyStats) {
      final key = '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(d);
    }
    final keys = byMonth.keys.toList()..sort();
    // Include the year so the two boundary months of a 12-month window (same
    // month name, different year) don't render as two identical labels.
    return keys
        .map((k) => _aggregate(
            byMonth[k]!, DateFormat("MMM ''yy").format(byMonth[k]!.first.date)))
        .toList();
  }

  _ChartBar _aggregate(List<_DayStats> days, String label) {
    var taken = 0;
    var scheduled = 0;
    for (final d in days) {
      taken += d.taken;
      scheduled += d.scheduled;
    }
    return _ChartBar(
      label: label,
      adherence: scheduled > 0 ? (taken / scheduled).clamp(0.0, 1.0) : 0.0,
      hasData: scheduled > 0,
    );
  }

  Color _adherenceColor(AppColorsExt c, double adherence) {
    if (adherence >= 0.9) return c.mark(c.success);
    if (adherence >= 0.7) return c.mark(c.info);
    if (adherence >= 0.5) return c.mark(c.warning);
    return c.mark(c.error);
  }

  Widget _buildMedicineBreakdown() {
    final ext = AppColorsExt.of(context);
    final activeMedicines = _medicines.where((m) => m.isActive && !m.isArchived).toList();

    if (activeMedicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'By medicine',
          icon: Symbols.medication_rounded,
          accent: ext.medicine,
        ),
        ...activeMedicines.map((medicine) => _buildMedicineStatCard(medicine)),
      ],
    );
  }

  Widget _buildMedicineStatCard(EnhancedMedicine medicine) {
    final c = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // Real per-medicine adherence over the selected period.
    final stats = _medStats[medicine.id];
    final scheduled = (stats?['scheduled'] as int?) ?? 0;
    final rate = (stats?['adherenceRate'] as int?) ?? 0;
    final hasData = scheduled > 0;
    final accentColor = hasData ? _adherenceColor(c, rate / 100) : c.textTertiary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor,
              // brFull clamps to min(w, h) / 2 = 4 on an 8pt-wide box, so this
              // is pixel-identical to the literal 4 it replaces.
              borderRadius: AppRadius.brFull,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: tt.titleLarge?.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasData
                      ? '${stats?['taken'] ?? 0} of $scheduled doses taken'
                      : medicine.schedule.frequencyType.displayName,
                  style: tt.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            hasData ? '$rate%' : '—',
            style: tt.headlineSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final adherenceRate = _summary.adherenceRate;

    final List<_Insight> insights = [];

    // Only judge adherence once doses have actually been due — otherwise the
    // 100% default would falsely award "Excellent Adherence!".
    if (_summary.scheduled == 0) {
      insights.add(_Insight(
        icon: Symbols.tips_and_updates_rounded,
        swatch: ext.info,
        title: 'Start tracking',
        description:
            'No doses due yet in this period. Your adherence will appear here.',
      ));
    } else if (adherenceRate >= 90) {
      insights.add(_Insight(
        icon: Symbols.emoji_events_rounded,
        swatch: ext.success,
        title: 'Excellent adherence!',
        description: 'You\'re doing great! Keep up the good work.',
      ));
    } else if (adherenceRate >= 70) {
      insights.add(_Insight(
        icon: Symbols.trending_up_rounded,
        swatch: ext.info,
        title: 'Good progress',
        description: 'You\'re on the right track. Try to improve a bit more.',
      ));
    } else {
      insights.add(_Insight(
        icon: Symbols.tips_and_updates_rounded,
        swatch: ext.warning,
        title: 'Room for improvement',
        description: 'Set reminders to help you remember your medicines.',
      ));
    }

    insights.add(_Insight(
      icon: Symbols.lightbulb_rounded,
      swatch: ext.medicine,
      title: 'Tip',
      description: 'Taking medicines at the same time daily can improve adherence.',
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Insights',
          icon: Symbols.auto_awesome_rounded,
          accent: ext.medicine,
        ),
        ...insights.map((insight) => AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: insight.swatch.container,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Icon(insight.icon,
                        color: insight.swatch.onContainer, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: tt.titleLarge?.copyWith(color: ext.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.description,
                          style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

/// Typed headline adherence summary parsed from
/// [MedicineCleanStorageService.getAdherenceStats].
class _AdherenceSummary {
  final int taken;
  final int skipped;
  final int missed;
  final int total;
  final int scheduled;
  final int adherenceRate; // 0-100

  const _AdherenceSummary({
    required this.taken,
    required this.skipped,
    required this.missed,
    required this.total,
    required this.scheduled,
    required this.adherenceRate,
  });

  static const empty = _AdherenceSummary(
    taken: 0,
    skipped: 0,
    missed: 0,
    total: 0,
    scheduled: 0,
    adherenceRate: 0,
  );

  factory _AdherenceSummary.fromMap(Map<String, dynamic> m) => _AdherenceSummary(
        taken: (m['taken'] as int?) ?? 0,
        skipped: (m['skipped'] as int?) ?? 0,
        missed: (m['missed'] as int?) ?? 0,
        total: (m['total'] as int?) ?? 0,
        scheduled: (m['scheduled'] as int?) ?? 0,
        adherenceRate: (m['adherenceRate'] as int?) ?? 0,
      );
}

class _DayStats {
  final DateTime date;
  final int taken;
  final int scheduled;
  final double adherence;
  final bool hasData;

  _DayStats({
    required this.date,
    required this.taken,
    required this.scheduled,
    required this.adherence,
    required this.hasData,
  });
}

/// A single rendered bar in the adherence chart (day / week / month bucket).
class _ChartBar {
  final String label;
  final double adherence; // 0-1
  final bool hasData;

  _ChartBar({
    required this.label,
    required this.adherence,
    required this.hasData,
  });
}

class _Insight {
  final IconData icon;
  final AccentSwatch swatch;
  final String title;
  final String description;

  _Insight({
    required this.icon,
    required this.swatch,
    required this.title,
    required this.description,
  });
}
