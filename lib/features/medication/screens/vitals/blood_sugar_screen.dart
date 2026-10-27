import 'package:flutter/material.dart';
import '../../../../core/utils/relative_time.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/health/vitals_analyzer.dart';
import '../../../../core/health/insight_engine.dart';
import '../../../../core/health/vitals_pattern_detector.dart';
import '../../../../core/health/glucose_patterns.dart';
import '../../../../core/services/clean_storage_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../../../core/widgets/app/vitals_widgets.dart';
import '../../models/glucose_reading.dart';
import '../../services/glucose_recheck.dart';
import '../../services/vitals_storage_service.dart';
import 'vitals_trend_chart.dart';
import 'vitals_emergency_call.dart';
import 'vitals_reminder_button.dart';
import 'blood_sugar_report_screen.dart';
import 'package:clock/clock.dart';
import '../../../../core/utils/calendar_day.dart';

/// Blood Sugar tracker — log, classify per-context (ADA), estimated A1C, trend.
class BloodSugarScreen extends StatefulWidget {
  const BloodSugarScreen({super.key});

  /// How recent a severe-low reading has to be for the emergency treatment
  /// card to still be describing something actionable. Identical to the
  /// blood-pressure screen's crisis-card window, so both vitals emergencies
  /// expire on the same rule.
  @visibleForTesting
  static const Duration emergencyCardWindow = Duration(hours: 48);

  /// True when [latest] is a severe low that is still current.
  ///
  /// The card fires a real medical emergency — "take 15 g of fast-acting
  /// carbs… use glucagon and get help now". Unbounded, a severe low logged
  /// days ago re-fired it on every visit, so the screen asserted an emergency
  /// that had long since passed. The classification itself is untouched: a
  /// stale severe low is still labelled Severe Low everywhere on the screen,
  /// it just no longer claims to be happening now.
  @visibleForTesting
  static bool showsSevereLowEmergency(GlucoseReading latest, DateTime now) =>
      latest.isEmergencyLow &&
      now.difference(latest.takenAt) < emergencyCardWindow;

  @override
  State<BloodSugarScreen> createState() => _BloodSugarScreenState();
}

class _BloodSugarScreenState extends State<BloodSugarScreen> {
  static const _unitKey = 'glucose_unit';
  List<GlucoseReading> _readings = [];
  GlucoseUnit _unit = GlucoseUnit.mgdl;
  bool _loading = true;

