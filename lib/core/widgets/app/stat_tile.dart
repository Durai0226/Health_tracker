import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../design/app_design.dart';
import 'app_card.dart';

enum StatTrend { up, down, flat }

/// One metric tile. [compact] renders transparently for use inside [StatTileRow];
/// otherwise it's a standalone [AppCard].
class StatTile extends StatelessWidget {
  final IconData? icon;
  final String value;
  final String label;
  final AccentSwatch? accent;
  final StatTrend? trend;
  final VoidCallback? onTap;
  final bool compact;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.accent,
    this.trend,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = accent ?? AccentScope.swatchOf(context);
    final tt = Theme.of(context).textTheme;

    // In a row (compact) each tile is centred within its equal-width cell, so
    // short values ("0", "0/0") sit balanced instead of hugging the left edge.
    // Standalone tiles keep their natural left alignment.
    final content = Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: s.container, borderRadius: AppRadius.brSm),
            child: Icon(icon, size: 18, color: s.onContainer),
          ),
        if (icon != null) const SizedBox(height: 10),
        // A 3-up row leaves each cell under ~100pt wide, so at large Dynamic
        // Type sizes ellipsizing shredded both lines ("0 …", "7-da…",
        // "Hydr…"). Shrink-to-fit instead: the value keeps its digits (a
        // number must never break or truncate) and the label stays readable.
        // scaleDown never enlarges, so default sizes are untouched.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: compact ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign:
                        compact ? TextAlign.center : TextAlign.start,
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (trend != null) ...[
                const SizedBox(width: 6),
                Icon(_trendIcon, size: 16, color: _trendColor(ext)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: compact ? Alignment.center : Alignment.centerLeft,
          child: Text(label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        ),
      ],
    );

    if (compact) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(child: content),
      );
    }
    return AppCard(onTap: onTap, child: content);
  }

  IconData get _trendIcon => switch (trend!) {
        StatTrend.up => Symbols.trending_up_rounded,
        StatTrend.down => Symbols.trending_down_rounded,
        StatTrend.flat => Symbols.trending_flat_rounded,
      };

  Color _trendColor(AppColorsExt ext) => switch (trend!) {
        StatTrend.up => ext.success.base,
        StatTrend.down => ext.error.base,
        StatTrend.flat => ext.textTertiary,
      };
}

/// A row of [StatTile]s inside one card, split by hairline dividers.
class StatTileRow extends StatelessWidget {
  final List<StatTile> tiles;
  const StatTileRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(Expanded(
        child: StatTile(
          value: tiles[i].value,
          label: tiles[i].label,
          icon: tiles[i].icon,
          accent: tiles[i].accent,
          trend: tiles[i].trend,
          onTap: tiles[i].onTap,
          compact: true,
        ),
      ));
      if (i != tiles.length - 1) {
        // Full-height hairline divider (IntrinsicHeight + stretch) with a small
        // vertical inset — matches the cell height instead of a floating stub.
        children.add(const SizedBox(width: 4));
        children.add(Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: ext.outline,
        ));
        children.add(const SizedBox(width: 4));
      }
    }
    return AppCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
