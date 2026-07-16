import 'package:flutter/material.dart';
import '../../design/app_design.dart';

/// Flat scaffold on the token background.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool safeTop;

  const AppScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.safeTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Scaffold(
      backgroundColor: ext.background,
      extendBody: extendBody,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: safeTop ? SafeArea(bottom: false, child: body) : body,
    );
  }
}

/// Accent icon-chip + title + optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AccentSwatch? accent;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, size: 16, color: s.onContainer),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title, style: tt.headlineMedium)),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!,
                  style: tt.labelLarge?.copyWith(color: ext.mark(s))),
            ),
        ],
      ),
    );
  }
}

/// Small pill — filter/status/selectable chip.
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final AccentSwatch? accent;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    final bg = selected ? s.container : ext.surfaceVariant;
    final fg = selected ? s.onContainer : ext.textSecondary;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brFull),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: tt.labelMedium?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Count pill (nav badges, "3 today").
class CountBadge extends StatelessWidget {
  final int count;
  final AccentSwatch? accent;
  const CountBadge({super.key, required this.count, this.accent});

  @override
  Widget build(BuildContext context) {
    final s = accent ?? AccentScope.swatchOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: s.container, borderRadius: AppRadius.brFull),
      child: Text(
        '$count',
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: s.onContainer, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Calm empty state — icon + title + optional message/action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final AccentSwatch? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: s.container, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: s.onContainer),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: tt.headlineSmall, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message!,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings/action row: accent icon chip + title + subtitle + trailing.
class AppListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final AccentSwatch? accent;
  final Color? iconColor;
  final Color? titleColor;

  const AppListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.accent,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;
    final ic = iconColor ?? s.onContainer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? s.base).withOpacity(0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, size: 20, color: ic),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleLarge
                            ?.copyWith(color: titleColor ?? ext.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading placeholder.
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  const LoadingSkeleton.card({super.key})
      : width = double.infinity,
        height = 96,
        radius = AppRadius.card;

  const LoadingSkeleton.line({super.key, this.width})
      : height = 14,
        radius = AppRadius.sm;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(ext.surfaceVariant, ext.outline, _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