  bool get _isMmol => _unit == GlucoseUnit.mmoll;
  String get _unitLabel => _isMmol ? 'mmol/L' : 'mg/dL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllGlucose();
    final unit = CleanStorageService.getAppPreference(_unitKey, 'mgdl');
    if (!mounted) return;
    setState(() {
      _readings = data;
      _unit = unit == 'mmoll' ? GlucoseUnit.mmoll : GlucoseUnit.mgdl;
      _loading = false;
    });
  }

  Future<void> _toggleUnit() async {
    final next = _isMmol ? GlucoseUnit.mgdl : GlucoseUnit.mmoll;
    await CleanStorageService.setAppPreference(
        _unitKey, next == GlucoseUnit.mmoll ? 'mmoll' : 'mgdl');
    setState(() => _unit = next);
  }

  String _display(int mgdl) =>
      _isMmol ? VitalsAnalyzer.mgdlToMmol(mgdl).toStringAsFixed(1) : '$mgdl';

  Future<void> _openLogSheet({GlucoseReading? edit}) async {
    final accent = VitalsColors.glucoseAccent(AppColorsExt.of(context).isDark);
    // `true` when saved, or — for a new low reading — the time its 15-minute
    // recheck was set for.
    final saved = await AppBottomSheet.show<Object>(
      context,
      title: edit == null ? 'Log blood sugar' : 'Edit reading',
      icon: Symbols.water_drop_rounded,
      accent: accent,
      builder: (_) => _GlucoseLogForm(accent: accent, unit: _unit, existing: edit),
    );
    if (saved == null) return;
    _load();
    if (saved is DateTime && mounted) {
      context.toastInfo(
        'Recheck reminder set for ${DateFormats.time.format(saved)}',
        action: const AppToastAction(label: 'Cancel', onPressed: GlucoseRecheck.cancel),
      );
    }
  }

  Future<void> _delete(GlucoseReading r) async {
    // Soft delete: remove now, but offer Undo — deleting a health record must
    // never be a one-swipe, unrecoverable action.
    await VitalsStorageService.deleteGlucose(r.id);
    _load();
    // The messenger used to be captured before the await so the toast
    // survived the gap; the toast kit takes a context, so guard instead.
    if (!mounted) return;
    context.toastSuccess(
      'Reading deleted',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await VitalsStorageService.saveGlucose(r);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.glucoseAccent(ext.isDark);

    return AppScaffold(
      // Only float the FAB once there are readings to add to; the empty state
      // carries its own 'Log reading' CTA, so a FAB there duplicates it.
      floatingActionButton: _readings.isEmpty
          ? null
          : AppFab(
              icon: Symbols.add_rounded,
              label: 'Log',
              accent: accent,
              onPressed: () => _openLogSheet(),
            ),
      body: Column(
        children: [
          AppHeader(
            title: 'Blood sugar',
            leading: AppHeader.backButton(context),
            // NB: no manual spacers between these — AppHeader already inserts
            // an 8pt gap before every action. The explicit SizedBox that used
            // to sit here was itself treated as an action, so it cost
            // 8 + 8 + 8 = 24pt and pushed the header off a 320pt screen.
            actions: [
              // A bare "mg/dL" chip announces as its own label with no hint
              // that tapping converts the whole screen to the other unit.
              Semantics(
                label: 'Units: $_unitLabel, tap to switch to '
                    '${_isMmol ? 'mg/dL' : 'mmol/L'}',
                button: true,
                container: true,
                child: AppChip(
                  label: _unitLabel,
                  accent: accent,
                  selected: true,
                  onTap: _toggleUnit,
                ),
              ),
              VitalsReminderButton(
                id: 900021,
                prefKey: 'vitals_glucose_reminder',
                title: 'Blood sugar check',
                body: 'Time to measure and log your blood sugar.',
                accent: accent,
                defaultHour: 8,
              ),
              if (_readings.isNotEmpty)
                AppIconButton(
                  icon: Symbols.assessment_rounded,
                  filled: false,
                  accent: accent,
                  tooltip: 'Blood sugar report',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BloodSugarReportScreen()),
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
    final cls = latest.glucoseClass;
    final band = VitalsColors.glucoseBand(ext.isDark, cls);

    // PV-13 — one 90-day window for all three tiles.
    //
    // "In range" was computed over ALL history while Average and eA1c beside it
    // were 90-day, so one card showed two windows without saying so: a user who
    // improved over the last month read a stale in-range percentage next to a
    // fresh average and had no way to tell they disagreed on purpose.
    // 90 days is the right window to keep — it is what eA1c is defined over.
    //
    // `calendarDaysBetween` rather than `.inDays`: a civil day is 23 or 25
    // hours across a DST boundary, and the reading exactly 90 days old must not
    // move in or out of the window depending on the time of year.
    final recent = _readings
        .where((r) => calendarDaysBetween(r.takenAt, clock.now()) < 90)
        .toList();
    final values90 = recent.map((r) => r.valueMgdl).toList();
    final avg = VitalsAnalyzer.mean(values90);
    final eA1c = VitalsAnalyzer.estimatedA1c(values90);
    final inRange = VitalsAnalyzer.inRangePercent(
        recent.map((r) => (mgdl: r.valueMgdl, ctx: r.context)).toList());

    final trend = _readings.take(20).toList().reversed.toList();
    // PV-16 — the chart drew raw mg/dL for everyone.
    //
    // Every other number on this screen goes through [_display], so an mmol/L
    // user read "6.7" in the history and saw a trend line against a 20-400
    // axis with an in-range band at 70-180. A glucose figure in the wrong unit
    // is out by ~18x, and this is the screen a person checks before deciding
    // whether to treat a low.
    //
    // The headroom and the clamps stay in mg/dL — they are calibrated to that
    // scale — and EVERYTHING the chart draws is converted together at the end.
    // Converting the series but not the axis (or the band) would be worse than
    // converting neither: the line would be right and its context wrong.
    final rawSeries = trend.map((r) => r.valueMgdl.toDouble()).toList();
    final rawMinY = rawSeries.isEmpty
        ? 40.0
        : (rawSeries.reduce((a, b) => a < b ? a : b) - 20).clamp(20, 400).toDouble();
    final rawMaxY = rawSeries.isEmpty
        ? 250.0
        : (rawSeries.reduce((a, b) => a > b ? a : b) + 20).clamp(120, 500).toDouble();

    double chartY(double mgdl) =>
        _isMmol ? VitalsAnalyzer.mgdlToMmol(mgdl.round()) : mgdl;
    final series = rawSeries.map(chartY).toList();
    final minY = chartY(rawMinY);
    final maxY = chartY(rawMaxY);

    // Deterministic pattern insight over the user's own readings.
    final insight = InsightEngine.bloodSugar(_readings
        .map((r) => GlucosePoint(at: r.takenAt, mgdl: r.valueMgdl, context: r.context))
        .toList());

    // Where in the day the readings tend to leave their range, named by meal or
    // hour, in the unit this screen is showing.
    final patterns = GlucosePatternCheck.check(
      _readings.map((r) => GlucoseSample(r.valueMgdl, r.context, r.takenAt)),
      now: clock.now(),
      format: (mgdl) => '${_display(mgdl)} $_unitLabel',
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.mark(accent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
        children: [
          // Recency-bounded — see [BloodSugarScreen.showsSevereLowEmergency].
          if (BloodSugarScreen.showsSevereLowEmergency(
              latest, DateTime.now())) ...[
            VitalsEmergencyCard(
              title: 'Severe low blood sugar',
              message:
                  'Your latest reading (${_display(latest.valueMgdl)} $_unitLabel) is dangerously low. '
                  'If you can swallow: take 15 g of fast-acting carbs, wait 15 minutes, and recheck (the 15-15 rule). '
                  'If confused or unable to swallow, this is an emergency — use glucagon and get help now.',
              primaryLabel: 'Call emergency',
              onPrimary: _callEmergency,
              secondaryLabel: 'Re-check',
              onSecondary: () => _openLogSheet(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          VitalsStatusHero(
            bigValue: _display(latest.valueMgdl),
            unitLabel: _unitLabel,
            ringProgress: _ringFor(cls),
            bandColor: band,
            categoryIcon: VitalsColors.glucoseIcon(cls),
            categoryLabel:
                '${VitalsAnalyzer.glucoseLabel(cls)} · ${VitalsAnalyzer.glucoseContextLabel(latest.context)}',
            meaning: VitalsAnalyzer.glucoseMeaning(cls),
            subtitle: 'Last reading · ${RelativeTime.since(latest.takenAt)}',
          ),
          const SizedBox(height: AppSpacing.md),
          StatTileRow(tiles: [
            StatTile(
              value: avg != null ? _display(avg.round()) : '—',
              label: 'Avg ($_unitLabel)',
              icon: Symbols.timeline_rounded,
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
          ]),
          if (eA1c != null) ...[
            const SizedBox(height: 6),
            Text('Estimated A1C is informational, not a lab result.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ext.textTertiary)),
          ],
          if (insight != null) ...[
            const SizedBox(height: AppSpacing.md),
            InsightCard(insight: insight),
          ],
          if (patterns.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
                title: 'By time of day',
                icon: Symbols.schedule_rounded,
                accent: accent),
            const SizedBox(height: AppSpacing.sm),
            for (final p in patterns) ...[
              InsightCard(insight: p.toInsight()),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Trend', icon: Symbols.show_chart_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: VitalsTrendChart(
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
              // A shaded band with no explanation is unreadable — and it is
              // where the unit has to be stated, since the axis carries no
              // label of its own.
              bandLabel: 'Shaded band is the in-range zone '
                  '(${_display(70)}–${_display(180)} $_unitLabel)',
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

  Widget _logRow(AppColorsExt ext, GlucoseReading r) {
    final tt = Theme.of(context).textTheme;
    final cls = r.glucoseClass;
    final band = VitalsColors.glucoseBand(ext.isDark, cls);
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
              // Icon + label, never colour alone — the class has to survive
              // colour-blindness (WCAG 1.4.1); the dot it replaced did not.
              Icon(VitalsColors.glucoseIcon(cls), size: 20, color: band),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_display(r.valueMgdl)} $_unitLabel',
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                      '${VitalsAnalyzer.glucoseLabel(cls)} · ${VitalsAnalyzer.glucoseContextLabel(r.context)} · ${DateFormats.dayMonthTime.format(r.takenAt)}'
                      '${r.insulinUnits == null ? '' : ' · ${_GlucoseLogFormState._unitsText(r.insulinUnits)} units insulin'}',
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

  // Ring convention (shared with the blood-pressure screen): FULL = healthy,
  // the ring empties monotonically as the reading worsens — so a mild low/high
  // shows more ring than a severe one, and in-range is full.
  double _ringFor(GlucoseClass c) {
    switch (c) {
      case GlucoseClass.inRange:
        return 1.0;
      case GlucoseClass.low:
      case GlucoseClass.high:
        return 0.5;
      case GlucoseClass.severeLow:
      case GlucoseClass.veryHigh:
        return 0.2;
    }
  }

  /// Opens the dialer on the region's emergency number. Shared with the
  /// blood-pressure screen's identical card — see [VitalsEmergencyCall].
  ///
  /// The 15-15 rule this button used to print as a toast is already the second
  /// sentence of the card's own message, so nothing is lost by the button
  /// doing what its label says instead.
  Future<void> _callEmergency() => VitalsEmergencyCall.dial(context);

}

// ---------------------------------------------------------------------------
// Empty state
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
      'Fasting = 8 h since eating',
      'Tag before/after meals for context',
      'After-meal is measured 1–2 h after',
      'Wash and dry hands before testing',
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: 24),
        Icon(Symbols.water_drop_rounded, size: 56, color: ext.mark(accent)),
        const SizedBox(height: AppSpacing.md),
        Text('Track your blood sugar',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text('Log a reading to see its range, trend, and estimated A1C.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                  title: 'For a useful reading',
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
          label: 'Log reading',
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
// Log form with LIVE class preview
// ---------------------------------------------------------------------------
class _GlucoseLogForm extends StatefulWidget {
  final AccentSwatch accent;
  final GlucoseUnit unit;
  final GlucoseReading? existing;
  const _GlucoseLogForm({required this.accent, required this.unit, this.existing});

  @override
  State<_GlucoseLogForm> createState() => _GlucoseLogFormState();
}

class _GlucoseLogFormState extends State<_GlucoseLogForm> {
  late final TextEditingController _value;
  late final TextEditingController _carbs;
  late final TextEditingController _insulin;
  late final TextEditingController _note;
  GlucoseContext _context = GlucoseContext.fasting;
  late DateTime _takenAt;
  String? _error;
  bool _saving = false;

  bool get _isMmol => widget.unit == GlucoseUnit.mmoll;
  String get _unitLabel => _isMmol ? 'mmol/L' : 'mg/dL';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _value = TextEditingController(
        text: e == null
            ? ''
            : (_isMmol
                ? VitalsAnalyzer.mgdlToMmol(e.valueMgdl).toStringAsFixed(1)
                : e.valueMgdl.toString()));
    _carbs = TextEditingController(text: e?.carbs?.toString() ?? '');
    _insulin = TextEditingController(text: _unitsText(e?.insulinUnits));
    _note = TextEditingController(text: e?.note ?? '');
    _context = e?.context ?? GlucoseContext.fasting;
    _takenAt = e?.takenAt ?? clock.now();
  }

  @override
  void dispose() {
    _value.dispose();
    _carbs.dispose();
    _insulin.dispose();
    _note.dispose();
    super.dispose();
  }

  /// "4" for 4.0 units, "4.5" for 4.5: no trailing ".0" on a whole number.
  static String _unitsText(double? u) => u == null
      ? ''
      : (u == u.roundToDouble() ? u.toInt().toString() : u.toString());

  /// The units typed, null when empty; NaN-free. Comma or point.
  double? get _insulinUnits =>
      double.tryParse(_insulin.text.trim().replaceAll(',', '.'));

  /// The most one entry may say. Not a dosing limit: a guard against a typo
  /// (a 400 where 4 was meant) landing in a record a doctor reads.
  static const double maxInsulinUnits = 200;

  int? get _mgdl {
    final raw = _value.text.trim();
    if (raw.isEmpty) return null;
    if (_isMmol) {
      final d = double.tryParse(raw);
      return d == null ? null : VitalsAnalyzer.mmolToMgdl(d);
    }
    return int.tryParse(raw);
  }

  GlucoseClass? get _previewClass {
    final v = _mgdl;
    if (v == null || !VitalsAnalyzer.isValidGlucoseMgdl(v)) return null;
    return VitalsAnalyzer.classifyGlucose(v, _context);
  }

  Future<void> _save() async {
    if (_saving) return;
    final v = _mgdl;
    if (v == null || !VitalsAnalyzer.isValidGlucoseMgdl(v)) {
      setState(() => _error = 'Enter a valid glucose value.');
      return;
    }
    final unitsText = _insulin.text.trim();
    final units = _insulinUnits;
    if (unitsText.isNotEmpty &&
        (units == null || units <= 0 || units > maxInsulinUnits)) {
      setState(() => _error = 'Enter insulin units from 0.5 to '
          '${maxInsulinUnits.toInt()}, or leave it empty.');
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final e = widget.existing;
    final reading = GlucoseReading(
      id: e?.id ?? 'gl_${DateTime.now().microsecondsSinceEpoch}',
      // See blood_pressure_screen.dart's identical fix for why this is
      // explicitly preserved rather than left to the active-profile fallback.
      dependentId: e?.dependentId,
      valueMgdl: v,
      context: _context,
      takenAt: _takenAt,
      carbs: int.tryParse(_carbs.text),
      // What is in the field. Emptying it clears the units, and an entry
      // that had none keeps none. (medNote and tags have no control here and
      // are kept as they were: an edit used to silently wipe them.)
      insulinUnits: unitsText.isEmpty ? null : units,
      medNote: e?.medNote,
      tags: e?.tags ?? const [],
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    // See blood_pressure_screen.dart's identical guard: without it a failed
    // write leaves the Save button spinning and the user unable to tell
    // whether the reading was recorded.
    try {
      await VitalsStorageService.saveGlucose(reading);
    } catch (e) {
      debugPrint('⚠️ Saving a glucose reading failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save this reading. Try again.';
        });
      }
      return;
    }
    if (VitalsAnalyzer.isGlucoseEmergencyLow(v)) HapticFeedback.heavyImpact();
    // A NEW low reading arms the 15-minute recheck, and any new reading takes
    // down the one a previous low set. An edit is not a new check.
    DateTime? recheckAt;
    if (e == null) {
      try {
        recheckAt = await GlucoseRecheck.afterSave(reading);
      } catch (err) {
        debugPrint('⚠️ Setting the glucose recheck failed: $err');
      }
    }
    if (mounted) Navigator.pop(context, recheckAt ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final cls = _previewClass;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cls == null
                ? ext.surfaceVariant
                : VitalsColors.glucoseBand(ext.isDark, cls).withOpacity(0.14),
            borderRadius: AppRadius.brMd,
          ),
          child: Row(
            children: [
              Icon(
                cls == null ? Symbols.info_rounded : VitalsColors.glucoseIcon(cls),
                color: cls == null
                    ? ext.textTertiary
                    : VitalsColors.glucoseBand(ext.isDark, cls),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  cls == null
                      ? 'Enter a reading to see its range'
                      : '${VitalsAnalyzer.glucoseLabel(cls)} — ${VitalsAnalyzer.glucoseMeaning(cls)}',
                  style: tt.bodyMedium?.copyWith(
                    color: cls == null ? ext.textSecondary : ext.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _value,
          label: 'Blood sugar ($_unitLabel)',
          hint: _isMmol ? '5.5' : '100',
          keyboardType: TextInputType.numberWithOptions(decimal: _isMmol),
          accent: widget.accent,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('When', style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: GlucoseContext.values.map((c) {
            return AppChip(
              label: VitalsAnalyzer.glucoseContextLabel(c),
              selected: _context == c,
              accent: widget.accent,
              onTap: () => setState(() => _context = c),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _carbs,
          label: 'Carbs (g, optional)',
          hint: 'grams',
          keyboardType: TextInputType.number,
          accent: widget.accent,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _insulin,
          label: 'Insulin (units, optional)',
          hint: 'units',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          accent: widget.accent,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        AppDateTimeField(
          value: _takenAt,
          accent: widget.accent,
          noun: 'Reading',
          onChanged: (v) => setState(() => _takenAt = v),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _note,
          label: 'Note (optional)',
          hint: 'e.g. after lunch',
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
