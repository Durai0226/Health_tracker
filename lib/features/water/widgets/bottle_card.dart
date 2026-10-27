import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/bottle_mode.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Drinking from one bottle: "Finished" or "Half" logs it in one tap, and a line
/// says how many bottles are left of the day. Before a size is set it is a short
/// offer to set one.
class BottleCard extends StatelessWidget {
  const BottleCard({
    super.key,
    required this.accent,
    required this.onSetSize,
    this.bottleMl,
    this.remainingMl,
    this.onFinished,
    this.onHalf,
  });

  final AccentSwatch accent;

  /// The bottle's size, or null when none is set.
  final int? bottleMl;

  /// What is left of the goal; null hides the "to go" line (a fluid limit is not
  /// something to count down bottles towards).
  final int? remainingMl;

  final VoidCallback onSetSize;
  final VoidCallback? onFinished;
  final VoidCallback? onHalf;

  /// The least width each button needs, at normal text size, to sit beside the
  /// other: its icon, its label and its padding.
  static const double minSideBySideWidth = 130;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final size = bottleMl;
    if (size == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.water_bottle_rounded,
                    size: 20, color: ext.mark(accent)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                      'Drink from a bottle? Set its size and log it in one tap.',
                      style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                ),
              ],
            ),
            // Below the sentence, not beside it: beside it the button could not
            // shrink and overflowed at large text on a narrow screen.
            TextButton(
              onPressed: onSetSize,
              style: TextButton.styleFrom(
                  foregroundColor: ext.mark(accent),
                  minimumSize: const Size(0, 44)),
              child: const Text('Set bottle'),
            ),
          ],
        ),
      );
    }
    final toGo = remainingMl == null
        ? null
        : BottleMode.toGo(remainingMl: remainingMl!, bottleMl: size);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.water_bottle_rounded, size: 20, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Your bottle · $size ml',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
              AppIconButton(
                icon: Symbols.edit_rounded,
                filled: false,
                accent: accent,
                tooltip: 'Change bottle size',
                onPressed: onSetSize,
              ),
            ],
          ),
          if (toGo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(toGo,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
            ),
          // Side by side while each has room for its icon and label; one above
          // the other once large text or a narrow screen takes that away (the
          // pair overflowed by 70pt at 320pt and twice the text size).
          LayoutBuilder(builder: (context, c) {
            final finished = AppButton(
              label: 'Finished',
              leadingIcon: Symbols.check_rounded,
              accent: accent,
              fullWidth: true,
              onPressed: onFinished,
            );
            final half = AppButton(
              label: 'Half',
              leadingIcon: Symbols.water_medium_rounded,
              accent: accent,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: onHalf,
            );
            final scale = MediaQuery.textScalerOf(context).scale(1.0);
            final each = (c.maxWidth - AppSpacing.sm) / 2;
            if (each < minSideBySideWidth * scale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [finished, const SizedBox(height: AppSpacing.sm), half],
              );
            }
            return Row(
              children: [
                Expanded(child: finished),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: half),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// The bottle's size, set with a stepper; "Remove" forgets it.
class BottleSizeSheet extends StatefulWidget {
  const BottleSizeSheet({super.key, required this.accent, this.initialMl});

  final AccentSwatch accent;
  final int? initialMl;

  /// The new size; `0` means "forget it"; null when the sheet was dismissed.
  static Future<int?> show(
    BuildContext context, {
    required AccentSwatch accent,
    int? initialMl,
  }) =>
      AppBottomSheet.show<int>(
        context,
        title: 'Your bottle',
        icon: Symbols.water_bottle_rounded,
        accent: accent,
        builder: (_) => BottleSizeSheet(accent: accent, initialMl: initialMl),
      );

  @override
  State<BottleSizeSheet> createState() => _BottleSizeSheetState();
}

class _BottleSizeSheetState extends State<BottleSizeSheet> {
  late int _ml = widget.initialMl ?? BottleMode.defaultBottleMl;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How much does it hold? "Finished" then logs that much, and "Half" '
            'logs half of it.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        AppStepper(
          value: '$_ml ml',
          accent: widget.accent,
          decrementTooltip: 'Smaller bottle',
          incrementTooltip: 'Larger bottle',
          onDecrement: _ml > BottleMode.minBottleMl
              ? () => setState(() => _ml -= BottleMode.stepMl)
              : null,
          onIncrement: _ml < BottleMode.maxBottleMl
              ? () => setState(() => _ml += BottleMode.stepMl)
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          leadingIcon: Symbols.check_rounded,
          accent: widget.accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: () => Navigator.pop(context, _ml),
        ),
        if (widget.initialMl != null)
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            style: TextButton.styleFrom(
                foregroundColor: ext.textSecondary,
                minimumSize: const Size(0, 44)),
            child: const Text('Remove my bottle'),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
