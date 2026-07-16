import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/nunito_theme.dart';
import '../../widgets/nunito_glass_card.dart';
import '../../models/enhanced_medicine.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/services/haptic_service.dart';

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
      _medicines = await MedicineCleanStorageService.getAllMedicines();
      _summary = _AdherenceSummary.fromMap(
        await MedicineCleanStorageService.getAdherenceStats(days: _periodDays),
      );
      _streak = await MedicineCleanStorageService.getCurrentStreak();

      _medStats.clear();
      for (final m in _medicines.where((m) => m.isActive && !m.isArchived)) {
        _medStats[m.id] = await MedicineCleanStorageService
            .getAdherenceStatsForMedicine(m.id, days: _periodDays);
      }

      await _calculateDailyStats();

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
  Future<void> _calculateDailyStats() async {
    _dailyStats = [];

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _periodDays - 1));
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);

    final medicines = (await MedicineCleanStorageService.getAllMedicines())
        .where((m) => m.isActive && !m.isArchived && !m.schedule.isPRN)
        .toList();
    final logs =
        await MedicineCleanStorageService.getLogsForDateRange(startDay, now);

    for (var day = startDay;
        !day.isAfter(today);
        day = day.add(const Duration(days: 1))) {
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
              l.isTaken &&
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Adherence Report',
          style: NunitoTheme.heading2.copyWith(
            color: isDark ? Colors.white : NunitoTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(NunitoTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildOverallStats(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildAdherenceChart(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildMedicineBreakdown(isDark),
                    const SizedBox(height: NunitoTheme.spacingL),
                    _buildInsights(isDark),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ['Week', 'Month', 'Year'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NunitoTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
      ),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(index),
              child: AnimatedContainer(
                duration: NunitoTheme.animationFast,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? NunitoTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(NunitoTheme.radiusSmall),
                ),
                child: Text(
                  periods[index],
                  textAlign: TextAlign.center,
                  style: NunitoTheme.labelMedium.copyWith(
                    color: isSelected ? Colors.white : NunitoTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverallStats(bool isDark) {
    final adherenceRate = _summary.adherenceRate;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: NunitoCard(
            gradient: NunitoTheme.primaryGradient,
            padding: const EdgeInsets.all(NunitoTheme.spacingL),
            child: Column(
              children: [
                Text(
                  '$adherenceRate%',
                  style: NunitoTheme.displayLarge.copyWith(
                    color: Colors.white,
                    fontSize: 48,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Overall Adherence',
                  style: NunitoTheme.labelMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _buildMiniProgressBar(adherenceRate / 100),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              NunitoCard(
                child: Column(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: Colors.orange, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '$_streak',
                      style: NunitoTheme.heading2.copyWith(
                        color: isDark ? Colors.white : NunitoTheme.textPrimary,
                      ),
                    ),
                    Text('Day Streak', style: NunitoTheme.caption),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NunitoCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_summary.taken}',
                          style: NunitoTheme.labelLarge.copyWith(
                            color: NunitoTheme.success,
                          ),
                        ),
                        Text('Taken', style: NunitoTheme.caption),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: NunitoTheme.textTertiary.withOpacity(0.2),
                    ),
                    Column(
                      children: [
                        Text(
                          '${_summary.missed}',
                          style: NunitoTheme.labelLarge.copyWith(
                            color: NunitoTheme.error,
                          ),
                        ),
                        Text('Missed', style: NunitoTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniProgressBar(double progress) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceChart(bool isDark) {
    final c = AppColorsExt.of(context);
    final bars = _buildChartBars();
    final hasAnyData = bars.any((b) => b.hasData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Adherence', style: NunitoTheme.heading3.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        )),
        const SizedBox(height: 12),
        NunitoCard(
          padding: const EdgeInsets.all(NunitoTheme.spacingM),
          child: hasAnyData
              ? _buildChartBody(c, bars)
              : _buildChartEmptyState(c),
        ),
      ],
    );
  }

  Widget _buildChartEmptyState(AppColorsExt c) {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 36, color: c.textTertiary),
            const SizedBox(height: 8),
            Text(
              'No doses scheduled in this period',
              style: NunitoTheme.bodySmall.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBody(AppColorsExt c, List<_ChartBar> bars) {
    // Subtle gridlines at 0% / 50% / 100% behind the bars.
    Widget gridline() => Container(height: 1, color: c.outline.withOpacity(0.5));

    return SizedBox(
      height: 170,
      child: Column(
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
                child: Text(
                  bar.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: NunitoTheme.caption.copyWith(
                    fontSize: 10,
                    color: c.textTertiary,
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
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          _adherenceColor(c, bar.adherence),
                          _adherenceColor(c, bar.adherence).withOpacity(0.65),
                        ],
                      ),
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
                label: DateFormat('E').format(d.date),
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
        bars.add(_aggregate(chunk, DateFormat('M/d').format(chunk.first.date)));
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
    return keys
        .map((k) => _aggregate(
            byMonth[k]!, DateFormat('MMM').format(byMonth[k]!.first.date)))
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

  Widget _buildMedicineBreakdown(bool isDark) {
    final activeMedicines = _medicines.where((m) => m.isActive && !m.isArchived).toList();

    if (activeMedicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Medication', style: NunitoTheme.heading3.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        )),
        const SizedBox(height: 12),
        ...activeMedicines.map((medicine) => _buildMedicineStatCard(medicine, isDark)),
      ],
    );
  }

  Widget _buildMedicineStatCard(EnhancedMedicine medicine, bool isDark) {
    final c = AppColorsExt.of(context);
    // Real per-medicine adherence over the selected period.
    final stats = _medStats[medicine.id];
    final scheduled = (stats?['scheduled'] as int?) ?? 0;
    final rate = (stats?['adherenceRate'] as int?) ?? 0;
    final hasData = scheduled > 0;
    final accentColor = hasData ? _adherenceColor(c, rate / 100) : c.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NunitoCard(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: NunitoTheme.labelLarge.copyWith(
                      color: isDark ? Colors.white : NunitoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    hasData
                        ? '${stats?['taken'] ?? 0} of $scheduled doses taken'
                        : medicine.schedule.frequencyType.displayName,
                    style: NunitoTheme.caption,
                  ),
                ],
              ),
            ),
            Text(
              hasData ? '$rate%' : '—',
              style: NunitoTheme.heading3.copyWith(color: accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(bool isDark) {
    final adherenceRate = _summary.adherenceRate;

    List<_Insight> insights = [];

    if (adherenceRate >= 90) {
      insights.add(_Insight(
        icon: Icons.emoji_events_rounded,
        color: NunitoTheme.warning,
        title: 'Excellent Adherence!',
        description: 'You\'re doing great! Keep up the good work.',
      ));
    } else if (adherenceRate >= 70) {
      insights.add(_Insight(
        icon: Icons.trending_up_rounded,
        color: NunitoTheme.accentBlue,
        title: 'Good Progress',
        description: 'You\'re on the right track. Try to improve a bit more.',
      ));
    } else {
      insights.add(_Insight(
        icon: Icons.tips_and_updates_rounded,
        color: NunitoTheme.warning,
        title: 'Room for Improvement',
        description: 'Set reminders to help you remember your medications.',
      ));
    }

    insights.add(_Insight(
      icon: Icons.lightbulb_rounded,
      color: NunitoTheme.primary,
      title: 'Tip',
      description: 'Taking medications at the same time daily can improve adherence.',
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: NunitoTheme.heading3.copyWith(
          color: isDark ? Colors.white : NunitoTheme.textPrimary,
        )),
        const SizedBox(height: 12),
        ...insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NunitoCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: insight.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(insight.icon, color: insight.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: NunitoTheme.labelLarge.copyWith(
                          color: isDark ? Colors.white : NunitoTheme.textPrimary,
                        ),
                      ),
                      Text(
                        insight.description,
                        style: NunitoTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  final Color color;
  final String title;
  final String description;

  _Insight({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
