import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;
import '../../../core/design/app_colors_ext.dart';
import 'package:tablet_remainder/core/widgets/app/app_toast.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';
import '../theme/aqua_theme.dart';
import '../widgets/aqua_shimmer.dart';
import '../../../core/utils/calendar_day.dart';

/// Advanced Statistics Screen with charts and insights
class WaterStatisticsScreen extends StatefulWidget {
  const WaterStatisticsScreen({super.key});

  @override
  State<WaterStatisticsScreen> createState() => _WaterStatisticsScreenState();
}

class _WaterStatisticsScreenState extends State<WaterStatisticsScreen> {
  int _selectedMonth = clock.now().month;
  int _selectedYear = clock.now().year;
  late MonthlyWaterStats _monthlyStats;
  late Map<String, dynamic> _weeklyStats;
  /// The goal the displayed month's days were actually measured against.
  late int _monthGoalMl;
  /// Millilitres logged per hour-of-day across the SELECTED month.
  late Map<int, int> _monthHourly;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Seed synchronously so the first frame has something coherent to render,
    // then reload from disk.
    _readStats();
    _loadStats();
  }

  void _readStats() {
    _monthlyStats = WaterService.getMonthlyStats(_selectedYear, _selectedMonth);
    _weeklyStats = WaterService.getWeeklyStats();
    _monthGoalMl = _averageGoalForMonth();
    _monthHourly = _hourlyForMonth();
  }

  /// When the selected month IS the current one — the only case where the
  /// live cards below the month section are also about what is on screen.
  bool get _isCurrentMonth =>
      _selectedMonth == clock.now().month && _selectedYear == clock.now().year;

  /// Millilitres logged in each hour of the day, summed over the selected
  /// month's days.
  ///
  /// This card read `getTodayData()`. Sitting under a month selector, it
  /// therefore showed today's twelve drinks whatever month the header named —
  /// paging back to March drew September's morning coffee as March's.
  Map<int, int> _hourlyForMonth() {
    final first = DateTime(_selectedYear, _selectedMonth, 1);
    final last = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final out = <int, int>{};
    for (final day in WaterService.getDataForRange(first, last)) {
      day.hourlyDistribution.forEach((hour, ml) {
        out[hour] = (out[hour] ?? 0) + ml;
      });
    }
    return out;
  }

  /// The goal this month's days were JUDGED against, averaged over exactly the
  /// rows `getMonthlyStats` averages the intake over — so the two halves of the
  /// "+" comparison below are about the same days.
  ///
  /// It used to compare that average to `getDailyGoal()`, today's
  /// profile-derived target. Paging back to March therefore marked it against
  /// the goal set in September, and — once the weather adjustment started
  /// re-stamping today's row — a hot afternoon could flip the badge on every
  /// past month at once. Falls back to today's own goal for a month with no
  /// rows, where there is nothing to average.
  int _averageGoalForMonth() {
    final first = DateTime(_selectedYear, _selectedMonth, 1);
    final last = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final days = WaterService.getDataForRange(first, last);
    if (days.isEmpty) {
      return WaterService.goalForDay(WaterService.getDataForDate(clock.now()));
    }
    final total = days.fold<int>(0, (sum, d) => sum + WaterService.goalForDay(d));
    return (total / days.length).round();
  }

  /// `getMonthlyStats` is synchronous and reads only WaterService's 90-day warm
  /// cache, so paging back beyond that rendered an all-zero month for data that
  /// was on disk the whole time — and the screen reported it as fact ("0 ml,
  /// 0 days tracked") rather than as "not loaded". Pull the month in first.
  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final first = DateTime(_selectedYear, _selectedMonth, 1);
    final last = DateTime(_selectedYear, _selectedMonth + 1, 0);
    await WaterService.ensureRangeLoaded(first, last);
    if (!mounted) return;
    setState(() {
      _readStats();
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
      _readStats();
    });
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // The last Material `AppBar` in the app. All three water bars set
      // `backgroundColor: Colors.transparent`, which is what made Flutter read
      // their luminance as 0 and paint white status-bar glyphs over a light
      // scaffold — the defect `AppBarTheme.systemOverlayStyle` was added for.
      // `AppScaffold` declares the overlay style for every screen now.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'Statistics',
            leading: AppHeader.backButton(context),
            actions: [
              AppIconButton(
                icon: Symbols.file_download_rounded,
                filled: false,
                accent: AppColorsExt.of(context).water,
                tooltip: 'Export data',
                onPressed: _exportData,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grouped by what the month selector actually governs.
            //
            // All six cards used to sit in one undivided stack under the
            // selector, and only two of them honoured it: paging back to March
            // left "This Week", the hourly chart, the streak and the insights
            // showing today's numbers under a header reading "March". The
            // hourly chart is month-scoped now; the remaining three are about
            // the present by definition — a current streak, this week, and
            // advice keyed off the hour of the day — so they are separated
            // rather than faked.
            _buildMonthSelector(),
            const SizedBox(height: AppSpacing.gutter),
            _buildOverviewCards(),
            const SizedBox(height: AppSpacing.xl),
            _buildHourlyDistribution(),
            const SizedBox(height: AppSpacing.xl),
            _buildBeverageBreakdown(),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: _isCurrentMonth ? 'Right now' : 'Right now, not $_monthLabel',
              icon: Symbols.bolt_rounded,
              accent: AppColorsExt.of(context).water,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildWeeklyChart(),
            const SizedBox(height: AppSpacing.xl),
            _buildStreakCard(),
            const SizedBox(height: AppSpacing.xl),
            _buildInsights(),
            // Not a magic 100: `AppInsets.pushed` is the same number plus the
            // bottom view padding, which the constant omitted — so on a device
            // with a gesture bar the last card sat partly underneath it.
            SizedBox(height: AppInsets.pushed(context)),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String get _monthLabel => '${_monthNames[_selectedMonth - 1]} $_selectedYear';

  Widget _buildMonthSelector() {
    final tt = Theme.of(context).textTheme;

    // DS-20/21: was a hand-rolled card — `black.withOpacity(isDark ? .25 : .05)`
    // at blur 10, offset (0,4), radius 16. `AppShadows.card` is .30/.06 at blur
    // 16, spread -2, offset (0,6), so the six cards on this screen cast a
    // visibly different shadow from every AppCard in the app. AppCard is that
    // surface.
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      pressEffect: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Symbols.chevron_left_rounded),
            tooltip: 'Previous month',
            onPressed: () => _changeMonth(-1),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _monthLabel,
                maxLines: 1,
                softWrap: false,
                style: tt.headlineSmall,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.chevron_right_rounded),
            tooltip: 'Next month',
            // clock.now(), like the rest of this screen — under a pinned
            // test clock `DateTime.now()` disagreed with the data being shown.
            onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  /// Builds a CSV with [build], writes it to app-internal temp storage and
  /// hands it to the OS share sheet.
  ///
  /// This used to be `debugPrint(csv)` with a toast saying "check console" —
  /// so the feature did nothing for the user AND wrote their entire
  /// drink-by-drink health log to logcat, where it is readable by `adb logcat`
  /// and captured in bug reports.
  ///
  /// [build] is called INSIDE the try, not before it. Both exports read the
  /// whole stored history out of Drift now, so producing the string is I/O
  /// that can fail — and the sheet has already been popped by the time it
  /// runs. An exception thrown out of the `onTap` callback instead of caught
  /// here is unhandled: the sheet closes and the user gets no file, no share
  /// sheet and no word about why.
  Future<void> _shareCsv(
      Future<String> Function() build, String filename, String subject) async {
    try {
      final csv = await build();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: subject,
      );
    } catch (e) {
      if (mounted) context.toastError('Could not export: $e');
    }
  }

  Widget _buildOverviewCards() {
    final ext = AppColorsExt.of(context);
    // A month older than the warm cache is a disk read. Showing "0.0L / 0ml"
    // while that is in flight states a falsehood; a skeleton says "loading".
    if (_loading) {
      return const AquaShimmer(
        child: Row(
          children: [
            Expanded(child: AquaSkeletonBox(height: 96)),
            SizedBox(width: 12),
            Expanded(child: AquaSkeletonBox(height: 96)),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            icon: Symbols.water_drop_rounded,
            iconColor: ext.mark(ext.water),
            value: '${(_monthlyStats.totalIntakeMl / 1000).toStringAsFixed(1)}L',
            label: 'Total Intake',
            trend: _monthlyStats.averageDailyMl > _monthGoalMl ? '+' : '',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            icon: Symbols.analytics_rounded,
            iconColor: ext.mark(ext.success),
            value: '${_monthlyStats.averageDailyMl}ml',
            label: 'Daily Average',
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? trend,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (trend != null && trend.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ext.success.container,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Text(
                    trend,
                    style: tt.labelMedium?.copyWith(
                      color: ext.success.onContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: tt.displaySmall),
          Text(label, style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final dailyData = _weeklyStats['dailyData'] as List<DailyWaterData>? ?? [];

    return AppCard(
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'This Week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ext.water.container,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${((_weeklyStats['completionRate'] as double) * 100).toInt()}% complete',
                      maxLines: 1,
                      softWrap: false,
                      style: tt.labelMedium?.copyWith(
                        color: ext.water.onContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                // dayOffset, not subtract(Duration(days: 6 - index)): across a
                // spring-forward this series rendered M T W T F S M — Monday
                // twice, Sunday missing and its intake dropped — while the
                // "% complete" badge on this same card came from the already
                // calendar-correct getWeeklyStats(), so one card contradicted
                // itself on exactly the transition day.
                final day = dayOffset(clock.now(), index - 6);
                final dayData = dailyData.where((d) =>
                    d.date.year == day.year &&
                    d.date.month == day.month &&
                    d.date.day == day.day).toList();

                final amount = dayData.isNotEmpty ? dayData.first.effectiveHydrationMl : 0;
                // Each bar against ITS OWN day's goal. Using today's goal for
                // the whole week made the green bars disagree with the
                // "% complete" badge on this very card, which is computed from
                // each day's persisted goalReached flag.
                final dayGoal = WaterService.goalForDay(
                    dayData.isNotEmpty ? dayData.first : null);
                final progress =
                    dayGoal > 0 ? (amount / dayGoal).clamp(0.0, 1.5) : 0.0;
                final isToday = index == 6;
                final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                // Expanded, and both labels in a FittedBox.
                //
                // Each column sizes to its widest child, so a day with data
                // ("1.5L") is far wider than an empty one ("-") — seven of them
                // ran 42px past a 320pt screen as soon as real values appeared.
                // This chart only ever looked safe because it read
                // DateTime.now() while the test seed is clock-pinned, so every
                // bar rendered empty and the widest child was the 30pt bar.
                //
                // The bar is Expanded rather than a fixed 100pt so the column
                // still fits its 160pt box when Dynamic Type grows the two
                // labels; FractionallySizedBox keeps the same
                // proportional-to-goal height it had before.
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // labelSmall (11) — the scale's floor. This was 10, which
                      // has no slot.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amount > 0
                              ? '${(amount / 1000).toStringAsFixed(1)}L'
                              : '-',
                          maxLines: 1,
                          style: tt.labelSmall?.copyWith(
                            color: ext.textSecondary,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            // Clamp so an over-goal day (>120%) can't grow the
                            // bar past its box; colour still flips to success
                            // at/above the goal.
                            heightFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              width: 30,
                              decoration: BoxDecoration(
                                color: progress >= 1
                                    ? ext.chartMark(ext.success)
                                    : isToday
                                        ? ext.chartMark(ext.water)
                                        : ext.chartMark(ext.water)
                                            .withOpacity(0.5),
                                borderRadius: AppRadius.brSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          dayNames[day.weekday - 1],
                          maxLines: 1,
                          style: tt.labelMedium?.copyWith(
                            color: isToday
                                ? ext.mark(ext.water)
                                : ext.textSecondary,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Wrap, not Row: the two legend entries flow onto a second line on a
          // 320pt screen at large text sizes instead of overflowing.
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                // A legend swatch IS a chart mark, so it uses the same colour
                // the bars are drawn in.
                _buildChartLegendItem(ext.chartMark(ext.success), 'Goal met'),
                _buildChartLegendItem(ext.chartMark(ext.water), 'In progress'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(Color color, String label) {
    final ext = AppColorsExt.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: ext.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyDistribution() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final hourlyData = _monthHourly;
    final maxValue = hourlyData.values.isEmpty
        ? 1
        : hourlyData.values.reduce(math.max);

    return AppCard(
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // Named for the month it is now actually about — this said
            // "Today's" while sitting under a month selector it ignored.
            'When you drink',
            style: tt.titleLarge,
          ),
          const SizedBox(height: AppSpacing.gutter),
          // `minHeight`, never a fixed height. Each hour column is a bar of up
          // to 60, a 4pt gap and an hour label — only the bar is fixed, so the
          // label growing was all it took to overflow a flat 80: +6px at 1.0x
          // and +30px at 2.0x, which is every one of this screen's 28 baselined
          // combinations.
          //
          // Worth recording how long it took to find. The creator chain named a
          // `SizedBox > Row > Expanded > Column`, and this screen has TWO fixed
          // boxes around bar charts. I fixed the other one first — the 160pt
          // weekly chart — took the count from 28 to 36, and had to restore the
          // file from a backup to get back to a known state. The probe that
          // printed the real `debugCreator` chain took two minutes and would
          // have skipped all of it.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Row(
              children: List.generate(24, (hour) {
                final amount = hourlyData[hour] ?? 0;
                final height = maxValue > 0 ? (amount / maxValue) * 60 : 0.0;
                final isActive = hour >= 6 && hour <= 22;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        // Keyed so a test can read a single hour's bar height
                        // and prove which days this chart is drawn from.
                        key: ValueKey('waterHourBar$hour'),
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: amount > 0
                              ? ext.chartMark(ext.water)
                              : isActive
                                  ? ext.surfaceVariant
                                  : ext.surfaceVariant.withOpacity(0.5),
                          // 2 and 4 have no slot on the 5-step scale; `sm` (8)
                          // is the nearest, and Flutter clamps a corner to half
                          // the shortest side, so on a ~10pt-wide bar this
                          // paints a rounded cap rather than an 8pt corner.
                          borderRadius: AppRadius.brSm,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hour % 4 == 0)
                        // 8pt was less than half the 11pt floor. labelSmall
                        // shrink-to-fits into the 1/24th-width column instead.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$hour',
                            maxLines: 1,
                            softWrap: false,
                            style: tt.labelSmall
                                ?.copyWith(color: ext.textSecondary),
                          ),
                        )
                      else
                        const SizedBox(height: 10),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeverageBreakdown() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final breakdown = _monthlyStats.beverageBreakdown;
    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = breakdown.values.fold(0, (sum, v) => sum + v);
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Beverage Breakdown', style: tt.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          ...sortedEntries.take(5).map((entry) {
            final beverage = WaterService.getBeverage(entry.key);
            final percent = total > 0 ? (entry.value / total * 100) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // DS-17: a 20pt emoji is badge-sized chrome. The row already
                  // names the drink beside it.
                  Icon(
                    AquaTheme.iconFor(entry.key),
                    size: 20,
                    color: ext.mark(ext.water),
                    applyTextScaling: false,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beverage?.name ?? entry.key,
                          style: tt.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: AppRadius.brSm,
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: ext.surfaceVariant,
                            valueColor:
                                AlwaysStoppedAnimation(ext.chartMark(ext.water)),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: tt.titleMedium?.copyWith(color: ext.textSecondary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final achievements = WaterService.getAchievements();
    // DS-02, and the same fix as DS-01 because it is the same defect: an
    // `orange.shade400 -> red.shade400` gradient with a 15pt orange glow,
    // white 22pt bold over the left ~40% of it (#FFA726, 1.94:1) and
    // white-at-80% 14pt under that.
    //
    // `PersonalBestCard` was the first candidate — it is a card with an icon
    // chip, a value and a sublabel, which is this shape exactly — but its
    // eyebrow reads PERSONAL BEST and is not parameterised. The headline here
    // is the CURRENT streak, with the best as context, so labelling it as a
    // record would state something false on every day but the best one.
    final fill = ext.fillBg(ext.reminders);
    final onFill = ext.fillFg(ext.reminders);
    return AppCard(
      color: fill,
      pressEffect: false,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: onFill.withOpacity(0.2),
              borderRadius: AppRadius.brLg,
            ),
            child: Icon(
              Symbols.local_fire_department_rounded,
              color: onFill,
              size: 40,
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${achievements.currentStreak} Day Streak',
                  style: tt.headlineMedium?.copyWith(color: onFill),
                ),
                const SizedBox(height: 4),
                Text(
                  'Best: ${achievements.longestStreak} days',
                  style: tt.bodyMedium?.copyWith(color: onFill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final insights = WaterService.getInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    return AppCard(
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.lightbulb_rounded, color: ext.mark(ext.warning)),
              const SizedBox(width: 8),
              // Flexible, not bare: at 2.0x Dynamic Type on a 320pt screen the
              // icon and this label together exceed the card's 248pt of content
              // width and the Row overflowed by 40px.
              Flexible(
                child: Text(
                  'Insights',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.take(3).map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // emoji-content-ok: `Insight.emoji` is authored per insight by
                // the rule engine and travels with the sentence it belongs to —
                // it is part of the message, not a badge on a tile. Rendered at
                // body size.
                Text(insight.emoji, style: tt.bodyLarge),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insight.title, style: tt.titleMedium),
                      Text(
                        insight.description,
                        style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _exportData() {
    AppBottomSheet.show(
      context,
      title: 'Export Data',
      icon: Symbols.file_download_rounded,
      accent: AppColorsExt.of(context).water,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ext.water.container,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(Symbols.summarize_rounded,
                    color: ext.water.onContainer),
              ),
              title: const Text('Summary CSV'),
              subtitle: const Text('Daily totals'),
              onTap: () async {
                // Close the sheet FIRST: the export now reads the whole
                // history from Drift, so awaiting it with the sheet still up
                // would leave a dead-looking bottom sheet on a long history.
                Navigator.pop(ctx);
                await _shareCsv(WaterService.exportToCsv, 'water-summary.csv',
                    'Water summary (daily totals)');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ext.success.container,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(Symbols.list_alt_rounded,
                    color: ext.success.onContainer),
              ),
              title: const Text('Detailed CSV'),
              subtitle: const Text('All drink logs'),
              onTap: () async {
                Navigator.pop(ctx);
                await _shareCsv(WaterService.exportDetailedCsv,
                    'water-detailed.csv', 'Water log (all drinks)');
              },
            ),
          ],
        );
      },
    );
  }
}
