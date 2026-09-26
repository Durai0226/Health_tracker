import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/app_design.dart';
import 'app/app_bottom_sheet.dart';
import 'app/app_button.dart';

/// The destructive-confirmation sheet — delete account, erase all data, restore
/// a backup, reset a forgotten PIN.
///
/// Now a thin adapter over [AppBottomSheet], which is the point: this was the
/// app's most consequential surface and also its least conformant one. It
/// hand-rolled a sheet that agreed with nothing else on screen —
/// `Color(0xFF1E1E1E)` for the dark surface (the theme's elevated dark surface
/// is `#1E242C`, so it was a visibly different grey from every other sheet), a
/// top radius of 20 against [AppRadius.sheet] 24, `Colors.red.shade400` for
/// danger against `ext.error`, `Theme.of(context).primaryColor` for the
/// non-destructive fill, and raw 18/14pt `TextStyle`s where the type scale has
/// `headlineSmall` / `bodyMedium`.
///
/// The danger red was the measurable one: white on `Colors.red.shade400`
/// (`#EF5350`) is 3.49:1 in both themes, below the 4.5:1 a 13pt button label
/// needs. The token path is 4.83:1 on light. On dark it is 2.77:1 — worse, and
/// not fixable from here: [AppButtonVariant.danger] hardcodes a white
/// foreground instead of pairing `fillBg`/`fillFg`, so all five danger buttons
/// in the app share that defect and it has to be fixed in `app_button.dart`.
///
/// The five call sites are unchanged. Layout follows [AppBottomSheet]'s grammar
/// now, so the title and message are leading-aligned rather than centred, and
/// the icon sits in the header chip rather than in a 56pt circle above the
/// title — for a destructive sheet that chip is tinted with the error swatch's
/// container pair (6.80:1 in both themes), which is what carries the signal.
class ConfirmationBottomSheet {
  /// Show a confirmation sheet for destructive actions.
  ///
  /// The former `confirmColor` parameter is gone: it took a raw [Color], which
  /// cannot be resolved into an accent-aware fill, and no call site passed it.
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    bool isDangerous = false,
  }) {
    final ext = AppColorsExt.of(context);

    return AppBottomSheet.show<bool>(
      context,
      title: title,
      icon: icon,
      // A destructive sheet states itself in its own accent rather than
      // inheriting whichever feature the caller happened to be scoped to.
      accent: isDangerous ? ext.error : null,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: tt.bodyMedium?.copyWith(color: AppColorsExt.of(ctx).textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelText,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: confirmText,
                    variant: isDangerous
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Show delete confirmation
  static Future<bool?> showDelete({
    required BuildContext context,
    required String itemName,
    String? customMessage,
  }) {
    return show(
      context: context,
      title: 'Delete $itemName?',
      message: customMessage ?? 'This action cannot be undone. Are you sure you want to delete this $itemName?',
      confirmText: 'Delete',
      icon: Symbols.delete_rounded,
      isDangerous: true,
    );
  }

  /// Show sign out confirmation
  static Future<bool?> showSignOut({
    required BuildContext context,
  }) {
    return show(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out? Your local data will be preserved.',
      confirmText: 'Sign Out',
      icon: Symbols.logout_rounded,
      isDangerous: false,
    );
  }

  /// Show discard changes confirmation
  static Future<bool?> showDiscardChanges({
    required BuildContext context,
  }) {
    return show(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Are you sure you want to discard them?',
      confirmText: 'Discard',
      icon: Symbols.warning_amber_rounded,
      isDangerous: true,
    );
  }

  /// Show reset confirmation
  static Future<bool?> showReset({
    required BuildContext context,
    required String featureName,
  }) {
    return show(
      context: context,
      title: 'Reset $featureName?',
      message: 'This will reset all $featureName data to default. This action cannot be undone.',
      confirmText: 'Reset',
      icon: Symbols.refresh_rounded,
      isDangerous: true,
    );
  }
}
