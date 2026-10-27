import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import '../../../core/widgets/app/app_widgets.dart';
import '../theme/aqua_theme.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';
import '../../../core/health/usual_drink.dart';

/// Quick add buttons grid for beverages
class AquaQuickAddGrid extends StatefulWidget {
  final String selectedBeverageId;
  final Function(int amount, String beverageId) onQuickAdd;
  final VoidCallback onCustomAmount;

  /// Called with the id of the beverage chip that was tapped.
  ///
  /// Found on device: this used to be a `VoidCallback` that opened the full
  /// beverage picker no matter which chip you hit, so tapping "Coffee"
  /// selected nothing — it opened a sheet and asked again. The strip renders
  /// *every* beverage, marks one `selected:` and labels it "…, select
  /// beverage", so both sighted and screen-reader users are told the chip is
  /// the selector. It has to actually be one. The picker is still reachable by
  /// tapping the hero gauge, which is where the full grid belongs.
  final ValueChanged<String> onBeverageSelect;

  /// Called when a saved container/cup chip is tapped for one-tap logging.
  final void Function(WaterContainer container)? onContainerAdd;

  /// Called to open the custom cup creator.
  final VoidCallback? onCreateCup;

  /// Called to edit or delete a cup the person made: a long press on its chip, or
  /// the screen reader's action menu. Built-in cups are not offered.
  final void Function(WaterContainer container)? onContainerManage;

  /// What the person usually drinks around now, when they have a habit — a
  /// one-tap tile above everything else. Null shows nothing.
  final UsualDrink? usual;

  /// Called with [usual] when its tile is tapped.
  final ValueChanged<UsualDrink>? onUsual;

  const AquaQuickAddGrid({
    super.key,
    required this.selectedBeverageId,
    required this.onQuickAdd,
    required this.onCustomAmount,
    required this.onBeverageSelect,
    this.onContainerAdd,
    this.onCreateCup,
    this.onContainerManage,
    this.usual,
    this.onUsual,
  });

  @override
  State<AquaQuickAddGrid> createState() => _AquaQuickAddGridState();
}

/// "Your usual · ☕ Coffee 200 ml" — one tap logs it.
class _UsualDrinkTile extends StatelessWidget {
  final UsualDrink usual;
  final ValueChanged<UsualDrink> onTap;
  const _UsualDrinkTile({required this.usual, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Log your usual: ${usual.amountMl} millilitres of ${usual.name}',
      child: AppCard(
        onTap: () => onTap(usual),
        color: ext.water.container,
        child: Row(
          children: [
            // The beverage's own icon: the water feature renders no emoji as
            // chrome (DS-17), and an icon takes the accent colour.
            Icon(AquaTheme.iconFor(usual.beverageId),
                color: ext.water.onContainer, size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your usual',
                      style: tt.labelMedium
                          ?.copyWith(color: ext.water.onContainer)),
                  Text('${usual.name} · ${usual.amountMl} ml',
                      style: tt.titleMedium?.copyWith(
                          color: ext.water.onContainer,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Symbols.add_circle_rounded, color: ext.water.onContainer),
          ],
        ),
      ),
    );
  }
}

class _AquaQuickAddGridState extends State<AquaQuickAddGrid> {
  int? _pressedIndex;

  final List<_QuickAddOption> _amounts = [
    _QuickAddOption(150, 'Small'),
    _QuickAddOption(250, 'Medium'),
    _QuickAddOption(500, 'Large'),
    _QuickAddOption(750, 'X-Large'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = WaterService.getBeverage(widget.selectedBeverageId);
    // The selected beverage now themes the whole quick-add block — the selector
    // chip, the amount cards, the custom CTA and the cups — so picking Tea turns
    // the amounts green/amber, Coffee brown, etc. (Screen chrome — gauge, app
    // bar, background, add-confirmation snackbar — stays on the water accent,
    // owned by the parent dashboard.)
    final beverage = selected != null
        ? AquaTheme.themeFromBeverage(selected)
        : AquaTheme.getBeverage(widget.selectedBeverageId);
    final isDark = AquaTheme.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.usual != null && widget.onUsual != null) ...[
          _UsualDrinkTile(usual: widget.usual!, onTap: widget.onUsual!),
          const SizedBox(height: AquaTheme.spacingM),
        ],
        // Beverage selector row (the only place the beverage color appears)
        _buildBeverageSelector(beverage, isDark),
        const SizedBox(height: AquaTheme.spacingM),

        // Quick add amount buttons — tinted by the selected beverage.
        Row(
          children: List.generate(_amounts.length, (index) {
            final option = _amounts[index];
            final isPressed = _pressedIndex == index;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < _amounts.length - 1 ? AquaTheme.spacingS : 0,
                ),
                child: _buildAmountButton(
                  option,
                  beverage,
                  isDark,
                  isPressed,
                  index,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: AquaTheme.spacingS),

        // Custom amount button
        _buildCustomAmountButton(beverage, isDark),

        // Cups / saved containers (one-tap logging + create)
        if (widget.onContainerAdd != null || widget.onCreateCup != null) ...[
          const SizedBox(height: AquaTheme.spacingM),
          _buildCupsSection(beverage, isDark),
        ],
      ],
    );
  }

