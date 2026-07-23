import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/flow_intensity.dart';
import '../models/period_day.dart';
import '../models/period_symptom.dart';
import '../services/period_service.dart';

/// Bottom sheet to log/edit a single day: flow, symptoms, mood, energy, BBT,
/// intercourse and notes. Writes through [PeriodService.logDay].
class LogTodaySheet extends StatefulWidget {
  final DateTime date;
  const LogTodaySheet({super.key, required this.date});

  /// Returns true when a save/clear happened so the caller can refresh.
  static Future<bool?> show(BuildContext context, {DateTime? date}) {
    final target = date ?? DateTime.now();
    return AppBottomSheet.show<bool>(
      context,
      title: 'Log ${_titleFor(target)}',
      icon: Symbols.edit_calendar_rounded,
      accent: AppColorsExt.of(context).period,
      builder: (ctx) => LogTodaySheet(date: target),
    );
  }

  static String _titleFor(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'today';
    }
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  State<LogTodaySheet> createState() => _LogTodaySheetState();
}

class _LogTodaySheetState extends State<LogTodaySheet> {
  late int _flowIndex;
  final Set<String> _symptoms = {};
  int? _mood;
  int? _energy;
  bool _intercourse = false;
  late final TextEditingController _bbtController;
  late final TextEditingController _noteController;
  bool _hadExisting = false;

  @override
  void initState() {
    super.initState();
    final existing = PeriodService.getDay(widget.date);
    _flowIndex = existing?.flowIndex ?? 0;
    _mood = existing?.mood;
    _energy = existing?.energy;
    _intercourse = existing?.intercourse ?? false;
    _symptoms.addAll(existing?.symptomIds ?? const []);
    _bbtController =
        TextEditingController(text: existing?.bbtCelsius?.toString() ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _hadExisting = existing?.hasData ?? false;
  }

  @override
  void dispose() {
    _bbtController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final bbt = double.tryParse(_bbtController.text.trim().replaceAll(',', '.'));
    final note = _noteController.text.trim();
    final day = PeriodDay(
      id: PeriodDay.keyFor(widget.date),
      date: widget.date,
      flowIndex: _flowIndex,
      mood: _mood,
      energy: _energy,
      bbtCelsius: bbt,
      intercourse: _intercourse ? true : null,
      symptomIds: _symptoms.toList(),
      note: note.isEmpty ? null : note,
    );
    await PeriodService.logDay(day);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _clear() async {
    HapticFeedback.lightImpact();
    await PeriodService.deleteDay(PeriodDay.keyFor(widget.date));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AccentScope(
      feature: FeatureAccent.period,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(context, 'Flow'),
          const SizedBox(height: AppSpacing.sm),
          _FlowSelector(
            selected: _flowIndex,
            onChanged: (i) => setState(() => _flowIndex = i),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Symptoms'),
          const SizedBox(height: AppSpacing.sm),
          ..._symptomGroups(context),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Mood'),
          const SizedBox(height: AppSpacing.sm),
          _MoodFaces(
            value: _mood,
            accent: ext.period,
            onChanged: (v) => setState(() => _mood = v),
          ),

          const SizedBox(height: AppSpacing.lg),
          _label(context, 'Energy'),
          const SizedBox(height: AppSpacing.sm),
          _Rating(
            value: _energy,
            accent: ext.info,
            icon: Symbols.bolt_rounded,
            onChanged: (v) => setState(() => _energy = v),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _bbtController,
            label: 'BBT (°C)',
            hint: '36.5',
            accent: ext.period,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Symbols.thermostat_rounded,
          ),

          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppChip(
              label: 'Intercourse',
              icon: Symbols.favorite_rounded,
              selected: _intercourse,
              accent: ext.period,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _intercourse = !_intercourse);
              },
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _noteController,
            label: 'Notes',
            hint: 'Anything worth remembering…',
            accent: ext.period,
            maxLines: 3,
          ),

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (_hadExisting) ...[
                Expanded(
                  child: AppButton(
                    label: 'Clear',
                    variant: AppButtonVariant.secondary,
                    onPressed: _clear,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Save',
                  accent: ext.period,
                  emphasized: true,
                  leadingIcon: Symbols.check_rounded,
                  onPressed: _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColorsExt.of(context).textSecondary),
      );

  /// The symptom picker, chunked into small category sub-wraps with neutral
  /// subheads (Physical / Mood / …) so the 16 chips read as grouped sets rather
  /// than one flat run. Categories render in model order to keep ids stable.
  List<Widget> _symptomGroups(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final blocks = <Widget>[];
    for (final c in SymptomCategory.values) {
      final items = defaultSymptoms.where((s) => s.category == c).toList();
      if (items.isEmpty) continue;
      final selectedCount = items.where((s) => _symptoms.contains(s.id)).length;
      if (blocks.isNotEmpty) {
        blocks.add(const SizedBox(height: AppSpacing.sm));
      }
      blocks.add(Text(
        selectedCount > 0 ? '${c.label} · $selectedCount' : c.label,
        style: tt.labelSmall?.copyWith(color: ext.textTertiary),
      ));
      blocks.add(const SizedBox(height: AppSpacing.xs));
      blocks.add(Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final s in items)
            AppChip(
              label: s.label,
              icon: s.icon,
              selected: _symptoms.contains(s.id),
              accent: ext.period,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (!_symptoms.remove(s.id)) _symptoms.add(s.id);
                });
              },
            ),
        ],
      ));
    }
    return blocks;
  }
}

