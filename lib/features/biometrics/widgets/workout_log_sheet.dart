import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/workout_entry.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/workout_session.dart';

/// What the form hands back.
class WorkoutLogResult {
  const WorkoutLogResult({
    required this.activityType,
    required this.startedAt,
    required this.durationMinutes,
    this.kcal,
    this.distanceKm,
    this.note,
  });

  final String activityType;
  final DateTime startedAt;
  final int durationMinutes;
  final int? kcal;
  final double? distanceKm;
  final String? note;
}

/// "Log a workout": for the session the watch never saw. Kind, when, how long, and
/// optionally calories, distance and a note.
class WorkoutLogSheet {
  const WorkoutLogSheet._();

  /// [existing] edits a workout entered earlier; null starts a new one.
  static Future<WorkoutLogResult?> show(BuildContext context,
      {WorkoutSession? existing}) {
    return AppBottomSheet.show<WorkoutLogResult>(
      context,
      title: existing == null ? 'Log a workout' : 'Edit workout',
      icon: Symbols.exercise_rounded,
      accent: AppColorsExt.of(context).steps,
      builder: (ctx) => WorkoutLogForm(
        existing: existing,
        onSave: (r) => Navigator.of(ctx).pop(r),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class WorkoutLogForm extends StatefulWidget {
  const WorkoutLogForm({super.key, this.existing, required this.onSave});

  final WorkoutSession? existing;
  final ValueChanged<WorkoutLogResult> onSave;

  @override
  State<WorkoutLogForm> createState() => _WorkoutLogFormState();
}

class _WorkoutLogFormState extends State<WorkoutLogForm> {
  late String _type;
  late DateTime _startedAt;
  late final TextEditingController _minutes;
  late final TextEditingController _kcal;
  late final TextEditingController _km;
  late final TextEditingController _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.activityType ?? WorkoutEntry.activities.first.type;
    // An hour ago by default: someone logging a workout is logging one that is
    // over.
    _startedAt = e?.startedAt ?? clock.now().subtract(const Duration(hours: 1));
    _minutes = TextEditingController(text: e?.durationMinutes.toString() ?? '');
    _kcal = TextEditingController(text: e?.energyKcal?.toString() ?? '');
    _km = TextEditingController(
        text: e?.distanceMeters == null
            ? ''
            : (e!.distanceMeters! / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''));
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _minutes.dispose();
    _kcal.dispose();
    _km.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
    final kcalText = _kcal.text.trim();
    final kmText = _km.text.trim().replaceAll(',', '.');
    final kcal = kcalText.isEmpty ? null : int.tryParse(kcalText);
    final km = kmText.isEmpty ? null : double.tryParse(kmText);

    // A figure that is typed but cannot be read is an error, not "left blank".
    if (kcalText.isNotEmpty && kcal == null) {
      setState(() => _error = 'Calories should be a whole number.');
      return;
    }
    if (kmText.isNotEmpty && km == null) {
      setState(() => _error = 'Distance should be a number of kilometres.');
      return;
    }
    final problem = WorkoutEntry.validate(
      startedAt: _startedAt,
      durationMinutes: minutes,
      now: clock.now(),
      kcal: kcal,
      distanceKm: km,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onSave(WorkoutLogResult(
      activityType: _type,
      startedAt: _startedAt,
      durationMinutes: minutes,
      kcal: kcal,
      distanceKm: km,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.steps;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What did you do?',
            style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final a in WorkoutEntry.activities)
              AppChip(
                label: a.label,
                selected: _type == a.type,
                accent: accent,
                onTap: () => setState(() {
                  _type = a.type;
                  _error = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppDateTimeField(
          value: _startedAt,
          accent: accent,
          noun: 'Started',
          onChanged: (v) => setState(() {
            _startedAt = v;
            _error = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _minutes,
          label: 'Minutes',
          hint: '45',
          keyboardType: TextInputType.number,
          accent: accent,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _kcal,
                label: 'Calories (optional)',
                hint: 'kcal',
                keyboardType: TextInputType.number,
                accent: accent,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                controller: _km,
                label: 'Distance (optional)',
                hint: 'km',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                accent: accent,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _note,
          label: 'Note (optional)',
          hint: 'e.g. park loop, felt strong',
          accent: accent,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: tt.bodySmall?.copyWith(color: ext.mark(ext.error))),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: widget.existing == null ? 'Save workout' : 'Save changes',
          leadingIcon: Symbols.check_rounded,
          accent: accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
