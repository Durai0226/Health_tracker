import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app/app_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';
import '../theme/aqua_theme.dart';
import '../widgets/aqua_shimmer.dart';
import 'water_history_edit_screen.dart';

/// Calendar History Screen - View past water intake by date
class WaterCalendarScreen extends StatefulWidget {
  const WaterCalendarScreen({super.key});

  @override
  State<WaterCalendarScreen> createState() => _WaterCalendarScreenState();
}

class _WaterCalendarScreenState extends State<WaterCalendarScreen> {
  late DateTime _selectedMonth;
  DateTime? _selectedDate;
  DailyWaterData? _selectedDayData;

  /// The rendered month, keyed by day-of-month.
  ///
  /// This used to be read inline inside `_buildCalendarGrid()` via the
  /// cache-only `WaterService.getDataForRange`. Because the service only warms
  /// [WaterService.warmCacheWindow] (90 days) at start-up, paging back more than
  /// ~3 months rendered a calendar of empty cells for data that was sitting in
  /// Drift the whole time. `ensureRangeLoaded` existed for exactly this and had
  /// no production callers. A build method cannot await, so the read is hoisted
  /// into state.
  Map<int, DailyWaterData> _monthData = const {};
  bool _loadingMonth = true;

  @override
  void initState() {
    super.initState();
    final now = clock.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedDate = now;
    _loadMonth();
  }

  /// Pull the month in from Drift, then read it synchronously.
  Future<void> _loadMonth() async {
    final first = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    // Day 0 of the next month is the last day of this one.
    final last = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    setState(() => _loadingMonth = true);
    await WaterService.ensureRangeLoaded(first, last);
    if (!mounted) return;

    final data = {
      for (final day in WaterService.getDataForRange(first, last))
        day.date.day: day,
    };
    setState(() {
      _monthData = data;
      _loadingMonth = false;
      if (_selectedDate != null) _selectedDayData = _dayFor(_selectedDate!);
    });
  }

  DailyWaterData? _dayFor(DateTime date) =>
      date.year == _selectedMonth.year && date.month == _selectedMonth.month
          ? _monthData[date.day]
          : WaterService.getDataForDate(date);

