import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../design/app_design.dart';

/// Semantic toast variants. Each maps to an [AppColorsExt] accent + status glyph.
enum AppToastVariant { success, info, warning, error }

/// An optional trailing action on a toast (e.g. "Undo").
class AppToastAction {
  final String label;
  final VoidCallback onPressed;
  const AppToastAction({required this.label, required this.onPressed});
}

/// Show a flat "Calm Clarity" toast — an elevated surface with a hairline
/// outline + soft shadow, a leading status badge, a message (optional title),
/// and an optional text action. Replaces raw Material `SnackBar`s.
///
/// Behaviour (research-backed): never stacks (hides the current one first),
/// auto-dismisses on a variant-appropriate timer, is swipe/tap dismissible,
/// announces politely to screen readers (inherited from SnackBar's live region),
/// and always sets `persist: false` so an action toast can't pin open forever.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastVariant variant = AppToastVariant.success,
  String? title,
  AppToastAction? action,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar(); // M3: toasts should not stack
  _haptic(variant);
  final dur = duration ?? _defaultDuration(variant, action != null);
  messenger.showSnackBar(
    SnackBar(
      content: _AppToastCard(
        message: message,
        variant: variant,
        title: title,
        action: action,
        onHide: messenger.hideCurrentSnackBar,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      duration: dur,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.sm),
      padding: EdgeInsets.zero,
      // This SDK's SnackBar pins action-toasts open unless persist is false.
      // (Our action lives inside the content, so there is no SnackBarAction, but
      // stay explicit so the guarantee is central, not per-call.)
      persist: false,
    ),
  );
}

/// Convenience wrappers.
extension AppToastX on BuildContext {
  void toastSuccess(String message, {String? title, AppToastAction? action}) =>
      showAppToast(this, message,
          variant: AppToastVariant.success, title: title, action: action);
  void toastError(String message, {String? title, AppToastAction? action}) =>
      showAppToast(this, message,
          variant: AppToastVariant.error, title: title, action: action);
  void toastInfo(String message, {String? title, AppToastAction? action}) =>
      showAppToast(this, message,
          variant: AppToastVariant.info, title: title, action: action);
  void toastWarning(String message, {String? title, AppToastAction? action}) =>
      showAppToast(this, message,
          variant: AppToastVariant.warning, title: title, action: action);
}

Duration _defaultDuration(AppToastVariant v, bool hasAction) {
  // WCAG 2.2.1: give actionable toasts enough time to find + hit the action.
  if (hasAction) return const Duration(seconds: 7);
  switch (v) {
    case AppToastVariant.success:
      return const Duration(seconds: 3);
    case AppToastVariant.info:
      return const Duration(milliseconds: 3500);
    case AppToastVariant.warning:
      return const Duration(seconds: 4);
    case AppToastVariant.error:
      return const Duration(seconds: 6);
  }
}

void _haptic(AppToastVariant v) {
  switch (v) {
    case AppToastVariant.success:
      HapticFeedback.lightImpact();
      break;
    case AppToastVariant.info:
      HapticFeedback.selectionClick();
      break;
    case AppToastVariant.warning:
      HapticFeedback.mediumImpact();
      break;
    case AppToastVariant.error:
      HapticFeedback.heavyImpact();
      break;
  }
}

AccentSwatch _swatchFor(AppColorsExt ext, AppToastVariant v) {
  switch (v) {
    case AppToastVariant.success:
      return ext.success;
    case AppToastVariant.info:
      return ext.info;
    case AppToastVariant.warning:
      return ext.warning;
    case AppToastVariant.error:
      return ext.error;
  }
}

IconData _iconFor(AppToastVariant v) {
  switch (v) {
    case AppToastVariant.success:
      return Symbols.check_circle_rounded;
    case AppToastVariant.info:
      return Symbols.info_rounded;
    case AppToastVariant.warning:
      return Symbols.warning_rounded;
    case AppToastVariant.error:
      return Symbols.error_rounded;
  }
}

class _AppToastCard extends StatelessWidget {
  final String message;
  final String? title;
  final AppToastVariant variant;
  final AppToastAction? action;
  final VoidCallback onHide;

  const _AppToastCard({
    required this.message,
    required this.variant,
    required this.onHide,
    this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _swatchFor(ext, variant);
    final glyph = ext.mark(swatch);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: ext.surfaceElevated,
            borderRadius: AppRadius.brCard,
            border: Border.all(color: ext.outline),
            boxShadow: AppShadows.elevated(context),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: swatch.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(_iconFor(variant), size: 24, color: glyph),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null && title!.isNotEmpty) ...[
                      Text(
                        title!,
                        style: tt.labelLarge?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      message,
                      style: tt.bodyMedium?.copyWith(
                          color: (title != null && title!.isNotEmpty)
                              ? ext.textSecondary
                              : ext.textPrimary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () {
                    onHide();
                    action!.onPressed();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: glyph,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(action!.label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
