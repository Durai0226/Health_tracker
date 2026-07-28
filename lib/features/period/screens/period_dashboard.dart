import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'period_reminder_settings_screen.dart';
import 'package:tablet_remainder/core/ai/ai_assistant.dart';

import '../models/cycle_phase.dart';
import '../models/cycle_prediction.dart';
import '../models/period_settings.dart';
import '../services/period_service.dart';
import '../theme/period_theme.dart';
import '../widgets/cycle_phase_wheel.dart';
import '../widgets/cycle_stats_card.dart';
import '../widgets/log_today_sheet.dart';
import '../widgets/prediction_card.dart';
import 'cycle_history_screen.dart';
import 'period_calendar_screen.dart';

/// The headline Period feature screen. In [embedded] mode the Health hub owns
/// the header, so this drops its own app bar and background.
class PeriodDashboard extends StatefulWidget {
  final bool embedded;
  const PeriodDashboard({super.key, this.embedded = false});

  @override
  State<PeriodDashboard> createState() => _PeriodDashboardState();
}

class _PeriodDashboardState extends State<PeriodDashboard> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PeriodService.init();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openLogSheet({DateTime? date}) async {
    await LogTodaySheet.show(context, date: date);
  }

  void _setMode(TrackingMode mode) {
    final settings = PeriodService.getSettings();
    PeriodService.saveSettings(settings.copyWith(trackingMode: mode));
  }

  Future<void> _pickPregnancyStart() async {
    final now = DateTime.now();
    final picked = await AppDatePicker.show(
      context,
      initial: PeriodService.getSettings().pregnancyStartDate ??
          now.subtract(const Duration(days: 28)),
      first: now.subtract(const Duration(days: 300)),
      last: now,
      title: 'Last menstrual period (LMP)',
    );
    if (picked != null) {
      final s = PeriodService.getSettings();
      await PeriodService.saveSettings(s.copyWith(pregnancyStartDate: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.period,
      child: widget.embedded
          ? _buildBody(context)
          : AppScaffold(safeTop: true, body: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          children: [
            SizedBox(height: AppSpacing.xl),
            LoadingSkeleton.card(),
            SizedBox(height: AppSpacing.lg),
            LoadingSkeleton.card(),
          ],
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: PeriodService.listenToDays(),
      builder: (context, _, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final settings = PeriodService.getSettings();
    final prediction = PeriodService.getPrediction();
    final stats = PeriodService.getStats();
    final mode = settings.trackingMode;

    final children = <Widget>[
      if (!widget.embedded) _header(context),
      const SizedBox(height: AppSpacing.sm),
      _modeSwitcher(mode),
      const SizedBox(height: AppSpacing.lg),
      if (mode == TrackingMode.pregnancy)
        _pregnancyBody(context, prediction, settings)
      else if (prediction.state == CycleState.onboarding)
        _onboardingBody(context)
      else
        _cycleBody(context, prediction, stats, mode),
      if (mode != TrackingMode.pregnancy &&
          prediction.state != CycleState.onboarding) ...[
        const SizedBox(height: AppSpacing.lg),
        _aiCoachCard(context, prediction),
      ],
      const SizedBox(height: AppSpacing.xl),
      _quickActions(context),
      const SizedBox(height: AppSpacing.xl),
      const SafetyDisclaimerBar(),
      const SizedBox(height: AppSpacing.huge),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }

  /// Self-loading generative AI cycle-coach card (on-device rule engine by
  /// default; honest, disclaimer-wrapped).
  Widget _aiCoachCard(BuildContext context, CyclePrediction p) {
    final ext = AppColorsExt.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inFertile = p.fertileStart != null &&
        p.fertileEnd != null &&
        !today.isBefore(p.fertileStart!) &&
        !today.isAfter(p.fertileEnd!);
    return AiInsightCard(
      title: 'Cycle insight',
      icon: kAiSparkle,
      accent: ext.period,
      cacheKey:
          'cycle:${p.state.name}:${p.daysUntilNextPeriod}:$inFertile:${p.dayOfCycle}',
      loader: () => AiAssistant().cycleInsight(
        daysUntilNextPeriod: p.daysUntilNextPeriod,
        inFertileWindow: inFertile,
        isLate: p.state == CycleState.late,
        irregular: p.state == CycleState.irregular,
        learning: p.state == CycleState.learning,
        pregnancy: p.state == CycleState.pregnancy,
        cycleDay: p.dayOfCycle,
      ),
    );
  }

  Widget _header(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: ext.period.container, borderRadius: AppRadius.brMd),
            child: Icon(Symbols.calendar_month_rounded,
                color: ext.period.onContainer, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Cycle', style: tt.displaySmall),
          const Spacer(),
          AppIconButton(
            icon: Symbols.notifications_rounded,
            filled: false,
            accent: ext.period,
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PeriodReminderSettingsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitcher(TrackingMode mode) {
    return SegmentedToggle(
      accent: AppColorsExt.of(context).period,
      index: mode.index,
      onChanged: (i) => _setMode(TrackingMode.values[i]),
      items: const [
        SegmentItem(icon: Symbols.calendar_today_rounded, label: 'Track'),
        SegmentItem(icon: Symbols.spa_rounded, label: 'TTC'),
        SegmentItem(icon: Symbols.child_friendly_rounded, label: 'Pregnancy'),
      ],
    );
  }

  // ---- Normal / TTC body -------------------------------------------------

  Widget _cycleBody(BuildContext context, CyclePrediction p, CycleStats stats,
      TrackingMode mode) {
    final ext = AppColorsExt.of(context);
    final settings = PeriodService.getSettings();
    final cycleLen = p.cycleLengthEstimate ?? settings.typicalCycleLength;
    final periodLen = stats.medianPeriodLength ?? settings.typicalPeriodLength;
    final ttc = mode == TrackingMode.ttc;

    int? dayIndex(DateTime? d) {
      if (d == null || p.lastPeriodStart == null) return null;
      return d.difference(p.lastPeriodStart!).inDays;
    }

    final confVal = switch (p.confidence) {
      PredictionConfidence.low => 0.33,
      PredictionConfidence.medium => 0.66,
      PredictionConfidence.high => 1.0,
    };

    final phase = p.phaseToday ?? CyclePhase.follicular;
    final late = p.state == CycleState.late;

    return Column(
      children: [
        Center(
          child: CyclePhaseWheel(
            cycleLength: cycleLen,
            periodLength: periodLen,
            lutealLength: settings.lutealPhaseLength,
            dayOfCycle: p.dayOfCycle,
            fertileStartDay: dayIndex(p.fertileStart),
            fertileEndDay: dayIndex(p.fertileEnd),
            confidence: confVal,
            currentPhase: phase,
            centerTop: late ? 'Late' : 'Day ${p.dayOfCycle ?? 1}',
            centerBottom: late
                ? '${(p.daysUntilNextPeriod ?? 0).abs()}d overdue'
                : 'of ~$cycleLen days',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _phasePill(context, phase),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Log today',
          accent: ext.period,
          fullWidth: true,
          leadingIcon: Symbols.add_rounded,
          onPressed: () {
            HapticFeedback.mediumImpact();
            _openLogSheet();
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        PredictionCard(prediction: p, emphasizeFertile: ttc),
        if (ttc) ...[
          const SizedBox(height: AppSpacing.lg),
          _ttcBbtHint(context, p),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: 'Cycle stats',
          icon: Symbols.insights_rounded,
          accent: ext.period,
          actionLabel: 'History',
          onAction: () => _openHistory(),
        ),
        CycleStatsCard(stats: stats, onTap: _openHistory),
      ],
    );
  }

  Widget _phasePill(BuildContext context, CyclePhase phase) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = PeriodTheme.phaseSwatch(ext, phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration:
          BoxDecoration(color: swatch.container, borderRadius: AppRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PeriodTheme.phaseIcon(phase),
              size: 15, color: swatch.onContainer),
          const SizedBox(width: 8),
          Text('${phase.label} phase',
              style: tt.labelMedium?.copyWith(
                  color: swatch.onContainer, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _ttcBbtHint(BuildContext context, CyclePrediction p) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      color: ext.reminders.container,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.thermostat_rounded,
              color: ext.reminders.onContainer, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Track BBT daily',
                    style: tt.titleMedium
                        ?.copyWith(color: ext.reminders.onContainer)),
                const SizedBox(height: 2),
                Text(
                  'Log your basal body temperature each morning — a sustained '
                  'rise helps confirm ovulation retrospectively.',
                  style: tt.bodySmall?.copyWith(
                      color: ext.reminders.onContainer, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Pregnancy body ----------------------------------------------------

  Widget _pregnancyBody(
      BuildContext context, CyclePrediction p, PeriodSettings settings) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    if (settings.pregnancyStartDate == null || p.gestationalWeeks == null) {
      return EmptyState(
        icon: Symbols.child_friendly_rounded,
        accent: ext.period,
        title: 'Set your start date',
        message:
            'Enter the first day of your last period (LMP) to estimate your '
            'gestational week.',
        action: AppButton(
          label: 'Set LMP date',
          accent: ext.period,
          leadingIcon: Symbols.event_rounded,
          onPressed: _pickPregnancyStart,
        ),
      );
    }

    final weeks = p.gestationalWeeks!;
    final days = p.gestationalWeekDays ?? 0;
    final trimester = weeks < 13
        ? 'First trimester'
        : weeks < 27
            ? 'Second trimester'
            : 'Third trimester';
    final progress = (weeks / 40).clamp(0.0, 1.0);

    return Column(
      children: [
        AppCard(
          child: Row(
            children: [
              ProgressRing(
                progress: progress,
                size: 96,
                stroke: 9,
                accent: ext.period,
                animate: !MediaQuery.of(context).disableAnimations,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$weeks',
                        style: tt.headlineMedium?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w800)),
                    Text('weeks',
                        style:
                            tt.labelSmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$weeks weeks, $days days',
                        style: tt.headlineSmall
                            ?.copyWith(color: ext.textPrimary)),
                    const SizedBox(height: 4),
                    Text(trimester,
                        style: tt.bodyMedium
                            ?.copyWith(color: ext.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('~${(40 - weeks).clamp(0, 40)} weeks to go',
                        style: tt.bodySmall
                            ?.copyWith(color: ext.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppListTile(
          icon: Symbols.event_rounded,
          accent: ext.period,
          title: 'LMP start date',
          subtitle: fmtPeriodDate(settings.pregnancyStartDate!),
          trailing: Icon(Symbols.edit_rounded, size: 18, color: ext.textTertiary),
          onTap: _pickPregnancyStart,
        ),
        const SizedBox(height: AppSpacing.md),
        const SafetyDisclaimerBar(),
      ],
    );
  }

  // ---- Onboarding / cold start ------------------------------------------

  Widget _onboardingBody(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return EmptyState(
      icon: Symbols.water_drop_rounded,
      accent: ext.period,
      title: 'Start tracking your cycle',
      message:
          'Log the first day of your period and DailyMinder will learn your '
          'rhythm — predicting your next period, phases and fertile window with '
          'an honest confidence score.',
      action: AppButton(
        label: 'Log your period',
        accent: ext.period,
        leadingIcon: Symbols.add_rounded,
        onPressed: () => _openLogSheet(),
      ),
    );
  }

  // ---- Quick actions -----------------------------------------------------

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Calendar',
            variant: AppButtonVariant.secondary,
            leadingIcon: Symbols.calendar_month_rounded,
            onPressed: _openCalendar,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: 'History',
            variant: AppButtonVariant.secondary,
            leadingIcon: Symbols.history_rounded,
            onPressed: _openHistory,
          ),
        ),
      ],
    );
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PeriodCalendarScreen()),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CycleHistoryScreen()),
    );
  }
}
