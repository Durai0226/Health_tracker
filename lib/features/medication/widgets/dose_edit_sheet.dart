import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_log.dart';
import '../services/dose_history_edit.dart';
import '../services/late_dose_recovery.dart';

/// Sheet for one dose already in the history: what it says now, and the ways to
/// put it right.
class DoseEditSheet {
  const DoseEditSheet._();

  /// Resolves the correction chosen, or null when the person closes it.
  static Future<DoseEdit?> show(
      BuildContext context, MedicineLog log, EnhancedMedicine medicine) {
    return AppBottomSheet.show<DoseEdit>(
      context,
      title: 'Change this dose',
      icon: Symbols.pill_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (ctx) => DoseEditBody(
        log: log,
        medicine: medicine,
        onEdit: (e) => Navigator.of(ctx).pop(e),
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class DoseEditBody extends StatefulWidget {
  const DoseEditBody({
    super.key,
    required this.log,
    required this.medicine,
    required this.onEdit,
    required this.onClose,
  });

  final MedicineLog log;
  final EnhancedMedicine medicine;
  final ValueChanged<DoseEdit> onEdit;
  final VoidCallback onClose;

  @override
  State<DoseEditBody> createState() => _DoseEditBodyState();
}

class _DoseEditBodyState extends State<DoseEditBody> {
  bool _futureTime = false;

  MedicineLog get log => widget.log;

  /// "Taken at 8:10 AM", "Skipped", "Missed".
  String get _now {
    final label = switch ((log.countsAsTaken, log.isSkipped)) {
      (true, _) => log.actionTime == null
          ? 'Taken'
          : 'Taken at ${DateFormats.time.format(log.actionTime!)}',
      (_, true) => 'Skipped',
      _ => 'Missed',
    };
    return 'Now: $label';
  }

  Future<void> _pickTime() async {
    final slot = log.scheduledTime;
    final initial = log.actionTime ?? slot;
    final picked = await AppTimePicker.show(
      context,
      initial: TimeOfDay(hour: initial.hour, minute: initial.minute),
      accent: AppColorsExt.of(context).medicine,
      title: 'Taken at',
    );
    if (picked == null) return;
    final at = LateDoseRecovery.takenAtFor(
        scheduled: slot, hour: picked.hour, minute: picked.minute);
    if (at == null) {
      setState(() => _futureTime = true);
      return;
    }
    widget.onEdit(DoseEdit(DoseCorrection.tookAt, at: at));
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final slot = log.scheduledTime;
    final when = '${DateFormats.dayLabel(slot)} · ${DateFormats.time.format(slot)}';
    final options = DoseHistoryEdit.optionsFor(log);
    final schedule = widget.medicine.schedule;
    final scheduled =
        !(schedule.isPRN || schedule.frequencyType == FrequencyType.asNeeded);

    Widget button(DoseCorrection c) {
      switch (c) {
        case DoseCorrection.tookAtSlot:
          return AppButton(
            label: 'I took it at ${DateFormats.time.format(slot)}',
            leadingIcon: Symbols.check_rounded,
            fullWidth: true,
            onPressed: () => widget.onEdit(const DoseEdit(DoseCorrection.tookAtSlot)),
          );
        case DoseCorrection.tookAt:
          return AppButton(
            label: log.countsAsTaken ? 'Change the time taken' : 'I took it at…',
            leadingIcon: Symbols.schedule_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: _pickTime,
          );
        case DoseCorrection.didNotTake:
          return AppButton(
            label: 'I did not take it',
            leadingIcon: Symbols.close_rounded,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () => widget.onEdit(const DoseEdit(DoseCorrection.didNotTake)),
          );
        case DoseCorrection.remove:
          return AppButton(
            label: 'Remove this entry',
            leadingIcon: Symbols.delete_rounded,
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => widget.onEdit(const DoseEdit(DoseCorrection.remove)),
          );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.medicine.name,
            style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: 2),
        Text('Due $when',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: 2),
        Text(_now, style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
        const SizedBox(height: AppSpacing.lg),
        for (final c in options) ...[
          button(c),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_futureTime) ...[
          Text('That time has not happened yet.',
              style: tt.bodySmall?.copyWith(color: ext.mark(ext.error))),
          const SizedBox(height: AppSpacing.sm),
        ],
        // Only a scheduled dose can come back: an as-needed entry has no slot to
        // be missed.
        if (options.contains(DoseCorrection.remove) && scheduled) ...[
          Text(
            'A dose that was due comes back as missed if you remove its entry.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Close',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onClose,
        ),
      ],
    );
  }
}
