import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../services/wind_down_link.dart';

/// "Wind down": the one-tap routine, offered on the Sleep screen at any time of day.
/// It never starts by itself; the reminder only opens the screen that asks.
class WindDownTile extends StatelessWidget {
  const WindDownTile({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ext.sleep.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Symbols.air_rounded,
                size: 22, color: ext.sleep.onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wind down', style: tt.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '4-7-8 breathing, then ${WindDownRoutine.soundMinutes} '
                  'minutes of a low sound',
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Start',
            size: AppButtonSize.sm,
            variant: AppButtonVariant.tonal,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
