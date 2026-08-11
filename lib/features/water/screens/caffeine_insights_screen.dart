import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math' as math;

import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';
import '../../../core/widgets/app/vitals_widgets.dart';
import '../../medication/screens/vitals/vitals_trend_chart.dart';
import '../models/enhanced_water_log.dart';
import '../services/water_service.dart';

/// How today's caffeine intake is classified against the FDA's 400 mg/day
/// guidance for healthy adults. General reference only — never presented as
/// personal medical advice (see the [SafetyDisclaimerBar] at the foot).
enum _CaffeineBand { none, withinRange, approaching, over }

/// Caffeine tracker — today's intake against a daily budget, a weekly trend,
/// where it came from, and the drinks behind it.
///
/// Rebuilt on the app's current design system (AppScaffold/AppHeader/AppCard/
/// AppSpacing + the AccentSwatch theming contract). The previous version was
/// the last screen still on the original generation: raw Scaffold + AppBar,
/// `CommonButton`, hand-rolled Container cards, ~25 hardcoded
/// `Colors.brown/amber/orange` values that ignored dark mode, and emoji used
/// as iconography.
class CaffeineInsightsScreen extends StatefulWidget {
  const CaffeineInsightsScreen({super.key});

  @override
  State<CaffeineInsightsScreen> createState() => _CaffeineInsightsScreenState();
}

class _CaffeineInsightsScreenState extends State<CaffeineInsightsScreen> {
  /// FDA guidance for healthy adults.
  static const int _dailyLimitMg = 400;

  /// Where "approaching the limit" starts.
  static const int _warningThresholdMg = 300;

