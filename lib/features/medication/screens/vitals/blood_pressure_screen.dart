import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/health/vitals_analyzer.dart';
import '../../../../core/health/insight_engine.dart';
import '../../../../core/health/vitals_pattern_detector.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../../../core/widgets/app/vitals_widgets.dart';
import '../../models/blood_pressure_reading.dart';
import '../../services/vitals_storage_service.dart';
import 'vitals_trend_chart.dart';
import 'vitals_reminder_button.dart';
import 'blood_pressure_report_screen.dart';

/// Blood Pressure tracker — log, classify (AHA/ACC), trend, and act on readings.
class BloodPressureScreen extends StatefulWidget {
  const BloodPressureScreen({super.key});

  /// Top of the app's own [BpCategory.normal] range for the SYSTOLIC series,
  /// read straight off `VitalsAnalyzer.classifyBp` (`systolic >= 120` is no
  /// longer normal). The trend chart shades one band per series from these
  /// two numbers instead of one shared band: systolic and diastolic have
  /// different normal ranges, so a single 80–120 band — which is what the
  /// chart used to draw across BOTH lines — painted a diastolic of 100 inside
  /// a green "normal" band, even though this app's own classifier calls
  /// 130/100 Stage 2 hypertension.
  ///
  /// These are not new medical thresholds; they are the existing
  /// `classifyBp` boundaries, and a test pins them to it.
  @visibleForTesting
  static const int normalSystolicMax = 120;

  /// Top of the app's own [BpCategory.normal] range for the DIASTOLIC series
  /// (`diastolic >= 80` is no longer normal). See [normalSystolicMax].
  @visibleForTesting
  static const int normalDiastolicMax = 80;

  /// How recent a crisis reading has to be for the emergency card to still be
  /// describing something actionable. Kept identical to the blood-sugar
  /// screen's window so both vitals emergencies expire on the same rule.
  @visibleForTesting
  static const Duration emergencyCardWindow = Duration(hours: 48);

