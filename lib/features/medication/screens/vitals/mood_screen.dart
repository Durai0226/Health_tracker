import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../../../core/widgets/app/vitals_theme.dart';
import '../../../../core/widgets/app/vitals_widgets.dart';
import '../../models/medicine_log.dart' show moodRatingLabels;
import '../../models/mood_entry.dart';
import '../../services/vitals_storage_service.dart';
import 'vitals_trend_chart.dart';
import 'vitals_reminder_button.dart';
import '../../services/vitals_reminder_service.dart';

/// Mood tracker — a standalone daily mood log (independent of period tracking
/// and of the per-dose mood already captured on medicine logs). Uses the same
/// [moodRatingLabels] scale (0 = Great … 4 = Terrible) so the two are directly
/// comparable if ever shown side by side.
class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  List<MoodEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await VitalsStorageService.getAllMood();
    if (!mounted) return;
    setState(() {
      _entries = data; // newest first (DAO orders desc)
      _loading = false;
    });
  }

  Future<void> _openLogSheet({MoodEntry? edit}) async {
    final accent = VitalsColors.moodAccent(AppColorsExt.of(context).isDark);
    final saved = await AppBottomSheet.show<bool>(
      context,
      title: edit == null ? 'Log mood' : 'Edit entry',
      icon: Symbols.mood_rounded,
      accent: accent,
      builder: (_) => _MoodLogForm(accent: accent, existing: edit),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(MoodEntry r) async {
    final messenger = ScaffoldMessenger.of(context);
    await VitalsStorageService.deleteMood(r.id);
    _load();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await VitalsStorageService.saveMood(r);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = VitalsColors.moodAccent(ext.isDark);

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
            title: 'Mood',
            icon: Symbols.mood_rounded,
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              VitalsReminderButton(
                id: VitalsReminderService.mood.id,
                prefKey: VitalsReminderService.mood.prefKey,
                title: VitalsReminderService.mood.title,
                body: VitalsReminderService.mood.body,
                accent: accent,
                defaultHour: VitalsReminderService.mood.defaultHour,
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: ext.mark(accent)))
                : _entries.isEmpty
                    ? _EmptyState(accent: accent, onLog: () => _openLogSheet())
                    : _buildBody(ext, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColorsExt ext, AccentSwatch accent) {
    final latest = _entries.first;

    final now = DateTime.now();
    final last7 = _entries.where((r) => now.difference(r.takenAt).inDays < 7).toList();
    final avg7 = _meanIndex(last7);

    final trend = _entries.take(20).toList().reversed.toList();
    // Inverted so the chart reads naturally (up = better mood); the axis
    // numbers themselves are never shown to the user without the label.
    final series =
        trend.map((r) => (moodRatingLabels.length - 1 - r.moodIndex).toDouble()).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.mark(accent),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
        children: [
          VitalsStatusHero(
            bigValue: latest.label,
            ringProgress: (moodRatingLabels.length - latest.moodIndex) /
                moodRatingLabels.length,
            bandColor: VitalsColors.moodBand(ext.isDark, latest.moodIndex),
            categoryIcon: VitalsColors.moodIcon(latest.moodIndex),
            categoryLabel: latest.label,
            meaning: _meaning(latest.moodIndex),
            subtitle: 'Last logged · ${_timeAgo(latest.takenAt)}'
                '${latest.note != null ? ' · ${latest.note}' : ''}',
          ),
          const SizedBox(height: AppSpacing.md),
          StatTileRow(tiles: [
            StatTile(
              value: avg7 != null ? moodRatingLabels[avg7.round().clamp(0, 4)] : '—',
              label: '7-day avg',
              icon: Symbols.timeline_rounded,
              accent: accent,
            ),
            StatTile(
              value: '${last7.length}',
              label: 'This week',
              icon: Symbols.calendar_month_rounded,
              accent: accent,
            ),
            StatTile(
              value: '${_entries.length}',
              label: 'Logged',
              icon: Symbols.checklist_rounded,
              accent: accent,
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'Trend', icon: Symbols.show_chart_rounded, accent: accent),
          const SizedBox(height: 4),
          Text('Higher = better mood',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ext.textTertiary)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: VitalsTrendChart(
              series: [
                VitalsSeries(values: series, color: ext.mark(accent), label: 'Mood'),
              ],
              minY: 0,
              maxY: (moodRatingLabels.length - 1).toDouble(),
              bandColor: ext.mark(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: 'History', icon: Symbols.history_rounded, accent: accent),
          const SizedBox(height: AppSpacing.sm),
          ..._entries.map((r) => _logRow(ext, r)),
        ],
      ),
    );
  }

  Widget _logRow(AppColorsExt ext, MoodEntry r) {
    final tt = Theme.of(context).textTheme;
    final band = VitalsColors.moodBand(ext.isDark, r.moodIndex);
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
              Icon(VitalsColors.moodIcon(r.moodIndex), size: 22, color: band),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.label,
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                      '${DateFormats.dayMonthTime.format(r.takenAt)}'
                      '${r.note != null ? ' · ${r.note}' : ''}',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  static double? _meanIndex(List<MoodEntry> list) {
    if (list.isEmpty) return null;
    return list.map((r) => r.moodIndex).reduce((a, b) => a + b) / list.length;
  }

  static String _meaning(int index) {
    const meanings = [
      'Feeling great today.',
      'A good day overall.',
      'An okay, middle-of-the-road day.',
      'A tougher day than usual.',
      'A really hard day — be gentle with yourself.',
    ];
    return meanings[index.clamp(0, meanings.length - 1)];
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
        Icon(Symbols.mood_rounded, size: 56, color: ext.mark(accent)),
        const SizedBox(height: AppSpacing.md),
        Text('Track your mood',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text('A quick daily check-in to see how you\'ve been feeling over time.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Log how you feel',
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
class _MoodLogForm extends StatefulWidget {
  final AccentSwatch accent;
  final MoodEntry? existing;
  const _MoodLogForm({required this.accent, this.existing});

  @override
  State<_MoodLogForm> createState() => _MoodLogFormState();
}

class _MoodLogFormState extends State<_MoodLogForm> {
  late final TextEditingController _note;
  int? _selected;
  late DateTime _takenAt;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _note = TextEditingController(text: e?.note ?? '');
    _selected = e?.moodIndex;
    _takenAt = e?.takenAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final index = _selected;
    if (index == null) {
      setState(() => _error = 'Pick how you\'re feeling.');
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final e = widget.existing;
    final entry = MoodEntry(
      id: e?.id ?? 'mood_${DateTime.now().microsecondsSinceEpoch}',
      dependentId: e?.dependentId,
      moodIndex: index,
      takenAt: _takenAt,
      tags: e?.tags ?? const [],
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAt: e?.createdAt ?? DateTime.now(),
    );
    await VitalsStorageService.saveMood(entry);
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
        Text('How are you feeling?',
            style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < moodRatingLabels.length; i++)
              _MoodFaceButton(
                selected: _selected == i,
                icon: VitalsColors.moodIcon(i),
                label: moodRatingLabels[i],
                color: VitalsColors.moodBand(ext.isDark, i),
                onTap: () => setState(() {
                  _selected = i;
                  _error = null;
                }),
              ),
          ],
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
          hint: 'What\'s on your mind?',
          accent: widget.accent,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: tt.bodySmall?.copyWith(color: ext.mark(ext.error))),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: widget.existing == null ? 'Save entry' : 'Update entry',
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

class _MoodFaceButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoodFaceButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.16) : ext.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? color : ext.outline, width: 1.5),
            ),
            child: Icon(icon, color: selected ? color : ext.textTertiary, size: 26),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: tt.labelSmall?.copyWith(
                  color: selected ? color : ext.textTertiary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
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
      title: 'Entry date',
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
      title: 'Entry time',
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
