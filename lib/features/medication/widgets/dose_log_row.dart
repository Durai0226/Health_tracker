import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/medicine_log.dart';

/// One dose in a medicine's history: when it was due and what became of it.
///
/// Tappable when [onTap] is given, so a dose that was written down wrong can be
/// opened and put right.
class DoseLogRow extends StatelessWidget {
  const DoseLogRow({super.key, required this.log, this.onTap});

  final MedicineLog log;
  final VoidCallback? onTap;

  /// "Taken", "Pre-logged", "Skipped", "Missed".
  static String statusLabel(MedicineLog log) => log.isTaken
      ? 'Taken'
      : (log.isPreLogged
          ? 'Pre-logged'
          : (log.isSkipped ? 'Skipped' : 'Missed'));

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final status = statusLabel(log);
    // Status colours must match the medication dashboard exactly: Skipped reads
    // as neutral grey, Missed as amber. They used to be swapped between the two
    // surfaces (amber = "Missed" on the dashboard, amber = "Skipped" here),
    // which is the sharpest comprehension failure for adherence data. A null
    // swatch means "no accent" — the neutral grey used for Skipped.
    final swatch = log.isTaken
        ? ext.success
        : (log.isPreLogged ? ext.info : (log.isSkipped ? null : ext.warning));
    final statusDot = swatch?.base ?? ext.textTertiary;
    final statusBg = swatch?.container ?? ext.textTertiary.withValues(alpha: 0.12);
    final statusFg = swatch?.onContainer ?? ext.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusDot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormats.weekdayDayMonthShort.format(log.scheduledTime),
                    style: tt.labelLarge?.copyWith(color: ext.textPrimary),
                  ),
                  Text(
                    DateFormats.time.format(log.scheduledTime),
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                status,
                style: tt.labelMedium?.copyWith(
                    color: statusFg, fontWeight: FontWeight.w600),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Symbols.chevron_right_rounded,
                  size: 20, color: ext.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}
