import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';

import '../models/cycle_phase.dart';
import '../services/period_service.dart';
import '../theme/period_theme.dart';
import '../widgets/log_today_sheet.dart';
import '../widgets/period_calendar_heatmap.dart';

/// Month heatmap of logged flow + symptoms, with predicted period + fertile
/// window overlays. Tapping a day opens the log sheet.
class PeriodCalendarScreen extends StatefulWidget {
  const PeriodCalendarScreen({super.key});

  @override
  State<PeriodCalendarScreen> createState() => _PeriodCalendarScreenState();
}

class _PeriodCalendarScreenState extends State<PeriodCalendarScreen> {
  late DateTime _month;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December' //
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.period,
      child: AppScaffold(
        safeTop: true,
        body: ValueListenableBuilder(
          valueListenable: PeriodService.listenToDays(),
          builder: (context, _, _) => _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final prediction = PeriodService.getPrediction();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Symbols.arrow_back_rounded, size: 18),
              color: ext.textPrimary,
            ),
            Expanded(child: Text('Calendar', style: tt.headlineMedium)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton(
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Symbols.chevron_left_rounded),
              color: ext.textPrimary,
            ),
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: tt.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Symbols.chevron_right_rounded),
              color: ext.textPrimary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PeriodCalendarHeatmap(
          month: _month,
          days: PeriodService.days,
          phaseOf: PeriodService.phaseOn,
          predictedWindowStart: prediction.windowStart,
          predictedWindowEnd: prediction.windowEnd,
          fertileStart: prediction.fertileStart,
          fertileEnd: prediction.fertileEnd,
          onTapDay: (date) async {
            await LogTodaySheet.show(context, date: date);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _legend(context),
        const SizedBox(height: AppSpacing.xl),
        const SafetyDisclaimerBar(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _legend(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    Widget item(Color color, String label, {bool outline = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: outline ? null : color,
                borderRadius: AppRadius.brSm,
                border: outline ? Border.all(color: color, width: 1.4) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          ],
        );

    return AppCard(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          item(ext.mark(PeriodTheme.phaseSwatch(ext, CyclePhase.menstrual)),
              'Period'),
          item(PeriodTheme.fertileSwatch(ext).container, 'Fertile window'),
          item(ext.mark(PeriodTheme.phaseSwatch(ext, CyclePhase.menstrual)),
              'Predicted',
              outline: true),
          item(ext.mark(ext.focus), 'Symptoms logged'),
        ],
      ),
    );
  }
}
