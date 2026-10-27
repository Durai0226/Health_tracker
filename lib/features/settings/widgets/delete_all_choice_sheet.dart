import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/delete_all_data.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "Delete all data" when a copy of it is in the cloud: how far to go.
///
/// A plain confirmation could only say "delete" — and with cloud sync on that is
/// a promise the next start breaks, because the sync brings the copy straight
/// back. This asks the one question that matters, and says what each answer
/// leaves behind.
class DeleteAllChoiceSheet {
  const DeleteAllChoiceSheet._();

  /// The scope chosen, or null when the person backed out.
  static Future<DeleteAllScope?> show(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet.show<DeleteAllScope>(
      context,
      title: 'Delete all data?',
      icon: Symbols.delete_forever_rounded,
      accent: ext.error,
      builder: (ctx) => DeleteAllChoiceBody(
        onChoose: (scope) => Navigator.pop(ctx, scope),
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }
}

/// The sheet's content, separate so a test can drive it without a route.
class DeleteAllChoiceBody extends StatelessWidget {
  const DeleteAllChoiceBody({
    super.key,
    required this.onChoose,
    required this.onCancel,
  });

  final ValueChanged<DeleteAllScope> onChoose;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ext = AppColorsExt.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This permanently removes your medicines, water history, focus data '
          'and reminders from this device. It cannot be undone.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Cloud sync is on, so your copy in the cloud would bring all of it back '
          'at the next start. Choose what happens to that copy.',
          style: tt.bodyMedium?.copyWith(color: ext.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Delete here and in the cloud',
          leadingIcon: Symbols.cloud_off_rounded,
          variant: AppButtonVariant.danger,
          fullWidth: true,
          onPressed: () => onChoose(DeleteAllScope.deviceAndCloud),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Delete here, turn sync off',
          leadingIcon: Symbols.delete_rounded,
          variant: AppButtonVariant.secondary,
          fullWidth: true,
          onPressed: () => onChoose(DeleteAllScope.deviceOnly),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.ghost,
          fullWidth: true,
          onPressed: onCancel,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'The cloud copy stays in the first case only if you choose the second. '
          'Another phone signed in to this account would upload its own copy '
          'again.',
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
      ],
    );
  }
}
