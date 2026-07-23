import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/beverage_type.dart';
import '../models/water_container.dart';
import '../services/water_service.dart';

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
  Color _selectedColor = const Color(0xFF3B82F6);
  bool _isSaving = false;

  // Multi-ingredient support
  final List<CupIngredient> _ingredients = [];
  bool _isMultiIngredient = false;

  final List<String> _emojiOptions = [
    '🥛', '☕', '🍵', '🧃', '🧴', '🍼', '🥤', '🫗', '🫖', '🏃',
    '💧', '🧊', '🥥', '🍺', '🍷', '🥃', '🧋', '🫧', '🍹', '🥝',
  ];

  final List<Color> _colorOptions = [
    const Color(0xFF3B82F6),
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.brown,
    Colors.blueGrey,
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
          _selectedColor = const Color(0xFF3B82F6);
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
    final ext = AppColorsExt.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? ext.error.base : ext.water.base,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
    );
  }

  Future<void> _save() async {
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
      safeTop: true,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            AppHeader(
              title: isEditing ? 'Edit Cup' : 'New Cup',
              icon: Symbols.local_drink_rounded,
              accent: water,
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
                child: Text(_selectedEmoji, style: const TextStyle(fontSize: 42)),
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
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
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

  // Contrast-safe check mark color on top of an arbitrary swatch.
  Color _onColor(Color c) =>
      c.computeLuminance() > 0.5 ? const Color(0xFF1A1A1A) : Colors.white;

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

  Widget _buildMultiIngredientCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
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
          AppSwitch(
            value: _isMultiIngredient,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() {
                _isMultiIngredient = v;
                if (!v) _ingredients.clear();
              });
            },
            accent: water,
          ),
        ],
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
                    Text(
                      beverage?.emoji ?? '💧',
                      style: const TextStyle(fontSize: 24),
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
    final ext = AppColorsExt.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ext.error.base,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      ),
    );
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
                      Text(bev.emoji, style: const TextStyle(fontSize: 26)),
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
          label: 'Add Ingredient',
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
