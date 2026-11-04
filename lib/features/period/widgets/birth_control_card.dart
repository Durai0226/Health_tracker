import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "Hormonal birth control" on the cycle screen.
///
/// The pill, patch, ring, implant and hormonal IUD can stop ovulation, so a fertile
/// window and an ovulation day counted back from the next period would describe
/// something that may not be happening. With this on they are not estimated, and
/// the card says so. The next-period estimate stays, from the bleeding that is
/// logged.
class BirthControlCard extends StatelessWidget {
  const BirthControlCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final accent = ext.period;

    return AppCard(
      onTap: () {
        HapticService().toggle();
        onChanged(!value);
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Symbols.medication_rounded,
                color: accent.onContainer, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hormonal birth control',
                    style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'No fertile window or ovulation day is estimated.'
                      : 'Turn on if you use the pill, patch, ring, implant or a '
                          'hormonal IUD.',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: (v) {
              HapticService().toggle();
              onChanged(v);
            },
            accent: accent,
          ),
        ],
      ),
    );
  }
}
