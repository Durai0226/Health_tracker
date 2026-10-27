import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_design.dart';
import '../theme/aqua_theme.dart';
import '../models/enhanced_water_log.dart';

/// Timeline list for today's water logs
class AquaTimelineList extends StatelessWidget {
  final List<EnhancedWaterLog> logs;
  final Function(EnhancedWaterLog)? onDelete;

  /// Open a drink to change it. Null leaves the rows read-only.
  final ValueChanged<EnhancedWaterLog>? onEdit;
  final VoidCallback? onViewAll;
  final int maxItems;

  const AquaTimelineList({
    super.key,
    required this.logs,
    this.onDelete,
    this.onEdit,
    this.onViewAll,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final displayLogs = logs.reversed.take(maxItems).toList();

    if (displayLogs.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return Container(
      decoration: AquaTheme.getCardDecoration(context),
      child: Column(
        children: [
          ...displayLogs.asMap().entries.map((entry) {
            final index = entry.key;
            final log = entry.value;
            final isLast = index == displayLogs.length - 1;
            
            return _AquaTimelineItem(
              log: log,
              isLast: isLast,
              onDelete: onDelete != null ? () => onDelete!(log) : null,
              onTap: onEdit != null ? () => onEdit!(log) : null,
            );
          }),
          
          if (logs.length > maxItems && onViewAll != null)
            _buildViewAllButton(context, isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final ext = AppColorsExt.of(context);
    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingXL),
      decoration: AquaTheme.getCardDecoration(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ext.water.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.water_drop_rounded,
              size: 40,
              color: ext.water.onContainer,
            ),
          ),
          const SizedBox(height: AquaTheme.spacingM),
          Text(
            'No drinks logged yet',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AquaTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: AquaTheme.spacingXS),
          Text(
            'Tap the buttons above to add water',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: ext.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context, bool isDark) {
    final ext = AppColorsExt.of(context);
    return GestureDetector(
      onTap: onViewAll,
      child: Container(
        padding: const EdgeInsets.all(AquaTheme.spacingM),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: ext.outline),
          ),
        ),
        // `mainAxisSize.min` plus `Flexible` on the label. Centred is not the
        // same as bounded: both children were non-flex, so at 2.0x
        // "View all 47 entries" ran 250px past a 320pt row. The 12pt chevron
        // is the one part that must not shrink — it is the affordance.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'View all ${logs.length} entries',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: ext.mark(ext.water),
                ),
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
    );
  }
}

/// Single timeline item widget
class _AquaTimelineItem extends StatefulWidget {
  final EnhancedWaterLog log;
  final bool isLast;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _AquaTimelineItem({
    required this.log,
    required this.isLast,
    this.onDelete,
    this.onTap,
  });

  @override
  State<_AquaTimelineItem> createState() => _AquaTimelineItemState();
}

class _AquaTimelineItemState extends State<_AquaTimelineItem> {
  double _dragOffset = 0;
  bool _showDelete = false;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final timeStr = TimeOfDay.fromDateTime(widget.log.time).format(context);

    return GestureDetector(
      onTap: widget.onTap,
      onHorizontalDragUpdate: widget.onDelete != null ? (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(-80.0, 0.0);
          _showDelete = _dragOffset < -40;
        });
      } : null,
      onHorizontalDragEnd: widget.onDelete != null ? (details) {
        if (_showDelete) {
          HapticFeedback.mediumImpact();
          widget.onDelete?.call();
        }
        setState(() {
          _dragOffset = 0;
          _showDelete = false;
        });
      } : null,
      child: Stack(
        children: [
          // Delete background
          if (widget.onDelete != null)
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: ext.error.container,
                child: Icon(
                  Symbols.delete_rounded,
                  color: ext.error.onContainer,
                ),
              ),
            ),
          
          // Main content
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Container(
              color: ext.surface,
              padding: const EdgeInsets.all(AquaTheme.spacingM),
              child: Row(
                children: [
                  // Timeline indicator
                  Column(
                    children: [
                      // DS-17. The emoji, the beverage gradient and the
                      // same-hue glow all go together, and the replacement is
                      // deliberately NOT "the gradient with a white glyph": the
                      // milk gradient is #FAFAFA -> #E0E0E0, so a white icon on
                      // it measures 1.04:1. The AA-verified `container` /
                      // `onContainer` pair works in both themes, and the drink
                      // is still identified twice over — by the glyph's shape
                      // and by its name in the line below.
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ext.water.container,
                          borderRadius: AppRadius.brMd,
                        ),
                        child: Center(
                          child: Icon(
                            // The log's OWN beverage id. This used to go
                            // through a local map of ten ids that fell back to
                            // 'water', while the catalogue defines beer, wine,
                            // spirits, cocktail, espresso, the three teas,
                            // orange juice, lemonade, coconut water, sports
                            // drink, diet soda and sparkling water — none of
                            // which were in it. `AquaTheme.iconFor` has cases
                            // for all of them and its own water-drop default,
                            // so the map could only ever lose information: a
                            // beer and an espresso were both drawn as a drop of
                            // water in Today's Log.
                            AquaTheme.iconFor(widget.log.beverageId),
                            size: 22,
                            color: ext.water.onContainer,
                            applyTextScaling: false,
                          ),
                        ),
                      ),
                      if (!widget.isLast)
                        Container(
                          width: 2,
                          height: 20,
                          margin: const EdgeInsets.only(top: 8),
                          color: ext.outline,
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: AquaTheme.spacingM),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // `[Text, Spacer, badge]` — three non-flex children
                        // plus a Spacer, which absorbs slack but cannot create
                        // any. It overflowed by 34px at 320pt at the DEFAULT
                        // text size and 226px at 2.0x, once per logged drink,
                        // which was most of this screen's baselined
                        // combinations.
                        //
                        // Identical in shape to `PredictionCard`'s eyebrow row,
                        // fixed the same way: `Expanded` bounds the amount and
                        // `Flexible` lets the badge give way. The badge is the
                        // right thing to sacrifice — "Logged" is decoration
                        // beside the figure the row exists to report.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '+${widget.log.amountMl} ml',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                                  color: ext.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AquaTheme.spacingS),
                            Flexible(
                              child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ext.success.container,
                                borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Symbols.check_rounded,
                                    size: 12,
                                    color: ext.success.onContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  // The 12pt tick stays; the word gives way.
                                  // Bounding the badge alone was not enough —
                                  // its own inner Row still could not shrink,
                                  // so the overflow moved from 34px to 9.8px
                                  // and stayed.
                                  Flexible(
                                    child: Text(
                                      'Logged',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                        color: ext.success.onContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$timeStr • ${widget.log.beverageName}',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: ext.textSecondary,
                          ),
                        ),
                        if (widget.log.effectiveHydrationMl != widget.log.amountMl) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Hydration: ${widget.log.effectiveHydrationMl} ml',
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: ext.mark(ext.water),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact log entry for lists
class AquaCompactLogEntry extends StatelessWidget {
  final EnhancedWaterLog log;
  final VoidCallback? onTap;

  const AquaCompactLogEntry({
    super.key,
    required this.log,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    // W15: the app formats a drink time exactly one way — the user's own 12/24h
    // locale setting — instead of the three hand-rolled variants this feature
    // had.
    final timeStr = TimeOfDay.fromDateTime(log.time).format(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AquaTheme.spacingM,
          vertical: AquaTheme.spacingS,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ext.water.container,
                borderRadius: AppRadius.brSm,
              ),
              child: Center(
                child: Icon(
                  // Same ten-id lossy map as the timeline tile above, same
                  // removal: `AquaTheme.iconFor` already knows every catalogue
                  // id and defaults to the drop.
                  AquaTheme.iconFor(log.beverageId),
                  size: 18,
                  color: ext.water.onContainer,
                  applyTextScaling: false,
                ),
              ),
            ),
            const SizedBox(width: AquaTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.amountMl} ml ${log.beverageName}',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: ext.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
