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

  /// Whether the grid ends with a "New drink" tile, which reports [createNew].
  final bool canCreate;

  const AquaBeverageSheet({
    super.key,
    required this.selectedBeverageId,
    required this.onSelect,
    this.canCreate = false,
  });

  /// What [show] returns when the person asks to make a new drink rather than
  /// pick one. Not a drink id: callers that do not offer it never see it.
  static const String createNew = '__create_new_drink__';

  static Future<String?> show(BuildContext context, String currentBeverageId,
      {bool canCreate = false}) {
    final ext = AppColorsExt.of(context);
    return AppBottomSheet.show<String>(
      context,
      title: 'Select Beverage',
      icon: Symbols.local_drink_rounded,
      accent: ext.water,
      builder: (ctx) => AquaBeverageSheet(
        selectedBeverageId: currentBeverageId,
        onSelect: (id) => Navigator.pop(ctx, id),
        canCreate: canCreate,
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
    // The whole catalogue and the person's own drinks, the ones they log most
    // first (see [WaterService.getBeveragesByUse]).
    final beverages = WaterService.getBeveragesByUse();

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
          itemCount: beverages.length + (widget.canCreate ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == beverages.length) {
              return _NewDrinkCard(
                  key: const ValueKey('new-drink'),
                  onTap: () => widget.onSelect(AquaBeverageSheet.createNew));
            }
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

/// The last tile of the grid: make a drink of your own.
class _NewDrinkCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NewDrinkCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Create new drink',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(color: ext.mark(ext.water), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Symbols.add_rounded,
                  size: 28, color: ext.mark(ext.water), applyTextScaling: false),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'New drink',
                style: tt.labelMedium?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
            // DS-17: 28/32pt emoji inside a bordered, tinted tile is chrome.
            Icon(
              AquaTheme.iconFor(beverage.id),
              size: isSelected ? 32 : 28,
              color: isSelected ? ext.water.onContainer : ext.textSecondary,
              applyTextScaling: false,
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
    // AquaTheme lookup only for the name when the id isn't in the catalog.
    // The glyph comes from `AquaTheme.iconFor`, keyed off the same id.
    final resolved = WaterService.getBeverage(beverageId);
    final IconData icon = AquaTheme.iconFor(beverageId);
    final String name =
        resolved?.name ?? AquaTheme.getBeverage(beverageId).name;

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
            Icon(
              icon,
              size: compact ? 14 : 18,
              color: isSelected ? ext.water.onContainer : ext.textSecondary,
              applyTextScaling: false,
            ),
            if (!compact || isSelected) ...[
              const SizedBox(width: 6),
              Text(
                name,
                style: tt.labelMedium?.copyWith(
                  color: isSelected ? ext.water.onContainer : ext.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
