import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../theme/aqua_theme.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';

/// Quick add buttons grid for beverages
class AquaQuickAddGrid extends StatefulWidget {
  final String selectedBeverageId;
  final Function(int amount, String beverageId) onQuickAdd;
  final VoidCallback onCustomAmount;
  final VoidCallback onBeverageSelect;

  /// Called when a saved container/cup chip is tapped for one-tap logging.
  final void Function(WaterContainer container)? onContainerAdd;

  /// Called to open the custom cup creator.
  final VoidCallback? onCreateCup;

  const AquaQuickAddGrid({
    super.key,
    required this.selectedBeverageId,
    required this.onQuickAdd,
    required this.onCustomAmount,
    required this.onBeverageSelect,
    this.onContainerAdd,
    this.onCreateCup,
  });

  @override
  State<AquaQuickAddGrid> createState() => _AquaQuickAddGridState();
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
                  beverage.emoji,
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
            Icon(Symbols.local_cafe_rounded, size: 16, color: beverage.primary),
            const SizedBox(width: 6),
            Text(
              'Cups',
              style: AquaTheme.labelMedium.copyWith(
                color: AquaTheme.getTextSecondary(context),
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
    return Semantics(
      button: true,
      label: 'Add ${container.capacityMl} millilitres from ${container.emoji} cup',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: widget.onContainerAdd == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onContainerAdd!(container);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
          border: Border.all(
            color: beverage.primary.withOpacity(isDark ? 0.3 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(container.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              '${container.capacityMl}ml',
              style: AquaTheme.labelMedium.copyWith(
                color: AquaTheme.getTextPrimary(context),
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
          gradient: beverage.gradient,
          borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'New Cup',
              style: AquaTheme.labelMedium.copyWith(
                color: Colors.white,
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
              widget.onBeverageSelect();
            },
            child: AnimatedContainer(
              duration: AquaTheme.animationFast,
              // 44pt floor: `vertical: 10` around the emoji lands at exactly
              // 40. These sit in a horizontally scrolling strip, where an
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
                gradient: isSelected ? bev.gradient : null,
                color: isSelected 
                    ? null 
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(AquaTheme.radiusFull),
                border: Border.all(
                  color: isSelected 
                      ? Colors.transparent 
                      : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                  width: 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: bev.primary.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bev.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      bev.name,
                      style: AquaTheme.labelMedium.copyWith(
                        color: Colors.white,
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
    String emoji,
    bool isDark,
    bool isPressed,
    int index,
  ) {
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                : [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
          border: Border.all(
            color: beverage.primary.withOpacity(isDark ? 0.3 : 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: beverage.primary.withOpacity(isDark ? 0.2 : 0.1),
              blurRadius: isPressed ? 5 : 12,
              offset: Offset(0, isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 6),
            // Four of these share a row, so each cell is ~80pt wide. At large
            // Dynamic Type sizes the amount wrapped mid-number ("+25" / "0")
            // and shoved the unit out of the tile. A number must never break:
            // shrink it to fit instead. scaleDown never enlarges, so the tile
            // is unchanged at default text sizes.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                child: Text(
                  '+${option.amount}',
                  maxLines: 1,
                  softWrap: false,
                  style: AquaTheme.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'ml',
                maxLines: 1,
                softWrap: false,
                style: AquaTheme.caption.copyWith(
                  color: AquaTheme.getTextSecondary(context),
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
          gradient: beverage.gradient,
          borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: beverage.primary.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.add_circle_rounded, color: Colors.white, size: 20),
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
                  style: AquaTheme.labelLarge.copyWith(
                    color: Colors.white,
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
    final beverage = AquaTheme.getBeverage(widget.beverageId);
    final isDark = AquaTheme.isDark(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AquaTheme.spacingL),
        decoration: BoxDecoration(
          color: AquaTheme.getCardBg(context),
          borderRadius: BorderRadius.circular(AquaTheme.radiusLarge),
          boxShadow: AquaTheme.cardShadow(beverage.primary),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Text(
                  beverage.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Amount',
                      style: AquaTheme.heading2.copyWith(
                        color: AquaTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      beverage.name,
                      style: AquaTheme.bodySmall.copyWith(
                        color: beverage.primary,
                      ),
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
                gradient: LinearGradient(
                  colors: [
                    beverage.primary.withOpacity(0.1),
                    beverage.secondary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _amount = (_amount - 50).clamp(50, 2000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: beverage.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Symbols.remove_rounded, color: beverage.primary),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => beverage.gradient.createShader(bounds),
                        child: Text(
                          '$_amount',
                          style: AquaTheme.displayLarge.copyWith(
                            color: Colors.white,
                            fontSize: 42,
                          ),
                        ),
                      ),
                      Text(
                        'ml',
                        style: AquaTheme.bodyMedium.copyWith(
                          color: AquaTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _amount = (_amount + 50).clamp(50, 2000);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: beverage.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Symbols.add_rounded, color: beverage.primary),
                    ),
                  ),
                ],
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
                    ),
                    child: Text(
                      '${preset}ml',
                      style: AquaTheme.labelMedium.copyWith(
                        color: isSelected ? Colors.white : AquaTheme.getTextPrimary(context),
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
                  gradient: beverage.gradient,
                  borderRadius: BorderRadius.circular(AquaTheme.radiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: beverage.primary.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.add_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Add $_amount ml',
                      style: AquaTheme.labelLarge.copyWith(
                        color: Colors.white,
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
