import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../services/morning_report_service.dart';

/// "Morning report": last night against your usual, the debt, the body check and
/// at most one suggestion. Until noon, once a day, and renders nothing when there
/// is no night that ended this morning to say anything about.
class MorningReportCard extends StatefulWidget {
  const MorningReportCard({super.key});

  @override
  State<MorningReportCard> createState() => _MorningReportCardState();
}

class _MorningReportCardState extends State<MorningReportCard> {
  Future<void> _dismiss() async {
    await MorningReportService.dismissToday();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final report = MorningReportService.today();
    if (report == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.sleep;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Symbols.wb_twilight_rounded, size: 18, color: ext.mark(accent)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Morning report',
                      style: tt.titleSmall?.copyWith(
                          color: ext.textPrimary, fontWeight: FontWeight.w700)),
                ),
                AppIconButton(
                  icon: Symbols.close_rounded,
                  filled: false,
                  accent: accent,
                  tooltip: 'Dismiss the morning report',
                  onPressed: _dismiss,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final line in report.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(line,
                    style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
              ),
            if (report.suggestion != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                    color: accent.container, borderRadius: AppRadius.brMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Symbols.lightbulb_rounded,
                        size: 18, color: accent.onContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(report.suggestion!,
                          style: tt.bodyMedium?.copyWith(
                              color: accent.onContainer,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
