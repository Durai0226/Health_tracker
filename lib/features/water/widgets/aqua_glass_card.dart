import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/design/app_design.dart';
import '../theme/aqua_theme.dart';

/// Glassmorphism card with dynamic beverage-based styling
class AquaGlassCard extends StatelessWidget {
  final Widget child;
  final String? beverageId;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool showGradientBorder;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const AquaGlassCard({
    super.key,
    required this.child,
    this.beverageId,
    this.padding,
    this.margin,
    this.borderRadius = AquaTheme.radiusMedium,
    this.showGradientBorder = false,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    // Calm Clarity: flat opaque surface (no BackdropFilter/glass), and the same
    // surface/outline/shadow triple `AppCard` paints.
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AquaTheme.spacingM),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: ext.isDark ? Border.all(color: ext.outline, width: 1) : null,
        boxShadow: AppShadows.card(context),
      ),
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

/// Gradient border decoration
class GradientBoxBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBoxBorder({
    required this.gradient,
    this.width = 1.0,
  });

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final RRect rrect = borderRadius != null
        ? borderRadius.toRRect(rect).deflate(width / 2)
        : RRect.fromRectAndRadius(rect.deflate(width / 2), Radius.zero);

    canvas.drawRRect(rrect, paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}

/// Section header with icon and optional action
class AquaSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onAction;
  final String? beverageId;

  const AquaSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionText,
    this.onAction,
    this.beverageId,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AquaTheme.spacingM,
        vertical: AquaTheme.spacingS,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ext.water.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(
                icon,
                color: ext.water.onContainer,
                size: 16,
              ),
            ),
            const SizedBox(width: AquaTheme.spacingS),
          ],
          // The title used to be unflexed next to a Spacer, so a long section
          // name ("Today's Log", "More Features") plus the trailing action ran
          // straight off the row on a 320pt phone — 48px over at default text
          // size. Expanded takes the place of the Spacer: it still pins the
          // action flush right, but now the title is the part that gives.
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: ext.textPrimary,
              ),
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              // A bare text+chevron link is only ~17pt tall — under even the
              // WCAG 2.2 24pt floor, let alone Apple's 44pt. Reserve a 44pt
              // hit box without moving the label.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionText!,
                        style: Theme.of(context).textTheme.labelMedium!.copyWith(
                          color: ext.mark(ext.water),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Symbols.arrow_forward_ios_rounded,
                        size: 12,
                        color: ext.mark(ext.water),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stat card with icon, value and label
class AquaStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? beverageId;
  final VoidCallback? onTap;

  const AquaStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.beverageId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AquaTheme.spacingM),
        decoration: BoxDecoration(
          color: ext.water.container,
          borderRadius: AppRadius.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ext.water.onContainer, size: 20),
            const SizedBox(height: AquaTheme.spacingS),
            // `onContainer` on `container` is the AA-verified pair. The value
            // used to be `beverage.primary` drawn on a 10%-tint of itself —
            // cyan #06B6D4 on #E6F8FC measures 2.24:1, and milk's #FAFAFA on
            // its own tint 1.03:1.
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: ext.water.onContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: ext.water.onContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Streak badge widget
class AquaStreakBadge extends StatelessWidget {
  final int streak;
  final bool isCompact;

  /// Grace days still in hand this week — the user's "shield".
  ///
  /// [StreakEngine] has always forgiven one missed day per rolling week, and
  /// the UI has always hidden that: the number simply didn't drop, and the user
  /// never learned they had a safety net. The whole retention benefit of
  /// forgiveness comes from knowing about it *before* the miss (Duolingo's
  /// streak freeze: +3.3% D14, and their explicit finding is that a freeze the
  /// user has to discover after the fact does nothing — they aren't in the app
  /// to discover it).
  final int gracesRemaining;

  const AquaStreakBadge({
    super.key,
    required this.streak,
    this.isCompact = false,
    this.gracesRemaining = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // Same defect as DS-01/DS-02, in a pill: an orange gradient
    // (#FF9500 -> #FF5E3A) with a same-hue glow, white w700 text on it at
    // 2.21:1 and `Colors.white70` at 1.61:1. The amber `container`/
    // `onContainer` pair carries the same "streak" heat and is AA-verified.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: ext.reminders.container,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.local_fire_department_rounded,
              size: 14,
              color: ext.reminders.onContainer,
              applyTextScaling: false),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: (isCompact ? tt.titleSmall : tt.titleMedium)?.copyWith(
              color: ext.reminders.onContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!isCompact) ...[
            const SizedBox(width: 2),
            Text(
              'days',
              style: tt.labelSmall?.copyWith(color: ext.reminders.onContainer),
            ),
          ],
          if (gracesRemaining > 0) ...[
            SizedBox(width: isCompact ? 4 : 6),
            // A shield the user can see. Not decoration: it is the difference
            // between "one bad day and I lose everything" and "one bad day is
            // already covered".
            Icon(Symbols.shield_rounded,
                size: isCompact ? 12 : 14,
                color: ext.reminders.onContainer,
                applyTextScaling: false),
          ],
        ],
      ),
    );
  }
}
