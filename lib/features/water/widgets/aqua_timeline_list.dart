import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../theme/aqua_theme.dart';
import '../models/enhanced_water_log.dart';

/// Timeline list for today's water logs
class AquaTimelineList extends StatelessWidget {
  final List<EnhancedWaterLog> logs;
  final Function(EnhancedWaterLog)? onDelete;
  final VoidCallback? onViewAll;
  final int maxItems;

  const AquaTimelineList({
    super.key,
    required this.logs,
    this.onDelete,
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
            );
          }),
          
          if (logs.length > maxItems && onViewAll != null)
            _buildViewAllButton(context, isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AquaTheme.spacingXL),
      decoration: AquaTheme.getCardDecoration(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AquaTheme.waterPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.water_drop_rounded,
              size: 40,
              color: AquaTheme.waterPrimary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AquaTheme.spacingM),
          Text(
            'No drinks logged yet',
            style: AquaTheme.bodyMedium.copyWith(
              color: AquaTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: AquaTheme.spacingXS),
          Text(
            'Tap the buttons above to add water',
            style: AquaTheme.bodySmall.copyWith(
              color: AquaTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: onViewAll,
      child: Container(
        padding: const EdgeInsets.all(AquaTheme.spacingM),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View all ${logs.length} entries',
              style: AquaTheme.labelMedium.copyWith(
                color: AquaTheme.waterPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Symbols.arrow_forward_ios_rounded,
              size: 12,
              color: AquaTheme.waterPrimary,
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

  const _AquaTimelineItem({
    required this.log,
    required this.isLast,
    this.onDelete,
  });

  @override
  State<_AquaTimelineItem> createState() => _AquaTimelineItemState();
}

class _AquaTimelineItemState extends State<_AquaTimelineItem> {
  double _dragOffset = 0;
  bool _showDelete = false;

  String _getBeverageId(String beverageId) {
    // Map common beverage IDs to theme IDs
    final mapping = {
      'water': 'water',
      'coffee': 'coffee',
      'tea': 'tea',
      'juice': 'juice',
      'soda': 'soda',
      'milk': 'milk',
      'smoothie': 'smoothie',
      'alcohol': 'alcohol',
      'energy': 'energy',
      'energy_drink': 'energy',
    };
    return mapping[beverageId.toLowerCase()] ?? 'water';
  }

  @override
  Widget build(BuildContext context) {
    final beverageId = _getBeverageId(widget.log.beverageId);
    final beverage = AquaTheme.getBeverage(beverageId);
    final timeStr = _formatTime(widget.log.time);

    return GestureDetector(
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
                color: AquaTheme.error.withOpacity(0.1),
                child: Icon(
                  Symbols.delete_rounded,
                  color: AquaTheme.error,
                ),
              ),
            ),
          
          // Main content
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Container(
              color: AquaTheme.getCardBg(context),
              padding: const EdgeInsets.all(AquaTheme.spacingM),
              child: Row(
                children: [
                  // Timeline indicator
                  Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: beverage.gradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: beverage.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            beverage.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      if (!widget.isLast)
                        Container(
                          width: 2,
                          height: 20,
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                beverage.primary.withOpacity(0.3),
                                beverage.primary.withOpacity(0.1),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: AquaTheme.spacingM),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '+${widget.log.amountMl} ml',
                              style: AquaTheme.heading3.copyWith(
                                color: AquaTheme.getTextPrimary(context),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AquaTheme.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Symbols.check_rounded,
                                    size: 12,
                                    color: AquaTheme.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Logged',
                                    style: AquaTheme.caption.copyWith(
                                      color: AquaTheme.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$timeStr • ${widget.log.beverageName}',
                          style: AquaTheme.bodySmall.copyWith(
                            color: AquaTheme.getTextSecondary(context),
                          ),
                        ),
                        if (widget.log.effectiveHydrationMl != widget.log.amountMl) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Hydration: ${widget.log.effectiveHydrationMl} ml',
                            style: AquaTheme.caption.copyWith(
                              color: beverage.primary,
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

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
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
    final beverageId = _getBeverageId(log.beverageId);
    final beverage = AquaTheme.getBeverage(beverageId);
    final timeStr = _formatTime(log.time);

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
                gradient: beverage.gradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  beverage.emoji,
                  style: const TextStyle(fontSize: 16),
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
                    style: AquaTheme.bodyMedium.copyWith(
                      color: AquaTheme.getTextPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: AquaTheme.caption.copyWith(
                      color: AquaTheme.getTextSecondary(context),
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

  String _getBeverageId(String beverageId) {
    final mapping = {
      'water': 'water',
      'coffee': 'coffee',
      'tea': 'tea',
      'juice': 'juice',
      'soda': 'soda',
      'milk': 'milk',
      'smoothie': 'smoothie',
      'alcohol': 'alcohol',
      'energy': 'energy',
      'energy_drink': 'energy',
    };
    return mapping[beverageId.toLowerCase()] ?? 'water';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
