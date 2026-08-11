import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/services/clean_storage_service.dart';
import '../../../../core/services/health_data_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../models/weight_reading.dart';
import '../../services/vitals_storage_service.dart';
import 'vitals_trend_chart.dart';
import 'vitals_reminder_button.dart';
import '../../services/vitals_reminder_service.dart';

enum _WeightUnit { kg, lb }

/// Weight tracker — log, trend, and 7/30-day averages. Mirrors the
/// blood-pressure/blood-sugar trackers' structure; unlike those two, weight
/// has no clinical "category", so the hero shows a trend arrow (vs the
/// previous reading) instead of a good/bad band.
class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  static const _unitKey = 'weight_unit';
  List<WeightReading> _readings = [];
  _WeightUnit _unit = _WeightUnit.kg;
  bool _loading = true;
  bool _importing = false;

  bool get _isLb => _unit == _WeightUnit.lb;
  String get _unitLabel => _isLb ? 'lb' : 'kg';
  String get _healthAppName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllWeight();
    final unit = CleanStorageService.getAppPreference(_unitKey, 'kg');
    if (!mounted) return;
    setState(() {
      _readings = data; // newest first (DAO orders desc)
      _unit = unit == 'lb' ? _WeightUnit.lb : _WeightUnit.kg;
      _loading = false;
    });
  }

  Future<void> _toggleUnit() async {
    final next = _isLb ? _WeightUnit.kg : _WeightUnit.lb;
    await CleanStorageService.setAppPreference(
        _unitKey, next == _WeightUnit.lb ? 'lb' : 'kg');
    setState(() => _unit = next);
  }

  double _toUnit(double kg) => _isLb ? kg * 2.2046226218 : kg;
  String _display(double kg) => _toUnit(kg).toStringAsFixed(1);

  Future<void> _openLogSheet({WeightReading? edit}) async {
    final accent = VitalsColors.weightAccent(AppColorsExt.of(context).isDark);
    final saved = await AppBottomSheet.show<bool>(
      context,
      title: edit == null ? 'Log weight' : 'Edit reading',
      icon: Symbols.monitor_weight_rounded,
      accent: accent,
      builder: (_) => _WeightLogForm(accent: accent, unit: _unit, existing: edit),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(WeightReading r) async {
    final messenger = ScaffoldMessenger.of(context);
    await VitalsStorageService.deleteWeight(r.id);
    _load();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Reading deleted'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await VitalsStorageService.saveWeight(r);
            _load();
          },
        ),
      ),
    );
  }

  /// Pull weight readings already logged in $_healthAppName (e.g. by a smart
  /// scale) into this tracker. Mirrors the permission check-then-request-
  /// then-recheck dance in VitalsReminderSettingsScreen's `_toggleSync`: the
  /// import reuses the vitals WRITE grant (see HealthDataService's doc on
  /// why there's no separate read-only request) so a user who never opted
  /// into write-sync is still prompted once, here, on first use.
  Future<void> _importFromHealth() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      var granted = await HealthDataService.instance.hasVitalsWritePermission();
      if (!granted) {
        await HealthDataService.instance.requestVitalsWritePermission();
        granted = await HealthDataService.instance.hasVitalsWritePermission();
      }
      if (!granted) {
        if (mounted) {
          context.toastError(
              'Permission to read from $_healthAppName was not granted.');
        }
        return;
      }
      final count = await VitalsStorageService.importFromHealthConnect();
      if (!mounted) return;
      if (count > 0) {
        await _load();
        if (!mounted) return;
        context.toastSuccess(
            'Imported $count new reading${count == 1 ? '' : 's'} from $_healthAppName');
      } else {
        context.toastInfo('No new readings found in $_healthAppName');
      }
    } catch (e) {
      if (mounted) {
        context.toastError('Import from $_healthAppName failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.weightAccent(ext.isDark);

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
            title: 'Weight',
            icon: Symbols.monitor_weight_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
            // NB: no manual spacers between these — AppHeader already inserts
            // an 8pt gap before every action. The explicit SizedBoxes that used
            // to sit here were themselves treated as actions, so each one cost
            // 8 + 8 + 8 = 24pt and pushed this four-control header off a 320pt
            // screen. (blood_pressure/mood never had them.)
            actions: [
              AppChip(
                label: _unitLabel,
                accent: accent,
                selected: true,
                onTap: _toggleUnit,
              ),
              _importing
                  ? SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: ext.mark(accent)),
                        ),
                      ),
                    )
                  : AppIconButton(
                      icon: Symbols.cloud_download_rounded,
                      filled: false,
                      accent: accent,
                      tooltip: 'Import from $_healthAppName',
                      onPressed: _importFromHealth,
                    ),
              VitalsReminderButton(
                id: VitalsReminderService.weight.id,
                prefKey: VitalsReminderService.weight.prefKey,
                title: VitalsReminderService.weight.title,
                body: VitalsReminderService.weight.body,
                accent: accent,
                defaultHour: VitalsReminderService.weight.defaultHour,
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
    final prev = _readings.length > 1 ? _readings[1] : null;
    final deltaKg = prev != null ? latest.valueKg - prev.valueKg : null;

    final now = DateTime.now();
    final last7 = _readings.where((r) => now.difference(r.takenAt).inDays < 7);
    final last30 = _readings.where((r) => now.difference(r.takenAt).inDays < 30);
    final avg7 = _mean(last7.map((r) => r.valueKg));
    final avg30 = _mean(last30.map((r) => r.valueKg));

    final trend = _readings.take(20).toList().reversed.toList();
    final series = trend.map((r) => _toUnit(r.valueKg)).toList();
    final minY = series.isEmpty
        ? 0.0
        : (series.reduce((a, b) => a < b ? a : b) - 3).clamp(0, 1000).toDouble();
    final maxY = series.isEmpty
        ? 100.0
        : (series.reduce((a, b) => a > b ? a : b) + 3).clamp(1, 2000).toDouble();

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.mark(accent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
        children: [
          _WeightHero(
            ext: ext,
            accent: accent,
            valueLabel: _display(latest.valueKg),
            unitLabel: _unitLabel,
            deltaLabel: (deltaKg == null || deltaKg == 0)
                ? null
                : '${deltaKg > 0 ? '+' : '-'}${_display(deltaKg.abs())} $_unitLabel vs last',
            subtitle: 'Last logged · ${_timeAgo(latest.takenAt)}',
          ),
          const SizedBox(height: AppSpacing.md),
          StatTileRow(tiles: [
            StatTile(
              value: avg7 != null ? _display(avg7) : '—',
              label: '7-day avg',
              icon: Symbols.timeline_rounded,
              accent: accent,
            ),
            StatTile(
              value: avg30 != null ? _display(avg30) : '—',
              label: '30-day avg',
              icon: Symbols.calendar_month_rounded,
              accent: accent,
            ),
            StatTile(
              value: '${_readings.length}',
              label: 'Logged',
              icon: Symbols.checklist_rounded,
              accent: accent,
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Trend', icon: Symbols.show_chart_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: VitalsTrendChart(
              series: [
                VitalsSeries(values: series, color: ext.mark(accent), label: 'Weight'),
              ],
              minY: minY,
              maxY: maxY,
              bandColor: ext.mark(accent),
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

  Widget _logRow(AppColorsExt ext, WeightReading r) {
    final tt = Theme.of(context).textTheme;
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
              Icon(Symbols.monitor_weight_rounded,
                  size: 20, color: ext.mark(VitalsColors.weightAccent(ext.isDark))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_display(r.valueKg)} $_unitLabel',
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                      DateFormat('MMM d, h:mm a').format(r.takenAt),
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

  static double? _mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
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
// Hero: big value + trend arrow (no clinical band — weight has no universal
// "good/bad" direction, so this deliberately never colors the change red/green).
// ---------------------------------------------------------------------------
class _WeightHero extends StatelessWidget {
  final AppColorsExt ext;
  final AccentSwatch accent;
  final String valueLabel;
  final String unitLabel;
  final String? deltaLabel;
  final String subtitle;

  const _WeightHero({
    required this.ext,
    required this.accent,
    required this.valueLabel,
    required this.unitLabel,
    required this.deltaLabel,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                color: ext.mark(accent).withOpacity(0.12),
                borderRadius: AppRadius.brMd),
            child: Icon(Symbols.monitor_weight_rounded,
                size: 32, color: ext.mark(accent)),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(valueLabel,
                        style: tt.headlineSmall?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(width: 4),
                    Text(unitLabel,
                        style: tt.labelMedium?.copyWith(color: ext.textTertiary)),
                  ],
                ),
                if (deltaLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(deltaLabel!,
                      style:
                          tt.bodySmall?.copyWith(color: ext.textSecondary)),
                ],
                const SizedBox(height: 6),
                Text(subtitle,
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        const SizedBox(height: 24),
        Icon(Symbols.monitor_weight_rounded, size: 56, color: ext.mark(accent)),
        const SizedBox(height: AppSpacing.md),
        Text('Track your weight',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text('Log a reading to see its trend and averages.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
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
// Log form (bottom-sheet body)
// ---------------------------------------------------------------------------
class _WeightLogForm extends StatefulWidget {
  final AccentSwatch accent;
  final _WeightUnit unit;
  final WeightReading? existing;
  const _WeightLogForm({required this.accent, required this.unit, this.existing});

  @override
  State<_WeightLogForm> createState() => _WeightLogFormState();
}

class _WeightLogFormState extends State<_WeightLogForm> {
  late final TextEditingController _value;
  late final TextEditingController _note;
  late DateTime _takenAt;
  String? _error;
  bool _saving = false;

  bool get _isLb => widget.unit == _WeightUnit.lb;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final initial = e == null
        ? ''
        : (_isLb ? (e.valueKg * 2.2046226218) : e.valueKg)
            .toStringAsFixed(1);
    _value = TextEditingController(text: initial);
    _note = TextEditingController(text: e?.note ?? '');
    _takenAt = e?.takenAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final v = double.tryParse(_value.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter a valid weight.');
      return;
    }
    final kg = _isLb ? v / 2.2046226218 : v;
    if (kg < 1 || kg > 500) {
      setState(() => _error = 'That doesn\'t look like a valid weight.');
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final e = widget.existing;
    final reading = WeightReading(
      id: e?.id ?? 'wt_${DateTime.now().microsecondsSinceEpoch}',
      // Not carried by any control on this form — explicitly preserved on
      // edit, same reasoning as BloodPressureReading's dependentId/tags.
      dependentId: e?.dependentId,
      valueKg: kg,
      takenAt: _takenAt,
      tags: e?.tags ?? const [],
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    await VitalsStorageService.saveWeight(reading);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _value,
          label: 'Weight (${_isLb ? 'lb' : 'kg'})',
          hint: _isLb ? '154.0' : '70.0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          accent: widget.accent,
          onChanged: (_) => setState(() => _error = null),
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
          hint: 'e.g. after workout',
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
    return DateFormat(day.year == today.year ? 'MMM d' : 'MMM d, yyyy')
        .format(day);
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
