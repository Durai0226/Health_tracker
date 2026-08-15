import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/health/insight.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../focus/services/focus_service.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../../sleep/models/sleep_consistency.dart';
import '../services/insight_service.dart';

class _WeekStats {
  final int? adherencePct;
  final int waterDaysHit;
  final int focusMinutes;
  final int readingsLogged;
  final String? bpAvg;
  final int? glucoseAvg;
  final int stepsDaysGoalMet;
  final int sleepNightsLogged;
  final double sleepRegularity;
  final SleepConsistency sleepConsistency;
  final List<Insight> highlights;
  const _WeekStats({
    this.adherencePct,
    required this.waterDaysHit,
    required this.focusMinutes,
    required this.readingsLogged,
    this.bpAvg,
    this.glucoseAvg,
    required this.stepsDaysGoalMet,
    required this.sleepNightsLogged,
    required this.sleepRegularity,
    required this.sleepConsistency,
    required this.highlights,
  });
}

/// A calm weekly recap: deterministic 7-day numbers + the top insights, narrated
/// plainly. Expected, self-paced, high-trust (Whoop/Spotify-Wrapped pattern).
class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  late Future<_WeekStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _gather();
  }

  Future<_WeekStats> _gather() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7));

    int? adherence;
    try {
      // One row per slot: a pre-fix install can hold both a `missed` and a
      // `taken` row for one dose, which would inflate `due`.
      // Ranged query, not a full-table scan filtered in Dart. This screen
      // only ever looks at 7 days, but it was reading every log ever written —
      // and `medicine_logs` grows forever with no pruning.
      final logs = MedicineCleanStorageService.dedupeByDose(
          await MedicineCleanStorageService.getLogsForDateRange(
              from, DateTime.now()));
      final due =
          logs.where((l) => l.countsAsTaken || l.isMissed || l.isSkipped).length;
      final taken = logs.where((l) => l.countsAsTaken).length;
      if (due > 0) adherence = (taken / due * 100).round();
    } catch (_) {}

    int waterDays = 0;
    try {
      for (var i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: i));
        final data = WaterService.getDataForDate(d);
        if (data != null && data.dailyGoalMl > 0 && data.effectiveHydrationMl >= data.dailyGoalMl) {
          waterDays++;
        }
      }
    } catch (_) {}

    int focusMin = 0;
    try {
      focusMin = FocusService()
          .sessions
          .where((s) => s.startedAt.isAfter(from) && s.wasCompleted)
          .fold(0, (a, s) => a + s.actualMinutes);
    } catch (_) {}

    int readings = 0;
    String? bpAvg;
    int? glucoseAvg;
    try {
      // Bounded in Dart rather than SQL for now — `getAllBp` has no ranged
      // variant — but at least fetched ONCE. gatherAll() below reads the same
      // table again; that duplicate is what the shared fetch there removed.
      final bp = (await VitalsStorageService.getAllBp())
          .where((r) => r.takenAt.isAfter(from))
          .toList();
      readings += bp.length;
      final s = VitalsAnalyzer.mean(bp.map((r) => r.systolic).toList());
      final d = VitalsAnalyzer.mean(bp.map((r) => r.diastolic).toList());
      if (s != null && d != null) bpAvg = '${s.round()}/${d.round()}';
    } catch (_) {}
    try {
      final gl = (await VitalsStorageService.getAllGlucose())
          .where((r) => r.takenAt.isAfter(from))
          .toList();
      readings += gl.length;
      final m = VitalsAnalyzer.mean(gl.map((r) => r.valueMgdl).toList());
      if (m != null) glucoseAvg = m.round();
    } catch (_) {}

    int stepsDaysMet = 0;
    try {
      await StepService.init();
      stepsDaysMet = (StepService.getWeeklyStats()['daysGoalMet'] as int?) ?? 0;
    } catch (_) {}

    int sleepNights = 0;
    var regularity = 0.75;
    var consistency = SleepConsistency.building;
    try {
      await SleepService.init();
      sleepNights =
          SleepService.getWeeklyTrend().where((d) => d.hasData).length;
      regularity = SleepService.regularityIndex();
      consistency = SleepConsistency.fromIndex(
        regularity,
        sampleSize: SleepService.regularitySampleSize(),
      );
    } catch (_) {}

    final highlights = await InsightService.gatherAll();

    return _WeekStats(
      adherencePct: adherence,
      waterDaysHit: waterDays,
      focusMinutes: focusMin,
      readingsLogged: readings,
      bpAvg: bpAvg,
      glucoseAvg: glucoseAvg,
      stepsDaysGoalMet: stepsDaysMet,
      sleepNightsLogged: sleepNights,
      sleepRegularity: regularity,
      sleepConsistency: consistency,
      highlights: highlights,
    );
  }

  static String _rhythmShort(SleepConsistency c) {
    switch (c) {
      case SleepConsistency.veryRegular:
        return 'Steady';
      case SleepConsistency.fairlyRegular:
        return 'Fair';
      case SleepConsistency.variable:
        return 'Varies';
      case SleepConsistency.building:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Weekly recap',
            greeting: '${_mon(from).toUpperCase()} ${from.day} – ${_mon(now).toUpperCase()} ${now.day}',
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: FutureBuilder<_WeekStats>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator(color: ext.mark(accent)));
                }
                // Don't force-unwrap: an error must surface a retry, not blank
                // the screen (or crash on `snap.data!`).
                if (snap.hasError || !snap.hasData) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Symbols.error_rounded,
                              size: 40, color: ext.textTertiary),
                          const SizedBox(height: AppSpacing.md),
                          Text("Couldn't load your recap",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: ext.textPrimary)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Something went wrong gathering this week. Please try again.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: ext.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Try again',
                            leadingIcon: Symbols.refresh_rounded,
                            accent: accent,
                            onPressed: () =>
                                setState(() => _future = _gather()),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final s = snap.data!;
                final primaryEmpty = s.adherencePct == null &&
                    s.waterDaysHit == 0 &&
                    s.focusMinutes == 0;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
                  children: [
                    _headline(ext, s, from, now),
                    const SizedBox(height: AppSpacing.md),
                    if (primaryEmpty)
                      _emptyLedger(ext)
                    else
                      _kpiCard(ext, [
                        KpiCell(
                          progress: (s.adherencePct ?? 0) / 100,
                          muted: s.adherencePct == null,
                          value: s.adherencePct != null ? '${s.adherencePct}%' : '—',
                          label: 'Doses',
                          accent: ext.medicine,
                        ),
                        KpiCell(
                          progress: s.waterDaysHit / 7,
                          muted: s.waterDaysHit == 0,
                          value: '${s.waterDaysHit}/7',
                          label: 'Water days',
                          accent: ext.water,
                        ),
                        KpiCell(
                          progress: (s.focusMinutes / 150).clamp(0, 1).toDouble(),
                          muted: s.focusMinutes == 0,
                          value: '${s.focusMinutes}m',
                          label: 'Focus',
                          accent: ext.focus,
                        ),
                      ]),
                    if (s.stepsDaysGoalMet > 0 || s.sleepNightsLogged > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _kpiCard(ext, [
                        KpiCell(
                          progress: s.stepsDaysGoalMet / 7,
                          muted: s.stepsDaysGoalMet == 0,
                          value: '${s.stepsDaysGoalMet}/7',
                          label: 'Step goals',
                          accent: ext.steps,
                        ),
                        KpiCell(
                          progress: s.sleepNightsLogged / 7,
                          muted: s.sleepNightsLogged == 0,
                          value: '${s.sleepNightsLogged}/7',
                          label: 'Sleep logs',
                          accent: ext.sleep,
                        ),
                        KpiCell(
                          progress: s.sleepConsistency.hasEnoughData
                              ? s.sleepRegularity.clamp(0.0, 1.0)
                              : 0,
                          muted: !s.sleepConsistency.hasEnoughData,
                          value: _rhythmShort(s.sleepConsistency),
                          label: 'Rhythm',
                          accent: ext.sleep,
                        ),
                      ]),
                    ],
                    if (s.bpAvg != null || s.glucoseAvg != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _kpiCard(ext, [
                        KpiCell(
                          progress: s.bpAvg != null ? 1 : 0,
                          muted: s.bpAvg == null,
                          value: s.bpAvg ?? '—',
                          label: 'Avg BP',
                          accent: InsightVisuals.accent(context, InsightFeature.bloodPressure),
                        ),
                        KpiCell(
                          progress: s.glucoseAvg != null ? 1 : 0,
                          muted: s.glucoseAvg == null,
                          value: s.glucoseAvg != null ? '${s.glucoseAvg}' : '—',
                          label: 'Avg sugar',
                          accent: InsightVisuals.accent(context, InsightFeature.bloodSugar),
                        ),
                        KpiCell(
                          progress: (s.readingsLogged / 14).clamp(0, 1).toDouble(),
                          muted: s.readingsLogged == 0,
                          value: '${s.readingsLogged}',
                          label: 'Readings',
                          accent: ext.brand,
                        ),
                      ]),
                    ],
                    if (s.highlights.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SectionHeader(title: 'Highlights', icon: Symbols.star_rounded, accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      for (final i in s.highlights.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InsightCard(insight: i),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const SafetyDisclaimerBar(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _mon(DateTime d) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][d.month - 1];

  /// A KPI ledger row: equal ring cells separated by hairline dividers, all
  /// numerals locked to one baseline (the one deliberate use of centering).
  Widget _kpiCard(AppColorsExt ext, List<Widget> cells) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i != 0) children.add(Container(width: 1, color: ext.outline));
      children.add(Expanded(child: cells[i]));
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
      ),
    );
  }

  Widget _emptyLedger(AppColorsExt ext) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Text('Start logging and your recap fills in here.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
    );
  }

  /// The editorial teal cover: overline · a big tabular cover number (adherence)
  /// with a caption, then the narrative sentence, and a quiet seal watermark.
  Widget _headline(AppColorsExt ext, _WeekStats s, DateTime from, DateTime now) {
    final tt = Theme.of(context).textTheme;
    final on = ext.brand.onContainer;
    final hasAny =
        s.adherencePct != null || s.waterDaysHit > 0 || s.focusMinutes > 0;

    // Narrative — the cover number carries adherence, so this leads with the rest.
    final parts = <String>[];
    if (s.waterDaysHit > 0) {
      parts.add('${s.waterDaysHit} hydrated ${s.waterDaysHit == 1 ? 'day' : 'days'}');
    }
    if (s.focusMinutes > 0) parts.add('${s.focusMinutes} focus minutes');
    final String narrative;
    if (!hasAny) {
      narrative = 'Log a few things this week and your recap will fill in.';
    } else if (s.adherencePct != null) {
      narrative = parts.isEmpty
          ? 'Steady dosing this week — keep the momentum going.'
          : 'Plus ${parts.join(' and ')}. Keep the momentum going.';
    } else {
      narrative = 'This week: ${parts.join(' and ')}. Keep the momentum going.';
    }

    return AppCard(
      color: ext.brand.container,
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THIS WEEK · ${_mon(from).toUpperCase()} ${from.day}–${now.day}',
                style: tt.labelSmall
                    ?.copyWith(color: on.withOpacity(0.7), letterSpacing: 0.6),
              ),
              if (s.adherencePct != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('${s.adherencePct}%',
                    style: tt.displayLarge?.copyWith(
                        color: on,
                        fontWeight: FontWeight.w800,
                        fontFeatures: kTabular,
                        height: 1.0)),
                const SizedBox(height: AppSpacing.xs),
                Text('of doses taken',
                    style: tt.bodyMedium?.copyWith(color: on.withOpacity(0.8))),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(narrative,
                  style: tt.headlineSmall?.copyWith(color: on, height: 1.3)),
            ],
          ),
        ],
      ),
    );
  }
}
