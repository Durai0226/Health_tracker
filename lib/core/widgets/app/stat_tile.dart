import 'package:flutter/material.dart';
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

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: s.container, borderRadius: AppRadius.brSm),
            child: Icon(icon, size: 18, color: s.onContainer),
          ),
        if (icon != null) const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (trend != null) ...[
              const SizedBox(width: 6),
              Icon(_trendIcon, size: 16, color: _trendColor(ext)),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
      ],
    );

    if (compact) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return AppCard(onTap: onTap, child: content);
  }

  IconData get _trendIcon => switch (trend!) {
        StatTrend.up => Icons.trending_up_rounded,
        StatTrend.down => Icons.trending_down_rounded,
        StatTrend.flat => Icons.trending_flat_rounded,
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
        children.add(Container(width: 1, height: 40, color: ext.outline));
        children.add(const SizedBox(width: 4));
      }
    }
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
    );
  }
}
