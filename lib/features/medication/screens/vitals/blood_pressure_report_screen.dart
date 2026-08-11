import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/health/vitals_analyzer.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../models/blood_pressure_reading.dart';
import '../../services/vitals_storage_service.dart';
import '../../services/vitals_report_service.dart';
import 'vitals_trend_chart.dart';

/// Blood-pressure report: period overview, trend, category breakdown, and a
/// doctor-ready PDF export.
class BloodPressureReportScreen extends StatefulWidget {
  const BloodPressureReportScreen({super.key});

  @override
  State<BloodPressureReportScreen> createState() =>
      _BloodPressureReportScreenState();
}

class _BloodPressureReportScreenState extends State<BloodPressureReportScreen> {
  static const _windows = [7, 30, 90];
  int _windowIndex = 1; // 30 days
  List<BloodPressureReading> _all = [];
  bool _loading = true;

  int get _days => _windows[_windowIndex];
  DateTime get _from => DateTime.now().subtract(Duration(days: _days));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllBp();
    if (!mounted) return;
    setState(() {
      _all = data;
      _loading = false;
    });
  }

  List<BloodPressureReading> get _inWindow =>
      _all.where((r) => r.takenAt.isAfter(_from)).toList();

  Future<void> _export() async {
    final data = _inWindow;
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readings in this period to export.')),
      );
      return;
    }
    try {
      final bytes = await VitalsReportService.buildBpPdf(
        readings: data,
        from: _from,
        to: DateTime.now(),
      );
      await Printing.sharePdf(bytes: bytes, filename: 'blood-pressure-report.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the report. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.bpAccent(ext.isDark);
    final data = _inWindow;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Blood pressure report',
            icon: Symbols.assessment_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              AppIconButton(
                icon: Symbols.ios_share_rounded,
                filled: false,
                accent: accent,
                onPressed: _export,
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
                    children: [
                      SegmentedToggle(
                        index: _windowIndex,
                        accent: accent,
                        items: const [
                          SegmentItem(icon: Symbols.calendar_view_week_rounded, label: '7d'),
                          SegmentItem(icon: Symbols.calendar_view_month_rounded, label: '30d'),
                          SegmentItem(icon: Symbols.calendar_today_rounded, label: '90d'),
                        ],
                        onChanged: (i) => setState(() => _windowIndex = i),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _overview(ext, accent, data),
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(title: 'Trend', icon: Symbols.show_chart_rounded, accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(child: _trend(ext, accent, data)),
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(title: 'Category breakdown', icon: Symbols.donut_small_rounded, accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      _breakdown(ext, data),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _overview(AppColorsExt ext, AccentSwatch accent, List<BloodPressureReading> data) {
    final avgSys = VitalsAnalyzer.mean(data.map((r) => r.systolic).toList());
    final avgDia = VitalsAnalyzer.mean(data.map((r) => r.diastolic).toList());
    final avgPulse = VitalsAnalyzer.mean(
        data.where((r) => r.pulse != null).map((r) => r.pulse!).toList());
    return StatTileRow(tiles: [
      StatTile(
        value: avgSys != null ? '${avgSys.round()}/${avgDia!.round()}' : '—',
        label: 'Average',
        icon: Symbols.favorite_rounded,
        accent: accent,
      ),
      StatTile(
        value: '${data.length}',
        label: 'Readings',
        icon: Symbols.numbers_rounded,
        accent: accent,
      ),
      StatTile(
        value: avgPulse != null ? '${avgPulse.round()}' : '—',
        label: 'Avg pulse',
        icon: Symbols.monitor_heart_rounded,
        accent: accent,
      ),
    ]);
  }

  Widget _trend(AppColorsExt ext, AccentSwatch accent, List<BloodPressureReading> data) {
    final trend = data.reversed.toList(); // oldest → newest
    final sys = trend.map((r) => r.systolic.toDouble()).toList();
    final dia = trend.map((r) => r.diastolic.toDouble()).toList();
    final all = [...sys, ...dia];
    final minY = all.isEmpty ? 40.0 : (all.reduce((a, b) => a < b ? a : b) - 10).clamp(30, 300).toDouble();
    final maxY = all.isEmpty ? 200.0 : (all.reduce((a, b) => a > b ? a : b) + 10).clamp(60, 320).toDouble();
    return VitalsTrendChart(
      series: [
        VitalsSeries(values: sys, color: ext.mark(accent), label: 'Systolic'),
        VitalsSeries(values: dia, color: ext.textSecondary, label: 'Diastolic'),
      ],
      minY: minY,
      maxY: maxY,
      bandLow: 80,
      bandHigh: 120,
      bandColor: VitalsColors.bpBand(ext.isDark, BpCategory.normal),
    );
  }

  Widget _breakdown(AppColorsExt ext, List<BloodPressureReading> data) {
    final tt = Theme.of(context).textTheme;
    final counts = <BpCategory, int>{};
    for (final r in data) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    final total = data.length;
    return AppCard(
      child: Column(
        children: BpCategory.values.map((c) {
          final n = counts[c] ?? 0;
          final frac = total == 0 ? 0.0 : n / total;
          final color = VitalsColors.bpBand(ext.isDark, c);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Row(children: [
                    Icon(VitalsColors.bpIcon(c), size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(VitalsAnalyzer.bpLabel(c),
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
                      value: frac,
                      minHeight: 8,
                      backgroundColor: ext.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 26,
                  child: Text('$n',
                      textAlign: TextAlign.right,
                      style: tt.bodySmall?.copyWith(color: ext.textPrimary)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
