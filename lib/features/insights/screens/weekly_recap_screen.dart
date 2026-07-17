import 'package:flutter/material.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/ai/insight.dart';
import '../../../core/ai/vitals_analyzer.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../medication/services/vitals_storage_service.dart';
import '../../water/services/water_service.dart';
import '../../focus/services/focus_service.dart';
import '../services/insight_service.dart';

class _WeekStats {
  final int? adherencePct;
  final int waterDaysHit;
  final int focusMinutes;
  final int readingsLogged;
  final String? bpAvg;
  final int? glucoseAvg;
  final List<Insight> highlights;
  const _WeekStats({
    this.adherencePct,
    required this.waterDaysHit,
    required this.focusMinutes,
    required this.readingsLogged,
    this.bpAvg,
    this.glucoseAvg,
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
      final logs = (await MedicineCleanStorageService.getAllLogs())
          .where((l) => l.scheduledTime.isAfter(from))
          .toList();
      final due = logs.where((l) => l.isTaken || l.isMissed || l.isSkipped).length;
      final taken = logs.where((l) => l.isTaken).length;
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

    final highlights = await InsightService.gatherAll();

    return _WeekStats(
      adherencePct: adherence,
      waterDaysHit: waterDays,
      focusMinutes: focusMin,
      readingsLogged: readings,
      bpAvg: bpAvg,
      glucoseAvg: glucoseAvg,
      highlights: highlights,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;
    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Weekly recap',
            icon: Icons.calendar_view_week_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Icons.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: FutureBuilder<_WeekStats>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator(color: ext.mark(accent)));
                }
                final s = snap.data!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
                  children: [
                    _headline(ext, s),
                    const SizedBox(height: AppSpacing.md),
                    StatTileRow(tiles: [
                      StatTile(value: s.adherencePct != null ? '${s.adherencePct}%' : '—', label: 'Doses', icon: Icons.medication_rounded, accent: accent),
                      StatTile(value: '${s.waterDaysHit}/7', label: 'Water days', icon: Icons.water_drop_rounded, accent: accent),
                      StatTile(value: '${s.focusMinutes}m', label: 'Focus', icon: Icons.self_improvement_rounded, accent: accent),
                    ]),
                    if (s.bpAvg != null || s.glucoseAvg != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      StatTileRow(tiles: [
                        StatTile(value: s.bpAvg ?? '—', label: 'Avg BP', icon: Icons.favorite_rounded, accent: accent),
                        StatTile(value: s.glucoseAvg != null ? '${s.glucoseAvg}' : '—', label: 'Avg sugar', icon: Icons.bloodtype_rounded, accent: accent),
                        StatTile(value: '${s.readingsLogged}', label: 'Readings', icon: Icons.timeline_rounded, accent: accent),
                      ]),
                    ],
                    if (s.highlights.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(title: 'Highlights', icon: Icons.star_rounded, accent: accent),
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

  Widget _headline(AppColorsExt ext, _WeekStats s) {
    final tt = Theme.of(context).textTheme;
    final bits = <String>[];
    if (s.adherencePct != null) bits.add('${s.adherencePct}% of doses');
    if (s.waterDaysHit > 0) bits.add('${s.waterDaysHit} hydrated days');
    if (s.focusMinutes > 0) bits.add('${s.focusMinutes} focus minutes');
    final summary = bits.isEmpty
        ? 'Log a few things this week and your recap will fill in.'
        : 'This week: ${bits.join(' · ')}. Keep the momentum going.';
    return AppCard(
      color: ext.brand.container,
      child: Row(children: [
        Icon(kAiSparkle, color: ext.brand.onContainer, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(summary,
              style: tt.titleMedium?.copyWith(color: ext.brand.onContainer, height: 1.3)),
        ),
      ]),
    );
  }
}