  Widget _buildCupsSection(BeverageThemeData beverage, bool isDark) {
    final ext = AppColorsExt.of(context);
    // Surface custom cups first, then defaults.
    final containers = [...WaterService.getAllContainers()]
      ..sort((a, b) {
        if (a.isDefault == b.isDefault) return 0;
        return a.isDefault ? 1 : -1;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Symbols.local_cafe_rounded,
                size: 16, color: ext.mark(ext.water)),
            const SizedBox(width: 6),
            Text(
              'Cups',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: ext.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AquaTheme.spacingS),
        SizedBox(
          // A horizontal list needs a bounded height, so grow it with Dynamic
          // Type instead of clipping the chips. Never below the base 44.
          height: MediaQuery.textScalerOf(context).scale(44).clamp(44.0, 96.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: containers.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AquaTheme.spacingS),
            itemBuilder: (context, index) {
              if (index == containers.length) {
                return _buildNewCupChip(beverage, isDark);
              }
              return _buildContainerChip(containers[index], beverage, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContainerChip(
    WaterContainer container,
    BeverageThemeData beverage,
    bool isDark,
  ) {
    final ext = AppColorsExt.of(context);
    final manage = widget.onContainerManage != null && !container.isDefault
        ? () => widget.onContainerManage!(container)
        : null;
    return Semantics(
      button: true,
      label: 'Add ${container.capacityMl} millilitres from ${container.emoji} cup',
      excludeSemantics: true,
      customSemanticsActions: {
        if (manage != null)
          const CustomSemanticsAction(label: 'Edit or delete cup'): manage,
      },
      child: GestureDetector(
      onTap: widget.onContainerAdd == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onContainerAdd!(container);
            },
      onLongPress: manage == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              manage();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ext.surfaceVariant,
          borderRadius: AppRadius.brFull,
          border: Border.all(color: ext.outline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // emoji-content-ok: the user PICKED this glyph for this cup in the
            // creator and it is persisted on the container. It renders at body
            // size, is not in a decorated tile of its own, and swapping it for
            // an icon would discard their choice.
            Text(container.emoji,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(width: 6),
            Text(
              '${container.capacityMl}ml',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: ext.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildNewCupChip(BeverageThemeData beverage, bool isDark) {
    final onFill = AquaTheme.onBeverage(beverage.primary);
    return Semantics(
      button: true,
      label: 'Create new cup',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: widget.onCreateCup == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onCreateCup!();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: beverage.primary,
          borderRadius: AppRadius.brFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.add_rounded, size: 16, color: onFill),
            const SizedBox(width: 6),
            Text(
              'New Cup',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: onFill,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildBeverageSelector(BeverageThemeData beverage, bool isDark) {
    final ext = AppColorsExt.of(context);
    final beverageList = WaterService.getAllBeverages();

    return SizedBox(
      // Same as the cups strip: a bounded height that tracks Dynamic Type, so
      // the selected beverage's name isn't clipped at large text sizes.
      height: MediaQuery.textScalerOf(context).scale(50).clamp(50.0, 104.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: beverageList.length,
        itemBuilder: (context, index) {
          final bev = AquaTheme.themeFromBeverage(beverageList[index]);
          final isSelected = bev.id == widget.selectedBeverageId;

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${bev.name}, select beverage',
            excludeSemantics: true,
            child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onBeverageSelect(bev.id);
            },
            child: AnimatedContainer(
              duration: AquaTheme.animationFast,
              // 44pt floor: `vertical: 10` around the 18pt glyph lands at 38.
              // These sit in a horizontally scrolling strip, where an
              // undersized target is easiest to miss — a near-miss scrolls the
              // strip instead of selecting the beverage.
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              margin: EdgeInsets.only(
                right: AquaTheme.spacingS,
                left: index == 0 ? 0 : 0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected ? bev.primary : ext.surfaceVariant,
                borderRadius: AppRadius.brFull,
                border: Border.all(
                  color: isSelected ? Colors.transparent : ext.outline,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DS-17: an 18pt emoji inside a filled chip is chrome. The
                  // glyph comes from the icon font; the drink's identity still
                  // comes from the chip's fill.
                  Icon(
                    AquaTheme.iconFor(bev.id),
                    size: 18,
                    color: isSelected
                        ? AquaTheme.onBeverage(bev.primary)
                        : ext.textSecondary,
                    applyTextScaling: false,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      bev.name,
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: AquaTheme.onBeverage(bev.primary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildAmountButton(
    _QuickAddOption option,
    BeverageThemeData beverage,
    bool isDark,
    bool isPressed,
    int index,
  ) {
    final ext = AppColorsExt.of(context);
    return Semantics(
      button: true,
      label: 'Add ${option.amount} millilitres, ${option.label}',
      excludeSemantics: true,
      child: GestureDetector(
      onTapDown: (_) => setState(() => _pressedIndex = index),
      onTapUp: (_) {
        setState(() => _pressedIndex = null);
        HapticFeedback.mediumImpact();
        widget.onQuickAdd(option.amount, widget.selectedBeverageId);
      },
      onTapCancel: () => setState(() => _pressedIndex = null),
      child: AnimatedContainer(
        duration: AquaTheme.animationFast,
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
        // Horizontal breathing room so a scaled-down amount never sits flush
        // against the 1.5pt border of its cell.
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: AppRadius.brLg,
          border: Border.all(color: beverage.primary, width: 1.5),
          boxShadow: isPressed ? AppShadows.resting(context) : AppShadows.card(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AquaTheme.iconFor(beverage.id),
              size: 24,
              color: ext.mark(ext.water),
              applyTextScaling: false,
            ),
            const SizedBox(height: 6),
            // Four of these share a row, so each cell is ~80pt wide. At large
            // Dynamic Type sizes the amount wrapped mid-number ("+25" / "0")
            // and shoved the unit out of the tile. A number must never break:
            // shrink it to fit instead. scaleDown never enlarges, so the tile
            // is unchanged at default text sizes.
            // Was white text behind a `ShaderMask` of the beverage gradient,
            // so on a white card the amount rendered in the drink's own two
            // hues — 1.03:1 for milk. The figure is the point of the tile: it
            // reads in `textPrimary`.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '+${option.amount}',
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'ml',
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: ext.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCustomAmountButton(BeverageThemeData beverage, bool isDark) {
    final onFill = AquaTheme.onBeverage(beverage.primary);
    return Semantics(
      button: true,
      label: 'Custom amount',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onCustomAmount();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: beverage.primary,
          borderRadius: AppRadius.brMd,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.add_circle_rounded, color: onFill, size: 20),
            const SizedBox(width: 8),
            // Bound the label to the row and shrink-to-fit rather than let it
            // run off the CTA at large text sizes (scaleDown never enlarges).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Custom Amount',
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: onFill,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _QuickAddOption {
  final int amount;
  final String label;

  _QuickAddOption(this.amount, this.label);
}

/// Custom amount dialog
class AquaCustomAmountDialog extends StatefulWidget {
  final String beverageId;
  final Function(int amount) onConfirm;

  const AquaCustomAmountDialog({
    super.key,
    required this.beverageId,
    required this.onConfirm,
  });

  @override
  State<AquaCustomAmountDialog> createState() => _AquaCustomAmountDialogState();
}

class _AquaCustomAmountDialogState extends State<AquaCustomAmountDialog> {
  int _amount = 250;
  
  final List<int> _presets = [100, 200, 250, 300, 350, 400, 500, 750, 1000];

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final beverage = AquaTheme.getBeverage(widget.beverageId);
    final onFill = AquaTheme.onBeverage(beverage.primary);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AquaTheme.spacingL),
        decoration: BoxDecoration(
          color: ext.surface,
          borderRadius: AppRadius.brSheet,
          boxShadow: AppShadows.elevated(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  AquaTheme.iconFor(beverage.id),
                  size: 28,
                  color: ext.mark(ext.water),
                  applyTextScaling: false,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Amount',
                      style: tt.headlineSmall!.copyWith(color: ext.textPrimary),
                    ),
                    Text(
                      beverage.name,
                      style: tt.bodySmall!.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: AquaTheme.spacingL),
            
            // Amount display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
              decoration: BoxDecoration(
                color: ext.surfaceVariant,
                borderRadius: AppRadius.brLg,
              ),
              child: AppStepper(
                value: '$_amount',
                subLabel: 'ml',
                valueStyle: tt.displayLarge,
                accent: ext.water,
                decrementTooltip: 'Decrease by 50 ml',
                incrementTooltip: 'Increase by 50 ml',
                onDecrement: _amount <= 50
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _amount = (_amount - 50).clamp(50, 2000));
                      },
                onIncrement: _amount >= 2000
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _amount = (_amount + 50).clamp(50, 2000));
                      },
              ),
            ),
            
            const SizedBox(height: AquaTheme.spacingM),
            
            // Preset amounts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final isSelected = preset == _amount;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _amount = preset);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? beverage.primary : ext.surfaceVariant,
                      borderRadius: AppRadius.brFull,
                      border: Border.all(
                        color: isSelected ? Colors.transparent : ext.outline,
                      ),
                    ),
                    child: Text(
                      '${preset}ml',
                      style: tt.labelMedium!.copyWith(
                        color: isSelected ? onFill : ext.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: AquaTheme.spacingL),
            
            // Confirm button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onConfirm(_amount);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: beverage.primary,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Symbols.add_rounded, color: onFill),
                    const SizedBox(width: 8),
                    Text(
                      'Add $_amount ml',
                      style: tt.labelLarge!.copyWith(
                        color: onFill,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
