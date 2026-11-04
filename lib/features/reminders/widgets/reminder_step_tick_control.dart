import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/reminder_step_targets.dart';

/// Ask how many steps today this reminder should wait for before it ticks itself
/// off.
///
/// The answer is a record so that "Don't tick it off for me" (a null count) is
/// distinguishable from the sheet being dismissed (a null record): the first
/// clears a stored choice, the second changes nothing.
Future<({int? steps})?> chooseReminderStepTarget(
  BuildContext context, {
  required int? current,
  required AccentSwatch accent,
}) =>
    AppBottomSheet.show<({int? steps})>(
      context,
      title: 'Tick off by itself',
      icon: Symbols.directions_walk_rounded,
      accent: accent,
      builder: (sheetCtx) {
        final selected = ReminderStepTargets.isKnown(current) ? current : null;
        void pick(int? steps) => Navigator.of(sheetCtx).pop((steps: steps));

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListTile(
              icon: selected == null
                  ? Symbols.check_circle_rounded
                  : Symbols.radio_button_unchecked_rounded,
              title: "Don't tick it off for me",
              subtitle: 'Only you mark it done',
              accent: accent,
              onTap: () => pick(null),
              trailing: const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final steps in ReminderStepTargets.options) ...[
              AppListTile(
                icon: selected == steps
                    ? Symbols.check_circle_rounded
                    : Symbols.directions_walk_rounded,
                title: 'When I reach ${ReminderStepTargets.labelFor(steps)}',
                accent: accent,
                onTap: () => pick(steps),
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );

/// The form row: what the reminder waits for, and a tap to change it.
class ReminderStepTickControl extends StatelessWidget {
  const ReminderStepTickControl({
    super.key,
    required this.steps,
    required this.onChanged,
    required this.accent,
  });

  final int? steps;
  final ValueChanged<int?> onChanged;
  final AccentSwatch accent;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final on = ReminderStepTargets.isKnown(steps);

    return AppCard(
      onTap: () async {
        final choice =
            await chooseReminderStepTarget(context, current: steps, accent: accent);
        if (choice != null) onChanged(choice.steps);
      },
      child: Row(children: [
        Icon(Symbols.directions_walk_rounded,
            color: on ? ext.mark(accent) : ext.textTertiary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                on
                    ? 'When I reach ${ReminderStepTargets.labelFor(steps!)}'
                    : "Don't tick it off for me",
                style: tt.bodyLarge?.copyWith(color: ext.textPrimary),
              ),
              Text(
                'Marks it done once it is due and today\'s steps reach this. '
                'A reminder is still sent at its time.',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
            ],
          ),
        ),
        Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
      ]),
    );
  }
}
