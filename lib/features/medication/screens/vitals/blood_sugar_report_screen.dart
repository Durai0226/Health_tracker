import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/health/vitals_analyzer.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../models/glucose_reading.dart';
import '../../services/vitals_storage_service.dart';
import '../../services/vitals_report_service.dart';
import 'vitals_trend_chart.dart';
import '../../services/medicine_storage_service.dart';
import '../../../../core/services/clean_storage_service.dart';

/// Blood-sugar report: period overview (avg, in-range %, est. A1C), trend,
/// class breakdown, and a doctor-ready PDF export.
class BloodSugarReportScreen extends StatefulWidget {
  const BloodSugarReportScreen({super.key});

  @override
  State<BloodSugarReportScreen> createState() => _BloodSugarReportScreenState();
}

class _BloodSugarReportScreenState extends State<BloodSugarReportScreen> {
  static const _windows = [7, 30, 90];
  int _windowIndex = 1;
  List<GlucoseReading> _all = [];
  bool _loading = true;

  /// The person's own unit, set on the Blood sugar screen. The report used to
  /// print mg/dL for everyone, so an mmol/L user read "126" beside a history
  /// that said "7.0".
  GlucoseUnit _unit = GlucoseUnit.mgdl;
  bool get _isMmol => _unit == GlucoseUnit.mmoll;

  int get _days => _windows[_windowIndex];
  DateTime get _from => DateTime.now().subtract(Duration(days: _days));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllGlucose();
    if (!mounted) return;
    setState(() {
      _all = data;
      _unit = VitalsAnalyzer.glucoseUnitFromPref(
          CleanStorageService.getAppPreference('glucose_unit', 'mgdl'));
      _loading = false;
    });
  }

  List<GlucoseReading> get _inWindow =>
      _all.where((r) => r.takenAt.isAfter(_from)).toList();

  Future<void> _export() async {
    final data = _inWindow;
    if (data.isEmpty) {
      context.toastInfo('No readings in this period to export.');
      return;
    }
    try {
      final bytes = await VitalsReportService.buildGlucosePdf(
        readings: data,
        from: _from,
        to: DateTime.now(),
        patientName: await MedicineCleanStorageService.activePatientName(),
        unit: _unit,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'blood-sugar-report.pdf');
    } catch (_) {
      if (mounted) {
        context.toastError('Could not create the report. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.glucoseAccent(ext.isDark);
    final data = _inWindow;

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Blood sugar report',
            leading: AppHeader.backButton(context),
            actions: [
              AppIconButton(
                icon: Symbols.ios_share_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Export report as PDF',
                onPressed: _export,
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : ListView(
                    padding: EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter,
                        AppInsets.pushed(context)),
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
                      SectionHeader(title: 'Range breakdown', icon: Symbols.donut_small_rounded, accent: accent),
                      const SizedBox(height: AppSpacing.sm),
                      _breakdown(ext, data),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _overview(AppColorsExt ext, AccentSwatch accent, List<GlucoseReading> data) {
    final avg = VitalsAnalyzer.mean(data.map((r) => r.valueMgdl).toList());
    final eA1c = VitalsAnalyzer.estimatedA1c(data.map((r) => r.valueMgdl).toList());
    final inRange = VitalsAnalyzer.inRangePercent(
        data.map((r) => (mgdl: r.valueMgdl, ctx: r.context)).toList());
    return StatTileRow(tiles: [
      StatTile(
        value: avg != null ? VitalsAnalyzer.formatGlucose(avg.round(), _unit) : '—',
        label: 'Avg ${VitalsAnalyzer.glucoseUnitLabel(_unit)}',
        icon: Symbols.water_drop_rounded,
        accent: accent,
      ),
      StatTile(
        value: inRange != null ? '${(inRange * 100).round()}%' : '—',
        label: 'In range',
        icon: Symbols.check_circle_rounded,
        accent: accent,
      ),
      StatTile(
        value: eA1c != null ? '${eA1c.toStringAsFixed(1)}%' : '—',
        label: 'Est. A1C',
        icon: Symbols.science_rounded,
        accent: accent,
      ),
    ]);
  }

  Widget _trend(AppColorsExt ext, AccentSwatch accent, List<GlucoseReading> data) {
    final trend = data.reversed.toList();
    final rawSeries = trend.map((r) => r.valueMgdl.toDouble()).toList();
    final rawMinY = rawSeries.isEmpty ? 40.0 : (rawSeries.reduce((a, b) => a < b ? a : b) - 20).clamp(20, 400).toDouble();
    final rawMaxY = rawSeries.isEmpty ? 250.0 : (rawSeries.reduce((a, b) => a > b ? a : b) + 20).clamp(120, 500).toDouble();
    // Headroom and clamps stay in mg/dL, where they are calibrated; everything
    // the chart draws — line, axis and band — is converted together, as on the
    // Blood sugar screen. Converting the line but not its axis would be worse
    // than converting neither.
    double chartY(double mgdl) =>
        _isMmol ? VitalsAnalyzer.mgdlToMmol(mgdl.round()) : mgdl;
    final series = rawSeries.map(chartY).toList();
    final minY = chartY(rawMinY);
    final maxY = chartY(rawMaxY);
    return VitalsTrendChart(
      series: [
        VitalsSeries(
            values: series,
            times: [for (final r in trend) r.takenAt],
            color: ext.chartMark(accent),
            label: 'Blood sugar'),
      ],
      minY: minY,
      maxY: maxY,
      bandLow: chartY(70),
      bandHigh: chartY(180),
      bandColor: VitalsColors.glucoseBand(ext.isDark, GlucoseClass.inRange),
    );
  }

  Widget _breakdown(AppColorsExt ext, List<GlucoseReading> data) {
    final tt = Theme.of(context).textTheme;
    final counts = <GlucoseClass, int>{};
    for (final r in data) {
      counts[r.glucoseClass] = (counts[r.glucoseClass] ?? 0) + 1;
    }
    final total = data.length;
    return AppCard(
      child: Column(
        children: GlucoseClass.values.map((c) {
          final n = counts[c] ?? 0;
          final frac = total == 0 ? 0.0 : n / total;
          final color = VitalsColors.glucoseBand(ext.isDark, c);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Row(children: [
                    Icon(VitalsColors.glucoseIcon(c), size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(VitalsAnalyzer.glucoseLabel(c),
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
