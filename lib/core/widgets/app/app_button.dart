import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_design.dart';

enum AppButtonVariant { primary, tonal, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// One accent-aware button. Fills use the AA-safe [AppColorsExt.fillBg]/[fillFg]
/// resolver so labels always meet contrast in both themes.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;
  final AccentSwatch? accent;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
    this.accent,
  });

  double get _height => switch (size) {
        AppButtonSize.sm => 40,
        AppButtonSize.md => 48,
        AppButtonSize.lg => 56,
      };

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    final disabled = onPressed == null && !loading;

    late Color bg;
    late Color fg;
    Border? border;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = ext.fillBg(s);
        fg = ext.fillFg(s);
        break;
      case AppButtonVariant.tonal:
        bg = s.container;
        fg = s.onContainer;
        break;
      case AppButtonVariant.secondary:
        bg = ext.surface;
        fg = ext.textPrimary;
        border = Border.all(color: ext.outlineStrong);
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = ext.mark(s);
        break;
      case AppButtonVariant.danger:
        bg = ext.fillBg(ext.error);
        fg = Colors.white;
        break;
    }

    if (disabled) {
      bg = variant == AppButtonVariant.ghost || variant == AppButtonVariant.secondary
          ? bg
          : ext.surfaceVariant;
      fg = ext.textDisabled;
    }

    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelLarge?.copyWith(color: fg)),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: fg),
              ],
            ],
          );

    return SizedBox(
      height: _height,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: bg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: border?.top ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: disabled || loading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Circular/rounded icon button — header actions, gear, +/- steppers.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final AccentSwatch? accent;
  final double size;
  final bool filled;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.accent,
    this.size = 44,
    this.filled = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final bg = filled ? ext.surface : Colors.transparent;
    final fg = ext.mark(s);

    Widget btn = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!.call();
              },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: fg),
        ),
      ),
    );
    if (filled) {
      btn = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadows.resting(context),
        ),
        child: btn,
      );
    }
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Solid FAB (no gradient/glow). Extended when [label] is provided.
class AppFab extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final AccentSwatch? accent;

  const AppFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final bg = ext.fillBg(s);
    final fg = ext.fillFg(s);
    void tap() {
      HapticFeedback.mediumImpact();
      onPressed();
    }

    if (label == null) {
      return FloatingActionButton(
        onPressed: tap,
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        child: Icon(icon),
      );
    }
    return FloatingActionButton.extended(
      onPressed: tap,
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      icon: Icon(icon),
      label: Text(label!,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
    );
  }
}
