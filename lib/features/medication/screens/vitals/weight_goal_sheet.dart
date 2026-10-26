import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/design/app_design.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../services/weight_goal.dart';

/// Set or clear the goal weight. Resolves `true` when it changed.
class WeightGoalSheet {
  const WeightGoalSheet._();

  static Future<bool> show(
    BuildContext context, {
    required AccentSwatch accent,
    required bool lb,
  }) async {
    final changed = await AppBottomSheet.show<bool>(
      context,
      title: 'Goal weight',
      icon: Symbols.flag_rounded,
      accent: accent,
      builder: (ctx) => WeightGoalForm(
        accent: accent,
        lb: lb,
        onDone: (c) => Navigator.of(ctx).pop(c),
      ),
    );
    return changed == true;
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class WeightGoalForm extends StatefulWidget {
  const WeightGoalForm({
    super.key,
    required this.accent,
    required this.lb,
    required this.onDone,
  });

  final AccentSwatch accent;
  final bool lb;
  final ValueChanged<bool> onDone;

  @override
  State<WeightGoalForm> createState() => _WeightGoalFormState();
}

class _WeightGoalFormState extends State<WeightGoalForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final kg = WeightGoal.get();
    final shown = kg == null ? '' : (widget.lb ? kg * 2.2046226218 : kg).toStringAsFixed(1);
    _controller = TextEditingController(text: shown)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _kg => WeightGoal.parse(_controller.text, lb: widget.lb);

  Future<void> _save() async {
    final kg = _kg;
    if (kg == null) return;
    await WeightGoal.set(kg);
    widget.onDone(true);
  }

  Future<void> _clear() async {
    await WeightGoal.clear();
    widget.onDone(true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final unit = widget.lb ? 'lb' : 'kg';
    final typed = _controller.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The Weight screen uses it to say roughly when your trend reaches it. '
          'It is stored on this phone only.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _controller,
          label: 'Goal weight ($unit)',
          hint: widget.lb ? '154.0' : '70.0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          accent: widget.accent,
        ),
        if (typed && _kg == null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Enter a weight between 20 and 400 kg.',
              style: tt.bodySmall?.copyWith(color: ext.error.strong)),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          fullWidth: true,
          accent: widget.accent,
          onPressed: _kg == null ? null : _save,
        ),
        if (WeightGoal.get() != null) ...[
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Remove goal',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            accent: widget.accent,
            onPressed: _clear,
          ),
        ],
      ],
    );
  }
}
