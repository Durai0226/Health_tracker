import 'dart:math' as math;

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

  /// Hero treatment for a top-level CTA (onboarding / primary flow). Keeps the
  /// fill a pure, FRESH accent (brightens to `base` where AA allows) and floats
  /// it with a same-hue glow + hairline top gloss. Default off → every other
  /// button in the app is unchanged.
  final bool emphasized;

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
    this.emphasized = false,
  });

  double get _height => switch (size) {
        AppButtonSize.sm => 44, // Apple/Material minimum tap target
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

    // ── Emphasized CTA (design-panel winner: "fresh solid teal, floated") ──
    final emph = emphasized && variant == AppButtonVariant.primary && !disabled;
    // In light mode the primary fill is the darkened `strong` (AA-safe but muddy).
    // Brighten to the vivid `base` — but ONLY where white still clears the
    // large/bold AA floor (3:1), so cyan/amber/green accents fall back safely.
    if (emph && !ext.isDark && _wcagContrast(s.base, fg) >= 3.0) {
      bg = s.base;
    }
    final radius = emph ? AppRadius.brLg : AppRadius.brMd;

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
              // A button is a FIXED-HEIGHT container, so at large Dynamic Type
              // a label that no longer fits its row must scale down rather than
              // clip to "+ Log so…". scaleDown never enlarges, so a label that
              // already fits renders exactly as before; the ellipsis stays as
              // the last-resort guard for genuinely long labels.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                          color: fg,
                          fontWeight: emph ? FontWeight.w700 : null)),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: fg),
              ],
            ],
          );

    if (emph) {
      final tap = loading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed?.call();
            };
      return SizedBox(
        height: _height,
        width: fullWidth ? double.infinity : null,
        child: DecoratedBox(
          // Same-hue teal "float" — depth without a muddy dark gradient. On dark
          // surfaces a colored glow reads as mud, so lift with a soft ambient.
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: ext.isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: bg.withOpacity(0.34),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: radius),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                // Hairline "lit-from-above" gloss confined to the top — only
                // LIGHTENS the top edge (above the centered label), never
                // darkens below the fill, so contrast never regresses.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_lighten(bg, 0.09), bg, bg],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
              child: InkWell(
                onTap: tap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      );
    }

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

// WCAG relative luminance + contrast — used to decide when a primary CTA may
// safely brighten to its vivid `base` fill under white text.
double _relLum(Color c) {
  double lin(double v) {
    v /= 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin(c.red.toDouble()) +
      0.7152 * lin(c.green.toDouble()) +
      0.0722 * lin(c.blue.toDouble());
}

double _wcagContrast(Color a, Color b) {
  final la = _relLum(a);
  final lb = _relLum(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Color _lighten(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;

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
        // Disable the default shared hero tag: multiple AppFab screens are kept
        // alive in the shell's IndexedStack, so a shared tag throws "multiple
        // heroes share the same tag" on route pushes. We don't need FAB flights.
        heroTag: null,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        child: Icon(icon),
      );
    }
    return FloatingActionButton.extended(
      onPressed: tap,
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 2,
      heroTag: null,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      icon: Icon(icon),
      label: Text(label!,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
    );
  }
}
