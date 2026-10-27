import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../services/drink_notes.dart';

/// Which note was put away.
enum DrinkNoteKind { caffeine, alcohol }

/// "Coffee after 2:30 PM may affect your 10:30 PM bedtime." and "A glass of
/// water alongside helps · + Glass of water", under the gauge for as long as
/// they are true. Renders nothing when neither is.
class DrinkNotesStrip extends StatelessWidget {
  const DrinkNotesStrip({
    super.key,
    this.lateCaffeine,
    this.showChaser = false,
    required this.onAddWater,
    required this.onDismiss,
  });

  final LateCaffeine? lateCaffeine;
  final bool showChaser;
  final VoidCallback onAddWater;
  final ValueChanged<DrinkNoteKind> onDismiss;

  @override
  Widget build(BuildContext context) {
    final caffeine = lateCaffeine;
    if (caffeine == null && !showChaser) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caffeine != null)
            _note(
              context,
              icon: Symbols.bedtime_rounded,
              text: '${caffeine.drink} after '
                  '${DateFormats.time.format(caffeine.cutoff)} may affect your '
                  '${DateFormats.time.format(caffeine.bedtime)} bedtime.',
              kind: DrinkNoteKind.caffeine,
            ),
          if (caffeine != null && showChaser)
            const SizedBox(height: AppSpacing.sm),
          if (showChaser)
            _note(
              context,
              icon: Symbols.local_bar_rounded,
              text: 'A glass of water alongside your drink helps.',
              kind: DrinkNoteKind.alcohol,
              actionLabel: '+ Glass of water',
              onAction: onAddWater,
            ),
        ],
      ),
    );
  }

  Widget _note(
    BuildContext context, {
    required IconData icon,
    required String text,
    required DrinkNoteKind kind,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ext.mark(ext.water)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
                if (actionLabel != null && onAction != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                          foregroundColor: ext.mark(ext.water),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 40),
                          tapTargetSize: MaterialTapTargetSize.padded),
                      child: Text(actionLabel),
                    ),
                  ),
              ],
            ),
          ),
          AppIconButton(
            icon: Symbols.close_rounded,
            filled: false,
            tooltip: 'Dismiss',
            onPressed: () => onDismiss(kind),
          ),
        ],
      ),
    );
  }
}
