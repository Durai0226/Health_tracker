import 'package:flutter/material.dart';
import '../../design/app_design.dart';

/// One calm, compact, non-gradient header for every screen — the antidote to
/// the four legacy header grammars and the double-header hub.
///
/// Use as a box (top of a Column / SliverToBoxAdapter). Optional [greeting]
/// (one place only), [icon] accent chip, [actions], and a [bottom] slot for a
/// segmented control.
class AppHeader extends StatelessWidget {
  final String title;
  final String? greeting;
  final IconData? icon;
  final AccentSwatch? accent;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? bottom;
  final bool safeTop;
  final EdgeInsetsGeometry padding;

  const AppHeader({
    super.key,
    required this.title,
    this.greeting,
    this.icon,
    this.accent,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.safeTop = true,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.sm),
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;

    final row = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: s.container, borderRadius: AppRadius.brMd),
            child: Icon(icon, size: 22, color: s.onContainer),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (greeting != null)
                Text(greeting!,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              Text(title, style: tt.headlineLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    );

    return Padding(
      padding: padding,
      child: SafeArea(
        bottom: false,
        top: safeTop,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            if (bottom != null) ...[const SizedBox(height: AppSpacing.md), bottom!],
          ],
        ),
      ),
    );
  }
}
