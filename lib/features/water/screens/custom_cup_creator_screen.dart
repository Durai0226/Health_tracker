import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';
import '../theme/aqua_theme.dart';

/// Screen for creating and customizing cups/containers
class CustomCupCreatorScreen extends StatefulWidget {
  final WaterContainer? existingContainer;

  const CustomCupCreatorScreen({super.key, this.existingContainer});

  @override
  State<CustomCupCreatorScreen> createState() => _CustomCupCreatorScreenState();
}

class _CustomCupCreatorScreenState extends State<CustomCupCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();

  String _selectedEmoji = '🥛';
  Color _selectedColor = AppPalette.info;
  bool _isSaving = false;

  // Multi-ingredient support
  final List<CupIngredient> _ingredients = [];
  bool _isMultiIngredient = false;

  /// The cup glyphs a user can pick from.
  ///
  /// emoji-content-ok: unlike every other emoji in this feature these are not
  /// chrome — the picked one is PERSISTED on the container and rendered back
  /// wherever that cup appears, so it is a user choice, not a decoration this
  /// code owns.
  ///
  /// DS-17 pruned it rather than replaced it. Gone: 🧴 (a lotion bottle), 🏃 (a
  /// runner), 🥝 (a kiwi fruit) — none of which is a vessel — and 🍺 🍷 🥃 🍹,
  /// which offered four ways to label a cup as alcohol inside a HYDRATION
  /// tracker whose own model scores alcohol at a NEGATIVE hydration factor.
  /// Alcohol is still loggable as a beverage; what it no longer gets is a
  /// promoted spot in the "make your everyday cup" picker.
  final List<String> _emojiOptions = [
    '🥛', '☕', '🍵', '🧃', '🍼', '🥤', '🫗', '🫖',
    '💧', '🧊', '🥥', '🧋', '🫧',
  ];

  /// The colours a cup can be tinted with.
  ///
  /// This was fourteen `Colors.*` constants — the only place in the feature
  /// where the Material palette was still being offered to the user. It is the
  /// app's OWN accents now, so a cup the user makes is the same blue, teal or
  /// amber as everything else on screen. The value is persisted as hex, so
  /// existing cups keep exactly the colour they were saved with.
  static const List<Color> _colorOptions = [
    AppPalette.info,
    AppPalette.water,
    AppPalette.brand,
    AppPalette.steps,
    AppPalette.success,
    AppPalette.reminders,
    AppPalette.warningStrong,
    AppPalette.period,
    AppPalette.focus,
    AppPalette.medicine,
    AppPalette.sleep,
    AppPalette.error,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingContainer != null) {
      final c = widget.existingContainer!;
      _nameController.text = c.name;
      _capacityController.text = c.capacityMl.toString();
      _selectedEmoji = c.emoji;
      if (c.colorHex != null) {
        try {
          _selectedColor = Color(int.parse(c.colorHex!.replaceFirst('#', '0xFF')));
        } catch (e) {
          debugPrint('Error parsing color: $e');
          _selectedColor = AppPalette.info;
        }
      }
    } else {
      _capacityController.text = '250';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  int get _totalCapacity {
    if (_isMultiIngredient && _ingredients.isNotEmpty) {
      return _ingredients.fold(0, (sum, i) => sum + i.amountMl);
    }
    return int.tryParse(_capacityController.text) ?? 0;
  }

  int get _effectiveHydration {
    if (_isMultiIngredient && _ingredients.isNotEmpty) {
      int totalEffective = 0;
      for (final ing in _ingredients) {
        final beverage = WaterService.getBeverage(ing.beverageId);
        if (beverage != null) {
          totalEffective += beverage.getEffectiveHydration(ing.amountMl);
        }
      }
      return totalEffective;
    }
    return int.tryParse(_capacityController.text) ?? 0;
  }

  void _snack(String message, {bool error = false}) {
    if (error) {
      context.toastError(message);
    } else {
      context.toastSuccess(message);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return; // reentrancy guard at entry — a same-frame double-tap
    // could otherwise pass validation twice before the button disables → dup cup.
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) _snack('Please enter a name', error: true);
      return;
    }

    if (name.length > 50) {
      if (mounted) _snack('Name is too long (max 50 characters)', error: true);
      return;
    }

    if (_totalCapacity <= 0) {
      if (mounted) _snack('Please enter a valid capacity', error: true);
      return;
    }

    if (_totalCapacity > 10000) {
      if (mounted) _snack('Capacity cannot exceed 10000ml', error: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final container = WaterContainer(
        id: widget.existingContainer?.id ?? const Uuid().v4(),
        name: name,
        emoji: _selectedEmoji,
        capacityMl: _totalCapacity,
        colorHex: '#${_selectedColor.value.toRadixString(16).substring(2)}',
        usageCount: widget.existingContainer?.usageCount ?? 0,
        lastUsed: widget.existingContainer?.lastUsed,
      );

      if (widget.existingContainer != null) {
        await WaterService.updateContainer(container);
        if (mounted) _snack('Cup updated successfully');
      } else {
        await WaterService.addCustomContainer(container);
        if (mounted) _snack('Cup created successfully');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving container: $e');
      if (mounted) _snack('Error: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addIngredient() {
    final beverages = WaterService.getAllBeverages();

    if (beverages.isEmpty) {
      _snack('No beverages available', error: true);
      return;
    }

    AppBottomSheet.show(
      context,
      title: 'Add Ingredient',
      icon: Symbols.local_drink_rounded,
      accent: AppColorsExt.of(context).water,
      builder: (context) => _IngredientSelector(
        beverages: beverages,
        onSelected: (beverageId, amount) {
          if (mounted) {
            setState(() {
              _ingredients.add(CupIngredient(
                beverageId: beverageId,
                amountMl: amount,
              ));
            });
          }
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    if (index >= 0 && index < _ingredients.length) {
      setState(() {
        _ingredients.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final water = ext.water;
    final isEditing = widget.existingContainer != null;

    return AppScaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            AppHeader(
              title: isEditing ? 'Edit Cup' : 'New Cup',
              leading: AppIconButton(
                icon: Symbols.close_rounded,
                accent: water,
                filled: false,
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppButton(
                  label: 'Save',
                  accent: water,
                  size: AppButtonSize.sm,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreview(ext, water),
                    const SizedBox(height: AppSpacing.xl),
                    _buildDetailsCard(ext, water),
                    const SizedBox(height: AppSpacing.lg),
                    _buildEmojiCard(ext, water),
                    const SizedBox(height: AppSpacing.lg),
                    _buildColorCard(ext, water),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCapacityCard(ext, water),
                    const SizedBox(height: AppSpacing.lg),
                    _buildMultiIngredientCard(ext, water),
                    if (_isMultiIngredient) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildIngredientsCard(ext, water),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: isEditing ? 'Save Changes' : 'Create Cup',
                      accent: water,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      loading: _isSaving,
                      leadingIcon: Symbols.check_rounded,
                      onPressed: _isSaving ? null : _save,
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

  Widget _buildPreview(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _selectedColor.withOpacity(0.12),
                borderRadius: AppRadius.brLg,
                border: Border.all(color: _selectedColor, width: 2),
              ),
              child: Center(
                // emoji-content-ok: the cup glyph the user picked, previewed at
                // the scale's largest step (42 has no slot).
                child: Text(_selectedEmoji,
                    style: Theme.of(context).textTheme.displayLarge),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _nameController.text.isEmpty ? 'Cup Name' : _nameController.text,
              style: tt.headlineSmall?.copyWith(color: ext.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_totalCapacity}ml',
              style: tt.titleMedium?.copyWith(
                color: _selectedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_isMultiIngredient && _effectiveHydration != _totalCapacity) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Effective: ${_effectiveHydration}ml',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Details',
            icon: Symbols.edit_note_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _nameController,
            label: 'Cup name',
            hint: 'e.g. My Favorite Mug',
            prefixIcon: Symbols.local_cafe_rounded,
            accent: water,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiCard(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Icon',
            icon: Symbols.emoji_emotions_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _emojiOptions.map((emoji) {
              final isSelected = emoji == _selectedEmoji;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedEmoji = emoji);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? water.container : ext.surfaceVariant,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: isSelected ? ext.mark(water) : ext.outline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    // emoji-content-ok: the persisted cup glyph, shown as the
                    // user will see it.
                    child: Text(emoji,
                        style: Theme.of(context).textTheme.displaySmall),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorCard(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Color',
            icon: Symbols.palette_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: _colorOptions.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedColor = color);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? ext.textPrimary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Symbols.check_rounded, color: _onColor(color), size: 22)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Contrast-safe check mark colour on top of an arbitrary swatch. The same
  // measured white-or-ink choice `AquaTheme.onBeverage` makes, and now the same
  // implementation rather than a second copy of the rule.
  Color _onColor(Color c) => AquaTheme.onBeverage(c);

  Widget _buildCapacityCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    if (_isMultiIngredient) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Total Capacity',
              icon: Symbols.straighten_rounded,
              accent: water,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: water.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_totalCapacity}ml',
                    style: tt.headlineMedium?.copyWith(
                      color: water.onContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'from ${_ingredients.length} ingredients',
                    style: tt.bodyMedium?.copyWith(color: water.onContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Capacity',
            icon: Symbols.straighten_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _capacityController,
            label: 'Capacity (ml)',
            hint: 'Enter capacity',
            prefixIcon: Symbols.water_drop_rounded,
            accent: water,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Enter valid amount';
              if (n > 10000) return 'Max 10000ml';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [100, 150, 250, 350, 500, 750, 1000].map((ml) {
              final selected = int.tryParse(_capacityController.text) == ml;
              return AppChip(
                label: '${ml}ml',
                selected: selected,
                accent: water,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _capacityController.text = ml.toString();
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _setMultiIngredient(bool v) {
    HapticFeedback.selectionClick();
    setState(() {
      _isMultiIngredient = v;
      if (!v) _ingredients.clear();
    });
  }

  Widget _buildMultiIngredientCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    // Row-tap toggles, one semantics node. Extracted to `_setMultiIngredient`
    // so the row and the switch cannot drift into doing different things —
    // which is the failure a row-tap handler duplicated inline invites.
    return AppCard(
      child: MergeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _setMultiIngredient(!_isMultiIngredient),
            borderRadius: AppRadius.brMd,
            child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: water.container,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(Symbols.blender_rounded, size: 20, color: water.onContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Multi-Ingredient Cup',
                    style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text('Mix different beverages for accurate hydration',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppRowMetrics.trailingGap),
          AppSwitch(
            value: _isMultiIngredient,
            onChanged: _setMultiIngredient,
            accent: water,
          ),
        ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientsCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Ingredients',
            icon: Symbols.science_rounded,
            accent: water,
            actionLabel: 'Add',
            onAction: _addIngredient,
          ),
          if (_ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'Tap "Add" to add ingredients',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ),
            )
          else
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final beverage = WaterService.getBeverage(ingredient.beverageId);

              return Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: ext.surfaceVariant,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  children: [
                    // DS-17: the ingredient's drink glyph is chrome in a
                    // tinted row — from the icon font, like every other one.
                    Icon(
                      AquaTheme.iconFor(ingredient.beverageId),
                      size: 24,
                      color: ext.mark(ext.water),
                      applyTextScaling: false,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beverage?.name ?? 'Unknown',
                            style: tt.titleSmall?.copyWith(color: ext.textPrimary),
                          ),
                          Text(
                            '${ingredient.amountMl}ml (${beverage?.hydrationPercent ?? 100}% hydration)',
                            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Symbols.remove_circle_rounded, color: ext.error.base),
                      tooltip: 'Remove ingredient',
                      onPressed: () => _removeIngredient(index),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Model for cup ingredients
class CupIngredient {
  final String beverageId;
  final int amountMl;

  CupIngredient({required this.beverageId, required this.amountMl});
}

/// Bottom sheet content for selecting ingredients
class _IngredientSelector extends StatefulWidget {
  final List<BeverageType> beverages;
  final Function(String beverageId, int amount) onSelected;

  const _IngredientSelector({
    required this.beverages,
    required this.onSelected,
  });

  @override
  State<_IngredientSelector> createState() => _IngredientSelectorState();
}

class _IngredientSelectorState extends State<_IngredientSelector> {
  BeverageType? _selectedBeverage;
  final _amountController = TextEditingController(text: '100');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    context.toastError(message);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final water = ext.water;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Beverage',
            style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.beverages.length,
            itemBuilder: (context, index) {
              final bev = widget.beverages[index];
              final isSelected = _selectedBeverage?.id == bev.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedBeverage = bev);
                },
                child: Container(
                  width: 74,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? water.container : ext.surfaceVariant,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: isSelected ? ext.mark(water) : ext.outline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AquaTheme.iconFor(bev.id),
                        size: 26,
                        color: isSelected
                            ? water.onContainer
                            : ext.textSecondary,
                        applyTextScaling: false,
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          bev.name,
                          style: tt.labelSmall?.copyWith(
                            color: isSelected
                                ? water.onContainer
                                : ext.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _amountController,
          label: 'Amount (ml)',
          accent: water,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [50, 100, 150, 200, 250].map((ml) {
            return AppChip(
              label: '${ml}ml',
              accent: water,
              onTap: () {
                HapticFeedback.selectionClick();
                _amountController.text = ml.toString();
                setState(() {});
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Add ingredient',
          accent: water,
          size: AppButtonSize.lg,
          fullWidth: true,
          leadingIcon: Symbols.add_rounded,
          onPressed: _selectedBeverage == null
              ? null
              : () {
                  final amount = int.tryParse(_amountController.text) ?? 0;
                  if (amount <= 0) {
                    _snack('Please enter a valid amount');
                    return;
                  }
                  if (amount > 5000) {
                    _snack('Amount cannot exceed 5000ml');
                    return;
                  }
                  widget.onSelected(_selectedBeverage!.id, amount);
                  Navigator.pop(context);
                },
        ),
      ],
    );
  }
}
