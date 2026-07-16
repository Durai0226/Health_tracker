import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aqua_theme.dart';
import '../models/beverage_type.dart';
import '../services/water_service.dart';

/// Modern beverage selection bottom sheet
class AquaBeverageSheet extends StatefulWidget {
  final String selectedBeverageId;
  final Function(String beverageId) onSelect;

  const AquaBeverageSheet({
    super.key,
    required this.selectedBeverageId,
    required this.onSelect,
  });

  static Future<String?> show(BuildContext context, String currentBeverageId) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AquaBeverageSheet(
        selectedBeverageId: currentBeverageId,
        onSelect: (id) => Navigator.pop(context, id),
      ),
    );
  }

  @override
  State<AquaBeverageSheet> createState() => _AquaBeverageSheetState();
}

class _AquaBeverageSheetState extends State<AquaBeverageSheet> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedBeverageId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final beverages = WaterService.getAllBeverages();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: AquaTheme.getCardBg(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AquaTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(AquaTheme.spacingL),
            child: Row(
              children: [
                const Text('🥤', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Beverage',
                      style: AquaTheme.heading2.copyWith(
                        color: AquaTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'Choose what you\'re drinking',
                      style: AquaTheme.bodySmall.copyWith(
                        color: AquaTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Beverage grid
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AquaTheme.spacingM,
                0,
                AquaTheme.spacingM,
                AquaTheme.spacingM,
              ),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: beverages.length,
              itemBuilder: (context, index) {
                final beverage = beverages[index];
                final isSelected = beverage.id == _selectedId;

                return _BeverageCard(
                  beverage: beverage,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedId = beverage.id);
                    widget.onSelect(beverage.id);
                  },
                );
              },
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + AquaTheme.spacingL),
        ],
      ),
    );
  }
}

class _BeverageCard extends StatelessWidget {
  final BeverageType beverage;
  final bool isSelected;
  final VoidCallback onTap;

  const _BeverageCard({
    required this.beverage,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AquaTheme.isDark(context);
    final style = AquaTheme.themeFromBeverage(beverage);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AquaTheme.animationFast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected ? style.gradient : null,
          color: isSelected
              ? null
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: style.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              beverage.emoji,
              style: TextStyle(fontSize: isSelected ? 32 : 28),
            ),
            const SizedBox(height: 8),
            Text(
              beverage.name,
              style: AquaTheme.labelMedium.copyWith(
                color: isSelected ? Colors.white : AquaTheme.getTextPrimary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : style.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
              ),
              child: Text(
                '${beverage.hydrationPercent}%',
                style: AquaTheme.caption.copyWith(
                  color: isSelected ? Colors.white70 : style.primary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick beverage chip for inline selection
class AquaBeverageChip extends StatelessWidget {
  final String beverageId;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const AquaBeverageChip({
    super.key,
    required this.beverageId,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = WaterService.getBeverage(beverageId);
    final beverage = resolved != null
        ? AquaTheme.themeFromBeverage(resolved)
        : AquaTheme.getBeverage(beverageId);
    final isDark = AquaTheme.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AquaTheme.animationFast,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? beverage.gradient : null,
          color: isSelected 
              ? null 
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: beverage.primary.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              beverage.emoji,
              style: TextStyle(fontSize: compact ? 14 : 18),
            ),
            if (!compact || isSelected) ...[
              const SizedBox(width: 6),
              Text(
                beverage.name,
                style: AquaTheme.labelMedium.copyWith(
                  color: isSelected ? Colors.white : AquaTheme.getTextPrimary(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
