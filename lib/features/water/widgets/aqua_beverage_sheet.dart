import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../theme/aqua_theme.dart';
import '../models/beverage_type.dart';
import '../services/water_service.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Modern beverage selection bottom sheet (Calm Clarity chrome).
class AquaBeverageSheet extends StatefulWidget {
  final String selectedBeverageId;
  final Function(String beverageId) onSelect;

  const AquaBeverageSheet({
    super.key,
    required this.selectedBeverageId,
    required this.onSelect,
  });

  static Future<String?> show(BuildContext context, String currentBeverageId) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet.show<String>(
      context,
      title: 'Select Beverage',
      icon: Symbols.local_drink_rounded,
      accent: ext.water,
      builder: (ctx) => AquaBeverageSheet(
        selectedBeverageId: currentBeverageId,
        onSelect: (id) => Navigator.pop(ctx, id),
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // Preserve the WaterService-driven catalog (22 items, hydration %, customs).
    final beverages = WaterService.getAllBeverages();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose what you\'re drinking',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
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
      ],
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? ext.water.container : ext.surfaceVariant,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: isSelected ? ext.mark(ext.water) : ext.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              beverage.emoji,
              style: TextStyle(fontSize: isSelected ? 32 : 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              beverage.name,
              style: tt.labelMedium?.copyWith(
                color: isSelected ? ext.water.onContainer : ext.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                    ? ext.water.onContainer.withOpacity(0.15)
                    : ext.water.container,
                borderRadius: AppRadius.brFull,
              ),
              child: Text(
                '${beverage.hydrationPercent}%',
                style: tt.labelSmall?.copyWith(
                  color: isSelected ? ext.water.onContainer : ext.mark(ext.water),
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

/// Quick beverage chip for inline selection (Calm Clarity tokens).
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
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // Resolve display data from the WaterService catalog; fall back to the
    // AquaTheme lookup only for name/emoji when the id isn't in the catalog.
    final resolved = WaterService.getBeverage(beverageId);
    final String emoji;
    final String name;
    if (resolved != null) {
      emoji = resolved.emoji;
      name = resolved.name;
    } else {
      final fallback = AquaTheme.getBeverage(beverageId);
      emoji = fallback.emoji;
      name = fallback.name;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? ext.water.container : ext.surfaceVariant,
          borderRadius: AppRadius.brFull,
          border: Border.all(
            color: isSelected ? ext.mark(ext.water) : ext.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: compact ? 14 : 18),
            ),
            if (!compact || isSelected) ...[
              const SizedBox(width: 6),
              Text(
                name,
                style: tt.labelMedium?.copyWith(
                  color: isSelected ? ext.water.onContainer : ext.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