class _FlowSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _FlowSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final f in FlowIntensity.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: f == FlowIntensity.values.last ? 0 : AppSpacing.sm),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(f.flowIndex);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == f.flowIndex
                        ? ext.period.container
                        : ext.surfaceVariant,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: selected == f.flowIndex
                          ? ext.mark(ext.period)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(f.icon,
                          size: 18,
                          color: selected == f.flowIndex
                              ? ext.period.onContainer
                              : ext.textSecondary),
                      const SizedBox(height: 4),
                      Text(
                        f.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelSmall?.copyWith(
                          color: selected == f.flowIndex
                              ? ext.period.onContainer
                              : ext.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Rating extends StatelessWidget {
  final int? value;
  final AccentSwatch accent;
  final IconData icon;
  final ValueChanged<int?> onChanged;

  const _Rating({
    required this.value,
    required this.accent,
    required this.onChanged,
    this.icon = Symbols.sentiment_satisfied_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(value == i ? null : i); // tap again to clear
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (value ?? 0) >= i ? accent.container : ext.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (value ?? 0) >= i ? ext.mark(accent) : ext.outline,
                  ),
                ),
                child: Text(
                  '$i',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: (value ?? 0) >= i
                            ? accent.onContainer
                            : ext.textTertiary,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Single-select 1..5 mood scale using the sentiment_* face family (cohering
/// with the emotional-symptom glyphs). Only the chosen face is highlighted;
/// tapping it again clears the value. Wiring stays [int]? like the old digit
/// rating, so persisted mood round-trips identically.
class _MoodFaces extends StatelessWidget {
  final int? value;
  final AccentSwatch accent;
  final ValueChanged<int?> onChanged;

  const _MoodFaces({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  static const List<IconData> _faces = [
    Symbols.sentiment_very_dissatisfied_rounded,
    Symbols.sentiment_dissatisfied_rounded,
    Symbols.sentiment_neutral_rounded,
    Symbols.sentiment_satisfied_rounded,
    Symbols.sentiment_very_satisfied_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(value == i ? null : i); // tap again to clear
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == i ? accent.container : ext.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == i ? ext.mark(accent) : ext.outline,
                  ),
                ),
                child: Icon(
                  _faces[i - 1],
                  size: 22,
                  color: value == i ? accent.onContainer : ext.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
