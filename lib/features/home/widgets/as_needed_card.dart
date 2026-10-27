import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../../medication/models/enhanced_medicine.dart';
import '../../medication/services/as_needed_service.dart';
import '../../medication/services/dose_undo.dart';
import '../../medication/services/medicine_storage_service.dart';

/// "Ibuprofen · 3 h ago · 2 of 4 · OK after 2:30 PM" with a one-tap Take, for the
/// medicines taken only when needed. Renders nothing without any.
///
/// It reports the limits set on each medicine and does nothing about them: a dose
/// that is not yet OK asks "log it anyway?" first, and is logged if the answer is
/// yes. Whatever is logged can be undone, stock and all.
class AsNeededCard extends StatelessWidget {
  const AsNeededCard({super.key, this.medicines});

  /// The medicines, when the screen has read them already (any of them: the
  /// as-needed ones are picked out here). Null reads them from the database.
  final List<EnhancedMedicine>? medicines;

  /// How many are listed; the rest are behind the medicines screen.
  static const int maxShown = 3;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MedicineCleanStorageService.revision,
      builder: (context, rev, _) => FutureBuilder<List<AsNeededEntry>>(
        future: AsNeededService.entries(medicines: medicines),
        builder: (context, snap) {
          final entries = snap.data;
          if (entries == null || entries.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _body(context, entries),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, List<AsNeededEntry> entries) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.medicine;
    final shown = entries.take(maxShown).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.medication_liquid_rounded,
                  size: 18, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('As needed',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final e in shown) _row(context, e),
          if (entries.length > maxShown)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('And ${entries.length - maxShown} more in Medicines.',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text('Follow the label and your doctor\'s advice.',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AsNeededEntry e) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final line = e.status.line(
        now: clock.now(), formatTime: (t) => DateFormats.time.format(t));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.medicine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w600)),
                Text(line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Take',
            accent: ext.medicine,
            variant: e.status.allowedNow
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            onPressed: () => _take(context, e),
          ),
        ],
      ),
    );
  }

  Future<void> _take(BuildContext context, AsNeededEntry e) async {
    if (!e.status.allowedNow) {
      final when = DateFormats.time.format(e.status.okFrom!);
      final yes = await ConfirmationBottomSheet.show(
        context: context,
        title: e.status.atLimit ? 'Daily limit reached' : 'A little early',
        message: e.status.atLimit
            ? '${e.medicine.name}: you have reached the most you set for 24 '
                'hours. The next is OK from $when. Log this dose anyway?'
            : '${e.medicine.name}: your gap between doses is not up until $when. '
                'Log this dose anyway?',
        confirmText: 'Log it',
        cancelText: 'Not now',
        icon: Symbols.schedule_rounded,
      );
      if (yes != true || !context.mounted) return;
    }
    final log = await AsNeededService.takeNow(e.medicine);
    if (!context.mounted) return;
    DoseUndo.confirm(context, '${e.medicine.name} taken', log);
  }
}