  DailyWaterData? _todayData;
  List<DailyWaterData> _weeklyData = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await WaterService.init();
      final stats = WaterService.getWeeklyStats();
      if (!mounted) return;
      setState(() {
        _todayData = WaterService.getTodayData();
        _weeklyData = stats['dailyData'] as List<DailyWaterData>? ?? const [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Loading caffeine data failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _todayMg => _todayData?.totalCaffeineMg ?? 0;

  List<EnhancedWaterLog> get _todayCaffeineDrinks =>
      (_todayData?.logs ?? const <EnhancedWaterLog>[])
          .where((l) => l.caffeineAmount > 0)
          .toList();

  _CaffeineBand get _band {
    if (_todayMg <= 0) return _CaffeineBand.none;
    if (_todayMg >= _dailyLimitMg) return _CaffeineBand.over;
    if (_todayMg >= _warningThresholdMg) return _CaffeineBand.approaching;
    return _CaffeineBand.withinRange;
  }

  /// Band colour drawn from the shared 5-step vitals scale, so caffeine reads
  /// with the same visual grammar as BP/glucose rather than its own palette.
  Color _bandColor(AppColorsExt ext) {
    switch (_band) {
      case _CaffeineBand.none:
      case _CaffeineBand.withinRange:
        return VitalsColors.moodBand(ext.isDark, 0); // green
      case _CaffeineBand.approaching:
        return VitalsColors.moodBand(ext.isDark, 1); // amber
      case _CaffeineBand.over:
        return VitalsColors.moodBand(ext.isDark, 3); // red
    }
  }

  IconData get _bandIcon {
    switch (_band) {
      case _CaffeineBand.none:
      case _CaffeineBand.withinRange:
        return Symbols.check_circle_rounded;
      case _CaffeineBand.approaching:
        return Symbols.trending_up_rounded;
      case _CaffeineBand.over:
        return Symbols.warning_amber_rounded;
    }
  }

  String get _bandLabel {
    switch (_band) {
      case _CaffeineBand.none:
        return 'None today';
      case _CaffeineBand.withinRange:
        return 'Within range';
      case _CaffeineBand.approaching:
        return 'Approaching limit';
      case _CaffeineBand.over:
        return 'Over the guideline';
    }
  }

  String get _bandMeaning {
    switch (_band) {
      case _CaffeineBand.none:
        return "You haven't logged any caffeine today.";
      case _CaffeineBand.withinRange:
        return 'Comfortably inside the usual $_dailyLimitMg mg daily guidance.';
      case _CaffeineBand.approaching:
        return 'Getting close to the $_dailyLimitMg mg daily guidance — worth easing off.';
      case _CaffeineBand.over:
        return 'Above the $_dailyLimitMg mg daily guidance for healthy adults.';
    }
  }

  /// How much effective hydration the day's caffeinated drinks gave up versus
  /// their raw volume. Always ≤ 0, so it is rendered as an explicit offset
  /// (e.g. "−45 ml") in the caffeine accent — never in the water accent, which
  /// would read as hydration gained.
  int get _hydrationOffsetMl {
    var offset = 0;
    for (final log in _todayData?.logs ?? const <EnhancedWaterLog>[]) {
      if (log.caffeineAmount > 0) {
        offset += log.effectiveHydrationMl - log.amountMl;
      }
    }
    return offset;
  }

  /// The last 7 days' totals, oldest → newest, aligned to real calendar days
  /// so a gap day reads as 0 rather than shifting the series.
  List<double> get _weekSeries {
    final today = DateTime.now();
    return List<double>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final match = _weeklyData.where((d) =>
          d.date.year == day.year &&
          d.date.month == day.month &&
          d.date.day == day.day);
      return match.isEmpty ? 0.0 : match.first.totalCaffeineMg.toDouble();
    });
  }

  int get _weeklyAverageMg {
    if (_weeklyData.isEmpty) return 0;
    final total = _weeklyData.fold<int>(0, (s, d) => s + d.totalCaffeineMg);
    return (total / _weeklyData.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.caffeineAccent(ext.isDark);

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Caffeine',
            icon: Symbols.coffee_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: ext.mark(accent)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: ext.mark(accent),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                          AppSpacing.sm, AppSpacing.gutter, AppSpacing.xl),
                      children: _buildBody(ext, accent),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(AppColorsExt ext, AccentSwatch accent) {
    return [
      VitalsStatusHero(
        bigValue: '$_todayMg',
        unitLabel: 'of $_dailyLimitMg mg',
        // Fills as the daily budget is consumed — the natural reading for an
        // allowance. (BP/glucose invert this because for them full = healthy.)
        ringProgress: (_todayMg / _dailyLimitMg).clamp(0.0, 1.0),
        bandColor: _bandColor(ext),
        categoryIcon: _bandIcon,
        categoryLabel: _bandLabel,
        meaning: _bandMeaning,
        subtitle: _todayCaffeineDrinks.isEmpty
            ? null
            : '${_todayCaffeineDrinks.length} '
                'drink${_todayCaffeineDrinks.length == 1 ? '' : 's'} today',
      ),
      const SizedBox(height: AppSpacing.md),
      StatTileRow(tiles: [
        StatTile(
          value: '${_todayCaffeineDrinks.length}',
          label: 'Drinks',
          icon: Symbols.coffee_rounded,
          accent: accent,
        ),
        StatTile(
          value: '$_weeklyAverageMg mg',
          label: '7-day avg',
          icon: Symbols.timeline_rounded,
          accent: accent,
        ),
        StatTile(
          value: _hydrationOffsetMl == 0 ? '—' : '$_hydrationOffsetMl ml',
          label: 'Hydration offset',
          icon: Symbols.water_drop_rounded,
          accent: accent,
        ),
      ]),
      const SizedBox(height: AppSpacing.lg),
      ..._buildWeeklyTrend(ext, accent),
      ..._buildSources(ext, accent),
      ..._buildTodayDrinks(ext, accent),
      const SizedBox(height: AppSpacing.lg),
      _buildTips(ext, accent),
      const SizedBox(height: AppSpacing.xl),
      const SafetyDisclaimerBar(),
    ];
  }

  List<Widget> _buildWeeklyTrend(AppColorsExt ext, AccentSwatch accent) {
    final series = _weekSeries;
    if (series.every((v) => v == 0)) return const [];
    final peak = series.reduce(math.max);
    return [
      SectionHeader(
          title: 'This week', icon: Symbols.show_chart_rounded, accent: accent),
      const SizedBox(height: 4),
      Text('Shaded band is the $_dailyLimitMg mg daily guidance',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: ext.textTertiary)),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        child: VitalsTrendChart(
          series: [
            VitalsSeries(
                values: series, color: ext.mark(accent), label: 'Caffeine'),
          ],
          minY: 0,
          // Headroom above the larger of the limit and the week's peak, so a
          // heavy day is never drawn clipped against the top of the chart.
          maxY: math.max(_dailyLimitMg.toDouble(), peak) * 1.15,
          bandLow: 0,
          bandHigh: _dailyLimitMg.toDouble(),
          bandColor: VitalsColors.moodBand(ext.isDark, 0),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _buildSources(AppColorsExt ext, AccentSwatch accent) {
    final byBeverage = <String, int>{};
    for (final log in _todayCaffeineDrinks) {
      byBeverage[log.beverageId] =
          (byBeverage[log.beverageId] ?? 0) + log.caffeineAmount;
    }
    if (byBeverage.isEmpty) return const [];

    final sorted = byBeverage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final tt = Theme.of(context).textTheme;

    return [
      SectionHeader(
          title: 'Where it came from',
          icon: Symbols.pie_chart_rounded,
          accent: accent),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        child: Column(
          children: [
            for (final entry in sorted)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WaterService.getBeverage(entry.key)?.name ??
                                entry.key,
                            style: tt.bodyMedium?.copyWith(
                                color: ext.textPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: AppRadius.brSm,
                            child: LinearProgressIndicator(
                              value: _todayMg > 0 ? entry.value / _todayMg : 0,
                              backgroundColor: ext.surfaceVariant,
                              valueColor:
                                  AlwaysStoppedAnimation(ext.mark(accent)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text('${entry.value} mg',
                        style: tt.labelLarge?.copyWith(
                            color: ext.mark(accent),
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  List<Widget> _buildTodayDrinks(AppColorsExt ext, AccentSwatch accent) {
    final drinks = _todayCaffeineDrinks;
    final tt = Theme.of(context).textTheme;

    if (drinks.isEmpty) {
      return [
        SectionHeader(
            title: "Today's drinks",
            icon: Symbols.local_cafe_rounded,
            accent: accent),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Icon(Symbols.coffee_rounded,
                    size: 40, color: ext.textTertiary),
                const SizedBox(height: AppSpacing.sm),
                Text('No caffeinated drinks logged today',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                const SizedBox(height: 4),
                Text('Log a coffee or tea from the Water tracker',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SectionHeader(
          title: "Today's drinks",
          icon: Symbols.local_cafe_rounded,
          accent: accent),
      const SizedBox(height: AppSpacing.sm),
      AppCard(
        child: Column(
          children: [
            for (final log in drinks.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.container,
                        borderRadius: AppRadius.brMd,
                      ),
                      child: Icon(Symbols.coffee_rounded,
                          size: 22, color: accent.onContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.beverageName,
                              style: tt.bodyMedium?.copyWith(
                                  color: ext.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            '${TimeOfDay.fromDateTime(log.time).format(context)}'
                            ' · ${log.amountMl} ml',
                            style: tt.bodySmall
                                ?.copyWith(color: ext.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text('${log.caffeineAmount} mg',
                        style: tt.labelLarge?.copyWith(
                            color: ext.mark(accent),
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _buildTips(AppColorsExt ext, AccentSwatch accent) {
    const tips = <(IconData, String)>[
      (
        Symbols.health_and_safety_rounded,
        'The FDA suggests up to 400 mg a day for most healthy adults.'
      ),
      (
        Symbols.bedtime_rounded,
        'Caffeine can disrupt sleep up to 6 hours before bed.'
      ),
      (
        Symbols.water_drop_rounded,
        "It's a mild diuretic — pair it with extra water."
      ),
      (
        Symbols.schedule_rounded,
        'Effects usually peak 30–60 minutes after drinking.'
      ),
    ];
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
            title: 'Good to know',
            icon: Symbols.lightbulb_rounded,
            accent: accent),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (final (icon, text) in tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: ext.mark(accent)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(text,
                            style: tt.bodyMedium?.copyWith(
                                color: ext.textPrimary, height: 1.35)),
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
}
