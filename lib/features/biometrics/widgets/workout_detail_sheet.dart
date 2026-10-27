import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/workout_entry.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/biometric_metric.dart';
import '../models/workout_session.dart';

/// What the person chose to do with a workout they entered.
enum WorkoutDetailAction { edit, delete }

/// One workout in full: what, when, how long and everything the source gave —
/// calories, distance, steps, heart rate — with where it came from. A session a
/// person entered can be edited or deleted; one a watch wrote cannot, and says
/// where to change it.
class WorkoutDetailSheet {
  const WorkoutDetailSheet._();

  static Future<WorkoutDetailAction?> show(
      BuildContext context, WorkoutSession workout) {
    return AppBottomSheet.show<WorkoutDetailAction>(
      context,
      title: workout.activityLabel,
      icon: Symbols.exercise_rounded,
      accent: AppColorsExt.of(context).steps,
      builder: (ctx) => WorkoutDetailBody(
        workout: workout,
        onAction: (a) => Navigator.of(ctx).pop(a),
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class WorkoutDetailBody extends StatelessWidget {
  const WorkoutDetailBody({
    super.key,
    required this.workout,
    required this.onAction,
    required this.onClose,
  });

  final WorkoutSession workout;
  final ValueChanged<WorkoutDetailAction> onAction;
  final VoidCallback onClose;

  bool get entered => WorkoutEntry.isEntered(workout.id);

  /// "Added by you", "From Health Connect", "From Apple Health".
  String get sourceLabel {
    if (entered) return 'Added by you';
    switch (workout.source) {
      case BiometricSource.healthConnect:
        return 'From Health Connect';
      case BiometricSource.healthKit:
        return 'From Apple Health';
      case BiometricSource.manual:
        return 'Added by you';
    }
  }

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String distance(double meters) {
    final km = meters / 1000;
    return km >= 10 ? '${km.toStringAsFixed(1)} km' : '${km.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final w = workout;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            children: [
              Text(label, style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              Text(value,
                  style: tt.bodyMedium?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    final hr = w.avgHr != null && w.maxHr != null
        ? 'average ${w.avgHr} · highest ${w.maxHr} bpm'
        : w.avgHr != null
            ? 'average ${w.avgHr} bpm'
            : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('When',
            '${DateFormats.weekdayDayMonthShort.format(w.startedAt)} · ${DateFormats.time.format(w.startedAt)}'),
        row('Length', duration(w.durationMinutes)),
        if (w.energyKcal != null) row('Energy', '${w.energyKcal} kcal'),
        if (w.distanceMeters != null) row('Distance', distance(w.distanceMeters!)),
        if (w.steps != null) row('Steps', '${w.steps}'),
        if (hr != null) row('Heart rate', hr),
        row('Source', sourceLabel),
        if (w.note != null && w.note!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(w.note!, style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (entered) ...[
          AppButton(
            label: 'Edit',
            leadingIcon: Symbols.edit_rounded,
            accent: ext.steps,
            fullWidth: true,
            onPressed: () => onAction(WorkoutDetailAction.edit),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Delete',
            leadingIcon: Symbols.delete_rounded,
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => onAction(WorkoutDetailAction.delete),
          ),
        ] else ...[
          Text(
            'This one came from your health app. To change or remove it, do it '
            'there.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Close',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: onClose,
          ),
        ],
      ],
    );
  }
}