  /// True when [latest] is a hypertensive crisis that is still current.
  /// Without the recency bound a single crisis reading from weeks ago
  /// re-rendered a non-dismissible "Call emergency" banner on every visit,
  /// long after it stopped being actionable.
  @visibleForTesting
  static bool showsCrisisEmergency(BloodPressureReading latest, DateTime now) =>
      latest.isCrisis && now.difference(latest.takenAt) < emergencyCardWindow;

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
      icon: Symbols.favorite_rounded,
      accent: accent,
      builder: (_) => _BpLogForm(accent: accent, existing: edit),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(BloodPressureReading r) async {
    // Soft delete: remove now, but offer Undo — deleting a health record must
    // never be a one-swipe, unrecoverable action.
    final messenger = ScaffoldMessenger.of(context);
    await VitalsStorageService.deleteBp(r.id);
    _load();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Reading deleted'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await VitalsStorageService.saveBp(r);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.bpAccent(ext.isDark);

    return AppScaffold(
      safeTop: true,
      floatingActionButton: AppFab(
        icon: Symbols.add_rounded,
        label: 'Log',
        accent: accent,
        onPressed: () => _openLogSheet(),
      ),
      body: Column(
        children: [
          AppHeader(
            title: 'Blood pressure',
            icon: Symbols.favorite_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              VitalsReminderButton(
                id: 900020,
                prefKey: 'vitals_bp_reminder',
                title: 'Blood pressure check',
                body: 'Time to measure and log your blood pressure.',
                accent: accent,
                defaultHour: 9,
              ),
              if (_readings.isNotEmpty)
                AppIconButton(
                  icon: Symbols.assessment_rounded,
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

    // Deterministic pattern insight over the user's own readings.
    final insight = InsightEngine.bloodPressure(_readings
        .map((r) => BpPoint(at: r.takenAt, systolic: r.systolic, diastolic: r.diastolic))
        .toList());

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.mark(accent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
        children: [
          // Recency-bounded — see [BloodPressureScreen.showsCrisisEmergency].
          if (BloodPressureScreen.showsCrisisEmergency(latest, now)) ...[
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
            // Ring convention (shared with the glucose screen): FULL = healthy,
            // the ring empties as the reading worsens. normal→1.0 … crisis→0.2.
            ringProgress: (5 - cat.index) / 5,
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
              icon: Symbols.timeline_rounded,
              accent: accent,
            ),
            StatTile(
              value: amAvg ?? '—',
              label: 'Morning',
              icon: Symbols.wb_sunny_rounded,
              accent: accent,
            ),
            StatTile(
              value: pmAvg ?? '—',
              label: 'Evening',
              icon: Symbols.nightlight_rounded,
              accent: accent,
            ),
          ]),
          if (insight != null) ...[
            const SizedBox(height: AppSpacing.md),
            InsightCard(insight: insight),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Trend', icon: Symbols.show_chart_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          // One chart per series. They used to share a chart AND a single
          // 80–120 "normal" band, which is a systolic-shaped range: it shaded
          // hypertensive diastolic values (80–120) green. Each series now
          // carries its own band, taken from this app's own classifier.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _seriesChart(
                  ext,
                  title: 'Systolic',
                  values: sysSeries,
                  color: ext.mark(accent),
                  minY: minY,
                  maxY: maxY,
                  normalMax: BloodPressureScreen.normalSystolicMax,
                ),
                const SizedBox(height: AppSpacing.lg),
                _seriesChart(
                  ext,
                  title: 'Diastolic',
                  values: diaSeries,
                  color: ext.textSecondary,
                  minY: minY,
                  maxY: maxY,
                  normalMax: BloodPressureScreen.normalDiastolicMax,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'History', icon: Symbols.history_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          ..._readings.map((r) => _logRow(ext, r)),
        ],
      ),
    );
  }

  /// One trend chart for one BP series, shaded with that series' own normal
  /// range (`< [normalMax]`, per `VitalsAnalyzer.classifyBp`).
  ///
  /// Both charts are handed the SAME [minY]/[maxY] — computed over systolic
  /// and diastolic together, exactly as before — so the two lines stay
  /// directly comparable and a 2 mmHg diastolic wobble isn't auto-scaled into
  /// a dramatic-looking swing.
  Widget _seriesChart(
    AppColorsExt ext, {
    required String title,
    required List<double> values,
    required Color color,
    required double minY,
    required double maxY,
    required int normalMax,
  }) {
    final tt = Theme.of(context).textTheme;
    // The band has nothing to shade when every reading on screen sits above
    // the normal ceiling; labelling an invisible band would just mislead.
    final bandVisible = normalMax > minY;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        VitalsTrendChart(
          series: [VitalsSeries(values: values, color: color, label: title)],
          minY: minY,
          maxY: maxY,
          // Lower edge is the axis floor: `classifyBp` puts no lower bound on
          // Normal, so inventing one here would contradict the category the
          // hero card shows for the same reading.
          bandLow: minY,
          bandHigh: normalMax.toDouble(),
          bandColor: VitalsColors.bpBand(ext.isDark, BpCategory.normal),
          bandLabel: bandVisible
              ? 'Shaded band = normal ${title.toLowerCase()} (under $normalMax mmHg)'
              : null,
        ),
      ],
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
        child: Icon(Symbols.delete_rounded, color: ext.mark(ext.error)),
      ),
      onDismissed: (_) => _delete(r),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          onTap: () => _openLogSheet(edit: r),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon + label, never colour alone — the category has to survive
              // colour-blindness (WCAG 1.4.1); the dot it replaced did not.
              Icon(VitalsColors.bpIcon(cat), size: 20, color: band),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r.systolic}/${r.diastolic} mmHg',
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                      '${VitalsAnalyzer.bpLabel(cat)} · ${DateFormats.dayMonthTime.format(r.takenAt)}'
                      '${r.pulse != null ? ' · ${r.pulse} bpm' : ''}',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: ext.textTertiary, size: 18),
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
    return DateFormats.dayMonth.format(t);
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
        Icon(Symbols.favorite_rounded, size: 56, color: ext.mark(accent)),
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
                  icon: Symbols.check_circle_rounded,
                  accent: accent),
              const SizedBox(height: AppSpacing.sm),
              ...tips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Symbols.done_rounded, size: 16, color: ext.mark(accent)),
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
          leadingIcon: Symbols.add_rounded,
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
  bool _saving = false;

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
    if (_saving) return;
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
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final e = widget.existing;
    final reading = BloodPressureReading(
      id: e?.id ?? 'bp_${DateTime.now().microsecondsSinceEpoch}',
      // Not carried by any control on this form — explicitly preserved on
      // edit rather than left to VitalsStorageService's active-profile
      // fallback, which only happens to produce the right answer today
      // because the sole caller already scopes its list to the active
      // profile before this screen ever opens.
      dependentId: e?.dependentId,
      systolic: s,
      diastolic: d,
      pulse: int.tryParse(_pulse.text),
      arm: BpArm.values[_arm],
      position: _position,
      takenAt: _takenAt,
      // Tags have no control on this form either — every edit through this
      // screen used to silently wipe them.
      tags: e?.tags ?? const [],
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
                cat == null ? Symbols.info_rounded : VitalsColors.bpIcon(cat),
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
                label: 'Systolic (mmHg)',
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
                label: 'Diastolic (mmHg)',
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
            SegmentItem(icon: Symbols.back_hand_rounded, label: 'Left'),
            SegmentItem(icon: Symbols.front_hand_rounded, label: 'Right'),
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
        _TakenAtField(
          value: _takenAt,
          accent: widget.accent,
          onChanged: (v) => setState(() => _takenAt = v),
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
          leadingIcon: Symbols.check_rounded,
          accent: widget.accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          loading: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Optional "when" control for the log sheet.
//
// `_takenAt` already existed on this form but nothing ever wrote to it, so a
// reading could not be back-dated and editing one silently kept the original
// timestamp with no way to correct it. Defaults to now, so the common case
// still costs zero taps.
// ---------------------------------------------------------------------------
class _TakenAtField extends StatelessWidget {
  final DateTime value;
  final AccentSwatch accent;
  final ValueChanged<DateTime> onChanged;

  const _TakenAtField({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await AppDatePicker.show(
      context,
      initial: value,
      first: DateTime(now.year - 5),
      // A reading can't have been taken in the future.
      last: DateTime(now.year, now.month, now.day),
      accent: accent,
      title: 'Reading date',
    );
    if (picked == null) return;
    onChanged(DateTime(
        picked.year, picked.month, picked.day, value.hour, value.minute));
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await AppTimePicker.show(
      context,
      initial: TimeOfDay.fromDateTime(value),
      accent: accent,
      title: 'Reading time',
    );
    if (picked == null) return;
    onChanged(DateTime(
        value.year, value.month, value.day, picked.hour, picked.minute));
  }

  String _dateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormats.dayLabel(day, reference: today);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date & time',
            style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _box(context, Symbols.calendar_today_rounded, _dateLabel(),
                  () => _pickDate(context)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _box(
                  context,
                  Symbols.schedule_rounded,
                  TimeOfDay.fromDateTime(value).format(context),
                  () => _pickTime(context)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _box(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: ext.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ext.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            // scaleDown only: a long date shrinks to fit on a 320pt screen,
            // nothing is ever enlarged and no font size is hardcoded.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
