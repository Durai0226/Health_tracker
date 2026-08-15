import 'package:flutter/material.dart';
import '../../design/app_design.dart';

/// The one Calm Clarity surface: flat, opaque, soft shadow, token radius.
/// No glass, no gradient. Replaces every legacy card/glass-card.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final List<BoxShadow>? shadow;
  final bool pressEffect;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.gutter),
    this.margin,
    this.radius = AppRadius.card,
    this.onTap,
    this.color,
    this.shadow,
    this.pressEffect = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final br = BorderRadius.circular(widget.radius);

    // The inner container, built once and shared by both branches below.
    final inner = Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color ?? ext.surface,
          borderRadius: br,
          border: ext.isDark ? Border.all(color: ext.outline, width: 1) : null,
          boxShadow: widget.shadow ?? AppShadows.card(context),
        ),
        child: widget.child,
    );

    // Only pay for the implicit animation when the press effect is actually
    // wanted. `AnimatedScale` is a StatefulWidget with its own controller and
    // Ticker — roughly five elements each — and it was built unconditionally
    // across 169 AppCard call sites, including the ones that explicitly turn
    // the press effect off.
    final Widget card = widget.pressEffect
        ? AnimatedScale(
            scale: _pressed ? 0.98 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            child: inner,
          )
        : inner;

    if (widget.onTap == null) return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: card,
    );

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }
}
