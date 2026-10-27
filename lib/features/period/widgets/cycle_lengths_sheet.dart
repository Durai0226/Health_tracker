import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/period_settings.dart';
import '../services/period_service.dart';

/// Set the lengths the cycle predictions start from.
///
/// They were 28, 5 and 14 for everyone with nowhere to change them, which suits
/// someone whose cycle is not 28 days for exactly as long as the app is still
/// learning. The luteal phase, which places ovulation, applies always; cycle and
/// period length are starting figures that give way to the person's own history
/// after three logged cycles, and the sheet says so.
class CycleLengthsSheet {
  const CycleLengthsSheet._();

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show<void>(
      context,
      title: 'Cycle lengths',
      icon: Symbols.tune_rounded,
      accent: AppColorsExt.of(context).period,
      builder: (ctx) => CycleLengthsForm(onDone: () => Navigator.of(ctx).pop()),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class CycleLengthsForm extends StatefulWidget {
  const CycleLengthsForm({super.key, required this.onDone});

  final VoidCallback onDone;

  static const int minCycle = 21;
  static const int maxCycle = 45;
  static const int minPeriod = 1;
  static const int maxPeriod = 10;
  static const int minLuteal = 10;
  static const int maxLuteal = 16;

  @override
  State<CycleLengthsForm> createState() => _CycleLengthsFormState();
}

class _CycleLengthsFormState extends State<CycleLengthsForm> {
  late int _cycle;
  late int _period;
  late int _luteal;

  @override
  void initState() {
    super.initState();
    final s = PeriodService.getSettings();
    _cycle = s.typicalCycleLength.clamp(
        CycleLengthsForm.minCycle, CycleLengthsForm.maxCycle);
    _period = s.typicalPeriodLength.clamp(
        CycleLengthsForm.minPeriod, CycleLengthsForm.maxPeriod);
    _luteal = s.lutealPhaseLength.clamp(
        CycleLengthsForm.minLuteal, CycleLengthsForm.maxLuteal);
  }

  Future<void> _save() async {
    await PeriodService.saveSettings(PeriodService.getSettings().copyWith(
      typicalCycleLength: _cycle,
      typicalPeriodLength: _period,
      lutealPhaseLength: _luteal,
    ));
    widget.onDone();
  }

  void _reset() {
    const d = PeriodSettings.defaults;
    setState(() {
      _cycle = d.typicalCycleLength;
      _period = d.typicalPeriodLength;
      _luteal = d.lutealPhaseLength;
    });
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required String noun,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          AppStepper(
            value: '$value days',
            valueStyle: tt.headlineMedium,
            decrementTooltip: 'Shorter $noun',
            incrementTooltip: 'Longer $noun',
            accent: ext.period,
            onDecrement: value > min ? () => onChanged(value - 1) : null,
            onIncrement: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Where predictions start. Once you have logged three cycles, '
          '${AppStrings.productName} uses your own history for cycle and period '
          'length instead. The luteal phase always applies: it is how ovulation '
          'is placed.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        _row(context,
            label: 'Typical cycle',
            value: _cycle,
            min: CycleLengthsForm.minCycle,
            max: CycleLengthsForm.maxCycle,
            noun: 'cycle',
            onChanged: (v) => setState(() => _cycle = v)),
        _row(context,
            label: 'Typical period',
            value: _period,
            min: CycleLengthsForm.minPeriod,
            max: CycleLengthsForm.maxPeriod,
            noun: 'period',
            onChanged: (v) => setState(() => _period = v)),
        _row(context,
            label: 'Luteal phase',
            value: _luteal,
            min: CycleLengthsForm.minLuteal,
            max: CycleLengthsForm.maxLuteal,
            noun: 'luteal phase',
            onChanged: (v) => setState(() => _luteal = v)),
        AppButton(label: 'Save', fullWidth: true, accent: ext.period, onPressed: _save),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Reset to 28 / 5 / 14',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: _reset,
        ),
      ],
    );
  }
}
