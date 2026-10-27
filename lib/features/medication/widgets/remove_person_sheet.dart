import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';

/// What to do with what is recorded for a person being removed.
enum RemovePersonChoice {
  /// The profile goes; their medicines, doses, readings and appointments stay
  /// on this device, under the account holder.
  keepRecords,

  /// The profile goes, and so does everything held for them.
  deleteRecords,
}

/// "Remove Maya?": two honest answers instead of one. Removing a person used to
/// quietly attach all their health records to the account holder, which is right
/// for a profile that was only ever a convenience and wrong for a family member
/// whose medicines and readings should not live on under someone else's name.
class RemovePersonSheet {
  const RemovePersonSheet._();

  static Future<RemovePersonChoice?> show(BuildContext context, {required String name}) {
    return AppBottomSheet.show<RemovePersonChoice>(
      context,
      title: 'Remove $name?',
      icon: Symbols.person_remove_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (ctx) => RemovePersonBody(
        name: name,
        onChoose: (c) => Navigator.of(ctx).pop(c),
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class RemovePersonBody extends StatelessWidget {
  const RemovePersonBody({
    super.key,
    required this.name,
    required this.onChoose,
    required this.onClose,
  });

  final String name;
  final ValueChanged<RemovePersonChoice> onChoose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    Widget option({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required RemovePersonChoice choice,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () => onChoose(choice),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleSmall?.copyWith(
                            color: ext.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
            ]),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Their profile goes either way. What is recorded for $name is yours to decide.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        option(
          icon: Symbols.inventory_2_rounded,
          color: ext.mark(ext.medicine),
          title: 'Remove them, keep the records',
          subtitle: 'Their medicines, doses, readings, weight, mood and appointments '
              'stay on this device, under you.',
          choice: RemovePersonChoice.keepRecords,
        ),
        option(
          icon: Symbols.delete_forever_rounded,
          color: ext.mark(ext.error),
          title: 'Remove them and delete everything',
          subtitle: 'Their medicines, doses, readings, weight, mood and appointments '
              'are deleted, with their reminders. This cannot be undone.',
          choice: RemovePersonChoice.deleteRecords,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: onClose,
        ),
      ],
    );
  }
}
