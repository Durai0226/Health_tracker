import 'package:flutter/material.dart';
import '../../design/app_design.dart';
import 'app_button.dart';

/// One flat, opaque bottom sheet (no glass). Grab handle + optional accent
/// header + scrollable body. Replaces the blurred glass sheets and the inline
/// confirmation sheet.
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final AccentSwatch? accent;
  final Widget child;

  const AppBottomSheet({
    super.key,
    this.title,
    this.icon,
    this.accent,
    required this.child,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    IconData? icon,
    AccentSwatch? accent,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppBottomSheet(
        title: title,
        icon: icon,
        accent: accent,
        child: builder(ctx),
      ),
    );
  }

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool danger = false,
    IconData? icon,
  }) {
    return show<bool>(
      context,
      title: title,
      icon: icon,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message,
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: ext.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: cancelLabel,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: danger ? AppButtonVariant.danger : AppButtonVariant.primary,
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

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      decoration: BoxDecoration(
        color: ext.surfaceElevated,
        borderRadius: AppRadius.topSheet,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ext.outlineStrong,
                      borderRadius: AppRadius.brFull,
                    ),
                  ),
                ),
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.md),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                                color: s.container, borderRadius: AppRadius.brMd),
                            child: Icon(icon, size: 20, color: s.onContainer),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: Text(title!, style: tt.headlineSmall)),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: ext.outline),
                ],
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
