import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/ai/vitals_analyzer.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../../../core/widgets/app/vitals_widgets.dart';
import '../../models/blood_pressure_reading.dart';
import '../../services/vitals_storage_service.dart';
import 'vitals_trend_chart.dart';
import 'blood_pressure_report_screen.dart';

/// Blood Pressure tracker — log, classify (AHA/ACC), trend, and act on readings.
class BloodPressureScreen extends StatefulWidget {
  const BloodPressureScreen({super.key});

  @override
  State<BloodPressureScreen> createState() => _BloodPressureScreenState();
}

class _BloodPressureScreenState extends State<BloodPressureScreen> {
  List<BloodPressureReading> _readings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllBp();
    if (!mounted) return;
    setState(() {
      _readings = data; // newest first (DAO orders desc)
      _loading = false;
    });
  }

  Future<void> _openLogSheet({BloodPressureReading? edit}) async {
    final accent = VitalsColors.bpAccent(AppColorsExt.of(context).isDark);
    final saved = await AppBottomSheet.show<bool>(
      context,
      title: edit == null ? 'Log blood pressure' : 'Edit reading',
      icon: Icons.favorite_rounded,
      accent: accent,
      builder: (_) => _BpLogForm(accent: accent, existing: edit),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(BloodPressureReading r) async {
    await VitalsStorageService.deleteBp(r.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.bpAccent(ext.isDark);

    return AppScaffold(
      safeTop: true,
      floatingActionButton: AppFab(
        icon: Icons.add_rounded,
        label: 'Log',
        accent: accent,
        onPressed: () => _openLogSheet(),
      ),
      body: Column(
        children: [
          AppHeader(
            title: 'Blood Pressure',
            icon: Icons.favorite_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Icons.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_readings.isNotEmpty)
                AppIconButton(
                  icon: Icons.assessment_rounded,
                  filled: false,
                  accent: accent,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BloodPressureReportScreen()),
                  ),
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : _readings.isEmpty
                    ? _EmptyState(accent: accent, onLog: () => _openLogSheet())
                    : _buildBody(ext, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColorsExt ext, AccentSwatch accent) {
    final latest = _readings.first;
    final cat = latest.category;
    final band = VitalsColors.bpBand(ext.isDark, cat);

    // Averages over the last 7 days.
    final now = DateTime.now();
    final last7 = _readings
        .where((r) => now.difference(r.takenAt).inDays < 7)
        .toList();
    final avgSys = VitalsAnalyzer.mean(last7.map((r) => r.systolic).toList());
    final avgDia = VitalsAnalyzer.mean(last7.map((r) => r.diastolic).toList());
    final amAvg = _amPmAvg(last7, morning: true);
    final pmAvg = _amPmAvg(last7, morning: false);

    // Trend: last 14 readings, oldest → newest.
    final trend = _readings.take(14).toList().reversed.toList();
    final sysSeries = trend.map((r) => r.systolic.toDouble()).toList();
    final diaSeries = trend.map((r) => r.diastolic.toDouble()).toList();
    final allVals = [...sysSeries, ...diaSeries];
    final minY = allVals.isEmpty ? 40.0 : (allVals.reduce((a, b) => a < b ? a : b) - 10).clamp(30, 300).toDouble();
    final maxY = allVals.isEmpty ? 200.0 : (allVals.reduce((a, b) => a > b ? a : b) + 10).clamp(60, 320).toDouble();

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.mark(accent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
        children: [
          if (latest.isCrisis) ...[
            VitalsEmergencyCard(
              title: 'Possible hypertensive crisis',
              message:
                  'Your latest reading (${latest.systolic}/${latest.diastolic}) is very high. '
                  'Rest 5 minutes and re-measure. If it stays this high — or you have chest pain, '
                  'shortness of breath, vision changes, weakness or trouble speaking — get emergency help now.',
              primaryLabel: 'Call emergency',
              onPrimary: () => _callEmergency(),
              secondaryLabel: 'Re-measure',
              onSecondary: () => _openLogSheet(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          VitalsStatusHero(
            bigValue: '${latest.systolic}/${latest.diastolic}',
            unitLabel: 'mmHg',
            ringProgress: (cat.index + 1) / 5,
            bandColor: band,
            categoryIcon: VitalsColors.bpIcon(cat),
            categoryLabel: VitalsAnalyzer.bpLabel(cat),
            meaning: VitalsAnalyzer.bpMeaning(cat),
            subtitle: 'Last reading · ${_timeAgo(latest.takenAt)}'
                '${latest.pulse != null ? ' · ${latest.pulse} bpm' : ''}',
          ),
          const SizedBox(height: AppSpacing.md),
          StatTileRow(tiles: [
            StatTile(
              value: avgSys != null ? '${avgSys.round()}/${avgDia!.round()}' : '—',
              label: '7-day avg',
              icon: Icons.timeline_rounded,
              accent: accent,
            ),
            StatTile(
              value: amAvg ?? '—',
              label: 'Morning',
              icon: Icons.wb_sunny_rounded,
              accent: accent,
            ),
            StatTile(
              value: pmAvg ?? '—',
              label: 'Evening',
              icon: Icons.nightlight_rounded,
              accent: accent,
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Trend', icon: Icons.show_chart_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: VitalsTrendChart(
              series: [
                VitalsSeries(values: sysSeries, color: ext.mark(accent), label: 'Systolic'),
                VitalsSeries(
                    values: diaSeries,
                    color: ext.textSecondary,
                    label: 'Diastolic'),
              ],
              minY: minY,
              maxY: maxY,
              bandLow: 80,
              bandHigh: 120,
              bandColor: VitalsColors.bpBand(ext.isDark, BpCategory.normal),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'History', icon: Icons.history_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          ..._readings.map((r) => _logRow(ext, r)),
        ],
      ),
    );
  }

  Widget _logRow(AppColorsExt ext, BloodPressureReading r) {
    final tt = Theme.of(context).textTheme;
    final cat = r.category;
    final band = VitalsColors.bpBand(ext.isDark, cat);
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
            color: ext.error.container, borderRadius: AppRadius.brMd),
        child: Icon(Icons.delete_rounded, color: ext.mark(ext.error)),
      ),
      onDismissed: (_) => _delete(r),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          onTap: () => _openLogSheet(edit: r),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: band, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.systolic}/${r.diastolic} mmHg',
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                      '${VitalsAnalyzer.bpLabel(cat)} · ${DateFormat('MMM d, h:mm a').format(r.takenAt)}'
                      '${r.pulse != null ? ' · ${r.pulse} bpm' : ''}',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ext.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String? _amPmAvg(List<BloodPressureReading> list, {required bool morning}) {
    final f = list.where((r) => r.isMorning == morning).toList();
    final s = VitalsAnalyzer.mean(f.map((r) => r.systolic).toList());
    final d = VitalsAnalyzer.mean(f.map((r) => r.diastolic).toList());
    if (s == null || d == null) return null;
    return '${s.round()}/${d.round()}';
  }

  void _callEmergency() {
    // Deep-dialing needs url_launcher/platform; keep it safe + informative here.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Call your local emergency number now, or go to the ER.')),
    );
  }

  static String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM d').format(t);
  }
}

// ---------------------------------------------------------------------------
// Empty state (first run) + pre-measure checklist
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final AccentSwatch accent;
  final VoidCallback onLog;
  const _EmptyState({required this.accent, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    const tips = [
      'Rest quietly for 5 minutes first',
      'Sit with back supported, feet flat',
      'Rest your arm at heart level',
      'Avoid caffeine/exercise for 30 min',
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.favorite_rounded, size: 56, color: ext.mark(accent)),
        const SizedBox(height: AppSpacing.md),
        Text('Track your blood pressure',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text('Log a reading to see its category, trend, and averages.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                  title: 'For an accurate reading',
                  icon: Icons.check_circle_outline_rounded,
                  accent: accent),
              const SizedBox(height: AppSpacing.sm),
              ...tips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.done_rounded, size: 16, color: ext.mark(accent)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: Text(t,
                              style: tt.bodyMedium
                                  ?.copyWith(color: ext.textPrimary))),
                    ]),
                  )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Log your first reading',
          leadingIcon: Icons.add_rounded,
          accent: accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: onLog,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Log form (bottom-sheet body) with LIVE category preview
// ---------------------------------------------------------------------------
class _BpLogForm extends StatefulWidget {
  final AccentSwatch accent;
  final BloodPressureReading? existing;
  const _BpLogForm({required this.accent, this.existing});

  @override
  State<_BpLogForm> createState() => _BpLogFormState();
}

class _BpLogFormState extends State<_BpLogForm> {
  late final TextEditingController _sys;
  late final TextEditingController _dia;
  late final TextEditingController _pulse;
  late final TextEditingController _note;
  int _arm = 0; // 0 left, 1 right
  BpPosition _position = BpPosition.sitting;
  late DateTime _takenAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _sys = TextEditingController(text: e?.systolic.toString() ?? '');
    _dia = TextEditingController(text: e?.diastolic.toString() ?? '');
    _pulse = TextEditingController(text: e?.pulse?.toString() ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _arm = e?.arm?.index ?? 0;
    _position = e?.position ?? BpPosition.sitting;
    _takenAt = e?.takenAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    _pulse.dispose();
    _note.dispose();
    super.dispose();
  }

  BpCategory? get _previewCategory {
    final s = int.tryParse(_sys.text);
    final d = int.tryParse(_dia.text);
    if (s == null || d == null) return null;
    if (!VitalsAnalyzer.isValidBp(s, d)) return null;
    return VitalsAnalyzer.classifyBp(s, d);
  }

  Future<void> _save() async {
    final s = int.tryParse(_sys.text);
    final d = int.tryParse(_dia.text);
    if (s == null || d == null) {
      setState(() => _error = 'Enter both systolic and diastolic.');
      return;
    }
    if (!VitalsAnalyzer.isValidBp(s, d)) {
      setState(() => _error = 'Check the values — systolic must be higher than diastolic.');
      return;
    }
    HapticFeedback.mediumImpact();
    final e = widget.existing;
    final reading = BloodPressureReading(
      id: e?.id ?? 'bp_${DateTime.now().microsecondsSinceEpoch}',
      systolic: s,
      diastolic: d,
      pulse: int.tryParse(_pulse.text),
      arm: BpArm.values[_arm],
      position: _position,
      takenAt: _takenAt,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    await VitalsStorageService.saveBp(reading);
    if (VitalsAnalyzer.isBpCrisis(s, d)) HapticFeedback.heavyImpact();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final cat = _previewCategory;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live preview chip.
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cat == null
                ? ext.surfaceVariant
                : VitalsColors.bpBand(ext.isDark, cat).withOpacity(0.14),
            borderRadius: AppRadius.brMd,
          ),
          child: Row(
            children: [
              Icon(
                cat == null ? Icons.info_outline_rounded : VitalsColors.bpIcon(cat),
                color: cat == null
                    ? ext.textTertiary
                    : VitalsColors.bpBand(ext.isDark, cat),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  cat == null
                      ? 'Enter a reading to see its category'
                      : '${VitalsAnalyzer.bpLabel(cat)} — ${VitalsAnalyzer.bpMeaning(cat)}',
                  style: tt.bodyMedium?.copyWith(
                    color: cat == null ? ext.textSecondary : ext.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _sys,
                label: 'Systolic',
                hint: '120',
                keyboardType: TextInputType.number,
                accent: widget.accent,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _dia,
                label: 'Diastolic',
                hint: '80',
                keyboardType: TextInputType.number,
                accent: widget.accent,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _pulse,
          label: 'Pulse (optional)',
          hint: 'bpm',
          keyboardType: TextInputType.number,
          accent: widget.accent,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Arm', style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        SegmentedToggle(
          index: _arm,
          accent: widget.accent,
          items: const [
            SegmentItem(icon: Icons.back_hand_rounded, label: 'Left'),
            SegmentItem(icon: Icons.front_hand_rounded, label: 'Right'),
          ],
          onChanged: (i) => setState(() => _arm = i),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Position', style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.sm,
          children: BpPosition.values.map((p) {
            return AppChip(
              label: p.name[0].toUpperCase() + p.name.substring(1),
              selected: _position == p,
              accent: widget.accent,
              onTap: () => setState(() => _position = p),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _note,
          label: 'Note (optional)',
          hint: 'e.g. after a walk',
          accent: widget.accent,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: tt.bodySmall?.copyWith(color: ext.mark(ext.error))),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: widget.existing == null ? 'Save reading' : 'Update reading',
          leadingIcon: Icons.check_rounded,
          accent: widget.accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