  Future<void> _loadSelectedDayData() async {
    final date = _selectedDate;
    if (date == null) return;
    // Reads disk when the day is outside the warm cache.
    final loaded = await WaterService.loadDataForDate(date);
    if (!mounted) return;
    setState(() => _selectedDayData = loaded ?? _dayFor(date));
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _selectedDate = null;
      _selectedDayData = null;
      _monthData = const {};
    });
    _loadMonth();
  }

  void _selectDate(DateTime date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = date;
      _selectedDayData = _dayFor(date);
    });
    _loadSelectedDayData();
  }

  Future<void> _openHistoryEdit() async {
    if (_selectedDate == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WaterHistoryEditScreen(date: _selectedDate!),
      ),
    );

    // Reload regardless of the pop value: the edit screen's own back button
    // pops with null, so an edit made and then dismissed that way used to leave
    // the calendar showing stale numbers.
    if (!mounted) return;
    await _loadMonth();
    if (result == true && mounted) await _loadSelectedDayData();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // AppHeader. These three were the last Material `AppBar`s in the app, and
      // the reason `AppBarTheme.systemOverlayStyle` had to exist: their
      // `backgroundColor: Colors.transparent` made Flutter read the bar's
      // luminance as 0, resolve it as dark, and paint WHITE status-bar glyphs
      // over a light scaffold. `AppScaffold` declares the overlay style for
      // every screen now, so the workaround and the bar can both go.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'History',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            // The month selector + 6-week grid + day details are taller than a
            // 320x568 viewport (and far taller once Dynamic Type is scaled up),
            // so the page scrolls instead of squeezing the details card into
            // whatever is left over.
            child: SingleChildScrollView(
        child: Column(
          children: [
            _buildMonthSelector(),
            _buildCalendarGrid(),
            if (_selectedDate != null) _buildDayDetails(),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final tt = Theme.of(context).textTheme;
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    // DS-20/21: one of three hand-rolled cards on this screen whose shadow
    // (black at .25/.05, blur 10, offset 0,4) and radius (16) disagreed with
    // AppCard's.
    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.lg),
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
                '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                maxLines: 1,
                softWrap: false,
                style: tt.headlineSmall,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.chevron_right_rounded),
            tooltip: 'Next month',
            onPressed: _selectedMonth.month == DateTime.now().month &&
                    _selectedMonth.year == DateTime.now().year
                ? null
                : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final dataMap = _monthData;

    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      pressEffect: false,
      child: Column(
        children: [
          // Day names
          Row(
            children: dayNames.map((name) => Expanded(
              child: Center(
                child: Text(
                  name,
                  style: tt.labelMedium?.copyWith(color: ext.textSecondary),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          LayoutBuilder(builder: (context, constraints) {
            // A fixed childAspectRatio of 1 pins the row height to the cell
            // width (~36pt on a 320pt phone), which clips the day number once
            // Dynamic Type is scaled up. Derive the row height from the text
            // scaler instead and keep the square cell as the floor, so nothing
            // changes at the default scale.
            final cellWidth = constraints.maxWidth / 7;
            final dayNumberHeight =
                MediaQuery.textScalerOf(context).scale(13) * 1.4 + 8;
            final rowExtent = math.max(cellWidth, dayNumberHeight);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: rowExtent,
              ),
              itemCount: 42, // 6 weeks
              itemBuilder: (context, index) {
                final dayOffset = index - (startWeekday - 1);

                if (dayOffset < 0 || dayOffset >= daysInMonth) {
                  return const SizedBox.shrink();
                }

                // Paging to a month older than the warm cache is a real disk
                // read. Without a placeholder the grid rendered as a wall of
                // empty cells first, which is indistinguishable from "you drank
                // nothing that month".
                if (_loadingMonth) {
                  return const Padding(
                    padding: EdgeInsets.all(4),
                    child: AquaShimmer(
                      child: AquaSkeletonBox(
                          height: double.infinity, shape: BoxShape.circle),
                    ),
                  );
                }
              
                final day = dayOffset + 1;
                final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                final dayData = dataMap[day];
                final isToday = date.day == DateTime.now().day &&
                    date.month == DateTime.now().month &&
                    date.year == DateTime.now().year;
                final isSelected = _selectedDate != null &&
                    date.day == _selectedDate!.day &&
                    date.month == _selectedDate!.month &&
                    date.year == _selectedDate!.year;
                final isFuture = date.isAfter(DateTime.now());

                // Judged against the goal THAT DAY had, not today's — see
                // WaterService.goalForDay. Dividing history by the current
                // goal meant raising it on Friday retroactively un-achieved
                // Monday, and lowering it awarded goals never met.
                double progress = 0;
                if (dayData != null) {
                  final dayGoal = WaterService.goalForDay(dayData);
                  if (dayGoal > 0) {
                    progress = dayData.effectiveHydrationMl / dayGoal;
                  }
                }

                return GestureDetector(
                  onTap: isFuture ? null : () => _selectDate(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ext.fillBg(ext.water)
                          : isToday
                              ? ext.water.container
                              : Colors.transparent,
                      borderRadius: AppRadius.brSm,
                      border: isToday && !isSelected
                          ? Border.all(color: ext.mark(ext.water), width: 2)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress indicator
                        if (progress > 0 && !isSelected)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: 2,
                                backgroundColor: ext.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation(
                                  progress >= 1
                                    ? ext.chartMark(ext.success)
                                    : ext.chartMark(ext.water),
                                ),
                              ),
                            ),
                          ),
                        // Day number — scaleDown only ever shrinks, so the
                        // default rendering is untouched; it stops a 2-digit
                        // day from spilling out of a narrow cell at 200% text.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$day',
                            maxLines: 1,
                            softWrap: false,
                            style: tt.titleSmall?.copyWith(
                              color: isSelected
                                  ? ext.fillFg(ext.water)
                                  : isFuture
                                      ? ext.textDisabled
                                      : ext.textPrimary,
                              fontWeight: isToday || isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        // Goal met indicator
                        if (progress >= 1 && !isSelected)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: ext.chartMark(ext.success),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          // Legend — a Wrap, not a Row: at 200% text the two labels together
          // are wider than a 320pt card, so they drop onto separate lines
          // instead of overflowing. The 16pt spacing matches the old gap, so
          // the single-line default rendering is unchanged.
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                dot: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ext.chartMark(ext.success),
                    shape: BoxShape.circle,
                  ),
                ),
                label: 'Goal met',
              ),
              _buildLegendItem(
                dot: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    border: Border.all(color: ext.mark(ext.water), width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                label: 'Today',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One legend entry: swatch + label. The label is Flexible so a long
  /// translation wraps inside the card rather than overflowing it.
  Widget _buildLegendItem({required Widget dot, required String label}) {
    final ext = AppColorsExt.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
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

  Widget _buildDayDetails() {
    if (_selectedDayData == null) {
      return _buildEmptyDayDetails();
    }

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final data = _selectedDayData!;
    final goal = WaterService.goalForDay(data);
    final progress = goal > 0 ? data.effectiveHydrationMl / goal : 0.0;

    return AppCard(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: EdgeInsets.zero,
      pressEffect: false,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: progress >= 1
                  ? ext.success.container
                  : ext.water.container,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.card)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: progress >= 1
                        ? ext.fillBg(ext.success)
                        : ext.fillBg(ext.water),
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(
                    progress >= 1 ? Symbols.check_rounded : Symbols.water_drop_rounded,
                    color: progress >= 1
                        ? ext.fillFg(ext.success)
                        : ext.fillFg(ext.water),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_selectedDate!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge,
                      ),
                      Text(
                        data.goalReached
                            ? 'Goal Achieved!'
                            : '${(progress * 100).toInt()}% of goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // `onContainer` on the header's own container tint,
                        // rather than `mark` on the app surface — the tint is
                        // what this text actually sits on.
                        style: tt.titleMedium?.copyWith(
                          color: data.goalReached
                              ? ext.success.onContainer
                              : ext.water.onContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Flexible + scaleDown: unchanged at normal sizes, shrinks
                // instead of pushing the edit button off a 320pt screen.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${data.effectiveHydrationMl}ml',
                          maxLines: 1,
                          softWrap: false,
                          style: tt.headlineMedium,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'of ${goal}ml',
                          maxLines: 1,
                          softWrap: false,
                          style: tt.bodySmall
                              ?.copyWith(color: ext.water.onContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Icon(Symbols.edit_rounded, color: ext.water.onContainer),
                  onPressed: () => _openHistoryEdit(),
                  tooltip: 'Edit',
                ),
              ],
            ),
          ),
          // Stats row
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _buildDayStatItem(
                  icon: Symbols.local_drink_rounded,
                  value: '${data.drinksCount}',
                  label: 'Drinks',
                  swatch: ext.water,
                ),
                // DS-09. These were Material brown (#795548) and purple
                // (#9C27B0) — 2.64:1 and 2.74:1 as bold value
                // text on the dark surface #171B22, both under AA. Amber and
                // violet are the palette's nearest brightness-aware swatches
                // and keep caffeine/alcohol reading as different things.
                _buildDayStatItem(
                  icon: Symbols.coffee_rounded,
                  value: '${data.totalCaffeineMg}mg',
                  label: 'Caffeine',
                  swatch: ext.reminders,
                ),
                _buildDayStatItem(
                  icon: Symbols.wine_bar_rounded,
                  value: '${data.alcoholicDrinksCount}',
                  label: 'Alcohol',
                  swatch: ext.focus,
                ),
              ],
            ),
          ),
          // Logs list — sized by its content because the whole page scrolls.
          if (data.logs.isEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: Center(
                child: Text(
                  'No drinks logged',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  for (final log in data.logs.reversed) _buildLogItem(log),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayDetails() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      // Without an explicit width this Container sized to its widest child
      // inside the page Column, so the empty state rendered visibly narrower
      // than the month and calendar cards above it — it read as a layout bug.
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brCard,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.water_drop_rounded, size: 64, color: ext.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No data for this day',
            style: tt.bodyLarge?.copyWith(color: ext.textSecondary),
          ),
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _formatDate(_selectedDate!),
                style: tt.bodyMedium?.copyWith(color: ext.textTertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayStatItem({
    required IconData icon,
    required String value,
    required String label,
    required AccentSwatch swatch,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: swatch.container,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, color: swatch.onContainer, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: ext.mark(swatch),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(EnhancedWaterLog log) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ext.surfaceVariant,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          // DS-17: a 24pt emoji in a tinted row is chrome.
          Icon(
            AquaTheme.iconFor(log.beverageId),
            size: 24,
            color: ext.mark(ext.water),
            applyTextScaling: false,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.beverageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium,
                ),
                // W15: the drink time, in the user's own 12/24h locale format —
                // this was a zero-padded 24h string, one of three formats the
                // feature used for the same value.
                Text(
                  TimeOfDay.fromDateTime(log.time).format(context),
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '+${log.amountMl}ml',
                    maxLines: 1,
                    softWrap: false,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Hydration: ${log.effectiveHydrationMl}ml',
                    maxLines: 1,
                    softWrap: false,
                    style: tt.labelSmall?.copyWith(
                      color: log.effectiveHydrationMl >= 0
                          ? ext.mark(ext.success)
                          : ext.mark(ext.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${dayNames[date.weekday - 1]}, ${monthNames[date.month - 1]} ${date.day}';
  }
}
