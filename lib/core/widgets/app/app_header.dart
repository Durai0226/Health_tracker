import 'package:flutter/material.dart';
import '../../design/app_design.dart';

/// How the header arranges its chrome relative to its title.
enum HeaderLayout {
  /// Stack when a [AppHeader.greeting] is present, otherwise sit inline.
  auto,

  /// Single row: leading · title · actions. Correct for a short literal title
  /// with at most a back button and a couple of icon actions.
  inline,

  /// Two rows: chrome on top, then greeting + title across the FULL width.
  ///
  /// This is the Material 3 medium/large top-app-bar and Apple large-title
  /// structure. Use it whenever the title has to share the row with anything
  /// text-bearing (a profile chip, a streak pill), because those size to their
  /// content and leave the title whatever is left.
  stacked,
}

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
  final HeaderLayout layout;
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
    this.layout = HeaderLayout.auto,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.sm),
  });

  /// A greeting must NEVER wrap.
  ///
  /// This is the bug that shipped: with a "Me" profile chip, a streak pill and
  /// a settings button all sizing to their content, the title column was left
  /// ~114 of 320pt, and `Good evening · Wednesday, Aug 12` — which needs ~215pt
  /// — soft-wrapped to three lines. A soft wrap is not an overflow, so nothing
  /// threw and the responsive harness passed. One clamp makes that impossible
  /// regardless of how starved the column gets.
  Widget _greetingText(TextTheme tt, AppColorsExt ext) => Text(
        greeting!,
        style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  /// Shrink-to-fit rather than ellipsize. With a back button, an icon badge and
  /// 2-3 actions there can be under 100pt left for the title, which truncated
  /// real titles to "Wei…" / "Blood s…" / "Family & careg…". scaleDown never
  /// enlarges, so short titles and the stacked layout are unaffected.
  Widget _titleText(TextTheme tt) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: tt.headlineLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      );

  /// [leading] sits in a `Row` as a non-flex child, so it is handed unbounded
  /// main-axis constraints and `AppChip`'s own `Flexible` + ellipsis never
  /// engages. A user-entered dependent name ("Grandmother Elizabeth") therefore
  /// grew without limit and overflowed for real. Cap it so the chip ellipsizes.
  Widget _boundedLeading(double maxWidth) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth * 0.4),
        child: leading!,
      );

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;

    final stacked = switch (layout) {
      HeaderLayout.stacked => true,
      HeaderLayout.inline => false,
      HeaderLayout.auto => greeting != null,
    };

    Widget badge() => Container(
          padding: const EdgeInsets.all(9),
          decoration:
              BoxDecoration(color: s.container, borderRadius: AppRadius.brMd),
          child: Icon(icon, size: 22, color: s.onContainer),
        );

    // Chrome on its own row, then the title across the full width. Nothing
    // competes for horizontal space, so the title cannot be starved and the
    // greeting cannot be squeezed into a three-line block.
    Widget buildStacked(double maxWidth) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Skipped entirely when there is no chrome, so a greeting-only
            // header never renders an empty row plus its gap.
            if (leading != null || actions.isNotEmpty || icon != null) ...[
              Row(
                children: [
                  if (leading != null) _boundedLeading(maxWidth),
                  if (icon != null) ...[
                    if (leading != null) const SizedBox(width: 8),
                    badge(),
                  ],
                  const Spacer(),
                  for (final a in actions) ...[const SizedBox(width: 8), a],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (greeting != null) _greetingText(tt, ext),
            _titleText(tt),
          ],
        );

    // On a narrow phone the fixed chrome (back button + icon badge + up to
    // three actions) can consume ~260 of 320pt, leaving the title so little
    // room that shrink-to-fit renders it at half size — legible-ish, but ugly.
    // The icon badge is decorative, so it is the first thing to give way; the
    // title is the one thing the user actually needs.
    Widget buildInline(double maxWidth) {
      // A back button is 44pt and an icon action 44pt, both plus an 8pt gap.
      // The old estimate used a flat 52 for `leading` too, which is right for a
      // back arrow but ~40% short for a text-bearing chip — chips are the very
      // thing that starve the title. Inline mode is now reserved for headers
      // with no greeting, but an honest constant costs nothing.
      final reserved =
          (leading != null ? 52.0 : 0.0) + actions.length * 52.0;
      final badgeWidth = icon != null ? 52.0 : 0.0;
      final showBadge =
          icon != null && (maxWidth - reserved - badgeWidth) >= 110.0;

      return Row(
        children: [
          if (leading != null) ...[
            _boundedLeading(maxWidth),
            const SizedBox(width: 8),
          ],
          if (showBadge) ...[badge(), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (greeting != null) _greetingText(tt, ext),
                _titleText(tt),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      );
    }

    return Padding(
      padding: padding,
      child: SafeArea(
        bottom: false,
        top: safeTop,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              stacked
                  ? buildStacked(constraints.maxWidth)
                  : buildInline(constraints.maxWidth),
              if (bottom != null) ...[
                const SizedBox(height: AppSpacing.md),
                bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
